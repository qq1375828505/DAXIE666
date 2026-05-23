import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/novel_model.dart';
import 'package:novel_ide/data/models/volume_model.dart';
import 'package:novel_ide/data/models/chapter_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/presentation/pages/writing/editor_page.dart';

class OutlinePage extends ConsumerWidget {
  const OutlinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedNovel = ref.watch(selectedNovelProvider);
    if (selectedNovel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('大纲')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_tree, size: 64, color: Colors.grey[300]),
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

    final volumesAsync = ref.watch(volumesProvider(selectedNovel.id));
    final chaptersAsync = ref.watch(chaptersProvider(selectedNovel.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('${selectedNovel.title} · 大纲'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddVolumeDialog(context, ref, selectedNovel),
          ),
        ],
      ),
      body: volumesAsync.when(
        data: (volumes) {
          if (volumes.isEmpty) {
            return _buildEmptyState(context, ref, selectedNovel);
          }
          return chaptersAsync.when(
            data: (chapters) {
              return ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: volumes.length,
                onReorder: (oldIndex, newIndex) async {
                  if (oldIndex < newIndex) newIndex--;
                  final vols = List<Volume>.from(volumes);
                  final moved = vols.removeAt(oldIndex);
                  vols.insert(newIndex, moved);
                  for (int i = 0; i < vols.length; i++) {
                    final updated = vols[i].copyWith(orderIndex: i);
                    await ref.read(volumeRepoProvider).updateVolume(updated);
                  }
                  ref.invalidate(volumesProvider(selectedNovel.id));
                },
                itemBuilder: (context, index) {
                  final volume = volumes[index];
                  final volumeChapters = chapters.where((c) => c.volumeId == volume.id).toList();
                  return _VolumeOutlineCard(
                    key: ValueKey(volume.id),
                    volume: volume,
                    volumeIndex: index,
                    chapters: volumeChapters,
                    novel: selectedNovel,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('加载失败: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败: $err')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, Novel novel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_tree_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('还没有卷', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showAddVolumeDialog(context, ref, novel),
            icon: const Icon(Icons.add),
            label: const Text('添加第一卷'),
          ),
        ],
      ),
    );
  }

  void _showAddVolumeDialog(BuildContext context, WidgetRef ref, Novel novel) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建卷'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '卷名', hintText: '例如：第一卷 潜龙在渊'),
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
}

class _VolumeOutlineCard extends ConsumerWidget {
  final Volume volume;
  final int volumeIndex;
  final List<Chapter> chapters;
  final Novel novel;

  const _VolumeOutlineCard({
    required super.key,
    required this.volume,
    required this.volumeIndex,
    required this.chapters,
    required this.novel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('${volumeIndex + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ),
        title: Text(volume.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${chapters.length}章 · ${chapters.fold<int>(0, (sum, c) => sum + c.wordCount)}字',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        children: [
          if (chapters.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('暂无章节', style: TextStyle(color: Colors.grey[400])),
            )
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) async {
                if (oldIndex < newIndex) newIndex--;
                final chaps = List<Chapter>.from(chapters);
                final moved = chaps.removeAt(oldIndex);
                chaps.insert(newIndex, moved);
                for (int i = 0; i < chaps.length; i++) {
                  final updated = chaps[i].copyWith(orderIndex: i);
                  await ref.read(chapterRepoProvider).updateChapter(updated, novel.title);
                }
                ref.invalidate(chaptersProvider(novel.id));
              },
              children: chapters.map((chapter) {
                final status = ChapterStatus.values.firstWhere(
                  (e) => e.name == chapter.status,
                  orElse: () => ChapterStatus.draft,
                );
                return ListTile(
                  key: ValueKey(chapter.id),
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: status.color.withOpacity(0.15),
                    child: Text(
                      '${chapter.orderIndex + 1}',
                      style: TextStyle(fontSize: 11, color: status.color, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(chapter.title, style: const TextStyle(fontSize: 14)),
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
                      Text('${chapter.wordCount}字', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        ref.read(selectedChapterProvider.notifier).state = chapter;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditorPage(novelId: novel.id, chapterId: chapter.id),
                          ),
                        );
                      } else if (value.startsWith('status_')) {
                        final newStatus = value.replaceFirst('status_', '');
                        final updated = chapter.copyWith(status: newStatus);
                        await ref.read(chapterRepoProvider).updateChapter(updated, novel.title);
                        ref.invalidate(chaptersProvider(novel.id));
                      } else if (value == 'summary') {
                        _showSummaryDialog(context, ref, chapter);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                      const PopupMenuItem(value: 'summary', child: Text('编辑梗概')),
                      const PopupMenuDivider(),
                      ...ChapterStatus.values.map((s) => PopupMenuItem(
                        value: 'status_${s.name}',
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(width: 8),
                            Text(s.label),
                          ],
                        ),
                      )),
                    ],
                  ),
                );
              }).toList(),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton.icon(
              onPressed: () => _showAddChapterDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加章节'),
            ),
          ),
        ],
      ),
    );
  }

  void _showSummaryDialog(BuildContext context, WidgetRef ref, Chapter chapter) {
    final ctrl = TextEditingController(text: chapter.summary ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑章节梗概'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '输入本章梗概...'),
          maxLines: 4,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final updated = chapter.copyWith(summary: ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
              await ref.read(chapterRepoProvider).updateChapter(updated, novel.title);
              ref.invalidate(chaptersProvider(novel.id));
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showAddChapterDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建章节'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '章节标题', hintText: '例如：第1章 退婚'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final chapter = await ref.read(chapterRepoProvider).createChapter(
                novelId: novel.id,
                volumeId: volume.id,
                title: ctrl.text.trim(),
                orderIndex: chapters.length,
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
