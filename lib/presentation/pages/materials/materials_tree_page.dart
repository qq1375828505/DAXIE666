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
import 'package:novel_ide/presentation/pages/works/export_page.dart';

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
  bool _isLoadingMemory = true;
  // AI大纲生成
  bool _isGeneratingOutline = false;
  List<OutlineNode> _outlineNodes = [];

  @override
  void initState() {
    super.initState();
    _loadMemory();
  }

  Future<void> _loadMemory() async {
    final selectedNovel = ref.read(selectedNovelProvider);
    if (selectedNovel == null) return;
    final memory = NovelMemory(novelId: selectedNovel.id, novelTitle: selectedNovel.title);
    final content = await memory.autoUpdate();
    if (mounted) {
      setState(() {
        _memoryContent = content;
        _isLoadingMemory = false;
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
        onNodeTap: (node) {
          if (!node.isFolder && node.content != null) {
            _showContentPreview(node);
          }
        },
        onNodeLongPress: (node) {
          _showNodeOptions(node, selectedNovel.id);
        },
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
  }) {
    return [
      FileTreeNode(
        id: 'folder_characters',
        name: '角色 (${characters.length})',
        isFolder: true,
        isExpanded: _expandedNodes.contains('角色'),
        children: characters.map((c) => FileTreeNode(
          id: c.id,
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
      // 记忆包
      FileTreeNode(
        id: 'folder_memory',
        name: '记忆包',
        isFolder: true,
        isExpanded: _expandedNodes.contains('记忆'),
        children: [
          FileTreeNode(
            id: 'memory_file',
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

  void _showContentPreview(FileTreeNode node) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(node.name),
        content: SingleChildScrollView(
          child: Text(node.content ?? '无内容'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
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
                // TODO: 编辑功能
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

  void _deleteNode(FileTreeNode node, String novelId) {
    // 根据节点ID前缀判断类型并删除
    // TODO: 实现删除逻辑
  }

  void _showAddMenu(String novelId) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            onPressed: () {
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
              MaterialRepository().saveCharacters(novelId, [...list, char]);
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showSettingDialog(String novelId) => _showSimpleDialog(novelId, '设定', (name, cat, desc) {
    final card = SettingCard(id: const Uuid().v4(), novelId: novelId, name: name, category: cat, description: desc);
    final list = ref.read(settingCardsProvider(novelId));
    ref.read(settingCardsProvider(novelId).notifier).state = [...list, card];
    MaterialRepository().saveSettingCards(novelId, [...list, card]);
  });

  void _showLocationDialog(String novelId) => _showSimpleDialog(novelId, '地点', (name, cat, desc) {
    final loc = Location(id: const Uuid().v4(), novelId: novelId, name: name, category: cat, description: desc);
    final list = ref.read(locationsProvider(novelId));
    ref.read(locationsProvider(novelId).notifier).state = [...list, loc];
    MaterialRepository().saveLocations(novelId, [...list, loc]);
  });

  void _showFactionDialog(String novelId) => _showSimpleDialog(novelId, '势力', (name, cat, desc) {
    final faction = Faction(id: const Uuid().v4(), novelId: novelId, name: name, category: cat, description: desc);
    final list = ref.read(factionsProvider(novelId));
    ref.read(factionsProvider(novelId).notifier).state = [...list, faction];
    MaterialRepository().saveFactions(novelId, [...list, faction]);
  });

  void _showItemDialog(String novelId) => _showSimpleDialog(novelId, '道具', (name, cat, desc) {
    final item = Item(id: const Uuid().v4(), novelId: novelId, name: name, category: cat, description: desc);
    final list = ref.read(itemsProvider(novelId));
    ref.read(itemsProvider(novelId).notifier).state = [...list, item];
    MaterialRepository().saveItems(novelId, [...list, item]);
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
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              final hook = PlotHook(
                id: const Uuid().v4(),
                novelId: novelId,
                title: titleCtrl.text.trim(),
                description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              );
              final list = ref.read(plotHooksProvider(novelId));
              ref.read(plotHooksProvider(novelId).notifier).state = [...list, hook];
              MaterialRepository().savePlotHooks(novelId, [...list, hook]);
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
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              final newRef = ReferenceMaterial(
                id: const Uuid().v4(),
                novelId: novelId,
                title: titleCtrl.text.trim(),
                content: contentCtrl.text.trim().isEmpty ? null : contentCtrl.text.trim(),
              );
              final list = ref.read(referencesProvider(novelId));
              ref.read(referencesProvider(novelId).notifier).state = [...list, newRef];
              MaterialRepository().saveReferences(novelId, [...list, newRef]);
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
