import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/datasources/local_file_datasource.dart';
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/repositories/material_repository.dart';
import 'package:novel_ide/data/models/chapter_model.dart';
import 'package:novel_ide/data/services/novel_memory.dart';

/// Export page - supports selective or full export as TXT.
class ExportPage extends StatefulWidget {
  final String novelId;
  final String novelTitle;

  const ExportPage({super.key, required this.novelId, required this.novelTitle});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  // Export options
  bool _exportChapters = true;
  bool _exportOutline = true;
  bool _exportCharacters = true;
  bool _exportSettings = true;
  bool _exportLocations = true;
  bool _exportFactions = true;
  bool _exportItems = true;
  bool _exportHooks = true;
  bool _exportReferences = true;
  bool _exportProjectInfo = true;

  // Chapter selection
  List<Chapter> _allChapters = [];
  Set<String> _selectedChapterIds = {};
  bool _selectAllChapters = true;
  bool _isLoadingChapters = true;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query('chapters', where: 'novel_id = ?', whereArgs: [widget.novelId], orderBy: 'order_index ASC');
    _allChapters = rows.map((r) => Chapter(
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
    _selectedChapterIds = _allChapters.map((c) => c.id).toSet();
    setState(() => _isLoadingChapters = false);
  }

  void _toggleAllChapters(bool? value) {
    setState(() {
      _selectAllChapters = value ?? true;
      if (_selectAllChapters) {
        _selectedChapterIds = _allChapters.map((c) => c.id).toSet();
      } else {
        _selectedChapterIds.clear();
      }
    });
  }

  /// Export selected data as TXT in a zip, then share.
  Future<void> _doExport() async {
    setState(() {});
    try {
      final tempDir = await getTemporaryDirectory();
      final exportDir = Directory(p.join(tempDir.path, widget.novelTitle));
      if (await exportDir.exists()) await exportDir.delete(recursive: true);
      await exportDir.create(recursive: true);

      final fs = LocalFileDataSource();
      final repo = MaterialRepository();
      final projectPath = await fs.getProjectDir(widget.novelId, widget.novelTitle);

      // 1. Project info
      if (_exportProjectInfo) {
        final infoFile = File(p.join(exportDir.path, '作品信息.txt'));
        final buffer = StringBuffer();
        buffer.writeln('作品名: ${widget.novelTitle}');
        buffer.writeln('导出时间: ${DateTime.now().toString().substring(0, 19)}');
        buffer.writeln('章节数: ${_allChapters.length}');
        final totalWords = _allChapters.fold(0, (sum, c) => sum + c.wordCount);
        buffer.writeln('总字数: $totalWords');
        buffer.writeln('已选导出章节数: ${_selectedChapterIds.length}');
        await infoFile.writeAsString(buffer.toString());
      }

      // 1.5. Novel Memory (always included)
      final memory = NovelMemory(novelId: widget.novelId, novelTitle: widget.novelTitle);
      final memoryContent = await memory.autoUpdate();
      await File(p.join(exportDir.path, '小说记忆文件.txt')).writeAsString(memoryContent);

      // 2. Chapters
      if (_exportChapters && _selectedChapterIds.isNotEmpty) {
        final chaptersDir = Directory(p.join(exportDir.path, '章节'));
        await chaptersDir.create();
        for (final chapter in _allChapters) {
          if (!_selectedChapterIds.contains(chapter.id)) continue;
          // Read content from source file
          final contentFile = File(p.join(projectPath, 'chapters', '${chapter.id}.md'));
          String content = '';
          if (await contentFile.exists()) {
            content = await contentFile.readAsString();
          }
          final safeTitle = chapter.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
          final outFile = File(p.join(chaptersDir.path, '${chapter.orderIndex.toString().padLeft(4, '0')}_$safeTitle.txt'));
          final buffer = StringBuffer();
          buffer.writeln('标题: ${chapter.title}');
          buffer.writeln('字数: ${chapter.wordCount}');
          buffer.writeln('状态: ${chapter.status}');
          buffer.writeln('---');
          buffer.writeln(content);
          await outFile.writeAsString(buffer.toString());
        }
      }

      // 3. Outline / Volumes
      if (_exportOutline) {
        // Read volume info from project source
        final volFile = File(p.join(projectPath, 'volumes.json'));
        if (await volFile.exists()) {
          final volData = await volFile.readAsString();
          final outFile = File(p.join(exportDir.path, '卷信息.txt'));
          final List volumes = jsonDecode(volData);
          final buffer = StringBuffer();
          for (final v in volumes) {
            buffer.writeln('卷: ${v['title'] ?? ''}');
            buffer.writeln('简介: ${v['summary'] ?? ''}');
            buffer.writeln('---');
          }
          await outFile.writeAsString(buffer.toString());
        }
        // Main outline (from novel description)
        final projFile = File(p.join(projectPath, 'project.json'));
        if (await projFile.exists()) {
          final projData = jsonDecode(await projFile.readAsString());
          if (projData['description'] != null && (projData['description'] as String).isNotEmpty) {
            final outFile = File(p.join(exportDir.path, '主线大纲.txt'));
            await outFile.writeAsString(projData['description']);
          }
        }
      }

      // 4. Characters
      if (_exportCharacters) {
        final chars = await repo.getCharacters(widget.novelId);
        if (chars.isNotEmpty) {
          final buffer = StringBuffer();
          for (final c in chars) {
            buffer.writeln('角色: ${c.name}');
            if (c.role != null) buffer.writeln('定位: ${c.role}');
            if (c.description != null) buffer.writeln('描述: ${c.description}');
            if (c.appearance != null) buffer.writeln('外貌: ${c.appearance}');
            if (c.personality != null) buffer.writeln('性格: ${c.personality}');
            if (c.background != null) buffer.writeln('背景: ${c.background}');
            buffer.writeln('---');
          }
          await File(p.join(exportDir.path, '角色卡.txt')).writeAsString(buffer.toString());
        }
      }

      // 5. Setting cards
      if (_exportSettings) {
        final cards = await repo.getSettingCards(widget.novelId);
        if (cards.isNotEmpty) {
          final buffer = StringBuffer();
          for (final s in cards) {
            buffer.writeln('设定: ${s.name}');
            if (s.category != null) buffer.writeln('分类: ${s.category}');
            if (s.description != null) buffer.writeln('描述: ${s.description}');
            buffer.writeln('---');
          }
          await File(p.join(exportDir.path, '设定卡.txt')).writeAsString(buffer.toString());
        }
      }

      // 6. Locations
      if (_exportLocations) {
        final locs = await repo.getLocations(widget.novelId);
        if (locs.isNotEmpty) {
          final buffer = StringBuffer();
          for (final l in locs) {
            buffer.writeln('地点: ${l.name}');
            if (l.category != null) buffer.writeln('分类: ${l.category}');
            if (l.description != null) buffer.writeln('描述: ${l.description}');
            if (l.features != null) buffer.writeln('特征: ${l.features}');
            if (l.rules != null) buffer.writeln('规则: ${l.rules}');
            buffer.writeln('---');
          }
          await File(p.join(exportDir.path, '地点.txt')).writeAsString(buffer.toString());
        }
      }

      // 7. Factions
      if (_exportFactions) {
        final factions = await repo.getFactions(widget.novelId);
        if (factions.isNotEmpty) {
          final buffer = StringBuffer();
          for (final f in factions) {
            buffer.writeln('势力: ${f.name}');
            if (f.category != null) buffer.writeln('分类: ${f.category}');
            if (f.description != null) buffer.writeln('描述: ${f.description}');
            if (f.leader != null) buffer.writeln('首领: ${f.leader}');
            if (f.strength != null) buffer.writeln('实力: ${f.strength}');
            if (f.members.isNotEmpty) buffer.writeln('成员: ${f.members.join("、")}');
            buffer.writeln('---');
          }
          await File(p.join(exportDir.path, '势力.txt')).writeAsString(buffer.toString());
        }
      }

      // 8. Items
      if (_exportItems) {
        final items = await repo.getItems(widget.novelId);
        if (items.isNotEmpty) {
          final buffer = StringBuffer();
          for (final i in items) {
            buffer.writeln('道具: ${i.name}');
            if (i.category != null) buffer.writeln('分类: ${i.category}');
            if (i.description != null) buffer.writeln('描述: ${i.description}');
            if (i.powerLevel != null) buffer.writeln('品阶: ${i.powerLevel}');
            if (i.owner != null) buffer.writeln('持有者: ${i.owner}');
            buffer.writeln('关键道具: ${i.isKeyItem ? "是" : "否"}');
            buffer.writeln('---');
          }
          await File(p.join(exportDir.path, '道具.txt')).writeAsString(buffer.toString());
        }
      }

      // 9. Plot hooks
      if (_exportHooks) {
        final hooks = await repo.getPlotHooks(widget.novelId);
        if (hooks.isNotEmpty) {
          final buffer = StringBuffer();
          for (final h in hooks) {
            buffer.writeln('伏笔: ${h.title}');
            if (h.description != null) buffer.writeln('描述: ${h.description}');
            buffer.writeln('状态: ${h.statusLabel}');
            if (h.idleChapters > 0) buffer.writeln('闲置章数: ${h.idleChapters}');
            buffer.writeln('---');
          }
          await File(p.join(exportDir.path, '伏笔.txt')).writeAsString(buffer.toString());
        }
      }

      // 10. References
      if (_exportReferences) {
        final refs = await repo.getReferences(widget.novelId);
        if (refs.isNotEmpty) {
          final buffer = StringBuffer();
          for (final r in refs) {
            buffer.writeln('标题: ${r.title}');
            if (r.content != null) buffer.writeln('内容: ${r.content}');
            if (r.source != null) buffer.writeln('来源: ${r.source}');
            if (r.sourceUrl != null) buffer.writeln('链接: ${r.sourceUrl}');
            buffer.writeln('---');
          }
          await File(p.join(exportDir.path, '参考资料.txt')).writeAsString(buffer.toString());
        }
      }

      // Create zip
      final zipPath = p.join(tempDir.path, '${widget.novelTitle}.zip');
      final encoder = ZipEncoder();
      final archive = Archive();
      await for (final entity in exportDir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = p.relative(entity.path, from: exportDir.path);
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
        }
      }
      final zipBytes = encoder.encode(archive)!;
      await File(zipPath).writeAsBytes(zipBytes);

      // Share
      final file = XFile(zipPath);
      await Share.shareXFiles([file], text: '${widget.novelTitle} 作品导出');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导出 ${_selectedChapterIds.length} 章 + 资料')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('导出 · ${widget.novelTitle}'),
        actions: [
          TextButton(
            onPressed: _isLoadingChapters ? null : _doExport,
            child: const Text('导出', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoadingChapters
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- Section: Chapters ---
                _SectionHeader(
                  title: '章节正文 (${_allChapters.length}章)',
                  trailing: Checkbox(
                    value: _selectAllChapters,
                    onChanged: _toggleAllChapters,
                  ),
                ),
                if (_exportChapters) ...[
                  // Select all / deselect all for chapters
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => _toggleAllChapters(true),
                          child: const Text('全选'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectAllChapters = false;
                              _selectedChapterIds.clear();
                            });
                          },
                          child: const Text('全不选'),
                        ),
                        const Spacer(),
                        Text('已选 ${_selectedChapterIds.length}/${_allChapters.length}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  ),
                  // Chapter list (show first 50, rest behind "show more")
                  ...List.generate(
                    _allChapters.length > 50 ? 50 : _allChapters.length,
                    (i) {
                      final ch = _allChapters[i];
                      return CheckboxListTile(
                        title: Text(ch.title, style: const TextStyle(fontSize: 14)),
                        subtitle: Text('${ch.wordCount}字 · ${ch.status}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        value: _selectedChapterIds.contains(ch.id),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedChapterIds.add(ch.id);
                            } else {
                              _selectedChapterIds.remove(ch.id);
                            }
                            _selectAllChapters = _selectedChapterIds.length == _allChapters.length;
                          });
                        },
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      );
                    },
                  ),
                  if (_allChapters.length > 50)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '还有 ${_allChapters.length - 50} 章未显示...',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ),
                ],
                const Divider(),

                // --- Section: Data files ---
                _SectionHeader(title: '作品资料'),
                _ExportTile(
                  title: '作品信息',
                  subtitle: '书名、字数、章节数',
                  icon: Icons.info_outline,
                  value: _exportProjectInfo,
                  onChanged: (v) => setState(() => _exportProjectInfo = v ?? false),
                ),
                _ExportTile(
                  title: '卷信息 + 主线大纲',
                  subtitle: '分卷结构、主线剧情',
                  icon: Icons.account_tree,
                  value: _exportOutline,
                  onChanged: (v) => setState(() => _exportOutline = v ?? false),
                ),
                _ExportTile(
                  title: '角色卡',
                  subtitle: '主角、配角、反派设定',
                  icon: Icons.person,
                  value: _exportCharacters,
                  onChanged: (v) => setState(() => _exportCharacters = v ?? false),
                ),
                _ExportTile(
                  title: '设定卡',
                  subtitle: '世界观、战力体系',
                  icon: Icons.settings,
                  value: _exportSettings,
                  onChanged: (v) => setState(() => _exportSettings = v ?? false),
                ),
                _ExportTile(
                  title: '地点',
                  subtitle: '城市、宗门、秘境',
                  icon: Icons.location_on,
                  value: _exportLocations,
                  onChanged: (v) => setState(() => _exportLocations = v ?? false),
                ),
                _ExportTile(
                  title: '势力',
                  subtitle: '门派、国家、组织',
                  icon: Icons.account_balance,
                  value: _exportFactions,
                  onChanged: (v) => setState(() => _exportFactions = v ?? false),
                ),
                _ExportTile(
                  title: '道具',
                  subtitle: '武器、法宝、丹药',
                  icon: Icons.inventory_2,
                  value: _exportItems,
                  onChanged: (v) => setState(() => _exportItems = v ?? false),
                ),
                _ExportTile(
                  title: '伏笔追踪',
                  subtitle: '伏笔状态和回收情况',
                  icon: Icons.link,
                  value: _exportHooks,
                  onChanged: (v) => setState(() => _exportHooks = v ?? false),
                ),
                _ExportTile(
                  title: '参考资料',
                  subtitle: '搜索结果、灵感笔记',
                  icon: Icons.bookmark,
                  value: _exportReferences,
                  onChanged: (v) => setState(() => _exportReferences = v ?? false),
                ),

                const SizedBox(height: 24),
                // Export button
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: Text('导出 (${_selectedChapterIds.length}章 + 资料)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isLoadingChapters ? null : _doExport,
                ),
                const SizedBox(height: 8),
                Text(
                  '导出为 ZIP 压缩包，内部文件均为 TXT 格式',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _ExportTile({required this.title, required this.subtitle, required this.icon, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      secondary: Icon(icon, size: 22, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      value: value,
      onChanged: onChanged,
      dense: true,
    );
  }
}
