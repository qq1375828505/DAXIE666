import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/novel_model.dart';
import 'package:novel_ide/data/models/chapter_model.dart';
import 'package:novel_ide/data/models/volume_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/presentation/pages/writing/editor_page.dart';
import 'package:novel_ide/presentation/pages/works/novel_import_dialog.dart';
import 'package:novel_ide/presentation/pages/works/export_page.dart';
import 'package:novel_ide/core/router.dart';

class NovelDetailPage extends ConsumerWidget {
  final Novel novel;
  const NovelDetailPage({super.key, required this.novel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumesAsync = ref.watch(volumesProvider(novel.id));
    final chaptersAsync = ref.watch(chaptersProvider(novel.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(novel.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '全局搜索',
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRouter.globalSearch,
                arguments: {'novelId': novel.id, 'novelTitle': novel.title},
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
                builder: (_) => ExportPage(novelId: novel.id, novelTitle: novel.title),
              ));
            },
          ),
        ],
      ),
      body: volumesAsync.when(
        data: (volumes) {
          if (volumes.isEmpty) {
            return _buildEmptyVolume(context, ref);
          }
          return chaptersAsync.when(
            data: (chapters) {
              return _ChapterTreeView(
                novel: novel,
                volumes: volumes,
                chapters: chapters,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('加载失败: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败: $err')),
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
                      builder: (_) => EditorPage(novelId: novel.id, chapterId: latest.id),
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
              final volumes = await ref.read(volumeRepoProvider).getVolumesByNovel(novel.id);
              await ref.read(volumeRepoProvider).createVolume(
                novelId: novel.id,
                title: ctrl.text.trim(),
                orderIndex: volumes.length,
              );
              ref.invalidate(volumesProvider(novel.id));
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
      builder: (ctx) => NovelImportDialog(novelId: novel.id, novelTitle: novel.title),
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
