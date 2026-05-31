import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/presentation/pages/ai/ai_chat_page.dart';
import 'package:novel_ide/presentation/pages/profile/profile_page.dart';
import 'package:novel_ide/presentation/pages/works/export_page.dart';
import 'package:novel_ide/presentation/pages/materials/materials_tree_page.dart';
import 'package:novel_ide/presentation/pages/materials/relationship_graph_page.dart';
import 'package:novel_ide/presentation/pages/stats/stats_page.dart';
import 'package:novel_ide/presentation/pages/tomato/shuangdian_report_page.dart';
import 'package:novel_ide/presentation/pages/tomato/water_report_page.dart';
import 'package:novel_ide/presentation/pages/tomato/title_generator_result_page.dart';
import 'package:novel_ide/presentation/pages/ai/full_text_review_page.dart';
import 'package:novel_ide/presentation/pages/tomato/agent_marketplace_page.dart';
import 'package:novel_ide/presentation/pages/ai/polish_engine_page.dart';
import 'package:novel_ide/presentation/pages/tomato/style_selector_bar.dart';
import 'package:novel_ide/presentation/pages/profile/skill_manage_page.dart';
import 'package:novel_ide/data/models/novel_model.dart';
import 'package:novel_ide/data/models/chapter_model.dart';
import 'package:novel_ide/data/models/volume_model.dart';
import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/data/models/ai_chat_session_model.dart';
import 'package:novel_ide/data/repositories/volume_repository.dart';
import 'package:novel_ide/data/repositories/chapter_repository.dart';
import 'package:novel_ide/data/repositories/chat_history_repository.dart';
import 'package:novel_ide/data/services/novel_import_service.dart';
import 'package:novel_ide/presentation/pages/writing/editor_page.dart';
import 'package:novel_ide/presentation/pages/writing/global_search_page.dart';
import 'package:novel_ide/presentation/pages/outline/outline_page.dart';
import 'package:novel_ide/presentation/widgets/top_notification.dart';
import 'package:novel_ide/core/router.dart';

/// GPT风格单页面聊天应用
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _sidebarOpen = false;
  bool _modelDropdownOpen = false;
  
  // 作品树展开状态
  final Set<String> _expandedNovels = {};
  final Set<String> _expandedVolumes = {};
  final Map<String, List<Volume>> _loadedVolumes = {};
  final Map<String, List<Chapter>> _loadedChapters = {};
  
  // 历史会话列表
  final ChatHistoryRepository _historyRepo = ChatHistoryRepository();
  List<AiChatSessionModel> _chatSessions = [];
  bool _sessionsLoaded = false;
  
  // 当前选中的模型名称（用于显示）
  String _selectedModelDisplay = 'GLM-4.7-Flash';

  @override
  void initState() {
    super.initState();
    _loadChatSessions();
  }

  /// 加载历史会话列表
  Future<void> _loadChatSessions() async {
    try {
      final sessions = await _historyRepo.loadSessions();
      if (mounted) {
        setState(() {
          _chatSessions = sessions;
          _sessionsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Load chat sessions error: $e');
      if (mounted) {
        setState(() => _sessionsLoaded = true);
      }
    }
  }

  /// 触发新建会话
  void _triggerNewSession() {
    // 通过增加触发器值来通知 AiChatPage 新建会话
    final currentTrigger = ref.read(newSessionTriggerProvider);
    ref.read(newSessionTriggerProvider.notifier).state = currentTrigger + 1;
    setState(() => _sidebarOpen = false);
  }

  /// 切换到指定会话
  void _switchToSession(String sessionId) {
    ref.read(currentSessionIdProvider.notifier).state = sessionId;
    setState(() => _sidebarOpen = false);
  }

  /// 处理导入文件
  Future<void> _handleImport() async {
    setState(() => _sidebarOpen = false);
    
    final selectedNovel = ref.read(selectedNovelProvider);
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'docx', 'epub'],
      );
      
      if (result == null || result.files.isEmpty) return;
      
      final filePath = result.files.first.path;
      if (filePath == null) return;
      
      final importService = NovelImportService();
      final preview = await importService.previewImport(filePath);
      
      if (!mounted) return;
      
      // 显示导入预览对话框
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导入预览'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('类型: ${preview.detectedType}'),
              Text('识别来源: ${preview.matchSource}'),
              Text('章节数: ${preview.chapters.length}'),
              Text('总字数: ${preview.totalWords}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('导入'),
            ),
          ],
        ),
      );
      
      if (confirm != true || !mounted) return;
      
      // 执行导入
      final importResult = await importService.importFromFile(
        novelId: selectedNovel?.id,
        novelTitle: selectedNovel?.title,
        filePath: filePath,
      );
      
      if (!mounted) return;
      
      if (importResult.success) {
        TopNotification.success(context, '导入成功：${importResult.chapterCount} 章');
        // 刷新作品列表
        ref.invalidate(novelsProvider);
      } else {
        TopNotification.error(context, '导入失败：${importResult.error}');
      }
    } catch (e) {
      if (mounted) {
        TopNotification.error(context, '导入失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final novels = ref.watch(novelsProvider).valueOrNull ?? [];
    final selectedNovel = ref.watch(selectedNovelProvider);
    final aiConfigs = ref.watch(aiConfigsProvider);
    final selectedAiConfig = ref.watch(selectedAiConfigProvider);
    
    // 更新显示的模型名称
    if (selectedAiConfig != null) {
      _selectedModelDisplay = selectedAiConfig.name;
    } else if (aiConfigs.isNotEmpty) {
      final textConfig = aiConfigs.where((c) => c.modelType == ModelType.text).firstOrNull;
      if (textConfig != null) {
        _selectedModelDisplay = textConfig.name;
      }
    }
    
    // GPT风格颜色
    const bgColor = Color(0xFF000000);
    const sidebarBg = Color(0xFF171717);
    const cardBg = Color(0xFF1A1A1A);
    const cardBg2 = Color(0xFF2A2A2A);
    const primaryColor = Color(0xFF10A37F);
    const textPrimary = Color(0xFFFFFFFF);
    const textSecondary = Color(0xFF888888);
    const textTertiary = Color(0xFF666666);
    const dividerColor = Color(0xFF2A2A2A);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 主内容区
          Column(
            children: [
              // 顶部栏
              _buildTopBar(
                context: context,
                bgColor: bgColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                primaryColor: primaryColor,
                cardBg: cardBg,
              ),
              // 聊天内容区
              const Expanded(
                child: AiChatPage(),
              ),
            ],
          ),
          
          // 侧边栏遮罩
          if (_sidebarOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _sidebarOpen = false),
                child: Container(color: Colors.black54),
              ),
            ),
          
          // 左侧侧边栏
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            left: _sidebarOpen ? 0 : -300,
            top: 0,
            bottom: 0,
            width: 280,
            child: _buildSidebar(
              context: context,
              sidebarBg: sidebarBg,
              cardBg: cardBg,
              cardBg2: cardBg2,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              textTertiary: textTertiary,
              primaryColor: primaryColor,
              dividerColor: dividerColor,
              novels: novels,
              selectedNovel: selectedNovel,
            ),
          ),
          
          // 模型选择下拉菜单
          if (_modelDropdownOpen)
            Positioned(
              top: 52,
              left: 0,
              right: 0,
              child: Center(
                child: _buildModelDropdown(
                  context: context,
                  cardBg: cardBg,
                  cardBg2: cardBg2,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primaryColor: primaryColor,
                  dividerColor: dividerColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 顶部栏
  Widget _buildTopBar({
    required BuildContext context,
    required Color bgColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required Color cardBg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // 菜单按钮
            IconButton(
              icon: Icon(Icons.menu, color: textPrimary, size: 24),
              onPressed: () => setState(() => _sidebarOpen = true),
            ),
            // 标题区域（点击展开模型选择）
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _modelDropdownOpen = !_modelDropdownOpen),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '网文写作IDE',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F2F2F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedModelDisplay,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 新建按钮
            IconButton(
              icon: Icon(Icons.edit, color: textPrimary, size: 22),
              onPressed: _triggerNewSession,
            ),
            // 搜索按钮
            IconButton(
              icon: Icon(Icons.search, color: textPrimary, size: 22),
              onPressed: () {
                final novel = ref.read(selectedNovelProvider);
                if (novel != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GlobalSearchPage(
                        novelId: novel.id,
                        novelTitle: novel.title,
                      ),
                    ),
                  );
                } else {
                  TopNotification.show(context, '请先选择一部作品再使用全局搜索');
                }
              },
            ),
            // 设置按钮
            IconButton(
              icon: Icon(Icons.settings, color: textPrimary, size: 22),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
            ),
            // AI工具按钮
            IconButton(
              icon: Icon(Icons.psychology, color: primaryColor, size: 22),
              onPressed: () {
                _showAiToolsMenu();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 左侧侧边栏
  Widget _buildSidebar({
    required BuildContext context,
    required Color sidebarBg,
    required Color cardBg,
    required Color cardBg2,
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
    required Color primaryColor,
    required Color dividerColor,
    required List<Novel> novels,
    required Novel? selectedNovel,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: dividerColor)),
      ),
      child: Column(
        children: [
          // 新会话按钮
          Padding(
            padding: const EdgeInsets.all(14),
            child: GestureDetector(
              onTap: _triggerNewSession,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF333333)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add, color: textPrimary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '新会话',
                      style: TextStyle(color: textPrimary, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 滚动内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 历史会话（从真实数据源读取）
                  _buildSectionLabel('历史会话', textSecondary),
                  if (_chatSessions.isEmpty && _sessionsLoaded)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Text('暂无历史会话', style: TextStyle(color: textTertiary, fontSize: 12)),
                    )
                  else
                    ..._chatSessions.take(10).map((session) => _buildHistoryItemFromModel(
                      session,
                      textPrimary,
                      textTertiary,
                      cardBg2,
                    )),
                  
                  const SizedBox(height: 8),
                  _buildSectionLabel('作品', textSecondary),
                  
                  // 作品树
                  ...novels.map((novel) => _buildNovelNode(
                    novel: novel,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    textTertiary: textTertiary,
                    primaryColor: primaryColor,
                    cardBg2: cardBg2,
                    selectedNovel: selectedNovel,
                  )),
                  
                  const SizedBox(height: 8),
                  _buildSectionLabel('资料库', textSecondary),
                  
                  // 资料库分类 - 读取真实数量
                  ..._buildMaterialNodesWithCounts(
                    selectedNovel,
                    textPrimary,
                    textTertiary,
                    cardBg2,
                    primaryColor,
                  ),
                  
                  const SizedBox(height: 8),
                  _buildSectionLabel('AI工具', textSecondary),
                  
                  // AI工具分类
                  _buildAiToolNode('写作统计', Icons.bar_chart, textPrimary, textTertiary, cardBg2, materialType: 'stats'),
                  _buildAiToolNode('爽点报告', Icons.analytics, textPrimary, textTertiary, cardBg2, materialType: 'shuangdian'),
                  _buildAiToolNode('水文检测', Icons.water_drop, textPrimary, textTertiary, cardBg2, materialType: 'water'),
                  _buildAiToolNode('标题生成', Icons.title, textPrimary, textTertiary, cardBg2, materialType: 'title'),
                  _buildAiToolNode('全文审查', Icons.fact_check, textPrimary, textTertiary, cardBg2, materialType: 'review'),
                  _buildAiToolNode('润色引擎', Icons.auto_fix_high, textPrimary, textTertiary, cardBg2, materialType: 'polish'),
                  _buildAiToolNode('风格预设', Icons.palette, textPrimary, textTertiary, cardBg2, materialType: 'style_preset'),
                  _buildAiToolNode('Agent市场', Icons.store, textPrimary, textTertiary, cardBg2, materialType: 'agent_market'),
                  _buildAiToolNode('写作技能', Icons.build, textPrimary, textTertiary, cardBg2, materialType: 'skill_manage'),
                ],
              ),
            ),
          ),
          
          // 底部导出/导入按钮
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _sidebarOpen = false);
                      // 跳转到导出页面
                      final novel = ref.read(selectedNovelProvider);
                      if (novel != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExportPage(novelId: novel.id, novelTitle: novel.title),
                          ),
                        );
                      } else {
                        TopNotification.show(context, '请先选择一部作品');
                      }
                    },
                    icon: const Icon(Icons.upload, size: 16),
                    label: const Text('导出'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: const BorderSide(color: Color(0xFF333333)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleImport,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('导入'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: const BorderSide(color: Color(0xFF333333)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String title, String time, Color textPrimary, Color textTertiary, Color cardBg2) {
    return GestureDetector(
      onTap: () {
        setState(() => _sidebarOpen = false);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: cardBg2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: textPrimary, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: TextStyle(color: textTertiary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  /// 从会话模型构建历史会话项
  Widget _buildHistoryItemFromModel(
    AiChatSessionModel session,
    Color textPrimary,
    Color textTertiary,
    Color cardBg2,
  ) {
    final currentSessionId = ref.watch(currentSessionIdProvider);
    final isSelected = currentSessionId == session.id;
    
    // 格式化时间
    String timeStr;
    final now = DateTime.now();
    final updatedAt = session.updatedAt;
    if (now.year == updatedAt.year && now.month == updatedAt.month && now.day == updatedAt.day) {
      timeStr = '今天 ${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}';
    } else if (now.year == updatedAt.year && now.month == updatedAt.month && now.day - updatedAt.day == 1) {
      timeStr = '昨天 ${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}';
    } else {
      timeStr = '${updatedAt.month}月${updatedAt.day}日';
    }
    
    return GestureDetector(
      onTap: () => _switchToSession(session.id),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2A3A2A) : cardBg2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.title,
              style: TextStyle(color: textPrimary, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              timeStr,
              style: TextStyle(color: textTertiary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNovelNode({
    required Novel novel,
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
    required Color primaryColor,
    required Color cardBg2,
    required Novel? selectedNovel,
  }) {
    final isExpanded = _expandedNovels.contains(novel.id);
    final volumes = _loadedVolumes[novel.id];
    final isSelected = selectedNovel?.id == novel.id;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _toggleNovelExpand(novel.id),
          onLongPress: () => _showNovelContextMenu(novel),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: isSelected ? cardBg2 : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: textTertiary,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Icon(Icons.menu_book, color: textPrimary, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    novel.title,
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F2F2F),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${novel.chapterCount}章',
                    style: TextStyle(color: textSecondary, fontSize: 10),
                  ),
                ),
                const SizedBox(width: 4),
                // 大纲按钮
                GestureDetector(
                  onTap: () {
                    ref.read(selectedNovelProvider.notifier).state = novel;
                    setState(() => _sidebarOpen = false);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OutlinePage()),
                    );
                  },
                  child: Icon(Icons.account_tree, color: primaryColor, size: 14),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && volumes != null)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: volumes.map((vol) => _buildVolumeNode(
                volume: vol,
                novel: novel,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                textTertiary: textTertiary,
                cardBg2: cardBg2,
              )).toList(),
            ),
          ),
      ],
    );
  }

  /// 显示作品长按菜单
  void _showNovelContextMenu(Novel novel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(novel.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.add, color: Colors.white),
                title: const Text('新建卷', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showNewVolumeDialog(novel);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text('重命名作品', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameNovelDialog(novel);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除作品', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteNovelConfirm(novel);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// 新建卷对话框
  void _showNewVolumeDialog(Novel novel) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('新建卷', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '卷名称',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final volumeRepo = ref.read(volumeRepoProvider);
              await volumeRepo.createVolume(
                novelId: novel.id,
                title: ctrl.text.trim(),
                orderIndex: (_loadedVolumes[novel.id]?.length ?? 0),
              );
              Navigator.pop(ctx);
              // 刷新卷列表
              final volumes = await volumeRepo.getVolumesByNovel(novel.id);
              setState(() {
                _loadedVolumes[novel.id] = volumes;
              });
              TopNotification.success(context, '已创建卷：${ctrl.text.trim()}');
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  /// 重命名作品对话框
  void _showRenameNovelDialog(Novel novel) {
    final ctrl = TextEditingController(text: novel.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('重命名作品', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '作品名称',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final novelRepo = ref.read(novelRepoProvider);
              await novelRepo.updateNovel(novel.copyWith(title: ctrl.text.trim()));
              Navigator.pop(ctx);
              // 刷新作品列表
              ref.invalidate(novelsProvider);
              TopNotification.success(context, '已重命名');
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 删除作品确认
  void _showDeleteNovelConfirm(Novel novel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('删除作品', style: TextStyle(color: Colors.white)),
        content: Text('确定要删除「${novel.title}」吗？此操作不可恢复。', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final novelRepo = ref.read(novelRepoProvider);
              await novelRepo.deleteNovel(novel.id, novel.title);
              Navigator.pop(ctx);
              // 清除选中状态
              if (ref.read(selectedNovelProvider)?.id == novel.id) {
                ref.read(selectedNovelProvider.notifier).state = null;
              }
              // 刷新作品列表
              ref.invalidate(novelsProvider);
              TopNotification.success(context, '已删除');
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeNode({
    required Volume volume,
    required Novel novel,
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
    required Color cardBg2,
  }) {
    final isExpanded = _expandedVolumes.contains(volume.id);
    final chapters = _loadedChapters[volume.id];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _toggleVolumeExpand(volume.id),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: textTertiary,
                  size: 14,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.folder, color: Color(0xFFFFC107), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    volume.title,
                    style: TextStyle(color: textPrimary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && chapters != null)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: chapters.map((ch) => _buildChapterLeaf(
                chapter: ch,
                novel: novel,
                textPrimary: textPrimary,
                textTertiary: textTertiary,
                cardBg2: cardBg2,
              )).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildChapterLeaf({
    required Chapter chapter,
    required Novel novel,
    required Color textPrimary,
    required Color textTertiary,
    required Color cardBg2,
  }) {
    final status = ChapterStatus.values.firstWhere(
      (e) => e.name == chapter.status,
      orElse: () => ChapterStatus.draft,
    );
    
    Color badgeColor;
    String badgeText;
    switch (status) {
      case ChapterStatus.unwritten:
        badgeColor = const Color(0xFF6C757D);
        badgeText = '未写';
        break;
      case ChapterStatus.draft:
        badgeColor = const Color(0xFFFFC107);
        badgeText = '草稿';
        break;
      case ChapterStatus.polishing:
        badgeColor = const Color(0xFF17A2B8);
        badgeText = '润色中';
        break;
      case ChapterStatus.completed:
        badgeColor = const Color(0xFF28A745);
        badgeText = '已完成';
        break;
      case ChapterStatus.exported:
        badgeColor = const Color(0xFF007BFF);
        badgeText = '已导出';
        break;
    }
    
    return GestureDetector(
      onTap: () {
        ref.read(selectedNovelProvider.notifier).state = novel;
        ref.read(selectedChapterProvider.notifier).state = chapter;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditorPage(novelId: novel.id, chapterId: chapter.id),
          ),
        );
        setState(() => _sidebarOpen = false);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          children: [
            const Icon(Icons.description, color: Color(0xFF999999), size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                chapter.title,
                style: TextStyle(color: textPrimary, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: TextStyle(color: badgeColor, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialNode(
    String label,
    int count,
    IconData icon,
    Color textPrimary,
    Color textTertiary,
    Color cardBg2, {
    String? materialType,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() => _sidebarOpen = false);
        // 设置初始分类，供 MaterialsTreePage 读取
        if (materialType != null) {
          ref.read(initialMaterialTabProvider.notifier).state = materialType;
        } else {
          ref.read(initialMaterialTabProvider.notifier).state = null;
        }
        // 跳转到资料库页面
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MaterialsTreePage(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        margin: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Icon(Icons.keyboard_arrow_right, color: textTertiary, size: 16),
            const SizedBox(width: 4),
            Icon(icon, color: textPrimary, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$label ($count)',
                style: TextStyle(color: textPrimary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建资料库节点列表，包含真实数量和关系图按钮
  List<Widget> _buildMaterialNodesWithCounts(
    Novel? selectedNovel,
    Color textPrimary,
    Color textTertiary,
    Color cardBg2,
    Color primaryColor,
  ) {
    // 没有选中作品时，显示默认数量并始终显示关系图按钮
    if (selectedNovel == null) {
      return [
        // 角色节点 + 关系图按钮（始终显示）
        _buildCharacterNodeWithGraphButton(
          0,
          textPrimary,
          textTertiary,
          cardBg2,
          primaryColor,
          selectedNovel,
        ),
        _buildMaterialNode('设定', 0, Icons.settings, textPrimary, textTertiary, cardBg2, materialType: 'setting'),
        _buildMaterialNode('地点', 0, Icons.location_on, textPrimary, textTertiary, cardBg2, materialType: 'location'),
        _buildMaterialNode('势力', 0, Icons.account_balance, textPrimary, textTertiary, cardBg2, materialType: 'faction'),
        _buildMaterialNode('道具', 0, Icons.inventory_2, textPrimary, textTertiary, cardBg2, materialType: 'item'),
        _buildMaterialNode('伏笔', 0, Icons.lightbulb_outline, textPrimary, textTertiary, cardBg2, materialType: 'hook'),
        _buildMaterialNode('参考', 0, Icons.book, textPrimary, textTertiary, cardBg2, materialType: 'reference'),
        _buildMaterialNode('记忆包', 0, Icons.psychology, textPrimary, textTertiary, cardBg2),
      ];
    }

    // 读取真实数量
    final novelId = selectedNovel.id;
    final characters = ref.watch(charactersProvider(novelId));
    final settings = ref.watch(settingCardsProvider(novelId));
    final locations = ref.watch(locationsProvider(novelId));
    final hooks = ref.watch(plotHooksProvider(novelId));
    final factions = ref.watch(factionsProvider(novelId));
    final items = ref.watch(itemsProvider(novelId));
    final references = ref.watch(referencesProvider(novelId));

    return [
      // 角色节点 + 关系图按钮
      _buildCharacterNodeWithGraphButton(
        characters.length,
        textPrimary,
        textTertiary,
        cardBg2,
        primaryColor,
        selectedNovel,
      ),
      _buildMaterialNode('设定', settings.length, Icons.settings, textPrimary, textTertiary, cardBg2, materialType: 'setting'),
      _buildMaterialNode('地点', locations.length, Icons.location_on, textPrimary, textTertiary, cardBg2, materialType: 'location'),
      _buildMaterialNode('势力', factions.length, Icons.account_balance, textPrimary, textTertiary, cardBg2, materialType: 'faction'),
      _buildMaterialNode('道具', items.length, Icons.inventory_2, textPrimary, textTertiary, cardBg2, materialType: 'item'),
      _buildMaterialNode('伏笔', hooks.length, Icons.lightbulb_outline, textPrimary, textTertiary, cardBg2, materialType: 'hook'),
      _buildMaterialNode('参考', references.length, Icons.book, textPrimary, textTertiary, cardBg2, materialType: 'reference'),
      _buildMaterialNode('记忆包', 0, Icons.psychology, textPrimary, textTertiary, cardBg2),
    ];
  }

  /// 构建角色节点，包含关系图按钮
  Widget _buildCharacterNodeWithGraphButton(
    int count,
    Color textPrimary,
    Color textTertiary,
    Color cardBg2,
    Color primaryColor,
    Novel? selectedNovel,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      margin: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          // 角色节点
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _sidebarOpen = false);
                ref.read(initialMaterialTabProvider.notifier).state = 'character';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MaterialsTreePage(),
                  ),
                );
              },
              child: Row(
                children: [
                  Icon(Icons.keyboard_arrow_right, color: textTertiary, size: 16),
                  const SizedBox(width: 4),
                  const Icon(Icons.person, color: Color(0xFFFFFFFF), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '角色 ($count)',
                    style: TextStyle(color: textPrimary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          // 关系图按钮
          GestureDetector(
            onTap: () {
              setState(() => _sidebarOpen = false);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RelationshipGraphPage(
                    novelId: selectedNovel?.id ?? "",
                    novelTitle: selectedNovel?.title ?? "",
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, color: primaryColor, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '关系图',
                    style: TextStyle(color: primaryColor, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建AI工具节点
  Widget _buildAiToolNode(
    String label,
    IconData icon,
    Color textPrimary,
    Color textTertiary,
    Color cardBg2, {
    String? materialType,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() => _sidebarOpen = false);
        // 根据materialType跳转到对应页面
        if (materialType == 'stats') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StatsPage()),
          );
        } else if (materialType == 'shuangdian') {
          // 爽点报告 - 需要选择作品
          final novel = ref.read(selectedNovelProvider);
          if (novel != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ShuangdianReportPage(),
              ),
            );
          } else {
            TopNotification.show(context, '请先选择一部作品');
          }
        } else if (materialType == 'water') {
          // 水文检测 - 需要选择作品
          final novel = ref.read(selectedNovelProvider);
          if (novel != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WaterReportPage(),
              ),
            );
          } else {
            TopNotification.show(context, '请先选择一部作品');
          }
        } else if (materialType == 'title') {
          // 标题生成 - 需要选择作品
          final novel = ref.read(selectedNovelProvider);
          if (novel != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TitleGeneratorResultPage(),
              ),
            );
          } else {
            TopNotification.show(context, '请先选择一部作品');
          }
        } else if (materialType == 'review') {
          // 全文审查 - 需要选择作品
          final novel = ref.read(selectedNovelProvider);
          if (novel != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const FullTextReviewPage(),
              ),
            );
          } else {
            TopNotification.show(context, '请先选择一部作品');
          }
        } else if (materialType == 'polish') {
          // 润色引擎 - 需要选择作品和章节
          final novel = ref.read(selectedNovelProvider);
          final chapter = ref.read(selectedChapterProvider);
          if (novel != null && chapter != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PolishEnginePage(
                  chapterContent: chapter.content,
                  novelTitle: novel.title,
                  onApply: (modifiedContent) {
                    // 应用修改后的内容
                  },
                ),
              ),
            );
          } else {
            TopNotification.show(context, '请先选择作品和章节');
          }
        } else if (materialType == 'style_preset') {
          // 风格预设 - 显示风格选择器
          _showStylePresetPicker();
        } else if (materialType == 'skill_manage') {
          // 写作技能管理
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SkillManagePage(),
            ),
          );
        } else if (materialType == 'agent_market') {
          // Agent市场
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AgentMarketplacePage(),
            ),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        margin: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Icon(Icons.keyboard_arrow_right, color: textTertiary, size: 16),
            const SizedBox(width: 4),
            Icon(icon, color: textPrimary, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: textPrimary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示AI工具菜单
  void _showAiToolsMenu() {
    final theme = Theme.of(context);
    final textPrimary = Colors.white;
    final textSecondary = Colors.grey;
    final primaryColor = const Color(0xFF10A37F);
    final cardBg = const Color(0xFF1A1A1A);
    final cardBg2 = const Color(0xFF2A2A2A);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 400,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF444444),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'AI工具',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildAiToolMenuItem(
                      icon: Icons.bar_chart,
                      title: '写作统计',
                      subtitle: '字数趋势、打卡、进度',
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StatsPage()),
                        );
                      },
                    ),
                    _buildAiToolMenuItem(
                      icon: Icons.analytics,
                      title: '爽点报告',
                      subtitle: '分析每章爽点分布',
                      onTap: () {
                        Navigator.pop(ctx);
                        final novel = ref.read(selectedNovelProvider);
                        if (novel != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ShuangdianReportPage(),
                            ),
                          );
                        } else {
                          TopNotification.show(context, '请先选择一部作品');
                        }
                      },
                    ),
                    _buildAiToolMenuItem(
                      icon: Icons.water_drop,
                      title: '水文检测',
                      subtitle: '检测凑字数、重复描写',
                      onTap: () {
                        Navigator.pop(ctx);
                        final novel = ref.read(selectedNovelProvider);
                        if (novel != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WaterReportPage(),
                            ),
                          );
                        } else {
                          TopNotification.show(context, '请先选择一部作品');
                        }
                      },
                    ),
                    _buildAiToolMenuItem(
                      icon: Icons.title,
                      title: '标题生成',
                      subtitle: 'AI生成多个候选标题',
                      onTap: () {
                        Navigator.pop(ctx);
                        final novel = ref.read(selectedNovelProvider);
                        if (novel != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TitleGeneratorResultPage(),
                            ),
                          );
                        } else {
                          TopNotification.show(context, '请先选择一部作品');
                        }
                      },
                    ),
                    _buildAiToolMenuItem(
                      icon: Icons.fact_check,
                      title: '全文审查',
                      subtitle: '设定冲突、战力一致性、伏笔追踪',
                      onTap: () {
                        Navigator.pop(ctx);
                        final novel = ref.read(selectedNovelProvider);
                        if (novel != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FullTextReviewPage(),
                            ),
                          );
                        } else {
                          TopNotification.show(context, '请先选择一部作品');
                        }
                      },
                    ),
                    _buildAiToolMenuItem(
                      icon: Icons.auto_fix_high,
                      title: '润色引擎',
                      subtitle: '章节精修、8个维度',
                      onTap: () {
                        Navigator.pop(ctx);
                        final novel = ref.read(selectedNovelProvider);
                        final chapter = ref.read(selectedChapterProvider);
                        if (novel != null && chapter != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PolishEnginePage(
                                chapterContent: chapter.content,
                                novelTitle: novel.title,
                                onApply: (modifiedContent) {
                                  // 应用修改后的内容
                                },
                              ),
                            ),
                          );
                        } else {
                          TopNotification.show(context, '请先选择作品和章节');
                        }
                      },
                    ),
                    _buildAiToolMenuItem(
                      icon: Icons.palette,
                      title: '风格预设',
                      subtitle: '25种写作风格预设',
                      onTap: () {
                        Navigator.pop(ctx);
                        _showStylePresetPicker();
                      },
                    ),
                    _buildAiToolMenuItem(
                      icon: Icons.store,
                      title: 'Agent市场',
                      subtitle: '内置多种写作智能体',
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AgentMarketplacePage(),
                          ),
                        );
                      },
                    ),
                    _buildAiToolMenuItem(
                      icon: Icons.build,
                      title: '写作技能',
                      subtitle: '管理写作技能和工具',
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SkillManagePage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示风格预设选择器
  void _showStylePresetPicker() {
    // 显示风格预设选择器
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 400,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF444444),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '选择写作风格',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildStylePresetItem('都市', '现代都市生活'),
                    _buildStylePresetItem('玄幻', '修仙玄幻世界'),
                    _buildStylePresetItem('穿越', '穿越时空题材'),
                    _buildStylePresetItem('悬疑', '悬疑推理故事'),
                    _buildStylePresetItem('女频', '女性向题材'),
                    _buildStylePresetItem('历史', '历史架空题材'),
                    _buildStylePresetItem('科幻', '科幻未来世界'),
                    _buildStylePresetItem('武侠', '武侠江湖题材'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建风格预设项
  Widget _buildStylePresetItem(String title, String description) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        // 应用风格预设
        TopNotification.success(context, '已选择风格：$title');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.palette, color: const Color(0xFF10A37F), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建AI工具菜单项
  Widget _buildAiToolMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF10A37F), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[500], size: 20),
          ],
        ),
      ),
    );
  }

  /// 模型选择下拉菜单
  Widget _buildModelDropdown({
    required BuildContext context,
    required Color cardBg,
    required Color cardBg2,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required Color dividerColor,
  }) {
    final aiConfigs = ref.watch(aiConfigsProvider);
    final selectedConfig = ref.watch(selectedAiConfigProvider);
    final textConfigs = aiConfigs.where((c) => c.modelType == ModelType.text).toList();
    
    // 如果没有配置，显示提示
    if (textConfigs.isEmpty) {
      return Container(
        width: 280,
        decoration: BoxDecoration(
          color: cardBg,
          border: Border.all(color: const Color(0xFF333333)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 32),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('暂无AI模型配置', style: TextStyle(color: textSecondary, fontSize: 14)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() => _modelDropdownOpen = false);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
              child: const Text('去配置'),
            ),
          ],
        ),
      );
    }
    
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: const Color(0xFF333333)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 32),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...textConfigs.map((config) => GestureDetector(
            onTap: () {
              // 更新选中的AI配置
              ref.read(selectedAiConfigProvider.notifier).state = config;
              setState(() {
                _selectedModelDisplay = config.name;
                _modelDropdownOpen = false;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selectedConfig?.id == config.id ? cardBg2 : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    config.name,
                    style: TextStyle(color: textPrimary, fontSize: 14),
                  ),
                  if (config.modelName.contains('GLM') || config.modelName.contains('glm')) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3A2A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '内置',
                        style: TextStyle(color: primaryColor, fontSize: 10),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (selectedConfig?.id == config.id)
                    Icon(Icons.check, color: primaryColor, size: 18),
                ],
              ),
            ),
          )),
          Container(height: 1, color: dividerColor, margin: const EdgeInsets.symmetric(vertical: 4)),
          GestureDetector(
            onTap: () {
              setState(() => _modelDropdownOpen = false);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                '管理模型',
                style: TextStyle(color: primaryColor, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleNovelExpand(String novelId) async {
    if (_expandedNovels.contains(novelId)) {
      setState(() => _expandedNovels.remove(novelId));
    } else {
      setState(() => _expandedNovels.add(novelId));
      if (!_loadedVolumes.containsKey(novelId)) {
        final volumes = await ref.read(volumeRepoProvider).getVolumesByNovel(novelId);
        if (mounted) {
          setState(() {
            _loadedVolumes[novelId] = volumes;
          });
        }
      }
    }
  }

  void _toggleVolumeExpand(String volumeId) async {
    if (_expandedVolumes.contains(volumeId)) {
      setState(() => _expandedVolumes.remove(volumeId));
    } else {
      setState(() => _expandedVolumes.add(volumeId));
      if (!_loadedChapters.containsKey(volumeId)) {
        final chapters = await ref.read(chapterRepoProvider).getChaptersByVolume(volumeId);
        if (mounted) {
          setState(() {
            _loadedChapters[volumeId] = chapters;
          });
        }
      }
    }
  }
}
