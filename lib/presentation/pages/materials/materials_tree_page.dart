import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/material_models.dart';
import 'package:novel_ide/data/models/chapter_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/repositories/material_repository.dart';
import 'package:novel_ide/data/services/novel_memory.dart';
import 'package:novel_ide/data/services/outline_generator_service.dart';
import 'package:uuid/uuid.dart';
import 'package:novel_ide/presentation/widgets/file_tree_view.dart';
import 'package:novel_ide/presentation/pages/works/export_page.dart' hide FileTreeNode;
import 'package:novel_ide/presentation/pages/materials/material_editor_page.dart';
import 'package:novel_ide/presentation/pages/materials/relationship_graph_page.dart';



/// 新版资料库页面 - 层级文件树展示
class MaterialsTreePage extends ConsumerStatefulWidget {
  const MaterialsTreePage({super.key});

  @override
  ConsumerState<MaterialsTreePage> createState() => _MaterialsTreePageState();
}

class _MaterialsTreePageState extends ConsumerState<MaterialsTreePage> {
  // 树节点展开状态
  final Set<String> _expandedNodes = {'角色', '设定', '地点', '势力', '道具', '伏笔', '参考', '记忆'};
  // 记忆包内容
  String _memoryContent = '';
  // AI大纲生成
  bool _isGeneratingOutline = false;
  List<OutlineNode> _outlineNodes = [];

  @override
  void initState() {
    super.initState();
    _loadMemory();
    // 关键修复：切到资料Tab时加载材料数据，否则页面为空
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final novel = ref.read(selectedNovelProvider);
      if (novel != null) {
        loadNovelMaterials(ref, novel.id);
        _loadCustomFolders(novel.id);
      }
    });
  }

  Future<void> _loadCustomFolders(String novelId) async {
    final folders = await MaterialRepository().getCustomFolders(novelId);
    if (mounted) {
      ref.read(customFoldersProvider.notifier).state = folders;
    }
  }

  Future<void> _persistCustomFolders() async {
    final novelId = ref.read(selectedNovelProvider)?.id;
    if (novelId == null) return;
    await MaterialRepository().saveCustomFolders(novelId, ref.read(customFoldersProvider));
  }

  Future<void> _loadMemory() async {
    final selectedNovel = ref.read(selectedNovelProvider);
    if (selectedNovel == null) return;
    final memory = NovelMemory(novelId: selectedNovel.id, novelTitle: selectedNovel.title);
    final content = await memory.autoUpdate();
    if (mounted) {
      setState(() {
        _memoryContent = content;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedNovel = ref.watch(selectedNovelProvider);
    
    if (selectedNovel == null) {
      return _buildEmptyState();
    }

    // 获取各类数据
    final characters = ref.watch(charactersProvider(selectedNovel.id));
    final settings = ref.watch(settingCardsProvider(selectedNovel.id));
    final locations = ref.watch(locationsProvider(selectedNovel.id));
    final factions = ref.watch(factionsProvider(selectedNovel.id));
    final items = ref.watch(itemsProvider(selectedNovel.id));
    final hooks = ref.watch(plotHooksProvider(selectedNovel.id));
    final references = ref.watch(referencesProvider(selectedNovel.id));
    final customFolders = ref.watch(customFoldersProvider);

    // 构建文件树
    final treeNodes = _buildFileTree(
      characters: characters,
      settings: settings,
      locations: locations,
      factions: factions,
      items: items,
      hooks: hooks,
      references: references,
      memoryContent: _memoryContent,
      customFolders: customFolders,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${selectedNovel.title} · 资料库'),
        actions: [
          IconButton(
            icon: _isGeneratingOutline
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            tooltip: 'AI生成大纲',
            onPressed: _isGeneratingOutline ? null : () => _generateOutline(selectedNovel.id),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: '打包',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ExportPage(novelId: selectedNovel.id, novelTitle: selectedNovel.title),
              ));
            },
          ),
        ],
      ),
      body: FileTreeView(
        nodes: treeNodes,
        onNodeTap: (node) => _handleNodeTap(node, selectedNovel.id),
        onNodeLongPress: (node) => _handleNodeLongPress(node, selectedNovel.id),
        onToggleExpand: (node) {
          setState(() {
            if (_expandedNodes.contains(node.name)) {
              _expandedNodes.remove(node.name);
            } else {
              _expandedNodes.add(node.name);
            }
          });
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenu(selectedNovel.id),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      appBar: AppBar(title: const Text('资料库')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('先选择一部作品', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(bottomNavIndexProvider.notifier).state = 0,
              child: const Text('去选择作品'),
            ),
          ],
        ),
      ),
    );
  }

  List<FileTreeNode> _buildFileTree({
    required List<Character> characters,
    required List<SettingCard> settings,
    required List<Location> locations,
    required List<Faction> factions,
    required List<Item> items,
    required List<PlotHook> hooks,
    required List<ReferenceMaterial> references,
    required String memoryContent,
    required List<CustomMaterialFolder> customFolders,
  }) {
    return [
      FileTreeNode(
        id: 'folder_characters',
        name: '角色 (${characters.length})',
        isFolder: true,
        isExpanded: _expandedNodes.contains('角色'),
        children: characters.map((c) => FileTreeNode(
          id: c.id,
          parentType: 'character',
          name: '${c.name}${c.role != null ? " · ${c.role}" : ""}.md',
          content: _formatCharacterContent(c),
          fileType: 'md',
        )).toList(),
      ),
      FileTreeNode(
        id: 'folder_settings',
        name: '设定 (${settings.length})',
        isFolder: true,
        isExpanded: _expandedNodes.contains('设定'),
        children: settings.map((s) => FileTreeNode(
          id: s.id,
          parentType: 'setting',
          name: '${s.name}${s.category != null ? " · ${s.category}" : ""}.md',
          content: _formatSettingContent(s),
          fileType: 'md',
        )).toList(),
      ),
      FileTreeNode(
        id: 'folder_locations',
        name: '地点 (${locations.length})',
        isFolder: true,
        isExpanded: _expandedNodes.contains('地点'),
        children: locations.map((l) => FileTreeNode(
          id: l.id,
          parentType: 'location',
          name: '${l.name}${l.category != null ? " · ${l.category}" : ""}.md',
          content: _formatLocationContent(l),
          fileType: 'md',
        )).toList(),
      ),
      FileTreeNode(
        id: 'folder_factions',
        name: '势力 (${factions.length})',
        isFolder: true,
        isExpanded: _expandedNodes.contains('势力'),
        children: factions.map((f) => FileTreeNode(
          id: f.id,
          parentType: 'faction',
          name: '${f.name}${f.category != null ? " · ${f.category}" : ""}.md',
          content: _formatFactionContent(f),
          fileType: 'md',
        )).toList(),
      ),
      FileTreeNode(
        id: 'folder_items',
        name: '道具 (${items.length})',
        isFolder: true,
        isExpanded: _expandedNodes.contains('道具'),
        children: items.map((i) => FileTreeNode(
          id: i.id,
          parentType: 'item',
          name: '${i.name}${i.category != null ? " · ${i.category}" : ""}.md',
          content: _formatItemContent(i),
          fileType: 'md',
        )).toList(),
      ),
      FileTreeNode(
        id: 'folder_hooks',
        name: '伏笔 (${hooks.length})',
        isFolder: true,
        isExpanded: _expandedNodes.contains('伏笔'),
        children: hooks.map((h) => FileTreeNode(
          id: h.id,
          parentType: 'hook',
          name: '${h.title}.md',
          content: _formatHookContent(h),
          fileType: 'md',
        )).toList(),
      ),
      FileTreeNode(
        id: 'folder_references',
        name: '参考 (${references.length})',
        isFolder: true,
        isExpanded: _expandedNodes.contains('参考'),
        children: references.map((r) => FileTreeNode(
          id: r.id,
          parentType: 'reference',
          name: '${r.title}.md',
          content: _formatReferenceContent(r),
          fileType: 'md',
        )).toList(),
      ),
      // AI生成的大纲
      if (_outlineNodes.isNotEmpty)
        FileTreeNode(
          id: 'folder_outline',
          name: 'AI大纲 (${_outlineNodes.length}卷)',
          isFolder: true,
          isExpanded: _expandedNodes.contains('大纲'),
          children: _outlineNodesToTreeNodes(_outlineNodes),
        ),
      // 自定义文件夹
      ...customFolders.map((folder) => FileTreeNode(
        id: 'custom_${folder.id}',
        name: '${folder.name} (${folder.items.length})',
        isFolder: true,
        isExpanded: _expandedNodes.contains(folder.name),
        icon: Icons.folder,
        iconColor: Colors.teal,
        children: folder.items.map((item) => FileTreeNode(
          id: 'custom_item_${item.id}',
          parentType: 'custom_${folder.id}',
          name: '${item.title}.md',
          content: item.content,
          icon: Icons.description,
          iconColor: Colors.teal[300],
          fileType: 'md',
        )).toList(),
      )),
      // 记忆包
      FileTreeNode(
        id: 'folder_memory',
        name: '记忆包',
        isFolder: true,
        isExpanded: _expandedNodes.contains('记忆'),
        children: [
          FileTreeNode(
            id: 'memory_file',
            parentType: 'memory',
            name: '小说记忆.md',
            content: memoryContent,
            fileType: 'md',
          ),
        ],
      ),
    ];
  }

  String _formatCharacterContent(Character c) {
    final buffer = StringBuffer();
    buffer.writeln('# ${c.name}');
    if (c.role != null) buffer.writeln('\n**定位**: ${c.role}');
    if (c.description != null) buffer.writeln('\n**描述**: ${c.description}');
    if (c.appearance != null) buffer.writeln('\n**外貌**: ${c.appearance}');
    if (c.personality != null) buffer.writeln('\n**性格**: ${c.personality}');
    if (c.background != null) buffer.writeln('\n**背景**: ${c.background}');
    return buffer.toString();
  }

  String _formatSettingContent(SettingCard s) {
    final buffer = StringBuffer();
    buffer.writeln('# ${s.name}');
    if (s.category != null) buffer.writeln('\n**分类**: ${s.category}');
    if (s.description != null) buffer.writeln('\n**描述**: ${s.description}');
    return buffer.toString();
  }

  String _formatLocationContent(Location l) {
    final buffer = StringBuffer();
    buffer.writeln('# ${l.name}');
    if (l.category != null) buffer.writeln('\n**分类**: ${l.category}');
    if (l.description != null) buffer.writeln('\n**描述**: ${l.description}');
    if (l.features != null) buffer.writeln('\n**特征**: ${l.features}');
    if (l.rules != null) buffer.writeln('\n**规则**: ${l.rules}');
    return buffer.toString();
  }

  String _formatFactionContent(Faction f) {
    final buffer = StringBuffer();
    buffer.writeln('# ${f.name}');
    if (f.category != null) buffer.writeln('\n**分类**: ${f.category}');
    if (f.description != null) buffer.writeln('\n**描述**: ${f.description}');
    if (f.leader != null) buffer.writeln('\n**首领**: ${f.leader}');
    if (f.strength != null) buffer.writeln('\n**实力**: ${f.strength}');
    return buffer.toString();
  }

  String _formatItemContent(Item i) {
    final buffer = StringBuffer();
    buffer.writeln('# ${i.name}');
    if (i.category != null) buffer.writeln('\n**分类**: ${i.category}');
    if (i.description != null) buffer.writeln('\n**描述**: ${i.description}');
    if (i.powerLevel != null) buffer.writeln('\n**品阶**: ${i.powerLevel}');
    if (i.owner != null) buffer.writeln('\n**持有者**: ${i.owner}');
    buffer.writeln('\n**关键道具**: ${i.isKeyItem ? "是" : "否"}');
    return buffer.toString();
  }

  String _formatHookContent(PlotHook h) {
    final buffer = StringBuffer();
    buffer.writeln('# ${h.title}');
    buffer.writeln('\n**状态**: ${h.statusLabel}');
    if (h.description != null) buffer.writeln('\n**描述**: ${h.description}');
    if (h.idleChapters > 0) buffer.writeln('\n**闲置章数**: ${h.idleChapters}');
    return buffer.toString();
  }

  String _formatReferenceContent(ReferenceMaterial r) {
    final buffer = StringBuffer();
    buffer.writeln('# ${r.title}');
    if (r.content != null) buffer.writeln('\n${r.content}');
    if (r.source != null) buffer.writeln('\n**来源**: ${r.source}');
    if (r.sourceUrl != null) buffer.writeln('\n**链接**: ${r.sourceUrl}');
    return buffer.toString();
  }

  /// AI生成大纲
  Future<void> _generateOutline(String novelId) async {
    // 获取AI配置
    final configs = ref.read(aiConfigsProvider);
    if (configs.isEmpty) {
      _showTopMsg('请先在"我的"页面配置AI模型', isError: true);
      return;
    }
    final aiConfig = configs.first;

    // 获取章节
    List<Chapter> chapters;
    try {
      chapters = await ref.read(chapterRepoProvider).getChaptersByNovel(novelId);
    } catch (e) {
      _showTopMsg('获取章节失败: $e', isError: true);
      return;
    }

    if (chapters.isEmpty) {
      _showTopMsg('没有可分析的章节，请先写一些内容', isError: true);
      return;
    }

    setState(() => _isGeneratingOutline = true);

    try {
      final service = OutlineGeneratorService();
      final outline = await service.generateOutline(
        chapters: chapters,
        aiConfig: aiConfig,
      );
      if (mounted) {
        setState(() {
          _outlineNodes = outline;
          _isGeneratingOutline = false;
          _expandedNodes.add('大纲');
        });
        _showTopMsg('大纲生成成功，共${outline.length}卷');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingOutline = false);
        _showTopMsg('生成失败: $e', isError: true);
      }
    }
  }

  /// 将OutlineNode转为FileTreeNode
  List<FileTreeNode> _outlineNodesToTreeNodes(List<OutlineNode> nodes, {int depth = 0}) {
    return nodes.map((node) {
      final hasChildren = node.children.isNotEmpty;
      final buffer = StringBuffer();
      buffer.writeln('# ${node.title}');
      if (node.summary != null) buffer.writeln('\n${node.summary}');
      final content = buffer.toString();

      return FileTreeNode(
        id: '${node.nodeType}_${node.title}',
        name: node.title,
        content: content,
        isFolder: hasChildren,
        isExpanded: depth < 1,
        fileType: hasChildren ? null : 'md',
        children: hasChildren
            ? _outlineNodesToTreeNodes(node.children, depth: depth + 1)
            : [],
      );
    }).toList();
  }

  /// 顶部提示
  void _showTopMsg(String message, {bool isError = false}) {
    final color = isError ? Colors.red : Colors.green;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  /// 点击节点 → 打开编辑器或展开文件夹
  void _handleNodeTap(FileTreeNode node, String novelId) {
    if (node.isFolder) {
      // 展开/折叠由 FileTreeView 的 onToggleExpand 处理
      return;
    }
    // 打开全页编辑器
    final type = node.parentType ?? 'reference';
    final cleanName = node.name.replaceAll(RegExp(r'\.[^.]+$'), '');

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MaterialEditorPage(
        title: cleanName,
        content: node.content ?? '',
        materialType: _typeLabel(type),
        materialId: node.id,
        category: _getCategoryFromNode(node),
        onSave: (newTitle, newContent) => _saveFromEditor(node, novelId, type, newTitle, newContent),
      ),
    )).then((_) {
      _refreshMaterials(novelId);
      setState(() {});
    });
  }

  String? _getCategoryFromNode(FileTreeNode node) {
    if (node.parentType?.startsWith('custom_') == true) return '自定义';
    return null;
  }

  void _saveFromEditor(FileTreeNode node, String novelId, String type, String newTitle, String newContent) {
    if (type.startsWith('custom_')) {
      final folderId = type.replaceFirst('custom_', '');
      final folders = ref.read(customFoldersProvider);
      final folderIdx = folders.indexWhere((f) => f.id == folderId);
      if (folderIdx >= 0) {
        final items = List<CustomMaterialItem>.from(folders[folderIdx].items);
        final itemIdx = items.indexWhere((i) => i.id == node.id);
        if (itemIdx >= 0) {
          items[itemIdx] = CustomMaterialItem(id: node.id, title: newTitle, content: newContent, category: items[itemIdx].category);
          final updated = List<CustomMaterialFolder>.from(folders);
          updated[folderIdx] = CustomMaterialFolder(id: folders[folderIdx].id, name: folders[folderIdx].name, items: items);
          ref.read(customFoldersProvider.notifier).state = updated;
          _persistCustomFolders();
        }
      }
      return;
    }
    _saveMaterialEdit(node, novelId, newTitle, newContent, type);
  }

  /// 长按节点 → 编辑/删除菜单
  void _handleNodeLongPress(FileTreeNode node, String novelId) {
    final type = node.parentType ?? 'reference';

    // 角色文件夹的长按 - 显示关系图选项
    if (node.id == 'folder_characters') {
      _showCharactersFolderMenu(node, novelId);
      return;
    }

    // 自定义文件夹的长按
    if (node.id.startsWith('custom_folder_')) {
      final folderId = node.id.replaceFirst('custom_folder_', '');
      _showCustomFolderMenu(node, folderId, novelId);
      return;
    }

    // 自定义文件夹内条目的长按
    if (type.startsWith('custom_')) {
      _showCustomItemMenu(node, type, novelId);
      return;
    }

    // 预置类型的长按
    _showNodeOptions(node, novelId);
  }

  void _showCharactersFolderMenu(FileTreeNode node, String novelId) {
    final selectedNovel = ref.read(selectedNovelProvider);
    if (selectedNovel == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.account_tree, color: AppColors.primary),
          title: const Text('查看关系图'),
          subtitle: const Text('可视化角色之间的关系'),
          onTap: () {
            Navigator.pop(ctx);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => RelationshipGraphPage(
                novelId: selectedNovel.id,
                novelTitle: selectedNovel.title,
              ),
            ));
          },
        ),
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('编辑文件夹'),
          onTap: () {
            Navigator.pop(ctx);
            // 默认行为
          },
        ),
      ])),
    );
  }

  void _showCustomFolderMenu(FileTreeNode node, String folderId, String novelId) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: Icon(Icons.note_add, color: Colors.teal),
          title: const Text('添加条目'),
          onTap: () { Navigator.pop(ctx); _showAddItemToCustomFolderDialog(folderId); },
        ),
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('重命名文件夹'),
          onTap: () { Navigator.pop(ctx); _showRenameCustomFolderDialog(folderId, novelId); },
        ),
        ListTile(
          leading: Icon(Icons.delete, color: Colors.red[400]),
          title: Text('删除文件夹', style: TextStyle(color: Colors.red[400])),
          onTap: () async {
            Navigator.pop(ctx);
            final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
              title: const Text('删除文件夹？'),
              content: const Text('文件夹内所有内容将被删除'),
              actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('删除'))],
            ));
            if (confirm == true) {
              ref.read(customFoldersProvider.notifier).state = ref.read(customFoldersProvider).where((f) => f.id != folderId).toList();
              _persistCustomFolders();
              setState(() {});
            }
          },
        ),
      ])),
    );
  }

  void _showAddItemToCustomFolderDialog(String folderId) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('添加条目'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '标题')),
          const SizedBox(height: 12),
          TextField(controller: contentCtrl, maxLines: 8, decoration: const InputDecoration(labelText: '内容')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () {
          if (titleCtrl.text.trim().isEmpty) return;
          final item = CustomMaterialItem(
            id: const Uuid().v4(),
            title: titleCtrl.text.trim(),
            content: contentCtrl.text,
          );
          final folders = List<CustomMaterialFolder>.from(ref.read(customFoldersProvider));
          final fi = folders.indexWhere((f) => f.id == folderId);
          if (fi >= 0) {
            folders[fi] = CustomMaterialFolder(id: folders[fi].id, name: folders[fi].name, items: [...folders[fi].items, item]);
            ref.read(customFoldersProvider.notifier).state = folders;
            _persistCustomFolders();
          }
          Navigator.pop(ctx);
          setState(() {});
        }, child: const Text('添加')),
      ],
    ));
  }

  void _showRenameCustomFolderDialog(String folderId, String novelId) {
    final folders = ref.read(customFoldersProvider);
    final folder = folders.firstWhere((f) => f.id == folderId);
    final ctrl = TextEditingController(text: folder.name);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('重命名文件夹'),
      content: TextField(controller: ctrl, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () {
          if (ctrl.text.trim().isEmpty) return;
          final updated = ref.read(customFoldersProvider).map((f) =>
            f.id == folderId ? CustomMaterialFolder(id: f.id, name: ctrl.text.trim(), items: f.items) : f
          ).toList();
          ref.read(customFoldersProvider.notifier).state = updated;
          _persistCustomFolders();
          Navigator.pop(ctx);
          setState(() {});
        }, child: const Text('确定'))],
    ));
  }

  void _showCustomItemMenu(FileTreeNode node, String type, String novelId) {
    final folderId = type.replaceFirst('custom_', '');
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.edit), title: const Text('编辑'), onTap: () { Navigator.pop(ctx); _handleNodeTap(node, novelId); }),
        ListTile(leading: Icon(Icons.delete, color: Colors.red[400]), title: Text('删除', style: TextStyle(color: Colors.red[400])),
          onTap: () async {
            Navigator.pop(ctx);
            final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
              title: const Text('删除？'), content: Text('确定删除「${node.name}」？'),
              actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('删除'))],
            ));
            if (confirm == true) {
              final folders = List<CustomMaterialFolder>.from(ref.read(customFoldersProvider));
              final fi = folders.indexWhere((f) => f.id == folderId);
              if (fi >= 0) {
                final items = List<CustomMaterialItem>.from(folders[fi].items)..removeWhere((i) => i.id == node.id);
                folders[fi] = CustomMaterialFolder(id: folders[fi].id, name: folders[fi].name, items: items);
                ref.read(customFoldersProvider.notifier).state = folders;
                _persistCustomFolders();
                setState(() {});
              }
            }
          },
        ),
      ])),
    );
  }

  void _showNodeOptions(FileTreeNode node, String novelId) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(ctx);
                _editNode(node, novelId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteNode(node, novelId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editNode(FileTreeNode node, String novelId) async {
    final nameCtrl = TextEditingController(text: node.name.replaceAll(RegExp(r'\\.[^.]+$'), ''));
    final contentCtrl = TextEditingController(text: node.content ?? '');
    final type = node.parentType ?? 'reference';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑${_typeLabel(type)}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (type != 'memory') TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称')),
                const SizedBox(height: 12),
                TextField(controller: contentCtrl, maxLines: 8, decoration: const InputDecoration(labelText: '内容')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );

    if (result == true && mounted) {
      await _saveMaterialEdit(node, novelId, nameCtrl.text.trim(), contentCtrl.text, type);
      _refreshMaterials(novelId);
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'character': return '角色';
      case 'setting': return '设定';
      case 'location': return '地点';
      case 'faction': return '势力';
      case 'item': return '道具';
      case 'hook': return '伏笔';
      case 'reference': return '参考资料';
      default: return '内容';
    }
  }

  Future<void> _saveMaterialEdit(FileTreeNode node, String novelId, String newName, String newContent, String type) async {
    final repo = MaterialRepository();
    switch (type) {
      case 'character':
        final list = await repo.getCharacters(novelId);
        final idx = list.indexWhere((c) => c.id == node.id);
        if (idx >= 0) {
          final old = list[idx];
          final updated = Character(
            id: old.id, novelId: novelId, name: newName,
            role: old.role, description: newContent,
            appearance: old.appearance, personality: old.personality,
            background: old.background, tags: old.tags,
            createdAt: old.createdAt,
          );
          final newList = List<Character>.from(list);
          newList[idx] = updated;
          await repo.saveCharacters(novelId, newList);
          ref.read(charactersProvider(novelId).notifier).state = newList;
        }
        break;
      case 'setting':
        final list = await repo.getSettingCards(novelId);
        final idx = list.indexWhere((s) => s.id == node.id);
        if (idx >= 0) {
          final old = list[idx];
          final updated = SettingCard(
            id: old.id, novelId: novelId, name: newName,
            category: old.category, description: newContent,
            tags: old.tags, createdAt: old.createdAt,
          );
          final newList = List<SettingCard>.from(list);
          newList[idx] = updated;
          await repo.saveSettingCards(novelId, newList);
          ref.read(settingCardsProvider(novelId).notifier).state = newList;
        }
        break;
      case 'reference':
        final list = await repo.getReferences(novelId);
        final idx = list.indexWhere((r) => r.id == node.id);
        if (idx >= 0) {
          final old = list[idx];
          final updated = ReferenceMaterial(
            id: old.id, novelId: novelId, title: newName,
            content: newContent, source: old.source,
            sourceUrl: old.sourceUrl, createdAt: old.createdAt,
          );
          final newList = List<ReferenceMaterial>.from(list);
          newList[idx] = updated;
          await repo.saveReferences(novelId, newList);
          ref.read(referencesProvider(novelId).notifier).state = newList;
        }
        break;
      case 'location':
        final list = await repo.getLocations(novelId);
        final idx = list.indexWhere((l) => l.id == node.id);
        if (idx >= 0) {
          final old = list[idx];
          final updated = Location(
            id: old.id, novelId: novelId, name: newName,
            category: old.category, description: newContent,
            features: old.features, rules: old.rules,
            tags: old.tags, createdAt: old.createdAt,
          );
          final newList = List<Location>.from(list);
          newList[idx] = updated;
          await repo.saveLocations(novelId, newList);
          ref.read(locationsProvider(novelId).notifier).state = newList;
        }
        break;
      case 'faction':
        final list = await repo.getFactions(novelId);
        final idx = list.indexWhere((f) => f.id == node.id);
        if (idx >= 0) {
          final old = list[idx];
          final updated = Faction(
            id: old.id, novelId: novelId, name: newName,
            category: old.category, description: newContent,
            leader: old.leader, strength: old.strength,
            members: old.members, tags: old.tags,
            createdAt: old.createdAt,
          );
          final newList = List<Faction>.from(list);
          newList[idx] = updated;
          await repo.saveFactions(novelId, newList);
          ref.read(factionsProvider(novelId).notifier).state = newList;
        }
        break;
      case 'item':
        final list = await repo.getItems(novelId);
        final idx = list.indexWhere((i) => i.id == node.id);
        if (idx >= 0) {
          final old = list[idx];
          final updated = Item(
            id: old.id, novelId: novelId, name: newName,
            category: old.category, description: newContent,
            powerLevel: old.powerLevel, owner: old.owner,
            isKeyItem: old.isKeyItem, tags: old.tags,
            createdAt: old.createdAt,
          );
          final newList = List<Item>.from(list);
          newList[idx] = updated;
          await repo.saveItems(novelId, newList);
          ref.read(itemsProvider(novelId).notifier).state = newList;
        }
        break;
      case 'hook':
        final list = await repo.getPlotHooks(novelId);
        final idx = list.indexWhere((h) => h.id == node.id);
        if (idx >= 0) {
          final old = list[idx];
          final updated = PlotHook(
            id: old.id, novelId: novelId, title: newName,
            description: newContent, isRevealed: old.isRevealed,
            chapterPlantedId: old.chapterPlantedId,
            chapterRevealedId: old.chapterRevealedId,
            idleChapters: old.idleChapters,
            createdAt: old.createdAt,
          );
          final newList = List<PlotHook>.from(list);
          newList[idx] = updated;
          await repo.savePlotHooks(novelId, newList);
          ref.read(plotHooksProvider(novelId).notifier).state = newList;
        }
        break;
    }
  }

  void _refreshMaterials(String novelId) {
    loadNovelMaterials(ref, novelId);
    setState(() {});
  }

  void _deleteNode(FileTreeNode node, String novelId) async {
    final type = node.parentType ?? 'reference';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${node.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final repo = MaterialRepository();
      switch (type) {
        case 'character':
          final list = await repo.getCharacters(novelId);
          list.removeWhere((c) => c.id == node.id);
          await repo.saveCharacters(novelId, list);
          break;
        case 'setting':
          final list = await repo.getSettingCards(novelId);
          list.removeWhere((s) => s.id == node.id);
          await repo.saveSettingCards(novelId, list);
          break;
        case 'reference':
          final list = await repo.getReferences(novelId);
          list.removeWhere((r) => r.id == node.id);
          await repo.saveReferences(novelId, list);
          break;
        case 'location':
          final list = await repo.getLocations(novelId);
          list.removeWhere((l) => l.id == node.id);
          await repo.saveLocations(novelId, list);
          break;
        case 'faction':
          final list = await repo.getFactions(novelId);
          list.removeWhere((f) => f.id == node.id);
          await repo.saveFactions(novelId, list);
          break;
        case 'item':
          final list = await repo.getItems(novelId);
          list.removeWhere((i) => i.id == node.id);
          await repo.saveItems(novelId, list);
          break;
        case 'hook':
          final list = await repo.getPlotHooks(novelId);
          list.removeWhere((h) => h.id == node.id);
          await repo.savePlotHooks(novelId, list);
          break;
      }
      _refreshMaterials(novelId);
    }
  }

  void _showNewFolderDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('新建文件夹'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(labelText: '文件夹名称', hintText: '例如：世界观设定集'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () {
          if (ctrl.text.trim().isEmpty) return;
          final folder = CustomMaterialFolder(
            id: const Uuid().v4(),
            name: ctrl.text.trim(),
          );
          ref.read(customFoldersProvider.notifier).state = [
            ...ref.read(customFoldersProvider),
            folder,
          ];
          _persistCustomFolders();
          _expandedNodes.add(ctrl.text.trim());
          Navigator.pop(ctx);
          setState(() {});
        }, child: const Text('创建')),
      ],
    ));
  }

  void _showAddMenu(String novelId) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.create_new_folder, color: Colors.teal),
              title: const Text('新建文件夹'),
              subtitle: const Text('创建自定义分类'),
              onTap: () { Navigator.pop(ctx); _showNewFolderDialog(); },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('添加角色'),
              onTap: () {
                Navigator.pop(ctx);
                _showCharacterDialog(novelId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('添加设定'),
              onTap: () {
                Navigator.pop(ctx);
                _showSettingDialog(novelId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('添加地点'),
              onTap: () {
                Navigator.pop(ctx);
                _showLocationDialog(novelId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance),
              title: const Text('添加势力'),
              onTap: () {
                Navigator.pop(ctx);
                _showFactionDialog(novelId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('添加道具'),
              onTap: () {
                Navigator.pop(ctx);
                _showItemDialog(novelId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('添加伏笔'),
              onTap: () {
                Navigator.pop(ctx);
                _showHookDialog(novelId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: const Text('添加参考'),
              onTap: () {
                Navigator.pop(ctx);
                _showReferenceDialog(novelId);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 添加对话框（简化版）
  void _showCharacterDialog(String novelId) {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加角色'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '角色名')),
              const SizedBox(height: 12),
              TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: '定位')),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '描述'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final char = Character(
                id: const Uuid().v4(),
                novelId: novelId,
                name: nameCtrl.text.trim(),
                role: roleCtrl.text.trim().isEmpty ? null : roleCtrl.text.trim(),
                description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              );
              final list = ref.read(charactersProvider(novelId));
              ref.read(charactersProvider(novelId).notifier).state = [...list, char];
              await MaterialRepository().saveCharacters(novelId, [...list, char]);
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showSettingDialog(String novelId) => _showSimpleDialog(novelId, '设定', (name, cat, desc) async {
    final card = SettingCard(id: const Uuid().v4(), novelId: novelId, name: name, category: cat, description: desc);
    final list = ref.read(settingCardsProvider(novelId));
    ref.read(settingCardsProvider(novelId).notifier).state = [...list, card];
    await MaterialRepository().saveSettingCards(novelId, [...list, card]);
  });

  void _showLocationDialog(String novelId) => _showSimpleDialog(novelId, '地点', (name, cat, desc) async {
    final loc = Location(id: const Uuid().v4(), novelId: novelId, name: name, category: cat, description: desc);
    final list = ref.read(locationsProvider(novelId));
    ref.read(locationsProvider(novelId).notifier).state = [...list, loc];
    await MaterialRepository().saveLocations(novelId, [...list, loc]);
  });

  void _showFactionDialog(String novelId) => _showSimpleDialog(novelId, '势力', (name, cat, desc) async {
    final faction = Faction(id: const Uuid().v4(), novelId: novelId, name: name, category: cat, description: desc);
    final list = ref.read(factionsProvider(novelId));
    ref.read(factionsProvider(novelId).notifier).state = [...list, faction];
    await MaterialRepository().saveFactions(novelId, [...list, faction]);
  });

  void _showItemDialog(String novelId) => _showSimpleDialog(novelId, '道具', (name, cat, desc) async {
    final item = Item(id: const Uuid().v4(), novelId: novelId, name: name, category: cat, description: desc);
    final list = ref.read(itemsProvider(novelId));
    ref.read(itemsProvider(novelId).notifier).state = [...list, item];
    await MaterialRepository().saveItems(novelId, [...list, item]);
  });

  void _showHookDialog(String novelId) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加伏笔'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '伏笔标题')),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '描述'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              final hook = PlotHook(
                id: const Uuid().v4(),
                novelId: novelId,
                title: titleCtrl.text.trim(),
                description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              );
              final list = ref.read(plotHooksProvider(novelId));
              ref.read(plotHooksProvider(novelId).notifier).state = [...list, hook];
              await MaterialRepository().savePlotHooks(novelId, [...list, hook]);
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showReferenceDialog(String novelId) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加参考'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '标题')),
              const SizedBox(height: 12),
              TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: '内容'), maxLines: 5),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              final newRef = ReferenceMaterial(
                id: const Uuid().v4(),
                novelId: novelId,
                title: titleCtrl.text.trim(),
                content: contentCtrl.text.trim().isEmpty ? null : contentCtrl.text.trim(),
              );
              final list = ref.read(referencesProvider(novelId));
              ref.read(referencesProvider(novelId).notifier).state = [...list, newRef];
              await MaterialRepository().saveReferences(novelId, [...list, newRef]);
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showSimpleDialog(String novelId, String type, Function(String name, String? cat, String? desc) onSave) {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('添加$type'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: '${type}名称')),
              const SizedBox(height: 12),
              TextField(controller: catCtrl, decoration: const InputDecoration(labelText: '分类')),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '描述'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              onSave(
                nameCtrl.text.trim(),
                catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
                descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              );
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}
