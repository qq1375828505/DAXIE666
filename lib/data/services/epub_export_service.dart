import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/datasources/local_file_datasource.dart';
import 'package:novel_ide/data/models/chapter_model.dart';
import 'package:novel_ide/data/models/volume_model.dart';

/// EPUB 电子书导出服务
/// 直接构建 EPUB 文件结构（EPUB = ZIP + 特定目录结构）
class EpubExportService {
  /// 导出作品为 EPUB 文件，返回文件路径
  Future<String> exportNovel({
    required String novelId,
    required String novelTitle,
    Set<String>? selectedChapterIds,
  }) async {
    final db = await DatabaseHelper().database;
    final fs = LocalFileDataSource();
    final projectPath = await fs.getProjectDir(novelId, novelTitle);

    // 1. 获取卷信息
    final volumeRows = await db.query('volumes',
        where: 'novel_id = ?', whereArgs: [novelId], orderBy: 'order_index ASC');
    final volumes = volumeRows.map((r) => Volume(
      id: r['id'] as String,
      novelId: r['novel_id'] as String,
      title: r['title'] as String,
      orderIndex: r['order_index'] as int? ?? 0,
      summary: r['summary'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
    )).toList();

    // 2. 获取章节信息
    final chapterRows = await db.query('chapters',
        where: 'novel_id = ?', whereArgs: [novelId], orderBy: 'order_index ASC');
    final allChapters = chapterRows.map((r) => Chapter(
      id: r['id'] as String,
      novelId: r['novel_id'] as String,
      volumeId: r['volume_id'] as String,
      title: r['title'] as String,
      wordCount: r['word_count'] as int? ?? 0,
      status: r['status'] as String? ?? 'draft',
      orderIndex: r['order_index'] as int? ?? 0,
      summary: r['summary'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
    )).toList();

    // 筛选章节
    final chapters = selectedChapterIds != null && selectedChapterIds.isNotEmpty
        ? allChapters.where((c) => selectedChapterIds.contains(c.id)).toList()
        : allChapters;

    // 3. 构建 EPUB 内容
    final archive = Archive();
    final now = DateTime.now().toIso8601String();
    final bookId = 'urn:uuid:${novelId.hashCode.abs()}';

    // mimetype（必须是第一个文件，不压缩）
    archive.addFile(ArchiveFile.noCompress(
      'mimetype',
      20,
      utf8.encode('application/epub+zip'),
    ));

    // META-INF/container.xml
    archive.addFile(ArchiveFile(
      'META-INF/container.xml',
      _containerXml.length,
      utf8.encode(_containerXml),
    ));

    // CSS 样式
    archive.addFile(ArchiveFile(
      'OEBPS/style.css',
      _bookCss.length,
      utf8.encode(_bookCss),
    ));

    // 4. 生成章节 HTML 和 TOC
    final List<_ChapterInfo> chapterInfos = [];
    int chapterIndex = 0;

    for (final volume in volumes) {
      final volumeChapters = chapters.where((c) => c.volumeId == volume.id).toList();
      if (volumeChapters.isEmpty) continue;

      for (final chapter in volumeChapters) {
        chapterIndex++;
        final contentFile = File(p.join(projectPath, 'chapters', '${chapter.id}.md'));
        String content = '';
        if (await contentFile.exists()) {
          content = await contentFile.readAsString();
        }

        final fileName = 'chapter_$chapterIndex.xhtml';
        final html = _buildChapterHtml(chapter.title, content);

        archive.addFile(ArchiveFile(
          'OEBPS/$fileName',
          utf8.encode(html).length,
          utf8.encode(html),
        ));

        chapterInfos.add(_ChapterInfo(
          title: chapter.title,
          fileName: fileName,
          volumeTitle: volume.title,
        ));
      }
    }

    // 5. content.opf（OPF 包描述文件）
    final contentOpf = _buildContentOpf(novelTitle, bookId, now, chapterInfos);
    archive.addFile(ArchiveFile(
      'OEBPS/content.opf',
      utf8.encode(contentOpf).length,
      utf8.encode(contentOpf),
    ));

    // 6. toc.ncx（目录文件）
    final tocNcx = _buildTocNcx(novelTitle, bookId, chapterInfos);
    archive.addFile(ArchiveFile(
      'OEBPS/toc.ncx',
      utf8.encode(tocNcx).length,
      utf8.encode(tocNcx),
    ));

    // 7. 编码为 ZIP
    final zipBytes = ZipEncoder().encode(archive)!;
    final tempDir = await getTemporaryDirectory();
    final epubPath = p.join(tempDir.path, '$novelTitle.epub');
    await File(epubPath).writeAsBytes(zipBytes);

    return epubPath;
  }

  // ==================== EPUB 文件模板 ====================

  static const _containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';

  static const _bookCss = '''body { font-family: serif; line-height: 1.8; margin: 1em; color: #333; }
h1 { font-size: 1.5em; margin: 1em 0; text-align: center; border-bottom: 1px solid #ddd; padding-bottom: 0.5em; }
h2 { font-size: 1.2em; margin: 0.8em 0; color: #555; }
p { text-indent: 2em; margin: 0.5em 0; }
.volume-title { text-align: center; font-size: 1.8em; margin: 2em 0; color: #6B4EFF; }''';

  /// 构建章节 HTML
  String _buildChapterHtml(String title, String content) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html xmlns="http://www.w3.org/1999/xhtml">');
    buffer.writeln('<head>');
    buffer.writeln('  <meta charset="UTF-8" />');
    buffer.writeln('  <title>${_escape(title)}</title>');
    buffer.writeln('  <link rel="stylesheet" type="text/css" href="style.css" />');
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    buffer.writeln('  <h1>${_escape(title)}</h1>');

    final paragraphs = content.split(RegExp(r'\n\s*\n'));
    for (final para in paragraphs) {
      final trimmed = para.trim();
      if (trimmed.isNotEmpty) {
        buffer.writeln('  <p>${_escape(trimmed)}</p>');
      }
    }

    buffer.writeln('</body>');
    buffer.writeln('</html>');
    return buffer.toString();
  }

  /// 构建 content.opf
  String _buildContentOpf(String title, String bookId, String now, List<_ChapterInfo> infos) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="3.0">');
    buffer.writeln('  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">');
    buffer.writeln('    <dc:identifier id="BookId">$bookId</dc:identifier>');
    buffer.writeln('    <dc:title>${_escape(title)}</dc:title>');
    buffer.writeln('    <dc:creator>网文写作IDE</dc:creator>');
    buffer.writeln('    <dc:language>zh-CN</dc:language>');
    buffer.writeln('    <meta property="dcterms:modified">${now.substring(0, 19)}Z</meta>');
    buffer.writeln('  </metadata>');
    buffer.writeln('  <manifest>');
    buffer.writeln('    <item id="css" href="style.css" media-type="text/css" />');
    for (int i = 0; i < infos.length; i++) {
      buffer.writeln('    <item id="chapter_${i + 1}" href="${infos[i].fileName}" media-type="application/xhtml+xml" />');
    }
    buffer.writeln('    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml" />');
    buffer.writeln('  </manifest>');
    buffer.writeln('  <spine toc="ncx">');
    for (int i = 0; i < infos.length; i++) {
      buffer.writeln('    <itemref idref="chapter_${i + 1}" />');
    }
    buffer.writeln('  </spine>');
    buffer.writeln('</package>');
    return buffer.toString();
  }

  /// 构建 toc.ncx（目录）
  String _buildTocNcx(String title, String bookId, List<_ChapterInfo> infos) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">');
    buffer.writeln('  <head>');
    buffer.writeln('    <meta name="dtb:uid" content="$bookId" />');
    buffer.writeln('  </head>');
    buffer.writeln('  <docTitle><text>${_escape(title)}</text></docTitle>');
    buffer.writeln('  <navMap>');

    String? currentVolume;
    int playOrder = 0;

    for (int i = 0; i < infos.length; i++) {
      final info = infos[i];

      // 如果进入新卷，添加卷节点
      if (info.volumeTitle != currentVolume) {
        currentVolume = info.volumeTitle;
        playOrder++;
        buffer.writeln('    <navPoint id="volume_$playOrder" playOrder="$playOrder">');
        buffer.writeln('      <navLabel><text>${_escape(currentVolume)}</text></navLabel>');
        buffer.writeln('      <content src="${info.fileName}" />');
      }

      playOrder++;
      buffer.writeln('      <navPoint id="chapter_$playOrder" playOrder="$playOrder">');
      buffer.writeln('        <navLabel><text>${_escape(info.title)}</text></navLabel>');
      buffer.writeln('        <content src="${info.fileName}" />');
      buffer.writeln('      </navPoint>');

      // 如果下一章是新卷或没有下一章，关闭卷节点
      if (i + 1 >= infos.length || infos[i + 1].volumeTitle != currentVolume) {
        buffer.writeln('    </navPoint>');
      }
    }

    buffer.writeln('  </navMap>');
    buffer.writeln('</ncx>');
    return buffer.toString();
  }

  /// HTML 转义
  String _escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}

class _ChapterInfo {
  final String title;
  final String fileName;
  final String volumeTitle;
  _ChapterInfo({required this.title, required this.fileName, required this.volumeTitle});
}
