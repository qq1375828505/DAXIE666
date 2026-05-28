import 'dart:io';
import 'package:docx_creator/docx_creator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/datasources/local_file_datasource.dart';

/// DOCX 文档导出服务
/// 将小说章节导出为 Word 文档（使用 docx_creator 库，支持 Markdown 解析）
class DocxExportService {
  /// 导出作品为 DOCX 文件，返回文件路径
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

    // 2. 获取章节信息
    final chapterRows = await db.query('chapters',
        where: 'novel_id = ?', whereArgs: [novelId], orderBy: 'order_index ASC');

    // 筛选章节
    final chapters = selectedChapterIds != null && selectedChapterIds.isNotEmpty
        ? chapterRows.where((r) => selectedChapterIds.contains(r['id'] as String)).toList()
        : chapterRows.toList();

    // 3. 构建 DOCX 文档（使用 fluent API）
    final builder = docx()
      .h1(novelTitle, align: DocxAlign.center)
      .p('');

    // 4. 按卷分组添加章节
    String? currentVolumeId;
    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final volumeId = chapter['volume_id'] as String?;
      final chapterTitle = chapter['title'] as String;
      final chapterId = chapter['id'] as String;

      // 如果有多个卷，在卷切换时添加卷标题
      if (volumeRows.length > 1 && volumeId != currentVolumeId) {
        currentVolumeId = volumeId;
        final volumeTitle = volumeRows.firstWhere(
          (r) => r['id'] == volumeId,
          orElse: () => {'title': ''},
        )['title'] as String?;
        if (volumeTitle != null && volumeTitle.isNotEmpty) {
          builder.h2(volumeTitle, align: DocxAlign.center).p('');
        }
      }

      // 读取章节内容（Markdown格式）
      final contentFile = File(p.join(projectPath, 'chapters', '$chapterId.md'));
      String content = '';
      if (await contentFile.exists()) {
        content = await contentFile.readAsString();
      }

      // 章节标题
      builder.h2(chapterTitle);

      // 章节正文（使用 Markdown 解析器，保留格式）
      if (content.trim().isNotEmpty) {
        try {
          final elements = await MarkdownParser.parse(content);
          for (final element in elements) {
            builder.add(element);
          }
        } catch (_) {
          // Markdown 解析失败，降级为纯文本
          final paragraphs = content.split(RegExp(r'\n\s*\n'));
          for (final para in paragraphs) {
            final trimmed = para.trim();
            if (trimmed.isNotEmpty) {
              builder.p(trimmed);
            }
          }
        }
      }

      // 章节之间空行
      builder.p('');
    }

    // 5. 生成 DOCX 文件
    final doc = builder.build();
    final bytes = await DocxExporter().exportToBytes(doc);

    // 6. 保存到临时目录
    final tempDir = await getTemporaryDirectory();
    // 清理文件名中的非法字符
    final safeTitle = novelTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final docxPath = p.join(tempDir.path, '$safeTitle.docx');
    await File(docxPath).writeAsBytes(bytes);

    return docxPath;
  }
}
