import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:archive/archive.dart';
import 'package:novel_ide/data/datasources/local_file_datasource.dart';
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/models/chapter_model.dart';

/// 小说文件导入服务
/// 支持 TXT / MD / DOCX 格式，自动拆分为章节
class NovelImportService {
  static final _uuid = Uuid();

  /// 导入结果
  static const int maxChapterTitleLength = 50;

  /// 从文件导入小说，自动拆分章节
  /// 如果不传入 novelId/novelTitle，会自动创建新作品
  /// 返回导入的章节数量
  Future<ImportResult> importFromFile({
    String? novelId,
    String? novelTitle,
    required String filePath,
    String? volumeId,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return ImportResult(success: false, error: '文件不存在');
    }

    final ext = p.extension(filePath).toLowerCase();
    String content;

    try {
      switch (ext) {
        case '.txt':
          content = await file.readAsString();
          break;
        case '.md':
          content = await file.readAsString();
          break;
        case '.docx':
          content = await _readDocx(file);
          break;
        default:
          return ImportResult(success: false, error: '不支持的文件格式: $ext');
      }
    } catch (e) {
      return ImportResult(success: false, error: '文件读取失败: $e');
    }

    if (content.trim().isEmpty) {
      return ImportResult(success: false, error: '文件内容为空');
    }

    // 自动拆分章节
    final chapters = _splitChapters(content);

    if (chapters.isEmpty) {
      return ImportResult(success: false, error: '未能识别到章节内容');
    }

    // 写入数据库和文件系统
    final db = await DatabaseHelper().database;
    final fs = LocalFileDataSource();

    // 如果没有传入 novelId，自动创建新作品
    String actualNovelId = novelId ?? '';
    String actualNovelTitle = novelTitle ?? '';

    if (actualNovelId.isEmpty) {
      // 从文件名提取作品标题
      actualNovelTitle = p.basenameWithoutExtension(filePath);
      if (actualNovelTitle.length > 50) {
        actualNovelTitle = actualNovelTitle.substring(0, 50);
      }
      actualNovelId = _uuid.v4();

      // 创建作品记录
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('novels', {
        'id': actualNovelId,
        'title': actualNovelTitle,
        'author': '',
        'description': '从文件导入：${p.basename(filePath)}',
        'status': 'ongoing',
        'word_count': content.length,
        'created_at': now,
        'updated_at': now,
      });
    }

    final projectPath = await fs.getProjectDir(actualNovelId, actualNovelTitle);
    final chaptersDir = Directory(p.join(projectPath, 'chapters'));
    if (!await chaptersDir.exists()) await chaptersDir.create(recursive: true);

    // 获取当前最大 order_index
    final existing = await db.query('chapters',
        where: 'novel_id = ? AND volume_id = ?',
        whereArgs: [actualNovelId, volumeId ?? ''],
        orderBy: 'order_index DESC',
        limit: 1);
    int startIndex = 0;
    if (existing.isNotEmpty) {
      startIndex = (existing.first['order_index'] as int? ?? 0) + 1;
    }

    // 如果没有 volumeId，创建一个默认卷
    String? actualVolumeId = volumeId;
    if (actualVolumeId == null || actualVolumeId.isEmpty) {
      // 查找或创建默认卷
      final volumes = await db.query('volumes',
          where: 'novel_id = ?', whereArgs: [actualNovelId],
          orderBy: 'order_index ASC');
      if (volumes.isEmpty) {
        actualVolumeId = _uuid.v4();
        await db.insert('volumes', {
          'id': actualVolumeId,
          'novel_id': actualNovelId,
          'title': '正文',
          'order_index': 0,
          'summary': '',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        actualVolumeId = volumes.first['id'] as String;
      }
    }

    int importedCount = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < chapters.length; i++) {
      final ch = chapters[i];
      final chapterId = _uuid.v4();
      final orderIndex = startIndex + i;

      // 写入数据库
      await db.insert('chapters', {
        'id': chapterId,
        'novel_id': actualNovelId,
        'volume_id': actualVolumeId,
        'title': ch.title,
        'word_count': ch.content.length,
        'status': 'draft',
        'order_index': orderIndex,
        'summary': '',
        'created_at': now,
        'updated_at': now,
      });

      // 写入文件系统
      await fs.saveChapterContent(projectPath, chapterId, ch.content);
      importedCount++;
    }

    return ImportResult(
      success: true,
      chapterCount: importedCount,
      totalWords: chapters.fold(0, (sum, ch) => sum + ch.content.length),
    );
  }

  /// 读取 DOCX 文件内容
  Future<String> _readDocx(File file) async {
    // 使用 docx_text_extractor 包
    try {
      // 动态导入避免构建时依赖
      final bytes = await file.readAsBytes();
      // 如果 docx_text_extractor 不可用，尝试手动解析
      // DOCX 本质是 ZIP，word/document.xml 包含正文
      return await _extractDocxText(bytes);
    } catch (e) {
      throw Exception('DOCX 解析失败: $e');
    }
  }

  /// 手动解析 DOCX（从 word/document.xml 提取文本）
  Future<String> _extractDocxText(List<int> bytes) async {
    final archive = Archive();
    // 使用 archive 包解压
    final decoder = ZipDecoder();
    final decoded = decoder.decodeBytes(bytes);

    String xmlContent = '';
    for (final file in decoded) {
      if (file.name == 'word/document.xml') {
        xmlContent = String.fromCharCodes(file.content);
        break;
      }
    }

    if (xmlContent.isEmpty) {
      throw Exception('无法找到 word/document.xml');
    }

    // 简单提取 <w:t> 标签中的文本
    final buffer = StringBuffer();
    final regex = RegExp(r'<w:t[^>]*>([^<]*)</w:t>');
    for (final match in regex.allMatches(xmlContent)) {
      buffer.write(match.group(1));
    }
    return buffer.toString();
  }

  /// 自动拆分章节
  /// 支持的章节标题格式：
  /// - 第X章 标题
  /// - 第X章：标题
  /// - 第X章 标题
  /// - Chapter X 标题
  /// - ### 标题 (Markdown)
  /// - ## 标题 (Markdown)
  /// - 【第X章】标题
  List<_ParsedChapter> _splitChapters(String content) {
    final lines = content.split('\n');
    final chapters = <_ParsedChapter>[];
    final currentContent = StringBuffer();
    String currentTitle = '';
    bool hasChapter = false;

    // 章节标题正则
    final chapterRegex = RegExp(
      r'^(?:【)?第[零一二三四五六七八九十百千万\d]+[章节回卷集话幕](?:】)?[：:\s]?(.*)$',
    );
    final markdownHeaderRegex = RegExp(r'^(#{1,3})\s+(.+)$');
    final chapterBracketsRegex = RegExp(r'^【(.+?)】$');

    void flushChapter() {
      final text = currentContent.toString().trim();
      if (text.isNotEmpty || hasChapter) {
        chapters.add(_ParsedChapter(
          title: currentTitle.isNotEmpty ? currentTitle : '未命名章节',
          content: text,
        ));
      }
      currentContent.clear();
      currentTitle = '';
      hasChapter = false;
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        currentContent.writeln();
        continue;
      }

      // 检查是否是章节标题
      String? matchTitle;

      final chapterMatch = chapterRegex.firstMatch(trimmed);
      if (chapterMatch != null) {
        matchTitle = trimmed;
      } else {
        final mdMatch = markdownHeaderRegex.firstMatch(trimmed);
        if (mdMatch != null && mdMatch.group(1)!.length <= 3) {
          matchTitle = mdMatch.group(2)!.trim();
        } else {
          final bracketMatch = chapterBracketsRegex.firstMatch(trimmed);
          if (bracketMatch != null) {
            matchTitle = bracketMatch.group(1)!.trim();
          }
        }
      }

      if (matchTitle != null && matchTitle.length <= maxChapterTitleLength) {
        // 找到新章节标题，先保存之前的章节
        if (currentContent.toString().trim().isNotEmpty || hasChapter) {
          flushChapter();
        }
        currentTitle = matchTitle.length > maxChapterTitleLength
            ? matchTitle.substring(0, maxChapterTitleLength)
            : matchTitle;
        hasChapter = true;
      } else {
        currentContent.writeln(line);
      }
    }

    // 保存最后一个章节
    flushChapter();

    // 如果没有识别到任何章节标题，把整个内容作为一个章节
    if (chapters.isEmpty && content.trim().isNotEmpty) {
      chapters.add(_ParsedChapter(
        title: '导入内容',
        content: content.trim(),
      ));
    }

    return chapters;
  }
}

/// 解析后的章节
class _ParsedChapter {
  final String title;
  final String content;
  _ParsedChapter({required this.title, required this.content});
}

/// 导入结果
class ImportResult {
  final bool success;
  final int chapterCount;
  final int totalWords;
  final String? error;

  ImportResult({
    required this.success,
    this.chapterCount = 0,
    this.totalWords = 0,
    this.error,
  });
}
