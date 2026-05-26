import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/novel_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/presentation/pages/works/novel_detail_page.dart';
import 'package:novel_ide/data/datasources/local_file_datasource.dart';
import 'package:novel_ide/data/services/novel_import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:novel_ide/presentation/pages/works/export_page.dart';
import 'package:path/path.dart' as p;

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
            icon: const Icon(Icons.file_download_outlined),
            tooltip: '导出当前作品',
            onPressed: () {
              final novel = ref.read(selectedNovelProvider);
              if (novel != null) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ExportPage(novelId: novel.id, novelTitle: novel.title),
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请先选择一部作品')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 26),
            tooltip: '导入',
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
                loadNovelMaterials(ref, novel.id);
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽指示条
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // 文件选项
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_outlined, color: AppColors.primary),
                ),
                title: const Text('文件', style: TextStyle(fontSize: 16)),
                subtitle: const Text('选择 TXT、DOCX、MD 等文件导入', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await FilePicker.platform.pickFiles(
                    dialogTitle: '选择小说文件',
                    type: FileType.custom,
                    allowedExtensions: ['txt', 'md', 'docx', 'novelpack'],
                  );
                  if (result != null && result.files.single.path != null) {
                    final filePath = result.files.single.path!;
                    final ext = p.extension(filePath).toLowerCase();
                    
                    try {
                      if (ext == '.novelpack') {
                        // .novelpack 格式：解压导入
                        final fs = LocalFileDataSource();
                        await fs.importNovelPack(filePath);
                      } else if (ext == '.txt' || ext == '.md' || ext == '.docx') {
                        // 文本文件：自动拆章导入（自动创建新作品）
                        final service = NovelImportService();
                        final importResult = await service.importFromFile(
                          filePath: filePath,
                        );
                        if (!importResult.success) {
                          throw Exception(importResult.error ?? '导入失败');
                        }
                      } else {
                        throw Exception('不支持的文件格式: $ext');
                      }
                      
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
              const SizedBox(height: 8),
            ],
          ),
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
          loadNovelMaterials(ref, novel.id);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NovelDetailPage(novel: novel)),
          );
        },
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('重命名'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showRenameNovelDialog(context, ref, novel);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('删除作品', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('删除「${novel.title}」？'),
                          content: const Text('所有章节和资料将被删除，此操作不可恢复'),
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
                        await ref.read(novelRepoProvider).deleteNovel(novel.id, novel.title);
                        ref.invalidate(novelsProvider);
                      }
                    },
                  ),
                ],
              ),
            ),
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
                  if (value == 'export_pack') {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ExportPage(novelId: novel.id, novelTitle: novel.title),
                    ));
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

void _showRenameNovelDialog(BuildContext context, WidgetRef ref, Novel novel) {
  final ctrl = TextEditingController(text: novel.title);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('重命名作品'),
      content: TextField(controller: ctrl, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(
          onPressed: () async {
            if (ctrl.text.trim().isEmpty) return;
            final updated = novel.copyWith(title: ctrl.text.trim());
            await ref.read(novelRepoProvider).updateNovel(updated);
            ref.invalidate(novelsProvider);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}
