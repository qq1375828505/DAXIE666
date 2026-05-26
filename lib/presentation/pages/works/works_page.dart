import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/novel_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/presentation/pages/works/novel_detail_page.dart';
import 'package:novel_ide/data/datasources/local_file_datasource.dart';
import 'package:novel_ide/data/services/novel_import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:novel_ide/presentation/pages/works/export_page.dart';
import 'package:novel_ide/presentation/pages/profile/profile_page.dart';
import 'package:path/path.dart' as p;

class WorksPage extends ConsumerWidget {
  const WorksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final novelsAsync = ref.watch(novelsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          '网文写作IDE',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: '导入作品',
            onPressed: () => _showImportDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
          ),
        ],
      ),
      body: novelsAsync.when(
        data: (novels) {
          if (novels.isEmpty) {
            return _buildEmptyState(context, ref);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部统计栏
              _buildStatsHeader(novels),
              // 作品列表
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: novels.length,
                  itemBuilder: (context, index) {
                    return _NovelCard(novel: novels[index]);
                  },
                ),
              ),
            ],
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

  /// 顶部统计摘要
  Widget _buildStatsHeader(List<Novel> novels) {
    final totalWords = novels.fold<int>(0, (sum, n) => sum + n.totalWordCount);
    final totalChapters = novels.fold<int>(0, (sum, n) => sum + n.chapterCount);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: '作品', value: '${novels.length}'),
          Container(width: 1, height: 28, color: Colors.white.withOpacity(0.3)),
          _StatItem(label: '总字数', value: _formatWordCount(totalWords)),
          Container(width: 1, height: 28, color: Colors.white.withOpacity(0.3)),
          _StatItem(label: '总章节', value: '$totalChapters'),
        ],
      ),
    );
  }

  String _formatWordCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    return '$count';
  }

  /// 空状态
  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_stories, size: 48, color: AppColors.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            const Text(
              '开始你的创作之旅',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '创建一部作品，开启网文写作之路',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _showCreateNovelDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('新建作品'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _showImportDialog(context, ref),
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('导入 TXT / MD 文件'),
            ),
          ],
        ),
      ),
    );
  }

  /// 新建作品对话框
  void _showCreateNovelDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建作品'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: '作品名称',
                hintText: '例如：都市神医',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                labelText: '简介（可选）',
                hintText: '一句话简介',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NovelDetailPage(novel: novel)),
                );
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  /// 导入对话框
  void _showImportDialog(BuildContext context, WidgetRef ref) {
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
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('导入作品', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.description_outlined, color: AppColors.primary),
                ),
                title: const Text('导入 TXT / MD 文件', style: TextStyle(fontSize: 16)),
                subtitle: const Text('自动拆章创建新作品', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                        final fs = LocalFileDataSource();
                        await fs.importNovelPack(filePath);
                      } else if (ext == '.txt' || ext == '.md' || ext == '.docx') {
                        final service = NovelImportService();
                        final importResult = await service.importFromFile(filePath: filePath);
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
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// 统计项
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
        ),
      ],
    );
  }
}

/// 作品卡片
class _NovelCard extends ConsumerWidget {
  final Novel novel;
  const _NovelCard({required this.novel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeStr = DateFormat('MM-dd HH:mm').format(novel.updatedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          ref.read(selectedNovelProvider.notifier).state = novel;
          loadNovelMaterials(ref, novel.id);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NovelDetailPage(novel: novel)),
          );
        },
        onLongPress: () => _showActions(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 封面
              _buildCover(),
              const SizedBox(width: 16),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      novel.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (novel.description != null && novel.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        novel.description!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildStatTag(Icons.font_download_outlined, '${novel.totalWordCount}字'),
                        const SizedBox(width: 12),
                        _buildStatTag(Icons.article_outlined, '${novel.chapterCount}章'),
                        const SizedBox(width: 12),
                        _buildStatTag(Icons.access_time, timeStr),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey[300]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    // 渐变封面
    final colors = [
      AppColors.primary.withOpacity(0.15),
      AppColors.primary.withOpacity(0.05),
    ];
    return Container(
      width: 68,
      height: 92,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 28, color: AppColors.primary.withOpacity(0.6)),
          const SizedBox(height: 4),
          Text(
            '${novel.chapterCount}章',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTag(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey[400]),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
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
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('重命名'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameDialog(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('导出'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ExportPage(novelId: novel.id, novelTitle: novel.title),
                  ));
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('删除作品', style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('删除「${novel.title}」？'),
                      content: const Text('所有章节和资料将被删除，此操作不可恢复'),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: novel.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名作品'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
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
}
