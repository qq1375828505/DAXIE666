import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/datasources/local_file_datasource.dart';

/// DOCX 文档导出服务
/// 使用 archive 库手动构建 DOCX（不引入额外依赖）
/// DOCX 本质是一个 ZIP 包，包含 XML 文件
class DocxExportService {
  Future<String> exportNovel({
    required String novelId,
    required String novelTitle,
    Set<String>? selectedChapterIds,
  }) async {
    final db = await DatabaseHelper().database;
    final fs = LocalFileDataSource();
    final projectPath = await fs.getProjectDir(novelId, novelTitle);

    final volumeRows = await db.query('volumes',
        where: 'novel_id = ?', whereArgs: [novelId], orderBy: 'order_index ASC');
    final chapterRows = await db.query('chapters',
        where: 'novel_id = ?', whereArgs: [novelId], orderBy: 'order_index ASC');

    final chapters = selectedChapterIds != null && selectedChapterIds.isNotEmpty
        ? chapterRows.where((r) => selectedChapterIds.contains(r['id'] as String)).toList()
        : chapterRows.toList();

    final paragraphs = <Map<String, dynamic>>[];
    paragraphs.add({'text': novelTitle, 'style': 'Title'});

    String? currentVolumeId;
    for (final chapter in chapters) {
      final volumeId = chapter['volume_id'] as String?;
      final chapterTitle = chapter['title'] as String;
      final chapterId = chapter['id'] as String;

      if (volumeRows.length > 1 && volumeId != currentVolumeId) {
        currentVolumeId = volumeId;
        final volumeTitle = volumeRows.firstWhere(
          (r) => r['id'] == volumeId,
          orElse: () => {'title': ''},
        )['title'] as String?;
        if (volumeTitle != null && volumeTitle.isNotEmpty) {
          paragraphs.add({'text': volumeTitle, 'style': 'Heading2'});
        }
      }

      paragraphs.add({'text': chapterTitle, 'style': 'Heading1'});

      final contentFile = File(p.join(projectPath, 'chapters', '$chapterId.md'));
      if (await contentFile.exists()) {
        final content = await contentFile.readAsString();
        final cleanContent = _stripMarkdown(content);
        final parts = cleanContent.split(RegExp(r'\n\s*\n'));
        for (final part in parts) {
          final trimmed = part.trim();
          if (trimmed.isNotEmpty) {
            paragraphs.add({'text': trimmed, 'style': 'Normal'});
          }
        }
      }
    }

    final archive = Archive();
    archive.addFile(ArchiveFile('[Content_Types].xml', _contentTypesXml.length, _contentTypesXml.codeUnits));
    archive.addFile(ArchiveFile('_rels/.rels', _relsRelsXml.length, _relsRelsXml.codeUnits));
    final bodyXml = _buildBodyXml(paragraphs);
    final documentXml = _buildDocumentXml(bodyXml);
    archive.addFile(ArchiveFile('word/document.xml', documentXml.length, documentXml.codeUnits));
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', _documentRelsXml.length, _documentRelsXml.codeUnits));
    final stylesXml = _buildStylesXml();
    archive.addFile(ArchiveFile('word/styles.xml', stylesXml.length, stylesXml.codeUnits));

    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) throw Exception('DOCX 编码失败');

    final tempDir = await getTemporaryDirectory();
    final safeTitle = novelTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final docxPath = p.join(tempDir.path, '$safeTitle.docx');
    await File(docxPath).writeAsBytes(zipData);
    return docxPath;
  }

  String _buildBodyXml(List<Map<String, dynamic>> paragraphs) {
    final buffer = StringBuffer();
    for (final p in paragraphs) {
      final text = _escapeXml(p['text'] as String);
      final style = p['style'] as String;
      buffer.writeln('<w:p>${_pPr(style)}<w:r>${_rPr(style)}<w:t xml:space="preserve">$text</w:t></w:r></w:p>');
    }
    return buffer.toString();
  }

  String _pPr(String style) {
    switch (style) {
      case 'Title': return '<w:pPr><w:jc w:val="center"/><w:spacing w:after="400"/></w:pPr>';
      case 'Heading1': return '<w:pPr><w:spacing w:before="360" w:after="200"/></w:pPr>';
      case 'Heading2': return '<w:pPr><w:jc w:val="center"/><w:spacing w:before="240" w:after="120"/></w:pPr>';
      default: return '<w:pPr><w:spacing w:line="360" w:after="200"/></w:pPr>';
    }
  }

  String _rPr(String style) {
    switch (style) {
      case 'Title': return '<w:rPr><w:sz w:val="56"/><w:szCs w:val="56"/><w:b/></w:rPr>';
      case 'Heading1': return '<w:rPr><w:sz w:val="36"/><w:szCs w:val="36"/><w:b/></w:rPr>';
      case 'Heading2': return '<w:rPr><w:sz w:val="32"/><w:szCs w:val="32"/><w:b/><w:i/></w:rPr>';
      default: return '<w:rPr><w:sz w:val="24"/><w:szCs w:val="24"/><w:rFonts w:eastAsia="宋体" w:cs="宋体"/></w:rPr>';
    }
  }

  String _buildDocumentXml(String body) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<w:body>$body<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body></w:document>';
  }

  String _buildStylesXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="宋体" w:eastAsia="宋体" w:hAnsi="宋体"/>'
        '<w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr></w:rPrDefault>'
        '<w:pPrDefault><w:pPr><w:spacing w:after="200" w:line="360"/></w:pPr></w:pPrDefault></w:docDefaults></w:styles>';
  }

  String _escapeXml(String text) => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  String _stripMarkdown(String c) => c
      .replaceAll(RegExp(r'^#{1,6}\s+'), '')
      .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'\1')
      .replaceAll(RegExp(r'\*(.+?)\*'), r'\1')
      .replaceAll(RegExp(r'~~(.+?)~~'), r'\1')
      .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '')
      .replaceAll(RegExp(r'\[(.+?)\]\(.*?\)'), r'\1')
      .replaceAll(RegExp(r'^>\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^---+$'), '')
      .replaceAll(RegExp(r'```[\s\S]*?```'), '')
      .replaceAll(RegExp(r'`(.+?)`'), r'\1');

  static const _contentTypesXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>';

  static const _relsRelsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>';

  static const _documentRelsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>';
}
