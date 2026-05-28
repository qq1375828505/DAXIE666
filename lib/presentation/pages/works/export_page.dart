import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
import 'package:novel_ide/data/services/epub_export_service.dart';

/// 树节点类型
enum TreeNodeType { folder, file }

/// 树节点
class FileTreeNode {
  final String name;
  final String path; // 相对路径
  final TreeNodeType type;
  final List<FileTreeNode> children;
  bool isSelected;
  bool isExpanded;

  FileTreeNode({
    required this.name,
    required this.path,
    required this.type,
    List<FileTreeNode>? children,
    this.isSelected = true,
    this.isExpanded = false,
  }) : children = children ?? [];

  /// 递归获取所有被选中的文件路径
  void collectSelectedFiles(List<String> result) {
    if (type == TreeNodeType.file) {
      if (isSelected) result.add(path);
    } else {
      for (final child in children) {
        child.collectSelectedFiles(result);
      }
    }
  }

  /// 搜索过滤：返回是否匹配
  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    if (type == TreeNodeType.file) {
      return name.toLowerCase().contains(query.toLowerCase());
    }
    // 文件夹：有任意子节点匹配则匹配
    return children.any((c) => c.matchesQuery(query));
  }

  /// 递归设置选中状态
  void setAllSelected(bool value) {
    isSelected = value;
    for (final child in children) {
      child.setAllSelected(value);
    }
  }

  /// 统计选中文件数
  int countSelected() {
    if (type == TreeNodeType.file) return isSelected ? 1 : 0;
    int count = 0;
    for (final child in children) {
      count += child.countSelected();
    }
    return count;
  }

  /// 统计总文件数
  int countTotal() {
    if (type == TreeNodeType.file) return 1;
    int count = 0;
    for (final child in children) {
      count += child.countTotal();
    }
    return count;
  }
}

/// 导出页面 - 工作树文件夹模式
class ExportPage extends StatefulWidget {
  final String novelId;
  final String novelTitle;

  const ExportPage({super.key, required this.novelId, required this.novelTitle});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  FileTreeNode? _worksTree;  // 作品区
  FileTreeNode? _materialsTree; // 资料区
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isExportingEpub = false;

  // 章节数据（用于生成TXT内容）
  List<Chapter> _allChapters = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final fs = LocalFileDataSource();
    final db = await DatabaseHelper().database;
    final projectPath = await fs.getProjectDir(widget.novelId, widget.novelTitle);

    // 加载章节列表
    final rows = await db.query('chapters',
        where: 'novel_id = ?', whereArgs: [widget.novelId], orderBy: 'order_index ASC');
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

    // 构建作品区树
    _worksTree = await _buildWorksTree(projectPath);

    // 构建资料区树
    _materialsTree = await _buildMaterialsTree(widget.novelId);

    if (mounted) setState(() => _isLoading = false);
  }

  /// 构建作品区文件树
  Future<FileTreeNode> _buildWorksTree(String projectPath) async {
    final root = FileTreeNode(
      name: '作品区',
      path: 'works',
      type: TreeNodeType.folder,
      isExpanded: true,
    );

    // chapters 文件夹
    final chaptersDir = Directory(p.join(projectPath, 'chapters'));
    final chaptersFolder = FileTreeNode(
      name: '章节',
      path: 'works/chapters',
      type: TreeNodeType.folder,
      isExpanded: true,
    );

    if (await chaptersDir.exists()) {
      final files = await chaptersDir.list().where((e) => e is File).toList();
      files.sort((a, b) => a.path.compareTo(b.path));
      for (final file in files) {
        final name = p.basename(file.path);
        final chapter = _allChapters.where((c) => '${c.id}.md' == name).firstOrNull;
        final displayName = chapter != null
            ? '${chapter.orderIndex.toString().padLeft(3, '0')}_${chapter.title}.txt'
            : name.replaceAll('.md', '.txt');
        chaptersFolder.children.add(FileTreeNode(
          name: displayName,
          path: 'chapters/$name',
          type: TreeNodeType.file,
        ));
      }
    }
    root.children.add(chaptersFolder);

    // 项目根目录文件
    for (final fileName in ['project.json', 'volumes.json', 'chapter_index.json']) {
      final file = File(p.join(projectPath, fileName));
      if (await file.exists()) {
        root.children.add(FileTreeNode(
          name: fileName.replaceAll('.json', '.txt'),
          path: fileName,
          type: TreeNodeType.file,
        ));
      }
    }

    return root;
  }

  /// 构建资料区文件树
  Future<FileTreeNode> _buildMaterialsTree(String novelId) async {
    final root = FileTreeNode(
      name: '资料区',
      path: 'materials',
      type: TreeNodeType.folder,
      isExpanded: true,
    );

    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final matDir = Directory(p.join(dir.path, 'NovelProjects', '资料区'));

    if (await matDir.exists()) {
      // 按类型分组
      final categories = <String, List<FileSystemEntity>>{};
      final files = await matDir.list().where((e) => e is File).toList();
      for (final file in files) {
        final name = p.basename(file.path);
        if (!name.startsWith(novelId)) continue;
        // 从文件名提取类型：{novelId}_characters.json → characters
        final type = name.replaceFirst('${novelId}_', '').replaceAll('.json', '');
        categories.putIfAbsent(type, () => []).add(file);
      }

      final categoryNames = {
        'characters': '角色',
        'settings': '设定',
        'locations': '地点',
        'factions': '势力',
        'items': '道具',
        'hooks': '伏笔',
        'references': '参考',
        'setting_reminders': '提醒',
      };

      for (final entry in categories.entries) {
        final folderName = categoryNames[entry.key] ?? entry.key;
        final folder = FileTreeNode(
          name: folderName,
          path: 'materials/${entry.key}',
          type: TreeNodeType.folder,
          isExpanded: false,
        );
        for (final file in entry.value) {
          final name = p.basename(file.path);
          folder.children.add(FileTreeNode(
            name: '${folderName}.txt',
            path: 'materials/$name',
            type: TreeNodeType.file,
          ));
        }
        root.children.add(folder);
      }
    }

    return root;
  }

  /// 全选/全不选
  void _toggleAll(bool select) {
    setState(() {
      _worksTree?.setAllSelected(select);
      _materialsTree?.setAllSelected(select);
    });
  }

  /// 执行导出（dual_track 模式）
  Future<void> _doExport({bool shareOnly = false}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final exportDir = Directory(p.join(tempDir.path, 'export_${widget.novelTitle}'));
      if (await exportDir.exists()) await exportDir.delete(recursive: true);
      await exportDir.create(recursive: true);

      final fs = LocalFileDataSource();
      final projectPath = await fs.getProjectDir(widget.novelId, widget.novelTitle);
      final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final matDir = Directory(p.join(dir.path, 'NovelProjects', '资料区'));

      // ====== workspace/ 目录：当前工作版本 ======
      final workspaceDir = Directory(p.join(exportDir.path, 'workspace'));
      await workspaceDir.create(recursive: true);

      // 收集所有选中的文件路径
      final selectedPaths = <String>[];
      _worksTree?.collectSelectedFiles(selectedPaths);
      _materialsTree?.collectSelectedFiles(selectedPaths);

      // 记录导出的工作文件路径（用于 metadata.json）
      final exportedWorkspaceFiles = <String>[];

      // 处理每个文件，转为TXT，输出到 workspace/ 下
      for (final relPath in selectedPaths) {
        String content = '';
        String outputName = '';

        if (relPath.startsWith('chapters/')) {
          // 章节文件
          final chapterFile = File(p.join(projectPath, relPath));
          if (await chapterFile.exists()) {
            final rawContent = await chapterFile.readAsString();
            final chapterId = p.basename(relPath).replaceAll('.md', '');
            final chapter = _allChapters.where((c) => c.id == chapterId).firstOrNull;
            final buf = StringBuffer();
            if (chapter != null) {
              buf.writeln('标题: ${chapter.title}');
              buf.writeln('字数: ${chapter.wordCount}');
              buf.writeln('状态: ${chapter.status}');
              buf.writeln('---');
            }
            buf.writeln(rawContent);
            content = buf.toString();
            outputName = chapter != null
                ? '作品区/章节/${chapter.orderIndex.toString().padLeft(3, '0')}_${chapter.title}.txt'
                : '作品区/章节/${p.basename(relPath).replaceAll('.md', '.txt')}';
          }
        } else if (relPath.startsWith('materials/')) {
          // 资料文件
          final fileName = p.basename(relPath);
          final matFile = File(p.join(matDir.path, fileName));
          if (await matFile.exists()) {
            final rawContent = await matFile.readAsString();
            // JSON转可读TXT
            final buf = StringBuffer();
            try {
              final list = jsonDecode(rawContent) as List<dynamic>;
              for (final item in list) {
                if (item is Map) {
                  item.forEach((key, value) {
                    if (value != null && value.toString().isNotEmpty) {
                      buf.writeln('$key: $value');
                    }
                  });
                  buf.writeln('---');
                }
              }
            } catch (_) {
              buf.writeln(rawContent);
            }
            content = buf.toString();
            final folderName = relPath.replaceFirst('materials/', '').replaceAll('.json', '');
            outputName = '资料区/$folderName/${p.basename(relPath).replaceAll('.json', '.txt')}';
          }
        } else if (relPath.endsWith('.json')) {
          // 项目根目录 JSON 文件
          final file = File(p.join(projectPath, relPath));
          if (await file.exists()) {
            final rawContent = await file.readAsString();
            final buf = StringBuffer();
            try {
              final data = jsonDecode(rawContent);
              if (data is Map) {
                data.forEach((key, value) {
                  buf.writeln('$key: $value');
                });
              } else if (data is List) {
                for (final item in data) {
                  buf.writeln(item.toString());
                  buf.writeln('---');
                }
              }
            } catch (_) {
              buf.writeln(rawContent);
            }
            content = buf.toString();
            outputName = '作品区/${relPath.replaceAll('.json', '.txt')}';
          }
        }

        if (content.isNotEmpty && outputName.isNotEmpty) {
          final outFile = File(p.join(workspaceDir.path, outputName));
          await outFile.create(recursive: true);
          await outFile.writeAsString(content);
          exportedWorkspaceFiles.add('workspace/$outputName');
        }
      }

      // 记忆包（固定导出到 workspace/ 下）
      final memory = NovelMemory(novelId: widget.novelId, novelTitle: widget.novelTitle);
      final memoryContent = await memory.autoUpdate();
      await File(p.join(workspaceDir.path, '记忆包', '小说记忆文件.txt'))
          .create(recursive: true)
          .then((f) => f.writeAsString(memoryContent));
      exportedWorkspaceFiles.add('workspace/记忆包/小说记忆文件.txt');

      // ====== original/ 目录：原始导入文件备份 ======
      final originalBaseDir = Directory(p.join(dir.path, 'NovelProjects', 'original', widget.novelId));
      final originalFilesMeta = <Map<String, String>>[];

      if (await originalBaseDir.exists()) {
        final originalEntities = await originalBaseDir.list().where((e) => e is File).toList();
        if (originalEntities.isNotEmpty) {
          final originalExportDir = Directory(p.join(exportDir.path, 'original'));
          await originalExportDir.create(recursive: true);

          for (final entity in originalEntities) {
            final file = entity as File;
            final fileName = p.basename(file.path);
            final bytes = await file.readAsBytes();
            final outFile = File(p.join(originalExportDir.path, fileName));
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(bytes);
            originalFilesMeta.add({
              'original': 'original/$fileName',
              'note': '导入的原始文件',
            });
          }
        }
      }

      // ====== metadata.json ======
      final now = DateTime.now();
      final exportTime = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}';

      final metadata = <String, dynamic>{
        'novel_title': widget.novelTitle,
        'export_time': exportTime,
        'original_files': originalFilesMeta,
        'workspace_files': {
          'chapters': 'workspace/作品区/章节/',
          'materials': 'workspace/资料区/',
          'memory': 'workspace/记忆包/',
        },
      };

      final metadataFile = File(p.join(exportDir.path, 'metadata.json'));
      await metadataFile.writeAsString(const JsonEncoder.withIndent('  ').convert(metadata));

      // ====== 创建 ZIP ======
      final zipPath = p.join(tempDir.path, '${widget.novelTitle}_导出.zip');
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

      if (shareOnly) {
        final file = XFile(zipPath);
        await Share.shareXFiles([file], text: '${widget.novelTitle} 作品导出');
      } else {
        final outputPath = await FilePicker.platform.saveFile(
          dialogTitle: '选择保存位置',
          fileName: '${widget.novelTitle}_导出.zip',
          type: FileType.custom,
          allowedExtensions: ['zip'],
          bytes: Uint8List.fromList(zipBytes),
        );
        if (outputPath != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已保存到: $outputPath')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('未选择保存位置')),
            );
          }
          return;
        }
      }

      if (mounted) {
        final totalSelected = (_worksTree?.countSelected() ?? 0) + (_materialsTree?.countSelected() ?? 0) + 1;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导出 $totalSelected 个文件（含记忆包${originalFilesMeta.isNotEmpty ? '及原始备份' : ''}）')),
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

  /// 导出为 EPUB 电子书
  Future<void> _doExportEpub() async {
    setState(() => _isExportingEpub = true);
    try {
      final service = EpubExportService();

      // 收集选中的章节ID
      final selectedPaths = <String>[];
      _worksTree?.collectSelectedFiles(selectedPaths);

      Set<String>? selectedChapterIds;
      if (selectedPaths.isNotEmpty) {
        // 从选中路径中提取章节ID
        selectedChapterIds = {};
        for (final relPath in selectedPaths) {
          if (relPath.startsWith('chapters/')) {
            final chapterId = p.basename(relPath).replaceAll('.md', '');
            selectedChapterIds.add(chapterId);
          }
        }
        // 如果没有选中任何章节，则导出全部（null）
        if (selectedChapterIds.isEmpty) selectedChapterIds = null;
      }

      final epubPath = await service.exportNovel(
        novelId: widget.novelId,
        novelTitle: widget.novelTitle,
        selectedChapterIds: selectedChapterIds,
      );

      // 读取生成的文件字节
      final epubFile = File(epubPath);
      final epubBytes = await epubFile.readAsBytes();

      // 让用户选择保存位置
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存 EPUB 电子书',
        fileName: '${widget.novelTitle}.epub',
        type: FileType.custom,
        allowedExtensions: ['epub'],
        bytes: Uint8List.fromList(epubBytes),
      );

      if (outputPath != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('EPUB 已保存到: $outputPath')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未选择保存位置')),
          );
        }
      }

      // 清理临时文件
      try {
        if (await epubFile.exists()) await epubFile.delete();
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('EPUB 导出失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingEpub = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSelected = (_worksTree?.countSelected() ?? 0) + (_materialsTree?.countSelected() ?? 0) + 1;
    final totalFiles = (_worksTree?.countTotal() ?? 0) + (_materialsTree?.countTotal() ?? 0) + 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('导出 · ${widget.novelTitle}'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => _doExport(shareOnly: false),
            child: Text('导出 ($totalSelected)', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 搜索栏
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: '搜索文件...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),

                // 全选/全不选 + 统计
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => _toggleAll(true),
                        child: const Text('全选'),
                      ),
                      TextButton(
                        onPressed: () => _toggleAll(false),
                        child: const Text('全不选'),
                      ),
                      const Spacer(),
                      Text('已选 $totalSelected/$totalFiles', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // 文件树
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    children: [
                      // 作品区
                      if (_worksTree != null) _buildTreeNode(_worksTree!, 0),
                      const SizedBox(height: 8),
                      // 资料区
                      if (_materialsTree != null) _buildTreeNode(_materialsTree!, 0),
                      const SizedBox(height: 8),
                      // 记忆包（固定导出）
                      _buildMemoryTile(),
                    ],
                  ),
                ),

                // 底部按钮
                Container(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save_alt),
                          label: Text('保存到本地 ($totalSelected项)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _isLoading ? null : () => _doExport(shareOnly: false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: _isExportingEpub
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.menu_book),
                          label: const Text('导出EPUB'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: (_isLoading || _isExportingEpub) ? null : _doExportEpub,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.share),
                          label: const Text('分享'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _isLoading ? null : () => _doExport(shareOnly: true),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// 构建文件树节点
  Widget _buildTreeNode(FileTreeNode node, int depth) {
    // 搜索过滤
    if (_searchQuery.isNotEmpty && !node.matchesQuery(_searchQuery)) {
      return const SizedBox.shrink();
    }

    if (node.type == TreeNodeType.file) {
      return _buildFileTile(node, depth);
    }

    // 文件夹
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFolderTile(node, depth),
        if (node.isExpanded)
          ...node.children.map((child) => _buildTreeNode(child, depth + 1)),
      ],
    );
  }

  Widget _buildFolderTile(FileTreeNode node, int depth) {
    final selectedCount = node.countSelected();
    final totalCount = node.countTotal();

    return InkWell(
      onTap: () => setState(() => node.isExpanded = !node.isExpanded),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.only(left: depth * 16.0, top: 6, bottom: 6, right: 4),
        child: Row(
          children: [
            Icon(
              node.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              size: 20,
              color: Colors.grey[600],
            ),
            Icon(Icons.folder, size: 18, color: Colors.amber[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(node.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            Text('$selectedCount/$totalCount', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(width: 4),
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: selectedCount == totalCount && totalCount > 0
                    ? true
                    : selectedCount == 0
                        ? false
                        : null, // 半选
                tristate: true,
                onChanged: (val) => setState(() => node.setAllSelected(val ?? true)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileTile(FileTreeNode node, int depth) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0 + 28),
      child: Row(
        children: [
          Icon(Icons.description, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(node.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: node.isSelected,
              onChanged: (val) => setState(() => node.isSelected = val ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  /// 记忆包固定导出项
  Widget _buildMemoryTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('小说记忆文件.txt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('固定导出', style: TextStyle(fontSize: 11, color: Colors.blue[700])),
          ),
          const SizedBox(width: 8),
          Icon(Icons.check_circle, size: 20, color: Colors.blue[600]),
        ],
      ),
    );
  }
}
