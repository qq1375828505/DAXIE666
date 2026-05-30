import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/data/models/tomato_agent_model.dart';
import 'package:novel_ide/data/models/ai_chat_session_model.dart';
import 'package:novel_ide/data/models/proactive_question_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/services/ai_service.dart';
import 'package:novel_ide/data/services/novel_memory.dart';
import 'package:novel_ide/data/services/user_memory.dart';
import 'package:novel_ide/data/services/workspace_agent.dart';
import 'package:novel_ide/data/services/agent_tool_executors.dart';
import 'package:novel_ide/data/services/voice_service.dart';
import 'package:novel_ide/data/services/skill_matcher.dart';
import 'package:novel_ide/data/services/fuzzy_need_detector.dart';
import 'package:novel_ide/data/models/writing_skill_model.dart';
import 'package:novel_ide/data/repositories/chat_history_repository.dart';
import 'package:novel_ide/presentation/pages/ai/voice_call_page.dart';
import 'package:novel_ide/presentation/widgets/top_notification.dart';
import 'package:novel_ide/presentation/widgets/skill_indicator.dart';
import 'package:novel_ide/presentation/widgets/proactive_question_dialog.dart';

/// AI chat session model.
class AiChatSession {
  final String id;
  String title;
  List<Map<String, String>> messages;
  final DateTime createdAt;

  AiChatSession({
    required this.id,
    required this.title,
    List<Map<String, String>>? messages,
    DateTime? createdAt,
  })  : messages = messages != null ? List.from(messages) : [],
        createdAt = createdAt ?? DateTime.now();
}

/// GPT风格聊天页面 - 纯聊天消息列表 + 底部胶囊式输入框
class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> with WidgetsBindingObserver {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<AiChatSession> _sessions = [];
  AiChatSession? _currentSession;
  bool _isLoading = false;
  String _selectedModel = 'GLM-4.7-Flash';

  // 语音相关
  final VoiceService _voiceService = VoiceService();

  // 技能匹配记录：assistant消息索引 → 匹配到的技能列表
  final Map<int, List<WritingSkill>> _skillMatches = {};

  // 历史记录仓库
  final ChatHistoryRepository _historyRepo = ChatHistoryRepository();
  bool _isHistoryLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVoice();
    _loadHistory();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _saveHistory();
    }
  }

  Future<void> _loadHistory() async {
    try {
      final savedSessions = await _historyRepo.loadSessions();
      if (savedSessions.isNotEmpty && mounted) {
        setState(() {
          _sessions.clear();
          for (final model in savedSessions) {
            _sessions.add(AiChatSession(
              id: model.id,
              title: model.title,
              messages: model.messages,
              createdAt: model.createdAt,
            ));
          }
          _currentSession = _sessions.first;
        });
      }
      _isHistoryLoaded = true;
    } catch (e) {
      debugPrint('Load history error: $e');
      _isHistoryLoaded = true;
    }
  }

  Future<void> _saveHistory() async {
    if (!_isHistoryLoaded) return;
    try {
      final models = _sessions.map((s) => AiChatSessionModel(
        id: s.id,
        title: s.title,
        messages: s.messages,
        createdAt: s.createdAt,
        updatedAt: DateTime.now(),
      )).toList();
      await _historyRepo.saveSessions(models);
    } catch (e) {
      debugPrint('Save history error: $e');
    }
  }

  Future<void> _initVoice() async {
    if (mounted) setState(() {});
  }

  void _newSession() {
    final session = AiChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '新会话 ${_sessions.length + 1}',
    );
    setState(() {
      _sessions.insert(0, session);
      _currentSession = session;
      _skillMatches.clear();
    });
  }

  void _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    if (_currentSession == null) _newSession();

    final config = ref.read(effectiveAiConfigProvider);
    if (config == null) {
      TopNotification.error(context, '请先配置AI模型');
      return;
    }

    // 模糊需求检测
    final detector = FuzzyNeedDetector();
    final fuzzyType = await detector.detect(
      text,
      config: config,
      userMemory: await UserMemory.load().catchError((_) => ''),
      novelContext: ref.read(selectedNovelProvider) != null
          ? await NovelMemory.getForAiContext(
              ref.read(selectedNovelProvider)!.id,
              ref.read(selectedNovelProvider)!.title,
            ).catchError((_) => '')
          : null,
    );
    
    if (fuzzyType != null) {
      List<WritingSkill>? skills;
      try {
        final skillRepo = ref.read(skillRepoProvider);
        skills = await skillRepo.getAllSkills();
      } catch (_) {}

      final question = await detector.generateQuestion(
        text,
        fuzzyType,
        config: config,
        userMemory: await UserMemory.load().catchError((_) => ''),
        novelContext: ref.read(selectedNovelProvider) != null
            ? await NovelMemory.getForAiContext(
                ref.read(selectedNovelProvider)!.id,
                ref.read(selectedNovelProvider)!.title,
              ).catchError((_) => '')
            : null,
        availableSkills: skills,
      );

      if (question != null && mounted) {
        ProactiveSelection? selection;
        await ProactiveQuestionDialog.show(
          context,
          question: question,
          onSelected: (s) => selection = s,
          onSkipped: () => selection = null,
        );

        if (selection != null) {
          _inputCtrl.text = '$text\n\n[用户选择：${selection!.toAiContext()}]';
        }
      }
    }

    final shouldTriggerAgent = detector.shouldTriggerWorkspaceAgent(text);

    setState(() {
      _currentSession!.messages.add({'role': 'user', 'content': _inputCtrl.text.trim()});
      if (_currentSession!.messages.length == 1) {
        _currentSession!.title = text.length > 20 ? '${text.substring(0, 20)}...' : text;
      }
      _isLoading = true;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    try {
      final preset = ref.read(currentPresetProvider);
      var systemPrompt = preset?.systemPrompt ?? '你是一位专业的网文写作助手，擅长帮助作者构思剧情、润色文字、生成大纲和角色设定。请用中文回复。';

      List<WritingSkill> matchedSkills = [];
      try {
        final skillRepo = ref.read(skillRepoProvider);
        final allSkills = await skillRepo.getAllSkills();
        final enabled = allSkills.where((s) => s.isEnabled).toList();
        matchedSkills = SkillMatcher.match(text, enabled);
        if (matchedSkills.isNotEmpty) {
          systemPrompt = SkillMatcher.injectSkillContext(systemPrompt, matchedSkills);
        }
      } catch (_) {}

      String memoryContext = '';
      try {
        final novel = ref.read(selectedNovelProvider);
        if (novel != null) {
          memoryContext = await NovelMemory.getForAiContext(novel.id, novel.title);
        }
      } catch (_) {}

      String userMemoryContext = '';
      try {
        userMemoryContext = await UserMemory.getForAiContext();
      } catch (_) {}

      if (_currentSession!.messages.length > 600) {
        await _compactMessages(config);
      }

      final novel = ref.read(selectedNovelProvider);
      final needsAgent = shouldTriggerAgent;

      if (needsAgent) {
        final agent = WorkspaceAgent();
        if (novel != null) {
          registerAllToolExecutors(agent: agent, novelId: novel.id, novelTitle: novel.title);
        } else {
          registerGeneralToolExecutors(
            agent: agent,
            onSwitchNovel: (id) {
              final novels = ref.read(novelsProvider).valueOrNull ?? [];
              final novel = novels.where((n) => n.id == id).firstOrNull;
              if (novel != null) {
                ref.read(selectedNovelProvider.notifier).state = novel;
                loadNovelMaterials(ref, id);
              }
            },
          );
        }

        final effectiveSystemPrompt = novel != null
            ? '$systemPrompt\n\n小说记忆文件（当前状态）：\n$memoryContext$userMemoryContext'
            : '$systemPrompt\n\n$userMemoryContext';

        final response = await agent.chat(
          config: config,
          messages: _currentSession!.messages,
          systemPrompt: effectiveSystemPrompt,
        );

        final buffer = StringBuffer();
        if (response.toolResults.isNotEmpty) {
          buffer.writeln('🔧 **工具调用：**\n');
          for (final result in response.toolResults) {
            final icon = result.success ? '✅' : '❌';
            buffer.writeln('$icon ${result.toolName}：${result.message}');
          }
          buffer.writeln('\n---\n');
        }
        buffer.write(response.content);

        setState(() {
          _currentSession!.messages.add({'role': 'assistant', 'content': buffer.toString()});
          if (matchedSkills.isNotEmpty) {
            _skillMatches[_currentSession!.messages.length - 1] = matchedSkills;
          }
          _isLoading = false;
        });
      } else {
        final agent = WorkspaceAgent();
        final aiText = await agent.chatLite(
          config: config,
          messages: _currentSession!.messages,
          systemPrompt: '$systemPrompt\n\n$userMemoryContext',
        );

        setState(() {
          _currentSession!.messages.add({'role': 'assistant', 'content': aiText});
          if (matchedSkills.isNotEmpty) {
            _skillMatches[_currentSession!.messages.length - 1] = matchedSkills;
          }
          _isLoading = false;
        });
      }
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _currentSession!.messages.add({'role': 'assistant', 'content': '请求失败: $e'});
        _isLoading = false;
      });
    }
  }

  Future<void> _compactMessages(AiConfig config) async {
    try {
      final msgs = _currentSession!.messages;
      final toSummarize = msgs.take(30).map((m) => '${m['role']}: ${m['content']}').join('\n');
      final aiService = ref.read(aiServiceProvider);
      final summary = await aiService.send(
        config: config,
        systemPrompt: '你是一个对话摘要助手。请将以下对话压缩为简短的摘要（200字以内），保留关键信息和上下文。',
        userMessage: toSummarize,
        taskType: 'chat',
      );
      setState(() {
        _currentSession!.messages = [
          {'role': 'user', 'content': '以下是之前的对话摘要，请据此回复用户后续的问题：\n$summary'},
          ...msgs.skip(30),
        ];
      });
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveHistory();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  // GPT风格颜色
  static const bgColor = Color(0xFF000000);
  static const cardBg = Color(0xFF1A1A1A);
  static const cardBg2 = Color(0xFF2A2A2A);
  static const primaryColor = Color(0xFF10A37F);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF888888);
  static const textTertiary = Color(0xFF666666);

  @override
  Widget build(BuildContext context) {
    final messages = _currentSession?.messages ?? [];

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // 聊天消息列表
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return _buildTypingIndicator();
                      }
                      final msg = messages[index];
                      final isUser = msg['role'] == 'user';
                      final matchedForThis = _skillMatches[index];
                      return _buildMessage(msg['content']!, isUser, matchedForThis, index);
                    },
                  ),
          ),
          // 底部胶囊式输入框
          _buildInputBar(),
        ],
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AI头像
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: textPrimary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: Text('AI', style: TextStyle(color: bgColor, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '欢迎使用网文写作IDE！',
              style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '我可以帮助你构思大纲、创建角色、润色文字、分析爽点分布。',
              style: TextStyle(color: textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // 快捷操作
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickChip('构思剧情', () => _quickSend('帮我构思一个有趣的剧情')),
                _buildQuickChip('起个书名', () => _quickSend('帮我起5个吸引人的书名')),
                _buildQuickChip('设计角色', () => _quickSend('帮我设计一个有意思的主角')),
                _buildQuickChip('生成大纲', () => _quickSend('帮我写一个小说大纲')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: cardBg2,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: const TextStyle(color: textPrimary, fontSize: 13)),
      ),
    );
  }

  void _quickSend(String text) {
    _inputCtrl.text = text;
    _sendMessage();
  }

  /// 消息气泡
  Widget _buildMessage(String content, bool isUser, List<WritingSkill>? skills, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (skills != null && skills.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 44),
            child: SkillIndicator(matchedSkills: skills),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头像
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isUser ? primaryColor : textPrimary,
                  borderRadius: BorderRadius.circular(isUser ? 14 : 4),
                ),
                child: Center(
                  child: Icon(
                    isUser ? Icons.person : Icons.smart_toy,
                    color: isUser ? textPrimary : bgColor,
                    size: 16,
                  ),
                ),
              ),
              // 内容
              Expanded(
                child: GestureDetector(
                  onLongPress: () => _showMessageMenu(content, index),
                  child: isUser
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: cardBg2,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            content,
                            style: const TextStyle(color: textPrimary, fontSize: 15, height: 1.6),
                          ),
                        )
                      : SelectableText(
                          content,
                          style: const TextStyle(color: textPrimary, fontSize: 15, height: 1.6),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 加载中指示器
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: textPrimary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text('AI', style: TextStyle(color: bgColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) => 
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: textTertiary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 底部胶囊式输入框
  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 20 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, bgColor],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg2,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // + 按钮
            IconButton(
              icon: const Icon(Icons.add, color: textSecondary, size: 22),
              onPressed: _showBottomSheet,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            // 输入框
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                maxLines: null,
                minLines: 1,
                style: const TextStyle(color: textPrimary, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Message',
                  hintStyle: TextStyle(color: textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            // 发送/语音按钮
            _inputCtrl.text.isNotEmpty
                ? Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: textPrimary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: bgColor, size: 18),
                      onPressed: _isLoading ? null : _sendMessage,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  )
                : Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.mic, color: textPrimary, size: 18),
                      onPressed: _handleMic,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  /// 显示底部弹窗菜单
  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
        decoration: const BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽指示条
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF444444),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 功能网格
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.0,
                  children: [
                    _buildSheetItem(Icons.mic, '语音输入', '语音转文字', () => Navigator.pop(ctx)),
                    _buildSheetItem(Icons.attach_file, '上传文件', 'TXT/DOCX/PDF', () => Navigator.pop(ctx)),
                    _buildSheetItem(Icons.library_books, '选择资料', '发给AI上下文', () { Navigator.pop(ctx); _showMaterialPicker(); }),
                    _buildSheetItem(Icons.description, '选择模板', '写作模板库', () => Navigator.pop(ctx)),
                    _buildSheetItem(Icons.local_fire_department, '番茄写作', '风格预设', () => Navigator.pop(ctx)),
                    _buildSheetItem(Icons.phone, '语音通话', '实时AI对话', () { Navigator.pop(ctx); _openVoiceCall(); }),
                    _buildSheetItem(Icons.bar_chart, '写作统计', '字数趋势', () => Navigator.pop(ctx)),
                    _buildSheetItem(Icons.settings, '更多设置', '模型/外观/数据', () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Agent列表
              _buildAgentSection(ctx),
              // Skill列表
              _buildSkillSection(ctx),
              // 番茄写作
              _buildTomatoSection(ctx),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textPrimary, size: 24),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(color: textPrimary, fontSize: 13)),
            Text(subtitle, style: const TextStyle(color: textTertiary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentSection(BuildContext ctx) {
    final agents = [
      ('爽点检查器', '检测章节爽点分布', Icons.local_fire_department),
      ('水文检测器', '找出注水段落', Icons.water_drop),
      ('大纲生成器', '自动生成多卷大纲', Icons.list_alt),
      ('标题生成器', '生成章节标题', Icons.title),
      ('全文审查', '节奏/角色/逻辑审查', Icons.fact_check),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('Agent（智能体）', style: TextStyle(color: textSecondary, fontSize: 12)),
        ),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: agents.length,
            itemBuilder: (context, index) {
              final (name, desc, icon) = agents[index];
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  final agentList = ref.read(tomatoAgentsProvider);
                  final agent = agentList.firstWhere(
                    (a) => a.name.contains(name.replaceAll('器', '').replaceAll('查', '')),
                    orElse: () => agentList.first,
                  );
                  _invokeAgent(agent);
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardBg2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: primaryColor, size: 20),
                      const SizedBox(height: 6),
                      Text(name, style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(desc, style: const TextStyle(color: textTertiary, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSkillSection(BuildContext ctx) {
    final skills = [
      ('金庸风格', '武侠文风'),
      ('爽文模板', '快节奏升级'),
      ('文学润色', '提升文笔'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('Skill（写作技巧）', style: TextStyle(color: textSecondary, fontSize: 12)),
        ),
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: skills.length,
            itemBuilder: (context, index) {
              final (name, desc) = skills[index];
              return GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardBg2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(name, style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(desc, style: const TextStyle(color: textTertiary, fontSize: 11)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTomatoSection(BuildContext ctx) {
    final presets = [
      ('都市爽文', '快节奏升级流'),
      ('言情甜宠', '轻松甜蜜'),
      ('悬疑推理', '烧脑反转'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('番茄写作', style: TextStyle(color: textSecondary, fontSize: 12)),
        ),
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final (name, desc) = presets[index];
              return GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardBg2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(name, style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(desc, style: const TextStyle(color: textTertiary, fontSize: 11)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _handleMic() {
    // TODO: 实现语音输入
    TopNotification.show(context, '语音输入功能开发中', isSuccess: true);
  }

  /// 调用Agent
  Future<void> _invokeAgent(TomatoAgent agent) async {
    final config = ref.read(effectiveAiConfigProvider);
    if (config == null) {
      TopNotification.error(context, '请先配置AI模型');
      return;
    }

    if (_currentSession == null) _newSession();

    final userMessage = '请执行「${agent.name}」任务';
    setState(() {
      _currentSession!.messages.add({
        'role': 'user',
        'content': '⚡ ${agent.name}\n$userMessage',
      });
      if (_currentSession!.messages.length == 1) {
        _currentSession!.title = agent.name;
      }
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final recentMsgs = _currentSession!.messages
          .where((m) => m != _currentSession!.messages.last)
          .toList();
      final contextMsgs = recentMsgs.length > 20
          ? recentMsgs.sublist(recentMsgs.length - 20)
          : recentMsgs;

      String memoryContext = '';
      try {
        final novel = ref.read(selectedNovelProvider);
        if (novel != null) {
          memoryContext = await NovelMemory.getForAiContext(novel.id, novel.title);
        }
      } catch (_) {}
      String userMemoryContext = '';
      try {
        userMemoryContext = await UserMemory.getForAiContext();
      } catch (_) {}

      final aiService = ref.read(aiServiceProvider);

      final messages = <Map<String, String>>[
        {'role': 'system', 'content': '${agent.systemPrompt}\n$memoryContext$userMemoryContext'},
        ...contextMsgs.map((m) => {'role': m['role']!, 'content': m['content']!}),
        {'role': 'user', 'content': userMessage},
      ];

      final aiText = await aiService.chat(config, messages, taskType: 'agent');

      setState(() {
        _currentSession!.messages.add({
          'role': 'assistant',
          'content': '【${agent.name}】\n$aiText',
        });
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _currentSession!.messages.add({
          'role': 'assistant',
          'content': '【${agent.name}】调用失败: $e',
        });
        _isLoading = false;
      });
    }
  }

  /// 打开语音通话
  void _openVoiceCall() async {
    final voiceConfig = ref.read(selectedVoiceConfigProvider);
    if (voiceConfig == null) {
      TopNotification.error(context, '请先在设置中配置语音模型');
      return;
    }
    final config = ref.read(effectiveAiConfigProvider);
    if (config == null) {
      TopNotification.error(context, '请先配置文本AI模型');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceCallPage(
          onCallEnd: (transcript, aiResponse) {
            if (_currentSession == null) _newSession();
            if (transcript.isNotEmpty) {
              setState(() {
                _currentSession!.messages.add({'role': 'user', 'content': '🎤 语音通话记录：\n$transcript'});
              });
            }
            if (aiResponse.isNotEmpty) {
              setState(() {
                _currentSession!.messages.add({'role': 'assistant', 'content': '🤖 AI回复：\n$aiResponse'});
              });
            }
          },
        ),
      ),
    );

    _scrollToBottom();
  }

  /// 显示消息长按菜单
  void _showMessageMenu(String content, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF444444),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: textPrimary),
                title: const Text('复制', style: TextStyle(color: textPrimary)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: content));
                  Navigator.pop(ctx);
                  TopNotification.success(context, '已复制到剪贴板');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('撤回', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(index);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// 删除单条消息
  void _deleteMessage(int index) {
    if (_currentSession == null || index < 0 || index >= _currentSession!.messages.length) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: const Text('撤回消息', style: TextStyle(color: textPrimary)),
        content: const Text('确定要撤回这条消息吗？', style: TextStyle(color: textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _currentSession!.messages.removeAt(index);
                _skillMatches.remove(index);
                final newMatches = <int, List<WritingSkill>>{};
                _skillMatches.forEach((key, value) {
                  if (key < index) {
                    newMatches[key] = value;
                  } else if (key > index) {
                    newMatches[key - 1] = value;
                  }
                });
                _skillMatches.clear();
                _skillMatches.addAll(newMatches);
              });
              _saveHistory();
              TopNotification.success(context, '消息已撤回');
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 选择资料作为AI上下文
  void _showMaterialPicker() {
    final novel = ref.read(selectedNovelProvider);
    if (novel == null) {
      TopNotification.error(context, '请先选择一部作品');
      return;
    }
    final novelId = novel.id;

    final characters = ref.read(charactersProvider(novelId));
    final settings = ref.read(settingCardsProvider(novelId));
    final hooks = ref.read(plotHooksProvider(novelId));
    final references = ref.read(referencesProvider(novelId));

    final selectedIds = <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPickerState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: const BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.library_books, size: 20, color: primaryColor),
                    const SizedBox(width: 8),
                    const Text('选择资料', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                    const Spacer(),
                    Text('${selectedIds.length} 项已选', style: const TextStyle(fontSize: 13, color: textSecondary)),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2A2A2A)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    _buildPickerSection('角色', characters.map((c) => (c.id, c.name, '${c.role ?? ""} ${c.description ?? ""}'.trim())).toList(), selectedIds, setPickerState),
                    _buildPickerSection('设定', settings.map((s) => (s.id, s.name, s.description ?? '')).toList(), selectedIds, setPickerState),
                    _buildPickerSection('伏笔', hooks.map((h) => (h.id, h.title, h.description ?? '')).toList(), selectedIds, setPickerState),
                    _buildPickerSection('参考', references.map((r) => (r.id, r.title, r.content ?? '')).toList(), selectedIds, setPickerState),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: primaryColor),
                      onPressed: selectedIds.isEmpty ? null : () {
                        final buffer = StringBuffer();
                        buffer.writeln('[选择的资料上下文]');
                        for (final c in characters.where((c) => selectedIds.contains(c.id))) {
                          buffer.writeln('## 角色：${c.name}');
                          if (c.role != null) buffer.writeln('定位: ${c.role}');
                          if (c.description != null) buffer.writeln(c.description);
                          buffer.writeln();
                        }
                        for (final s in settings.where((s) => selectedIds.contains(s.id))) {
                          buffer.writeln('## 设定：${s.name}');
                          if (s.description != null) buffer.writeln(s.description);
                          buffer.writeln();
                        }
                        buffer.writeln('---请基于以上资料回答用户的问题---');
                        _inputCtrl.text = '${buffer.toString()}\n${_inputCtrl.text}';
                        Navigator.pop(ctx);
                      },
                      child: Text('确定 (${selectedIds.length}项)'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerSection(String title, List<(String, String, String)> items, Set<String> selectedIds, StateSetter setPickerState) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
        ),
        for (final (id, name, desc) in items)
          CheckboxListTile(
            value: selectedIds.contains(id),
            onChanged: (v) => setPickerState(() {
              v == true ? selectedIds.add(id) : selectedIds.remove(id);
            }),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500, color: textPrimary)),
            subtitle: Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: textTertiary)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: primaryColor,
          ),
      ],
    );
  }
}
