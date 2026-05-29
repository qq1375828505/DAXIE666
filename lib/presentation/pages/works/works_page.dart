import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/novel_model.dart';
import 'package:novel_ide/data/models/chapter_model.dart';
import 'package:novel_ide/data/models/volume_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/presentation/pages/writing/editor_page.dart';
import 'package:novel_ide/data/datasources/local_file_datasource.dart';
import 'package:novel_ide/data/services/novel_import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:novel_ide/presentation/pages/works/export_page.dart' hide FileTreeNode;
import 'package:novel_ide/presentation/pages/profile/profile_page.dart';
import 'package:novel_ide/presentation/widgets/file_tree_view.dart';
import 'package:path/path.dart' as p;

class WorksPage extends ConsumerStatefulWidget {
  const WorksPage({super.key});

  @override
  ConsumerState<WorksPage> createState() => _WorksPageState();
}

class _WorksPageState extends ConsumerState<WorksPage> {
  // 展开的作品ID集合
  final Set<String> _expandedNovels = {};
  // 展开的卷ID集合
  final Set<String> _expandedVolumes = {};
  // 已加载的卷数据 novelId -> List<Volume>
  final Map<String, List<Volume>> _loadedVolumes = {};
  // 已加载的章节数据 volumeId -> List<Chapter>
  final Map<String, List<Chapter>> _loadedChapters = {};
  // 正在加载的novelId
  final Set<String> _loadingNovels = {};
  // 正在加载的volumeId
  final Set<String> _loadingVolumes = {};

  @override
  Widget build(BuildContext context) {
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
              // 作品列表（树形）
              Expanded(
                child: _buildWorksTree(novels),
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
              label: const Text('导入 TXT / MD / EPUB 文件'),
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
                setState(() {
                  _expandedNovels.add(novel.id);
                });
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
                title: const Text('导入 TXT / MD / EPUB 文件', style: TextStyle(fontSize: 16)),
                subtitle: const Text('自动拆章创建新作品', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await FilePicker.platform.pickFiles(
                    dialogTitle: '选择小说文件',
                    type: FileType.custom,
                    allowedExtensions: ['txt', 'md', 'docx', 'epub', 'novelpack'],
                  );
                  if (result != null && result.files.single.path != null) {
                    final filePath = result.files.single.path!;
                    final ext = p.extension(filePath).toLowerCase();
                    try {
                      if (ext == '.novelpack') {
                        final fs = LocalFileDataSource();
                        await fs.importNovelPack(filePath);
                      } else if (ext == '.txt' || ext == '.md' || ext == '.docx' || ext == '.epub') {
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

  /// 构建作品工作树
  Widget _buildWorksTree(List<Novel> novels) {
    final treeNodes = novels.map((novel) {
      final isExpanded = _expandedNovels.contains(novel.id);
      final volumes = _loadedVolumes[novel.id];

      List<FileTreeNode> volumeNodes = [];
      if (_loadingNovels.contains(novel.id)) {
        volumeNodes = [FileTreeNode(id: 'loading_${novel.id}', name: '加载中...',)];
      } else if (volumes != null) {
        volumeNodes = volumes.map((vol) => _buildVolumeNode(novel, vol)).toList();
        if (volumeNodes.isEmpty) {
          volumeNodes = [FileTreeNode(id: 'empty_${novel.id}', name: '暂无卷，长按添加',)];
        }
      }

      return FileTreeNode(
        id: novel.id,
        name: novel.title,
        isFolder: true,
        isExpanded: isExpanded,
        icon: Icons.auto_stories,
        iconColor: AppColors.primary,
        trailing: volumes != null
            ? '${volumes.length}卷 ${novel.chapterCount}章 ${_formatWordCount(novel.totalWordCount)}'
            : '${novel.chapterCount}章 ${_formatWordCount(novel.totalWordCount)}',
        children: volumeNodes,
      );
    }).toList();

    return FileTreeView(
      nodes: treeNodes,
      onToggleExpand: (node) => _handleNodeTap(node, novels),
      onNodeTap: (node) => _handleNodeTap(node, novels),
      onNodeLongPress: (node) => _handleNodeLongPress(node, novels),
    );
  }

  FileTreeNode _buildVolumeNode(Novel novel, Volume volume) {
    final isExpanded = _expandedVolumes.contains(volume.id);
    final chapters = _loadedChapters[volume.id];
    final volWordCount = chapters?.fold<int>(0, (s, c) => s + c.wordCount) ?? 0;

    List<FileTreeNode> chapterNodes = [];
    if (_loadingVolumes.contains(volume.id)) {
      chapterNodes = [FileTreeNode(id: 'loading_${volume.id}', name: '加载中...',)];
    } else if (chapters != null) {
      chapterNodes = chapters.map((ch) => _buildChapterNode(novel, ch)).toList();
      if (chapterNodes.isEmpty) {
        chapterNodes = [FileTreeNode(id: 'empty_${volume.id}', name: '暂无章节，长按添加',)];
      }
    }

    return FileTreeNode(
      id: volume.id,
      name: volume.title,
      isFolder: true,
      isExpanded: isExpanded,
      icon: Icons.folder,
      iconColor: Colors.amber[700],
      trailing: chapters != null
          ? '${chapters.length}章 ${_formatWordCount(volWordCount)}'
          : null,
      children: chapterNodes,
    );
  }

  FileTreeNode _buildChapterNode(Novel novel, Chapter chapter) {
    final status = ChapterStatus.values.firstWhere(
      (e) => e.name == chapter.status,
      orElse: () => ChapterStatus.draft,
    );
    return FileTreeNode(
      id: chapter.id,
      name: chapter.title,
      isFolder: false,
      icon: Icons.description,
      iconColor: status.color,
      badge: status.label,
      badgeColor: status.color,
      trailing: '${chapter.wordCount}字',
    );
  }

  void _toggleNovelExpand(String novelId) {
    setState(() {
      if (_expandedNovels.contains(novelId)) {
        _expandedNovels.remove(novelId);
      } else {
        _expandedNovels.add(novelId);
        if (!_loadedVolumes.containsKey(novelId)) {
          _loadVolumes(novelId);
        }
      }
    });
  }

  void _toggleVolumeExpand(String volumeId) {
    setState(() {
      if (_expandedVolumes.contains(volumeId)) {
        _expandedVolumes.remove(volumeId);
      } else {
        _expandedVolumes.add(volumeId);
        if (!_loadedChapters.containsKey(volumeId)) {
          _loadChapters(volumeId);
        }
      }
    });
  }

  /// 路由节点点击：判断是作品/卷/章节
  void _handleNodeTap(FileTreeNode node, List<Novel> novels) {
    // 作品级节点
    if (_expandedNovels.contains(node.id) || novels.any((n) => n.id == node.id)) {
      _toggleNovelExpand(node.id);
      return;
    }
    // 卷级节点
    if (_loadedVolumes.values.any((vols) => vols.any((v) => v.id == node.id))) {
      _toggleVolumeExpand(node.id);
      return;
    }
    // 章节级节点
    final chapterData = _findChapterById(node.id);
    if (chapterData != null) {
      final (novel, chapter) = chapterData;
      ref.read(selectedNovelProvider.notifier).state = novel;
      ref.read(selectedChapterProvider.notifier).state = chapter;
      Navigator.push(context, MaterialPageRoute(builder: (_) => EditorPage(novelId: novel.id, chapterId: chapter.id)));
    }
  }

  /// 路由节点长按：判断是作品/卷/章节
  void _handleNodeLongPress(FileTreeNode node, List<Novel> novels) {
    // 作品级
    final novel = novels.where((n) => n.id == node.id).firstOrNull;
    if (novel != null) { _showNovelMenu(novel); return; }
    // 卷级
    final volumeData = _findVolumeById(node.id);
    if (volumeData != null) { _showVolumeMenu(volumeData.$1, volumeData.$2); return; }
    // 章节级
    final chapterData = _findChapterById(node.id);
    if (chapterData != null) { _showChapterMenu(chapterData.$1, chapterData.$2); }
  }

  /// 在已加载的卷数据中查找Volume
  (Novel, Volume)? _findVolumeById(String volumeId) {
    for (final entry in _loadedVolumes.entries) {
      final novelId = entry.key;
      for (final vol in entry.value) {
        if (vol.id == volumeId) {
          final novel = ref.read(novelsProvider).valueOrNull?.where((n) => n.id == novelId).firstOrNull;
          if (novel != null) return (novel, vol);
        }
      }
    }
    return null;
  }

  /// 在已加载的章节数据中查找Chapter
  (Novel, Chapter)? _findChapterById(String chapterId) {
    for (final entry in _loadedChapters.entries) {
      for (final ch in entry.value) {
        if (ch.id == chapterId) {
          final novel = ref.read(novelsProvider).valueOrNull?.where((n) => n.id == ch.novelId).firstOrNull;
          if (novel != null) return (novel, ch);
        }
      }
    }
    return null;
  }

  Future<void> _loadVolumes(String novelId) async {
    setState(() => _loadingNovels.add(novelId));
    final volumes = await ref.read(volumeRepoProvider).getVolumesByNovel(novelId);
    if (mounted) {
      setState(() {
        _loadingNovels.remove(novelId);
        _loadedVolumes[novelId] = volumes;
      });
    }
  }

  Future<void> _loadChapters(String volumeId) async {
    setState(() => _loadingVolumes.add(volumeId));
    final chapters = await ref.read(chapterRepoProvider).getChaptersByVolume(volumeId);
    if (mounted) {
      setState(() {
        _loadingVolumes.remove(volumeId);
        _loadedChapters[volumeId] = chapters;
      });
    }
  }

  // --- 作品长按菜单 ---
  void _showNovelMenu(Novel novel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 8),
              ListTile(leading: const Icon(Icons.edit), title: const Text('重命名'), onTap: () { Navigator.pop(ctx); _showRenameNovelDialog(novel); }),
              ListTile(leading: const Icon(Icons.file_download_outlined), title: const Text('导出'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => ExportPage(novelId: novel.id, novelTitle: novel.title))); }),
              ListTile(leading: Icon(Icons.create_new_folder, color: AppColors.primary), title: const Text('新建卷'), onTap: () { Navigator.pop(ctx); _showCreateVolumeDialog(novel); }),
              ListTile(leading: const Icon(Icons.delete_outline, color: AppColors.error), title: Text('删除作品', style: TextStyle(color: AppColors.error)), onTap: () async { Navigator.pop(ctx); _confirmDeleteNovel(novel); }),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameNovelDialog(Novel novel) {
    final ctrl = TextEditingController(text: novel.title);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('重命名作品'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () async { if (ctrl.text.trim().isEmpty) return; await ref.read(novelRepoProvider).updateNovel(novel.copyWith(title: ctrl.text.trim())); ref.invalidate(novelsProvider); if (ctx.mounted) Navigator.pop(ctx); }, child: const Text('确定')),
      ],
    ));
  }

  void _confirmDeleteNovel(Novel novel) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('删除「${novel.title}」？'),
      content: const Text('所有章节和资料将被删除，此操作不可恢复'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.error), onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
      ],
    ));
    if (confirm == true) {
      await ref.read(novelRepoProvider).deleteNovel(novel.id, novel.title);
      ref.invalidate(novelsProvider);
    }
  }

  // --- 卷操作 ---
  void _showCreateVolumeDialog(Novel novel) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('新建卷'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: '卷名', hintText: '例如：第一卷 潜龙在渊')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () async {
          if (ctrl.text.trim().isEmpty) return;
          final existing = _loadedVolumes[novel.id] ?? [];
          await ref.read(volumeRepoProvider).createVolume(novelId: novel.id, title: ctrl.text.trim(), orderIndex: existing.length);
          ref.invalidate(novelsProvider);
          _loadedVolumes.remove(novel.id);
          if (ctx.mounted) Navigator.pop(ctx);
          setState(() {});
        }, child: const Text('创建')),
      ],
    ));
  }

  void _showVolumeMenu(Novel novel, Volume volume) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (ctx) => Container(
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 8),
        ListTile(leading: Icon(Icons.add, color: AppColors.primary), title: const Text('添加章节'), onTap: () { Navigator.pop(ctx); _showCreateChapterDialog(novel, volume); }),
        ListTile(leading: const Icon(Icons.edit), title: const Text('编辑卷概要'), onTap: () { Navigator.pop(ctx); _showEditVolumeSummaryDialog(volume); }),
        ListTile(leading: const Icon(Icons.delete_outline, color: AppColors.error), title: Text('删除卷', style: TextStyle(color: AppColors.error)), onTap: () async { Navigator.pop(ctx); _confirmDeleteVolume(novel, volume); }),
      ])),
    ));
  }

  void _showEditVolumeSummaryDialog(Volume volume) {
    final ctrl = TextEditingController(text: volume.summary ?? '');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('编辑「${volume.title}」概要'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: TextField(controller: ctrl, maxLines: 5, decoration: const InputDecoration(hintText: '输入卷概要...')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () async { await ref.read(volumeRepoProvider).updateVolume(volume.copyWith(summary: ctrl.text.trim().isEmpty ? null : ctrl.text.trim())); if (ctx.mounted) Navigator.pop(ctx); }, child: const Text('保存')),
      ],
    ));
  }

  void _confirmDeleteVolume(Novel novel, Volume volume) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('删除「${volume.title}」？'),
      content: const Text('该卷下所有章节将被删除'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.error), onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
      ],
    ));
    if (confirm == true) {
      await ref.read(volumeRepoProvider).deleteVolume(volume.id);
      _loadedVolumes.remove(novel.id);
      _loadedChapters.remove(volume.id);
      ref.invalidate(novelsProvider);
      setState(() {});
    }
  }

  // --- 章节操作 ---
  void _showCreateChapterDialog(Novel novel, Volume volume) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('新建章节'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: '章节标题', hintText: '例如：第1章 退婚')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () async {
          if (ctrl.text.trim().isEmpty) return;
          final existing = _loadedChapters[volume.id] ?? [];
          final chapter = await ref.read(chapterRepoProvider).createChapter(novelId: novel.id, volumeId: volume.id, title: ctrl.text.trim(), orderIndex: existing.length);
          ref.invalidate(novelsProvider);
          _loadedChapters.remove(volume.id);
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ref.read(selectedNovelProvider.notifier).state = novel;
            ref.read(selectedChapterProvider.notifier).state = chapter;
            Navigator.push(context, MaterialPageRoute(builder: (_) => EditorPage(novelId: novel.id, chapterId: chapter.id)));
          }
        }, child: const Text('创建并编辑')),
      ],
    ));
  }

  void _showChapterMenu(Novel novel, Chapter chapter) {
    final status = ChapterStatus.values.firstWhere((e) => e.name == chapter.status, orElse: () => ChapterStatus.draft);
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (ctx) => Container(
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 8),
        ListTile(leading: const Icon(Icons.edit), title: const Text('编辑'), onTap: () { Navigator.pop(ctx); ref.read(selectedNovelProvider.notifier).state = novel; ref.read(selectedChapterProvider.notifier).state = chapter; Navigator.push(context, MaterialPageRoute(builder: (_) => EditorPage(novelId: novel.id, chapterId: chapter.id))); }),
        ListTile(leading: const Icon(Icons.summarize), title: const Text('编辑梗概'), onTap: () { Navigator.pop(ctx); _showEditSummaryDialog(novel, chapter); }),
        ...ChapterStatus.values.map((s) => ListTile(
          leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(6))),
          title: Text(s.label),
          trailing: s == status ? const Icon(Icons.check, size: 18) : null,
          onTap: () async { Navigator.pop(ctx); await ref.read(chapterRepoProvider).updateChapter(chapter.copyWith(status: s.name), novel.title); _loadedChapters.remove(chapter.volumeId); ref.invalidate(novelsProvider); setState(() {}); },
        )),
        const Divider(),
        ListTile(leading: const Icon(Icons.delete_outline, color: AppColors.error), title: Text('删除章节', style: TextStyle(color: AppColors.error)), onTap: () async { Navigator.pop(ctx); final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('删除章节？'), content: Text('确定删除「${chapter.title}」？'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')), FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.error), onPressed: () => Navigator.pop(ctx, true), child: const Text('删除'))])); if (confirm == true) { await ref.read(chapterRepoProvider).deleteChapter(chapter.id); _loadedChapters.remove(chapter.volumeId); ref.invalidate(novelsProvider); setState(() {}); } }),
      ])),
    ));
  }

  void _showEditSummaryDialog(Novel novel, Chapter chapter) {
    final ctrl = TextEditingController(text: chapter.summary ?? '');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('编辑「${chapter.title}」梗概'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: TextField(controller: ctrl, maxLines: 5, decoration: const InputDecoration(hintText: '输入本章梗概...')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () async { await ref.read(chapterRepoProvider).updateChapter(chapter.copyWith(summary: ctrl.text.trim().isEmpty ? null : ctrl.text.trim()), novel.title); _loadedChapters.remove(chapter.volumeId); if (ctx.mounted) Navigator.pop(ctx); setState(() {}); }, child: const Text('保存')),
      ],
    ));
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
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
      ],
    );
  }
}

