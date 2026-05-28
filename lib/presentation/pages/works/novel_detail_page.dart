import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/novel_model.dart';
import 'package:novel_ide/data/models/chapter_model.dart';
import 'package:novel_ide/data/models/volume_model.dart';
import 'package:novel_ide/data/models/material_models.dart';
import 'package:novel_ide/data/repositories/material_repository.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/presentation/pages/writing/editor_page.dart';
import 'package:novel_ide/presentation/pages/works/novel_import_dialog.dart';
import 'package:novel_ide/presentation/pages/works/export_page.dart';
import 'package:novel_ide/core/router.dart';

class NovelDetailPage extends ConsumerStatefulWidget {
  final Novel novel;
  const NovelDetailPage({super.key, required this.novel});

  @override
  ConsumerState<NovelDetailPage> createState() => _NovelDetailPageState();
}

class _NovelDetailPageState extends ConsumerState<NovelDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  static const _tabs = ['章节', '大纲', '角色', '设定'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    // Load materials for this novel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadNovelMaterials(ref, widget.novel.id);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final volumesAsync = ref.watch(volumesProvider(widget.novel.id));
    final chaptersAsync = ref.watch(chaptersProvider(widget.novel.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.novel.title),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '全局搜索',
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRouter.globalSearch,
                arguments: {'novelId': widget.novel.id, 'novelTitle': widget.novel.title},
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: '导入章节',
            onPressed: () => _showImportDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: '导出作品',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ExportPage(novelId: widget.novel.id, novelTitle: widget.novel.title),
              ));
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Tab 0: 章节
          volumesAsync.when(
            data: (volumes) {
              if (volumes.isEmpty) return _buildEmptyVolume(context, ref);
              return chaptersAsync.when(
                data: (chapters) => _ChapterTreeView(
                  novel: widget.novel, volumes: volumes, chapters: chapters,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('加载失败: $err')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('加载失败: $err')),
          ),
          // Tab 1: 大纲
          _OutlineTab(novelId: widget.novel.id),
          // Tab 2: 角色
          _CharactersTab(novelId: widget.novel.id),
          // Tab 3: 设定
          _SettingsTab(novelId: widget.novel.id),
        ],
      ),
      floatingActionButton: volumesAsync.when(
        data: (volumes) {
          if (volumes.isEmpty) return null;
          return chaptersAsync.when(
            data: (chapters) {
              if (chapters.isEmpty) return null;
              // 找到最近编辑的章节
              final latest = chapters.reduce((a, b) =>
                  a.updatedAt.isAfter(b.updatedAt) ? a : b);
              return FloatingActionButton.extended(
                onPressed: () {
                  ref.read(selectedChapterProvider.notifier).state = latest;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditorPage(novelId: widget.novel.id, chapterId: latest.id),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: Text('继续写作 · ${latest.title}', maxLines: 1),
              );
            },
            loading: () => null,
            error: (_, __) => null,
          );
        },
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }

  Widget _buildEmptyVolume(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.create_new_folder, size: 40, color: AppColors.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            const Text('还没有卷', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('创建第一卷开始你的故事', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showAddVolumeDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('添加第一卷'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVolumeDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建卷'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: '卷名',
            hintText: '例如：第一卷 潜龙在渊',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final volumes = await ref.read(volumeRepoProvider).getVolumesByNovel(widget.novel.id);
              await ref.read(volumeRepoProvider).createVolume(
                novelId: widget.novel.id,
                title: ctrl.text.trim(),
                orderIndex: volumes.length,
              );
              ref.invalidate(volumesProvider(widget.novel.id));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => NovelImportDialog(novelId: widget.novel.id, novelTitle: widget.novel.title),
    );
  }
}

void _showRenameVolumeDialog(BuildContext context, WidgetRef ref, Volume volume, Novel novel) {
  final ctrl = TextEditingController(text: volume.title);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('重命名卷'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(
          onPressed: () async {
            if (ctrl.text.trim().isEmpty) return;
            final updated = volume.copyWith(title: ctrl.text.trim());
            await ref.read(volumeRepoProvider).updateVolume(updated);
            ref.invalidate(volumesProvider(novel.id));
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

class _ChapterTreeView extends ConsumerWidget {
  final Novel novel;
  final List<Volume> volumes;
  final List<Chapter> chapters;
  const _ChapterTreeView({required this.novel, required this.volumes, required this.chapters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: volumes.length,
      itemBuilder: (context, volumeIndex) {
        final volume = volumes[volumeIndex];
        final volumeChapters = chapters.where((c) => c.volumeId == volume.id).toList();
        final volumeWordCount = volumeChapters.fold<int>(0, (sum, c) => sum + c.wordCount);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 1,
          shadowColor: Colors.black.withOpacity(0.06),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 卷头
              GestureDetector(
                onLongPress: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                            const SizedBox(height: 8),
                            ListTile(
                              leading: const Icon(Icons.edit),
                              title: const Text('重命名卷'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _showRenameVolumeDialog(context, ref, volume, novel);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.delete, color: Colors.red),
                              title: const Text('删除卷', style: TextStyle(color: Colors.red)),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx2) => AlertDialog(
                                    title: Text('删除 ${volume.title}？'),
                                    content: const Text('此操作将同时删除该卷下所有章节，不可恢复'),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx2, false), child: const Text('取消')),
                                      FilledButton(
                                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () => Navigator.pop(ctx2, true),
                                        child: const Text('删除'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  for (final ch in volumeChapters) {
                                    await ref.read(chapterRepoProvider).deleteChapter(ch.id);
                                  }
                                  await ref.read(volumeRepoProvider).deleteVolume(volume.id);
                                  ref.invalidate(volumesProvider(novel.id));
                                  ref.invalidate(chaptersProvider(novel.id));
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.08),
                        AppColors.primary.withOpacity(0.03),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '第${volumeIndex + 1}卷',
                          style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              volume.title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${volumeChapters.length}章 · $volumeWordCount字',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 22),
                        color: AppColors.primary,
                        onPressed: () => _showAddChapterDialog(context, ref, volume),
                      ),
                    ],
                  ),
                ),
              ),
              // 章节列表
              if (volumeChapters.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('暂无章节', style: TextStyle(color: Colors.grey[400])),
                  ),
                )
              else
                ...volumeChapters.map((chapter) => _ChapterTile(
                  chapter: chapter,
                  novel: novel,
                )),
            ],
          ),
        );
      },
    );
  }

  void _showAddChapterDialog(BuildContext context, WidgetRef ref, Volume volume) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建章节'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: '章节标题',
            hintText: '例如：第1章 退婚',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final volChapters = chapters.where((c) => c.volumeId == volume.id).toList();
              final chapter = await ref.read(chapterRepoProvider).createChapter(
                novelId: novel.id,
                volumeId: volume.id,
                title: ctrl.text.trim(),
                orderIndex: volChapters.length,
              );
              ref.invalidate(chaptersProvider(novel.id));
              if (context.mounted) {
                Navigator.pop(context);
                ref.read(selectedChapterProvider.notifier).state = chapter;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditorPage(novelId: novel.id, chapterId: chapter.id),
                  ),
                );
              }
            },
            child: const Text('创建并编辑'),
          ),
        ],
      ),
    );
  }
}

class _ChapterTile extends ConsumerWidget {
  final Chapter chapter;
  final Novel novel;
  const _ChapterTile({required this.chapter, required this.novel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ChapterStatus.values.firstWhere(
      (e) => e.name == chapter.status,
      orElse: () => ChapterStatus.draft,
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 4,
        height: 36,
        decoration: BoxDecoration(
          color: status.color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      title: Text(
        chapter.title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: status.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(status.label, style: TextStyle(fontSize: 10, color: status.color)),
          ),
          const SizedBox(width: 8),
          Text('${chapter.wordCount}字', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chapter.wordCount > 10000)
            Tooltip(
              message: '建议拆章',
              child: Icon(Icons.warning_amber, size: 18, color: Colors.orange[300]),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
      onTap: () {
        ref.read(selectedChapterProvider.notifier).state = chapter;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditorPage(novelId: novel.id, chapterId: chapter.id),
          ),
        );
      },
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('重命名'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showRenameChapterDialog(context, ref, chapter);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('删除', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('删除 ${chapter.title}？'),
                          content: const Text('此操作不可恢复'),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(chapterRepoProvider).deleteChapter(chapter.id);
                        ref.invalidate(chaptersProvider(novel.id));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

void _showRenameChapterDialog(BuildContext context, WidgetRef ref, Chapter chapter) {
  final ctrl = TextEditingController(text: chapter.title);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('重命名章节'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(
          onPressed: () async {
            if (ctrl.text.trim().isEmpty) return;
            final updated = chapter.copyWith(title: ctrl.text.trim());
            await ref.read(chapterRepoProvider).updateChapter(updated, '');
            ref.invalidate(chaptersProvider(chapter.novelId));
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}


// ========== 大纲 Tab ==========
class _OutlineTab extends ConsumerWidget {
  final String novelId;
  const _OutlineTab({required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refs = ref.watch(referencesProvider(novelId));
    final outlineRefs = refs.where((r) => r.source == '大纲').toList();

    if (outlineRefs.isEmpty && refs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_tree_outlined, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text('暂无大纲', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('拥有一份大纲的作品更容易获得成功', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showCreateDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('创建总纲'),
              ),
            ],
          ),
        ),
      );
    }

    final items = outlineRefs.isNotEmpty ? outlineRefs : refs;
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final r = items[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  child: const Icon(Icons.account_tree, color: Colors.orange),
                ),
                title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(r.content ?? '', maxLines: 3, overflow: TextOverflow.ellipsis),
                onTap: () => _showEditDialog(context, ref, r),
              ),
            );
          },
        ),
        Positioned(
          right: 16, bottom: 16,
          child: FloatingActionButton.small(
            onPressed: () => _showCreateDialog(context, ref),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建大纲'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '标题', hintText: '例如：总纲、分卷大纲')),
            const SizedBox(height: 12),
            TextField(controller: contentCtrl, maxLines: 10, decoration: const InputDecoration(labelText: '内容', hintText: '输入大纲内容...')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            if (titleCtrl.text.trim().isEmpty) return;
            final repo = MaterialRepository();
            final existing = await repo.getReferences(novelId);
            final newRef = ReferenceMaterial(
              id: const Uuid().v4(), novelId: novelId,
              title: titleCtrl.text.trim(), content: contentCtrl.text,
              source: '大纲',
            );
            existing.add(newRef);
            await repo.saveReferences(novelId, existing);
            ref.invalidate(referencesProvider(novelId));
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text('创建')),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, ReferenceMaterial r) {
    final titleCtrl = TextEditingController(text: r.title);
    final contentCtrl = TextEditingController(text: r.content ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(r.title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '标题')),
              const SizedBox(height: 12),
              TextField(controller: contentCtrl, maxLines: 10, decoration: const InputDecoration(labelText: '内容')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            final repo = MaterialRepository();
            final list = await repo.getReferences(novelId);
            final idx = list.indexWhere((x) => x.id == r.id);
            if (idx >= 0) {
              list[idx].title = titleCtrl.text.trim();
              list[idx].content = contentCtrl.text;
              await repo.saveReferences(novelId, list);
            }
            ref.invalidate(referencesProvider(novelId));
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text('保存')),
        ],
      ),
    );
  }
}

// ========== 角色 Tab ==========
class _CharactersTab extends ConsumerWidget {
  final String novelId;
  const _CharactersTab({required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters = ref.watch(charactersProvider(novelId));

    if (characters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text('暂无角色', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('添加角色让故事更丰满', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showCreateDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('添加角色'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: characters.length,
          itemBuilder: (context, index) {
            final c = characters[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: const Icon(Icons.person, color: AppColors.primary),
                ),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(c.description ?? "", maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => _showEditDialog(context, ref, c),
              ),
            );
          },
        ),
        Positioned(
          right: 16, bottom: 16,
          child: FloatingActionButton.small(
            onPressed: () => _showCreateDialog(context, ref),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建角色'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '角色名')),
            const SizedBox(height: 12),
            TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: '定位', hintText: '例如：主角、反派、配角')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 4, decoration: const InputDecoration(labelText: '描述')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            final repo = MaterialRepository();
            final existing = await repo.getCharacters(novelId);
            final newChar = Character(
              id: const Uuid().v4(), novelId: novelId,
              name: nameCtrl.text.trim(), role: roleCtrl.text.trim(),
              description: descCtrl.text,
            );
            existing.add(newChar);
            await repo.saveCharacters(novelId, existing);
            ref.invalidate(charactersProvider(novelId));
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text('创建')),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Character c) {
    final nameCtrl = TextEditingController(text: c.name);
    final roleCtrl = TextEditingController(text: c.role ?? '');
    final descCtrl = TextEditingController(text: c.description ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.name),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '角色名')),
            const SizedBox(height: 12),
            TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: '定位')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 4, decoration: const InputDecoration(labelText: '描述')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            final repo = MaterialRepository();
            final list = await repo.getCharacters(novelId);
            final idx = list.indexWhere((x) => x.id == c.id);
            if (idx >= 0) {
              list[idx].name = nameCtrl.text.trim();
              list[idx].role = roleCtrl.text.trim();
              list[idx].description = descCtrl.text;
              await repo.saveCharacters(novelId, list);
            }
            ref.invalidate(charactersProvider(novelId));
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text('保存')),
        ],
      ),
    );
  }
}

// ========== 设定 Tab ==========
class _SettingsTab extends ConsumerWidget {
  final String novelId;
  const _SettingsTab({required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingCardsProvider(novelId));

    if (settings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.public_outlined, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text('暂无设定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('世界观和设定让故事更有深度', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showCreateDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('添加设定'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: settings.length,
          itemBuilder: (context, index) {
            final s = settings[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: const Icon(Icons.public, color: Colors.blue),
                ),
                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(s.description ?? "", maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => _showEditDialog(context, ref, s),
              ),
            );
          },
        ),
        Positioned(
          right: 16, bottom: 16,
          child: FloatingActionButton.small(
            onPressed: () => _showCreateDialog(context, ref),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建设定'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '设定名', hintText: '例如：修仙体系、门派势力')),
            const SizedBox(height: 12),
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: '分类', hintText: '例如：世界观、战力体系')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 4, decoration: const InputDecoration(labelText: '内容')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            final repo = MaterialRepository();
            final existing = await repo.getSettingCards(novelId);
            final newSetting = SettingCard(
              id: const Uuid().v4(), novelId: novelId,
              name: nameCtrl.text.trim(), category: catCtrl.text.trim(),
              description: descCtrl.text,
            );
            existing.add(newSetting);
            await repo.saveSettingCards(novelId, existing);
            ref.invalidate(settingCardsProvider(novelId));
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text('创建')),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, SettingCard s) {
    final nameCtrl = TextEditingController(text: s.name);
    final catCtrl = TextEditingController(text: s.category ?? '');
    final descCtrl = TextEditingController(text: s.description ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.name),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '设定名')),
            const SizedBox(height: 12),
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: '分类')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 4, decoration: const InputDecoration(labelText: '内容')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () async {
            final repo = MaterialRepository();
            final list = await repo.getSettingCards(novelId);
            final idx = list.indexWhere((x) => x.id == s.id);
            if (idx >= 0) {
              list[idx].name = nameCtrl.text.trim();
              list[idx].category = catCtrl.text.trim();
              list[idx].description = descCtrl.text;
              await repo.saveSettingCards(novelId, list);
            }
            ref.invalidate(settingCardsProvider(novelId));
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text('保存')),
        ],
      ),
    );
  }
}
