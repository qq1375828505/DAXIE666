import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/material_models.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/repositories/material_repository.dart';
import 'package:uuid/uuid.dart';

class MaterialsPage extends ConsumerStatefulWidget {
  const MaterialsPage({super.key});

  @override
  ConsumerState<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends ConsumerState<MaterialsPage> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedNovel = ref.watch(selectedNovelProvider);
    if (selectedNovel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('资料')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('先选择一部作品', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(bottomNavIndexProvider.notifier).state = 1,
                child: const Text('去选择作品'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${selectedNovel.title} · 资料'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '角色'),
            Tab(text: '设定'),
            Tab(text: '伏笔'),
            Tab(text: '参考'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CharacterTab(novelId: selectedNovel.id),
          _SettingTab(novelId: selectedNovel.id),
          _HookTab(novelId: selectedNovel.id),
          _ReferenceTab(novelId: selectedNovel.id),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(selectedNovel.id),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(String novelId) {
    final index = _tabController.index;
    switch (index) {
      case 0:
        _showCharacterDialog(novelId);
        break;
      case 1:
        _showSettingDialog(novelId);
        break;
      case 2:
        _showHookDialog(novelId);
        break;
      case 3:
        _showReferenceDialog(novelId);
        break;
    }
  }

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
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '角色名', hintText: '例如：林逸')),
              const SizedBox(height: 12),
              TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: '角色定位', hintText: '例如：主角/反派/配角')),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '描述', hintText: '外貌、性格、背景'), maxLines: 3),
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
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showSettingDialog(String novelId) {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加设定卡'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '设定名称', hintText: '例如：灵气复苏')),
              const SizedBox(height: 12),
              TextField(controller: catCtrl, decoration: const InputDecoration(labelText: '分类', hintText: '例如：世界观/战力/势力')),
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
              final card = SettingCard(
                id: const Uuid().v4(),
                novelId: novelId,
                name: nameCtrl.text.trim(),
                category: catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
                description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              );
              final list = ref.read(settingCardsProvider(novelId));
              ref.read(settingCardsProvider(novelId).notifier).state = [...list, card];
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

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
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '伏笔标题', hintText: '例如：主角的身世之谜')),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '伏笔描述', hintText: '在哪里埋下、初步线索'), maxLines: 3),
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
    final sourceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加参考资料'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '标题', hintText: '例如：明代官制参考')),
              const SizedBox(height: 12),
              TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: '内容'), maxLines: 4),
              const SizedBox(height: 12),
              TextField(controller: sourceCtrl, decoration: const InputDecoration(labelText: '来源（可选）')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              final refModel = ReferenceMaterial(
                id: const Uuid().v4(),
                novelId: novelId,
                title: titleCtrl.text.trim(),
                content: contentCtrl.text.trim().isEmpty ? null : contentCtrl.text.trim(),
                source: sourceCtrl.text.trim().isEmpty ? null : sourceCtrl.text.trim(),
              );
              final list = ref.read(referencesProvider(novelId));
              ref.read(referencesProvider(novelId).notifier).state = [...list, refModel];
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}

class _CharacterTab extends ConsumerWidget {
  final String novelId;
  const _CharacterTab({required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chars = ref.watch(charactersProvider(novelId));
    if (chars.isEmpty) {
      return _emptyState('角色卡', '记录主角、配角、反派的人物设定', Icons.people);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chars.length,
      itemBuilder: (context, index) {
        final ch = chars[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(ch.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    if (ch.role != null)
                      Chip(
                        label: Text(ch.role!, style: const TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      onPressed: () {
                        final list = ref.read(charactersProvider(novelId)).where((c) => c.id != ch.id).toList();
                        ref.read(charactersProvider(novelId).notifier).state = list;
                      },
                    ),
                  ],
                ),
                if (ch.description != null) ...[
                  const SizedBox(height: 8),
                  Text(ch.description!, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingTab extends ConsumerWidget {
  final String novelId;
  const _SettingTab({required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(settingCardsProvider(novelId));
    if (cards.isEmpty) {
      return _emptyState('设定卡', '世界观、战力体系、势力分布等核心设定', Icons.settings);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(card.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    if (card.category != null)
                      Chip(
                        label: Text(card.category!, style: const TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.secondary.withOpacity(0.1),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      onPressed: () {
                        final list = ref.read(settingCardsProvider(novelId)).where((c) => c.id != card.id).toList();
                        ref.read(settingCardsProvider(novelId).notifier).state = list;
                      },
                    ),
                  ],
                ),
                if (card.description != null) ...[
                  const SizedBox(height: 8),
                  Text(card.description!, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HookTab extends ConsumerWidget {
  final String novelId;
  const _HookTab({required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hooks = ref.watch(plotHooksProvider(novelId));
    if (hooks.isEmpty) {
      return _emptyState('伏笔追踪', '记录伏笔、回收状态、闲置章节', Icons.track_changes);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hooks.length,
      itemBuilder: (context, index) {
        final hook = hooks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: hook.statusColor.withOpacity(0.15),
              child: Icon(Icons.lightbulb, size: 16, color: hook.statusColor),
            ),
            title: Text(hook.title, style: const TextStyle(fontSize: 15)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hook.description != null)
                  Text(hook.description!, style: TextStyle(fontSize: 12, color: Colors.grey[500]), maxLines: 1),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: hook.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(hook.statusLabel, style: TextStyle(fontSize: 10, color: hook.statusColor)),
                    ),
                    const SizedBox(width: 8),
                    Text('闲置${hook.idleChapters}章', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(hook.isRevealed ? Icons.check_circle : Icons.check_circle_outline,
                      size: 20, color: hook.isRevealed ? Colors.green : Colors.grey),
                  tooltip: '标记回收',
                  onPressed: () {
                    final list = ref.read(plotHooksProvider(novelId));
                    final idx = list.indexWhere((h) => h.id == hook.id);
                    if (idx >= 0) {
                      final updated = list.toList();
                      updated[idx].isRevealed = !updated[idx].isRevealed;
                      ref.read(plotHooksProvider(novelId).notifier).state = updated;
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  onPressed: () {
                    final list = ref.read(plotHooksProvider(novelId)).where((h) => h.id != hook.id).toList();
                    ref.read(plotHooksProvider(novelId).notifier).state = list;
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReferenceTab extends ConsumerWidget {
  final String novelId;
  const _ReferenceTab({required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refs = ref.watch(referencesProvider(novelId));
    if (refs.isEmpty) {
      return _emptyState('参考资料', '联网搜索结果、历史资料、灵感笔记', Icons.bookmark);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: refs.length,
      itemBuilder: (context, index) {
        final refModel = refs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: const Icon(Icons.bookmark, color: AppColors.primary),
            title: Text(refModel.title, style: const TextStyle(fontSize: 15)),
            subtitle: refModel.source != null
                ? Text('来源：${refModel.source}', style: TextStyle(fontSize: 12, color: Colors.grey[500]))
                : null,
            children: [
              if (refModel.content != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(refModel.content!, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ),
              ButtonBar(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('删除'),
                    onPressed: () {
                      final list = ref.read(referencesProvider(novelId)).where((r) => r.id != refModel.id).toList();
                      ref.read(referencesProvider(novelId).notifier).state = list;
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _emptyState(String title, String desc, IconData icon) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[500])),
        const SizedBox(height: 8),
        Text(desc, style: TextStyle(fontSize: 14, color: Colors.grey[400])),
        const SizedBox(height: 16),
        Text('点击右下角 + 添加', style: TextStyle(fontSize: 12, color: Colors.grey[350])),
      ],
    ),
  );
}
