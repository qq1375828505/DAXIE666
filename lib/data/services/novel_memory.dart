import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/repositories/material_repository.dart';
import 'package:novel_ide/data/models/chapter_model.dart';

/// NovelMemory: The persistent "brain" of a novel project.
/// Auto-updated on every save, loaded into AI context on every chat.
/// Similar to Claude Code's MEMORY.md - persists across sessions.
class NovelMemory {
  final String novelId;
  final String novelTitle;

  NovelMemory({required this.novelId, required this.novelTitle});

  /// Get the path to the memory file for this novel.
  Future<String> get _memoryPath async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'NovelProjects', 'memories'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return p.join(dir.path, '${novelId}_memory.txt');
  }

  /// Check if a memory file exists for this novel.
  Future<bool> exists() async {
    final path = await _memoryPath;
    return await File(path).exists();
  }

  /// Load the memory file content. Returns null if not exists.
  Future<String?> load() async {
    final path = await _memoryPath;
    final file = File(path);
    if (!await file.exists()) return null;
    return await file.readAsString();
  }

  /// Save memory content to disk.
  Future<void> save(String content) async {
    final path = await _memoryPath;
    await File(path).writeAsString(content);
  }

  /// Auto-generate and update the memory file from current data.
  /// Called after every chapter save, chapter add/delete, material change.
  Future<String> autoUpdate() async {
    final content = await _generateContent();
    await save(content);
    return content;
  }

  /// Generate the full memory content from current project state.
  Future<String> _generateContent() async {
    final buf = StringBuffer();
    final db = await DatabaseHelper().database;
    final matRepo = MaterialRepository();

    buf.writeln('╔══════════════════════════════════════════╗');
    buf.writeln('║     小说记忆文件 (Novel Memory File)      ║');
    buf.writeln('║  此文件由系统自动生成，请勿手动编辑      ║');
    buf.writeln('╚══════════════════════════════════════════╝');
    buf.writeln();

    // --- 1. Novel info ---
    buf.writeln('═══ 1. 作品信息 ═══');
    final novels = await db.query('novels', where: 'id = ?', whereArgs: [novelId]);
    if (novels.isNotEmpty) {
      final n = novels.first;
      buf.writeln('书名: $novelTitle');
      buf.writeln('分类: ${n['category'] ?? "未分类"}');
      buf.writeln('总字数: ${n['total_word_count'] ?? 0}');
      buf.writeln('总章数: ${n['chapter_count'] ?? 0}');
      final desc = n['description'] as String?;
      if (desc != null && desc.isNotEmpty) {
        buf.writeln('主线大纲: $desc');
      }
    }
    buf.writeln();

    // --- 2. Volume & Chapter structure ---
    buf.writeln('═══ 2. 卷章结构 ═══');
    final volumes = await db.query('volumes', where: 'novel_id = ?', whereArgs: [novelId], orderBy: 'order_index ASC');
    final chapters = await db.query('chapters', where: 'novel_id = ?', whereArgs: [novelId], orderBy: 'order_index ASC');

    if (volumes.isNotEmpty) {
      for (final vol in volumes) {
        buf.writeln('【${vol['title']}】');
        if (vol['summary'] != null && (vol['summary'] as String).isNotEmpty) {
          buf.writeln('  卷纲要: ${vol['summary']}');
        }
        final volChapters = chapters.where((c) => c['volume_id'] == vol['id']).toList();
        for (final ch in volChapters) {
          buf.writeln('  ${ch['order_index']}. ${ch['title']} (${ch['word_count']}字) [${ch['status']}]');
        }
        buf.writeln();
      }
    } else {
      buf.writeln('（未分卷，共${chapters.length}章）');
      for (final ch in chapters) {
        buf.writeln('  ${ch['order_index']}. ${ch['title']} (${ch['word_count']}字) [${ch['status']}]');
      }
      buf.writeln();
    }

    // --- 3. Latest 5 chapter summaries ---
    buf.writeln('═══ 3. 最近章节摘要 ═══');
    final recentChapters = chapters.length > 5 ? chapters.sublist(chapters.length - 5) : chapters;
    for (final ch in recentChapters) {
      buf.writeln('【${ch['title']}】');
      if (ch['summary'] != null && (ch['summary'] as String).isNotEmpty) {
        buf.writeln('  ${ch['summary']}');
      } else {
        buf.writeln('  （无摘要）');
      }
    }
    buf.writeln();

    // --- 4. Characters ---
    buf.writeln('═══ 4. 角色状态 ═══');
    final characters = await matRepo.getCharacters(novelId);
    if (characters.isNotEmpty) {
      for (final c in characters) {
        buf.writeln('【${c.name}】${c.role != null ? " (${c.role})" : ""}');
        if (c.description != null && c.description!.isNotEmpty) buf.writeln('  简介: ${c.description}');
        if (c.personality != null && c.personality!.isNotEmpty) buf.writeln('  性格: ${c.personality}');
        if (c.background != null && c.background!.isNotEmpty) buf.writeln('  背景: ${c.background}');
        if (c.tags.isNotEmpty) buf.writeln('  属性: ${c.tags.map((t) => "${t.key}=${t.value}").join(", ")}');
      }
    } else {
      buf.writeln('（暂无角色卡）');
    }
    buf.writeln();

    // --- 5. Settings (金手指 etc) ---
    buf.writeln('═══ 5. 设定状态 ═══');
    final settings = await matRepo.getSettingCards(novelId);
    if (settings.isNotEmpty) {
      for (final s in settings) {
        buf.writeln('【${s.name}】${s.category != null ? " (${s.category})" : ""}');
        if (s.description != null && s.description!.isNotEmpty) buf.writeln('  ${s.description}');
        if (s.tags.isNotEmpty) buf.writeln('  属性: ${s.tags.map((t) => "${t.key}=${t.value}").join(", ")}');
      }
    } else {
      buf.writeln('（暂无设定卡）');
    }
    buf.writeln();

    // --- 6. Locations ---
    buf.writeln('═══ 6. 地点 ═══');
    final locations = await matRepo.getLocations(novelId);
    if (locations.isNotEmpty) {
      for (final l in locations) {
        buf.writeln('【${l.name}】${l.category != null ? " (${l.category})" : ""}');
        if (l.description != null && l.description!.isNotEmpty) buf.writeln('  ${l.description}');
        if (l.rules != null && l.rules!.isNotEmpty) buf.writeln('  规则: ${l.rules}');
      }
    } else {
      buf.writeln('（暂无地点）');
    }
    buf.writeln();

    // --- 7. Factions ---
    buf.writeln('═══ 7. 势力 ═══');
    final factions = await matRepo.getFactions(novelId);
    if (factions.isNotEmpty) {
      for (final f in factions) {
        buf.writeln('【${f.name}】${f.category != null ? " (${f.category})" : ""}');
        if (f.description != null && f.description!.isNotEmpty) buf.writeln('  ${f.description}');
        if (f.leader != null) buf.writeln('  首领: ${f.leader}');
        if (f.members.isNotEmpty) buf.writeln('  成员: ${f.members.join("、")}');
      }
    } else {
      buf.writeln('（暂无势力）');
    }
    buf.writeln();

    // --- 8. Items ---
    buf.writeln('═══ 8. 重要道具 ═══');
    final items = await matRepo.getItems(novelId);
    if (items.isNotEmpty) {
      for (final i in items) {
        final star = i.isKeyItem ? " ⭐" : "";
        buf.writeln('【${i.name}】${i.category != null ? " (${i.category})" : ""}$star');
        if (i.description != null && i.description!.isNotEmpty) buf.writeln('  ${i.description}');
        if (i.powerLevel != null) buf.writeln('  品阶: ${i.powerLevel}');
        if (i.owner != null) buf.writeln('  持有者: ${i.owner}');
      }
    } else {
      buf.writeln('（暂无道具）');
    }
    buf.writeln();

    // --- 9. Hooks ---
    buf.writeln('═══ 9. 伏笔追踪 ═══');
    final hooks = await matRepo.getPlotHooks(novelId);
    if (hooks.isNotEmpty) {
      final unresolved = hooks.where((h) => !h.isRevealed).toList();
      final resolved = hooks.where((h) => h.isRevealed).toList();
      buf.writeln('【未回收伏笔】(${unresolved.length}条)');
      for (final h in unresolved) {
        final warn = h.idleChapters > 10 ? ' ⚠️闲置${h.idleChapters}章' : '';
        buf.writeln('  · ${h.title}$warn');
        if (h.description != null && h.description!.isNotEmpty) buf.writeln('    ${h.description}');
      }
      buf.writeln('【已回收伏笔】(${resolved.length}条)');
      for (final h in resolved) {
        buf.writeln('  ✓ ${h.title}');
      }
    } else {
      buf.writeln('（暂无伏笔）');
    }
    buf.writeln();

    // --- 10. References ---
    buf.writeln('═══ 10. 参考资料 ═══');
    final refs = await matRepo.getReferences(novelId);
    if (refs.isNotEmpty) {
      for (final r in refs) {
        buf.writeln('· ${r.title}');
        if (r.source != null) buf.writeln('  来源: ${r.source}');
      }
    } else {
      buf.writeln('（暂无参考资料）');
    }
    buf.writeln();

    buf.writeln('═══════════════════════════════════════════');
    buf.writeln('更新时间: ${DateTime.now().toString().substring(0, 19)}');
    buf.writeln('═══════════════════════════════════════════');

    return buf.toString();
  }

  // --- Singleton cache for the currently loaded memory ---
  static String? _cachedContent;
  static String? _cachedNovelId;

  /// Get memory for AI context. Returns cached version if available.
  static Future<String> getForAiContext(String novelId, String novelTitle) async {
    if (_cachedContent != null && _cachedNovelId == novelId) {
      return _cachedContent!;
    }
    final memory = NovelMemory(novelId: novelId, novelTitle: novelTitle);
    _cachedContent = await memory.autoUpdate();
    _cachedNovelId = novelId;
    return _cachedContent!;
  }

  /// Invalidate cache (call after any data change).
  static void invalidateCache() {
    _cachedContent = null;
    _cachedNovelId = null;
  }
}
