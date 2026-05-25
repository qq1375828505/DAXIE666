import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/material_models.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/repositories/material_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:novel_ide/data/services/novel_memory.dart';

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
    _tabController = TabController(length: 8, vsync: this);
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
          isScrollable: true,
          tabs: const [
            Tab(text: '角色'),
            Tab(text: '设定'),
            Tab(text: '地点'),
            Tab(text: '势力'),
            Tab(text: '道具'),
            Tab(text: '伏笔'),
            Tab(text: '参考'),
            Tab(text: '记忆'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CharacterTab(novelId: selectedNovel.id),
          _SettingTab(novelId: selectedNovel.id),
          _LocationTab(novelId: selectedNovel.id),
          _FactionTab(novelId: selectedNovel.id),
          _ItemTab(novelId: selectedNovel.id),
          _HookTab(novelId: selectedNovel.id),
          _ReferenceTab(novelId: selectedNovel.id),
          _MemoryTab(novelId: selectedNovel.id, novelTitle: selectedNovel.title),
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
      case 0: _showCharacterDialog(novelId); break;
      case 1: _showSettingDialog(novelId); break;
      case 2: _showLocationDialog(novelId); break;
      case 3: _showFactionDialog(novelId); break;
      case 4: _showItemDialog(novelId); break;
      case 5: _showHookDialog(novelId); break;
      case 6: _showReferenceDialog(novelId); break;
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
              final updated = [...list, char];
              ref.read(charactersProvider(novelId).notifier).state = updated;
              MaterialRepository().saveCharacters(novelId, updated);
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
              final updated = [...list, card];
              ref.read(settingCardsProvider(novelId).notifier).state = updated;
              MaterialRepository().saveSettingCards(novelId, updated);
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showLocationDialog(String novelId) {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加地点'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '地点名称', hintText: '例如：青云宗')),
              const SizedBox(height: 12),
              TextField(controller: catCtrl, decoration: const InputDecoration(labelText: '分类', hintText: '例如：宗门/城市/秘境')),
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
              final loc = Location(
                id: const Uuid().v4(), novelId: novelId,
                name: nameCtrl.text.trim(),
                category: catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
                description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              );
              final list = ref.read(locationsProvider(novelId));
              ref.read(locationsProvider(novelId).notifier).state = [...list, loc];
              MaterialRepository().saveLocations(novelId, [...list, loc]);
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showFactionDialog(String novelId) {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final leaderCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加势力'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '势力名称', hintText: '例如：天剑宗')),
              const SizedBox(height: 12),
              TextField(controller: catCtrl, decoration: const InputDecoration(labelText: '分类', hintText: '例如：正道/魔道/中立')),
              const SizedBox(height: 12),
              TextField(controller: leaderCtrl, decoration: const InputDecoration(labelText: '首领', hintText: '可选')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              final faction = Faction(
                id: const Uuid().v4(), novelId: novelId,
                name: nameCtrl.text.trim(),
                category: catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
                leader: leaderCtrl.text.trim().isEmpty ? null : leaderCtrl.text.trim(),
              );
              final list = ref.read(factionsProvider(novelId));
              ref.read(factionsProvider(novelId).notifier).state = [...list, faction];
              MaterialRepository().saveFactions(novelId, [...list, faction]);
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showItemDialog(String novelId) {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final powerCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加道具'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '道具名称', hintText: '例如：诛仙剑')),
              const SizedBox(height: 12),
              TextField(controller: catCtrl, decoration: const InputDecoration(labelText: '分类', hintText: '例如：武器/法宝/丹药')),
              const SizedBox(height: 12),
              TextField(controller: powerCtrl, decoration: const InputDecoration(labelText: '品阶/等级', hintText: '可选')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              final item = Item(
                id: const Uuid().v4(), novelId: novelId,
                name: nameCtrl.text.trim(),
                category: catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
                powerLevel: powerCtrl.text.trim().isEmpty ? null : powerCtrl.text.trim(),
              );
              final list = ref.read(itemsProvider(novelId));
              ref.read(itemsProvider(novelId).notifier).state = [...list, item];
              MaterialRepository().saveItems(novelId, [...list, item]);
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
              final updated = [...list, hook];
              ref.read(plotHooksProvider(novelId).notifier).state = updated;
              MaterialRepository().savePlotHooks(novelId, updated);
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
              final updated = [...list, refModel];
              ref.read(referencesProvider(novelId).notifier).state = updated;
              MaterialRepository().saveReferences(novelId, updated);
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
                        MaterialRepository().saveCharacters(novelId, list);
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
                        MaterialRepository().saveSettingCards(novelId, list);
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
                    MaterialRepository().savePlotHooks(novelId, list);
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
                      MaterialRepository().saveReferences(novelId, list);
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

// --- V2: Location Tab ---
class _LocationTab extends ConsumerWidget {
  final String novelId;
  const _LocationTab({required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationsProvider(novelId));
    if (locations.isEmpty) {
      return _emptyState('地点', '记录故事发生的重要地点', Icons.location_on);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final loc = locations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.1),
              child: const Icon(Icons.location_on, color: Colors.green, size: 20),
            ),
            title: Text(loc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(loc.category ?? loc.description ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () async {
                final updated = List<Location>.from(locations)..removeAt(index);
                ref.read(locationsProvider(novelId).notifier).state = updated;
                await MaterialRepository().saveLocations(novelId, updated);
              },
            ),
          ),
        );
      },
    );
  }
}

// --- V2: Faction Tab ---
class _FactionTab extends ConsumerWidget {
  final String novelId;
  const _FactionTab({required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factions = ref.watch(factionsProvider(novelId));
    if (factions.isEmpty) {
      return _emptyState('势力', '记录故事中的门派、国家、组织', Icons.account_balance);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: factions.length,
      itemBuilder: (context, index) {
        final f = factions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.withOpacity(0.1),
              child: const Icon(Icons.account_balance, color: Colors.purple, size: 20),
            ),
            title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${f.category ?? ''} ${f.leader != null ? '· ${f.leader}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () async {
                final updated = List<Faction>.from(factions)..removeAt(index);
                ref.read(factionsProvider(novelId).notifier).state = updated;
                await MaterialRepository().saveFactions(novelId, updated);
              },
            ),
          ),
        );
      },
    );
  }
}

// --- V2: Item Tab ---
class _ItemTab extends ConsumerWidget {
  final String novelId;
  const _ItemTab({required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider(novelId));
    if (items.isEmpty) {
      return _emptyState('道具', '记录武器、法宝、丹药等重要道具', Icons.inventory_2);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: item.isKeyItem ? Colors.amber.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
              child: Icon(
                item.isKeyItem ? Icons.star : Icons.inventory_2,
                color: item.isKeyItem ? Colors.amber : Colors.blue,
                size: 20,
              ),
            ),
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${item.category ?? ''} ${item.powerLevel != null ? '· ${item.powerLevel}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () async {
                final updated = List<Item>.from(items)..removeAt(index);
                ref.read(itemsProvider(novelId).notifier).state = updated;
                await MaterialRepository().saveItems(novelId, updated);
              },
            ),
          ),
        );
      },
    );
  }
}

// --- V3: Memory Tab ---
class _MemoryTab extends ConsumerStatefulWidget {
  final String novelId;
  final String novelTitle;
  const _MemoryTab({required this.novelId, required this.novelTitle});

  @override
  ConsumerState<_MemoryTab> createState() => _MemoryTabState();
}

class _MemoryTabState extends ConsumerState<_MemoryTab> {
  String _memoryContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemory();
  }

  Future<void> _loadMemory() async {
    final memory = NovelMemory(novelId: widget.novelId, novelTitle: widget.novelTitle);
    final content = await memory.autoUpdate();
    if (mounted) {
      setState(() {
        _memoryContent = content;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadMemory,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.psychology, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            const Text('小说记忆文件', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18),
                              onPressed: _loadMemory,
                              tooltip: '刷新',
                            ),
                          ],
                        ),
                        const Divider(),
                        Text('此文件记录了小说的完整状态，AI对话时自动读取。', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        const SizedBox(height: 12),
                        Text(_memoryContent, style: const TextStyle(fontSize: 13, height: 1.6, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
  }
}
