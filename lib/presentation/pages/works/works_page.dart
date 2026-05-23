import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/novel_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/presentation/pages/works/novel_detail_page.dart';
import 'package:novel_ide/data/datasources/local_file_datasource.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class WorksPage extends ConsumerWidget {
  const WorksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final novelsAsync = ref.watch(novelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的作品'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: () => _showImportDialog(context, ref),
          ),
        ],
      ),
      body: novelsAsync.when(
        data: (novels) {
          if (novels.isEmpty) {
            return _buildEmptyState(context, ref);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: novels.length,
            itemBuilder: (context, index) {
              return _NovelCard(novel: novels[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateNovelDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新建作品'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('还没有作品', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text('点击右下角创建你的第一部作品', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateNovelDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('新建作品'),
          ),
        ],
      ),
    );
  }

  void _showCreateNovelDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建作品'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: '作品名称',
                hintText: '例如：都市神医',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: '简介（可选）',
                hintText: '一句话简介',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              final repo = ref.read(novelRepoProvider);
              final novel = await repo.createNovel(
                title: titleCtrl.text.trim(),
                description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              );
              ref.invalidate(novelsProvider);
              if (context.mounted) {
                Navigator.pop(context);
                ref.read(selectedNovelProvider.notifier).state = novel;
                ref.read(bottomNavIndexProvider.notifier).state = 2;
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('导入作品', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2, color: AppColors.primary),
              title: const Text('导入 .novelpack 作品包'),
              subtitle: const Text('从压缩包导入完整作品'),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.any,
                );
                if (result != null && result.files.single.path != null) {
                  try {
                    final fs = LocalFileDataSource();
                    await fs.importNovelPack(result.files.single.path!);
                    ref.invalidate(novelsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('导入成功')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('导入失败: $e')),
                      );
                    }
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open, color: AppColors.secondary),
              title: const Text('导入源文件目录'),
              subtitle: const Text('从Markdown/JSON源文件目录导入'),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await FilePicker.platform.getDirectoryPath();
                if (result != null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已从 $result 导入')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NovelCard extends ConsumerWidget {
  final Novel novel;
  const _NovelCard({required this.novel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          ref.read(selectedNovelProvider.notifier).state = novel;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NovelDetailPage(novel: novel)),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.book, color: AppColors.primary, size: 32),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      novel.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (novel.description != null && novel.description!.isNotEmpty)
                      Text(
                        novel.description!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatChip(icon: Icons.format_align_left, text: '${novel.totalWordCount}字'),
                        const SizedBox(width: 12),
                        _StatChip(icon: Icons.folder, text: '${novel.chapterCount}章'),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('MM-dd').format(novel.updatedAt),
                          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  final fs = LocalFileDataSource();
                  if (value == 'export_pack') {
                    try {
                      final path = await fs.getProjectDir(novel.id, novel.title);
                      final result = await FilePicker.platform.saveFile(
                        fileName: '${novel.title}.novelpack',
                      );
                      if (result != null) {
                        await fs.exportNovelPack(path, result);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已导出到 $result')),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('导出失败: $e')),
                        );
                      }
                    }
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('删除作品'),
                        content: Text('确定删除《${novel.title}》吗？此操作不可恢复。'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(novelRepoProvider).deleteNovel(novel.id, novel.title);
                      ref.invalidate(novelsProvider);
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'export_pack', child: Text('导出 .novelpack')),
                  const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: AppColors.error))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _StatChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }
}
