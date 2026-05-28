import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:archive/archive.dart';
import 'package:charset/charset.dart';
import 'package:epubx/epubx.dart';
import 'package:novel_ide/data/datasources/local_file_datasource.dart';
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/models/chapter_model.dart';
import 'package:novel_ide/data/models/material_models.dart';
import 'package:novel_ide/data/repositories/material_repository.dart';

/// 导入内容类型
enum ImportContentType {
  chapters,   // 正文章节（默认）
  outline,    // 大纲/总纲
  characters, // 角色卡
  settings,   // 设定
}

/// 解析后的章节（公开，供 ImportPreview 使用）
class ParsedChapter {
  final String title;
  final String content;
  ParsedChapter({required this.title, required this.content});
}

/// 导入预览结果（确认前展示）
class ImportPreview {
  final ImportContentType contentType;
  final String detectedType;
  final String matchSource;
  final List<ParsedChapter> chapters;
  final int totalWords;

  ImportPreview({
    required this.contentType,
    required this.detectedType,
    required this.matchSource,
    required this.chapters,
    required this.totalWords,
  });
}

/// 小说文件导入服务
/// 支持 TXT / MD / DOCX 格式，自动识别文件类型，拆分章节
class NovelImportService {
  static final _uuid = Uuid();

  static const int maxChapterTitleLength = 50;

  // 文件名语义关键词映射
  static const _filenameKeywords = {
    ImportContentType.outline:    ['总纲', '大纲', '纲要', '主线', 'outline'],
    ImportContentType.characters: ['角色', '人物', '人设', 'character'],
    ImportContentType.settings:   ['设定', '世界观', '背景', 'setting'],
  };

  // 内容结构特征关键词
  static const _contentOutlineMarkers = ['总纲', '主线剧情', '世界观设定', '分卷大纲', '故事线'];
  static const _contentCharacterMarkers = ['姓名：', '年龄：', '身份：', '性格：', '外貌：', '主角', '配角', '反派'];
  static const _contentSettingMarkers = ['世界观', '修炼体系', '势力分布', '魔法体系', '战力体系'];

  /// 预览导入：分析文件，返回识别结果（不写入数据库）
  Future<ImportPreview> previewImport(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('文件不存在');

    final ext = p.extension(filePath).toLowerCase();
    String content;
    switch (ext) {
      case '.txt': case '.md':
        content = await _readTextFile(file);
        break;
      case '.docx':
        content = await _readDocx(file);
        break;
      case '.epub':
        return _previewEpub(file);
      default:
        throw Exception('不支持的文件格式: $ext');
    }

    if (content.trim().isEmpty) throw Exception('文件内容为空');

    return _analyzeContent(filePath, content);
  }

  /// 分析内容类型和拆分章节（共用逻辑）
  ImportPreview _analyzeContent(String filePath, String content) {
    final fileName = p.basenameWithoutExtension(filePath);
    final detectedByFilename = _detectByFilename(fileName);
    final detectedByContent = _detectByContent(content);

    ImportContentType contentType;
    String detectedType;
    String matchSource;

    if (detectedByFilename != null) {
      contentType = detectedByFilename.key;
      detectedType = detectedByFilename.value;
      matchSource = '文件名';
    } else if (detectedByContent != null) {
      contentType = detectedByContent.key;
      detectedType = detectedByContent.value;
      matchSource = '内容结构';
    } else {
      contentType = ImportContentType.chapters;
      detectedType = '正文章节';
      matchSource = '默认';
    }

    List<ParsedChapter> chapters;
    if (contentType == ImportContentType.chapters) {
      chapters = _splitChapters(content);
      if (chapters.isEmpty) {
        chapters = [ParsedChapter(title: '导入内容', content: content.trim())];
      }
    } else {
      chapters = [ParsedChapter(title: detectedType, content: content.trim())];
    }

    final totalWords = chapters.fold<int>(0, (sum, ch) => sum + ch.content.length);

    return ImportPreview(
      contentType: contentType,
      detectedType: detectedType,
      matchSource: matchSource,
      chapters: chapters,
      totalWords: totalWords,
    );
  }

  /// 文件名语义分析
  MapEntry<ImportContentType, String>? _detectByFilename(String fileName) {
    final lower = fileName.toLowerCase();
    for (final entry in _filenameKeywords.entries) {
      for (final kw in entry.value) {
        if (lower.contains(kw.toLowerCase())) {
          final label = switch (entry.key) {
            ImportContentType.outline => '大纲/总纲',
            ImportContentType.characters => '角色卡',
            ImportContentType.settings => '设定资料',
            _ => '正文',
          };
          return MapEntry(entry.key, label);
        }
      }
    }
    return null;
  }

  /// 内容结构分析
  MapEntry<ImportContentType, String>? _detectByContent(String content) {
    int outlineScore = 0;
    int characterScore = 0;
    int settingScore = 0;

    for (final kw in _contentOutlineMarkers) {
      outlineScore += kw.allMatches(content).length;
    }
    for (final kw in _contentCharacterMarkers) {
      characterScore += kw.allMatches(content).length;
    }
    for (final kw in _contentSettingMarkers) {
      settingScore += kw.allMatches(content).length;
    }

    if (characterScore >= 3 && characterScore > outlineScore && characterScore > settingScore) {
      return const MapEntry(ImportContentType.characters, '角色卡（内容结构识别）');
    }
    if (settingScore >= 3 && settingScore > outlineScore) {
      return const MapEntry(ImportContentType.settings, '设定资料（内容结构识别）');
    }
    if (outlineScore >= 3) {
      return const MapEntry(ImportContentType.outline, '大纲/总纲（内容结构识别）');
    }
    return null;
  }

  /// 使用预览结果直接导入（避免重复读文件和检测）
  Future<ImportResult> importWithPreview({
    String? novelId,
    String? novelTitle,
    required String filePath,
    required ImportPreview preview,
    required String fileContent,
    String? volumeId,
  }) async {
    return _doImport(
      novelId: novelId,
      novelTitle: novelTitle,
      filePath: filePath,
      content: fileContent,
      contentType: preview.contentType,
      chapters: preview.chapters,
      volumeId: volumeId,
    );
  }

  /// 从文件导入（独立使用，无预览时）
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
        case '.txt': case '.md':
          content = await _readTextFile(file);
          break;
        case '.docx':
          content = await _readDocx(file);
          break;
        case '.epub':
          return _importEpub(
            novelId: novelId,
            novelTitle: novelTitle,
            filePath: filePath,
            volumeId: volumeId,
          );
        default:
          return ImportResult(success: false, error: '不支持的文件格式: $ext');
      }
    } catch (e) {
      return ImportResult(success: false, error: '文件读取失败: $e');
    }

    if (content.trim().isEmpty) {
      return ImportResult(success: false, error: '文件内容为空');
    }

    final preview = _analyzeContent(filePath, content);

    return _doImport(
      novelId: novelId,
      novelTitle: novelTitle,
      filePath: filePath,
      content: content,
      contentType: preview.contentType,
      chapters: preview.chapters,
      volumeId: volumeId,
    );
  }

  /// 实际写入数据库和文件系统
  Future<ImportResult> _doImport({
    String? novelId,
    String? novelTitle,
    required String filePath,
    required String content,
    required ImportContentType contentType,
    required List<ParsedChapter> chapters,
    String? volumeId,
  }) async {
    // 非章节类型 → 存入资料库
    if (contentType != ImportContentType.chapters) {
      return _importAsMaterial(
        novelId: novelId,
        filePath: filePath,
        content: content,
        contentType: contentType,
        detectedTitle: chapters.first.title,
      );
    }

    // 正文章节 → 存入章节表
    final db = await DatabaseHelper().database;
    final fs = LocalFileDataSource();

    String actualNovelId = novelId ?? '';
    String actualNovelTitle = novelTitle ?? '';

    if (actualNovelId.isEmpty) {
      actualNovelTitle = p.basenameWithoutExtension(filePath);
      if (actualNovelTitle.length > 50) {
        actualNovelTitle = actualNovelTitle.substring(0, 50);
      }
      actualNovelId = _uuid.v4();

      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('novels', {
        'id': actualNovelId,
        'title': actualNovelTitle,
        'author': '',
        'description': '从文件导入：${p.basename(filePath)}',
        'status': 'ongoing',
        'total_word_count': content.length,
        'chapter_count': chapters.length,
        'created_at': now,
        'updated_at': now,
      });
    }

    // 保存原始文件备份（原始不可变原则）
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final fileBytes = await file.readAsBytes();
        final fileName = p.basename(filePath);
        await fs.saveOriginalBackup(actualNovelId, fileName, fileBytes);
      }
    } catch (_) {
      // 备份失败不影响导入流程
    }

    final projectPath = await fs.getProjectDir(actualNovelId, actualNovelTitle);
    final chaptersDir = Directory(p.join(projectPath, 'chapters'));
    if (!await chaptersDir.exists()) await chaptersDir.create(recursive: true);

    final existing = await db.query('chapters',
        where: 'novel_id = ? AND volume_id = ?',
        whereArgs: [actualNovelId, volumeId ?? ''],
        orderBy: 'order_index DESC',
        limit: 1);
    int startIndex = 0;
    if (existing.isNotEmpty) {
      startIndex = (existing.first['order_index'] as int? ?? 0) + 1;
    }

    String? actualVolumeId = volumeId;
    if (actualVolumeId == null || actualVolumeId.isEmpty) {
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

      await fs.saveChapterContent(projectPath, chapterId, ch.content);
      importedCount++;
    }

    return ImportResult(
      success: true,
      chapterCount: importedCount,
      totalWords: chapters.fold(0, (sum, ch) => sum + ch.content.length),
      contentType: contentType,
    );
  }

  /// 将非章节内容（大纲/角色/设定）存入资料库
  Future<ImportResult> _importAsMaterial({
    String? novelId,
    required String filePath,
    required String content,
    required ImportContentType contentType,
    required String detectedTitle,
  }) async {
    if (novelId == null || novelId.isEmpty) {
      return ImportResult(success: false, error: '需要先选择作品才能导入资料');
    }

    final materialRepo = MaterialRepository();
    final title = '$detectedTitle - ${p.basenameWithoutExtension(filePath)}';

    switch (contentType) {
      case ImportContentType.outline:
      case ImportContentType.characters:
      case ImportContentType.settings:
        // 统一存为参考资料
        final ref = ReferenceMaterial(
          id: _uuid.v4(),
          novelId: novelId,
          title: title,
          content: content.trim(),
          source: '文件导入',
        );
        final existing = await materialRepo.getReferences(novelId);
        existing.add(ref);
        await materialRepo.saveReferences(novelId, existing);
        break;
      default:
        break;
    }

    return ImportResult(
      success: true,
      chapterCount: 0,
      totalWords: content.length,
      contentType: contentType,
    );
  }

  /// 读取 EPUB 文件并提取章节内容（纯文本）
  Future<String> _readEpubText(File file) async {
    final bytes = await file.readAsBytes();
    final book = await EpubReader.readBook(bytes);

    final buffer = StringBuffer();

    // 遍历所有章节
    if (book.Chapters != null) {
      for (final chapter in book.Chapters!) {
        final title = chapter.Title?.trim() ?? '';
        final content = _extractEpubChapterContent(chapter);
        if (content.trim().isNotEmpty) {
          if (title.isNotEmpty) {
            buffer.writeln(title);
          }
          buffer.writeln(content.trim());
          buffer.writeln();
        }
        // 递归处理子章节
        _collectSubChapters(chapter.SubChapters, buffer);
      }
    }

    return buffer.toString();
  }

  /// 递归收集子章节内容
  void _collectSubChapters(List<EpubChapter>? chapters, StringBuffer buffer) {
    if (chapters == null) return;
    for (final chapter in chapters) {
      final title = chapter.Title?.trim() ?? '';
      final content = _extractEpubChapterContent(chapter);
      if (content.trim().isNotEmpty) {
        if (title.isNotEmpty) {
          buffer.writeln(title);
        }
        buffer.writeln(content.trim());
        buffer.writeln();
      }
      _collectSubChapters(chapter.SubChapters, buffer);
    }
  }

  /// 从 EPUB 章节中提取纯文本内容
  String _extractEpubChapterContent(EpubChapter chapter) {
    final buffer = StringBuffer();

    // 读取章节的 HTML 内容
    if (chapter.HtmlContent != null && chapter.HtmlContent!.isNotEmpty) {
      buffer.write(_stripHtmlTags(chapter.HtmlContent!));
    } else if (chapter.ContentFileName != null && chapter.ContentFileName!.isNotEmpty) {
      // 尝试从 book 的 Content 中按文件名查找
      // epubx 库通常会将内容解析到 HtmlContent 中
    }

    return buffer.toString();
  }

  /// 去除 HTML 标签，提取纯文本
  String _stripHtmlTags(String html) {
    // 替换常见 HTML 实体
    String text = html
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    // 去除 script 和 style 标签及其内容
    text = text.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');

    // 将块级标签替换为换行
    text = text.replaceAll(RegExp(r'<br\s*/?\s*>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</(p|div|h[1-6]|li|tr|blockquote)>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<(p|div|h[1-6]|li|tr|blockquote)[^>]*>', caseSensitive: false), '\n');

    // 去除所有剩余 HTML 标签
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // 清理多余空行
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  /// 预览 EPUB 文件（返回 ImportPreview）
  Future<ImportPreview> _previewEpub(File file) async {
    final bytes = await file.readAsBytes();
    final book = await EpubReader.readBook(bytes);

    final chapters = <ParsedChapter>[];

    // 从 EPUB 的章节结构中提取
    if (book.Chapters != null) {
      _collectEpubChapters(book.Chapters!, chapters);
    }

    // 如果没有提取到章节，尝试读取全部文本并按标题拆分
    if (chapters.isEmpty) {
      final fullText = await _readEpubText(file);
      if (fullText.trim().isEmpty) throw Exception('EPUB 文件内容为空');
      chapters.addAll(_splitChapters(fullText));
    }

    if (chapters.isEmpty) {
      final fullText = await _readEpubText(file);
      chapters.add(ParsedChapter(title: '导入内容', content: fullText.trim()));
    }

    final totalWords = chapters.fold<int>(0, (sum, ch) => sum + ch.content.length);

    return ImportPreview(
      contentType: ImportContentType.chapters,
      detectedType: 'EPUB电子书',
      matchSource: 'EPUB章节结构',
      chapters: chapters,
      totalWords: totalWords,
    );
  }

  /// 递归收集 EPUB 章节为 ParsedChapter 列表
  void _collectEpubChapters(List<EpubChapter> epubChapters, List<ParsedChapter> result) {
    for (final chapter in epubChapters) {
      final title = chapter.Title?.trim() ?? '';
      final content = _extractEpubChapterContent(chapter).trim();

      // 如果有子章节，优先使用子章节结构
      if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
        // 如果当前章节也有内容，先添加当前章节
        if (content.isNotEmpty && title.isNotEmpty) {
          result.add(ParsedChapter(title: title, content: content));
        }
        _collectEpubChapters(chapter.SubChapters!, result);
      } else if (content.isNotEmpty) {
        // 叶子章节：有内容就添加
        result.add(ParsedChapter(
          title: title.isNotEmpty ? title : '未命名章节',
          content: content,
        ));
      }
    }
  }

  /// 导入 EPUB 文件
  Future<ImportResult> _importEpub({
    String? novelId,
    String? novelTitle,
    required String filePath,
    String? volumeId,
  }) async {
    try {
      final preview = await _previewEpub(File(filePath));
      return _doImport(
        novelId: novelId,
        novelTitle: novelTitle,
        filePath: filePath,
        content: preview.chapters.map((c) => '${c.title}\n${c.content}').join('\n\n'),
        contentType: preview.contentType,
        chapters: preview.chapters,
        volumeId: volumeId,
      );
    } catch (e) {
      return ImportResult(success: false, error: 'EPUB 解析失败: $e');
    }
  }

  /// 读取文本文件，自动检测编码（UTF-8 / GBK）
  Future<String> _readTextFile(File file) async {
    final bytes = await file.readAsBytes();
    try {
      final utf8Result = utf8.decode(bytes, allowMalformed: false);
      if (!utf8Result.contains('�')) return utf8Result;
    } catch (_) {}
    try {
      return gbk.decode(bytes);
    } catch (_) {}
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// 读取 DOCX 文件内容
  Future<String> _readDocx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return await _extractDocxText(bytes);
    } catch (e) {
      throw Exception('DOCX 解析失败: $e');
    }
  }

  /// 手动解析 DOCX（从 word/document.xml 提取文本）
  Future<String> _extractDocxText(List<int> bytes) async {
    final decoder = ZipDecoder();
    final decoded = decoder.decodeBytes(bytes);

    ArchiveFile? docXmlFile;
    for (final file in decoded) {
      if (file.name == 'word/document.xml') {
        docXmlFile = file;
        break;
      }
    }

    if (docXmlFile == null) throw Exception('无法找到 word/document.xml');

    final contentBytes = docXmlFile.content as List<int>;
    final xmlContent = utf8.decode(contentBytes, allowMalformed: true);

    final buffer = StringBuffer();
    final regex = RegExp(r'<w:t[^>]*>([^<]*)</w:t>');
    for (final match in regex.allMatches(xmlContent)) {
      buffer.write(match.group(1));
    }
    return buffer.toString();
  }

  /// 自动拆分章节
  List<ParsedChapter> _splitChapters(String content) {
    final lines = content.split('\n');
    final chapters = <ParsedChapter>[];
    final currentContent = StringBuffer();
    String currentTitle = '';
    bool hasChapter = false;

    final chapterRegex = RegExp(
      r'^(?:【)?第[零一二三四五六七八九十百千万\d]+[章节回卷集话幕](?:】)?[：:\s]?(.*)$',
    );
    final markdownHeaderRegex = RegExp(r'^(#{1,3})\s+(.+)$');
    final chapterBracketsRegex = RegExp(r'^【(.+?)】$');

    void flushChapter() {
      final text = currentContent.toString().trim();
      if (text.isNotEmpty || hasChapter) {
        chapters.add(ParsedChapter(
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

    flushChapter();

    if (chapters.isEmpty && content.trim().isNotEmpty) {
      chapters.add(ParsedChapter(title: '导入内容', content: content.trim()));
    }

    return chapters;
  }
}

/// 导入结果
class ImportResult {
  final bool success;
  final int chapterCount;
  final int totalWords;
  final ImportContentType? contentType;
  final String? error;

  ImportResult({
    required this.success,
    this.chapterCount = 0,
    this.totalWords = 0,
    this.contentType,
    this.error,
  });
}
