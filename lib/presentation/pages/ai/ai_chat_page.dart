import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:novel_ide/core/constants.dart';
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
import 'package:novel_ide/data/services/workflow_engine.dart';
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

/// AI Chat page as a main tab with session management.
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
  bool _showHistory = false;

  // 语音相关
  final VoiceService _voiceService = VoiceService();
  bool _isVoiceListening = false;
  bool _voiceInitialized = false;

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
      // 切到后台或关闭：保存历史记录
      _saveHistory();
    }
  }

  /// 加载历史会话
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
          // 恢复上次活跃的会话（最新的）
          _currentSession = _sessions.first;
        });
      }
      _isHistoryLoaded = true;
    } catch (e) {
      debugPrint('Load history error: $e');
      _isHistoryLoaded = true;
    }
  }

  /// 保存历史会话
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
    _voiceInitialized = await _voiceService.init();
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
      _showHistory = false;
      _skillMatches.clear();
    });
  }

  void _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    // Auto-create session if none
    if (_currentSession == null) _newSession();

    final config = ref.read(selectedAiConfigProvider);
    if (config == null) {
      TopNotification.error(context, '请先在"我的"页面配置AI模型');
      return;
    }

    // === 主动式交互：模糊需求检测 ===
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
      // 获取可用技能
      List<WritingSkill>? skills;
      try {
        final skillRepo = ref.read(skillRepoProvider);
        skills = await skillRepo.getAllSkills();
      } catch (_) {}

      // AI生成个性化问题
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

    // 检查是否需要触发 Workspace Agent
    final shouldTriggerAgent = detector.shouldTriggerWorkspaceAgent(text);
    final intent = detector.extractIntent(text);

    setState(() {
      _currentSession!.messages.add({'role': 'user', 'content': _inputCtrl.text.trim()});
      // Update title from first message
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

      // 技能自动匹配
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

      // Load novel memory for context
      String memoryContext = '';
      try {
        final novel = ref.read(selectedNovelProvider);
        if (novel != null) {
          memoryContext = await NovelMemory.getForAiContext(novel.id, novel.title);
        }
      } catch (_) {}

      // Load user-level global memory
      String userMemoryContext = '';
      try {
        userMemoryContext = await UserMemory.getForAiContext();
      } catch (_) {}

      // Auto-compact if too many messages (>20 pairs = 40 messages)
      if (_currentSession!.messages.length > 40) {
        await _compactMessages(config);
      }

      // Check if we have a novel selected for Agent mode
      final novel = ref.read(selectedNovelProvider);
      if (novel != null) {
        // Agent mode with tools
        final agent = WorkspaceAgent();
        registerAllToolExecutors(agent: agent, novelId: novel.id, novelTitle: novel.title);

        final effectiveSystemPrompt = '$systemPrompt\n\n小说记忆文件（当前状态）：\n$memoryContext$userMemoryContext';

        final response = await agent.chat(
          config: config,
          messages: _currentSession!.messages,
          systemPrompt: effectiveSystemPrompt,
        );

        // Build response with tool call info
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
        // Normal mode without tools
        final aiService = ref.read(aiServiceProvider);
        final aiText = await aiService.send(
          config: config,
          systemPrompt: '$systemPrompt\n\n$userMemoryContext',
          userMessage: text,
          taskType: 'chat',
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

  /// Compress old messages into a summary when conversation gets too long.
  Future<void> _compactMessages(AiConfig config) async {
    try {
      final msgs = _currentSession!.messages;
      // Take first 30 messages as context to summarize
      final toSummarize = msgs.take(30).map((m) => '${m['role']}: ${m['content']}').join('\n');
      final aiService = ref.read(aiServiceProvider);
      final summary = await aiService.send(
        config: config,
        systemPrompt: '你是一个对话摘要助手。请将以下对话压缩为简短的摘要（200字以内），保留关键信息和上下文。',
        userMessage: toSummarize,
        taskType: 'chat',
      );
      // Replace old messages with summary + recent messages
      setState(() {
        _currentSession!.messages = [
          {'role': 'system', 'content': '之前的对话摘要：$summary'},
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
    _saveHistory(); // 关闭前保存
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configs = ref.watch(aiConfigsProvider);
    final selectedConfig = ref.watch(selectedAiConfigProvider);
    final currentPreset = ref.watch(currentPresetProvider);
    final messages = _currentSession?.messages ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: _showHistory
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showHistory = false),
              )
            : IconButton(
                icon: const Icon(Icons.history),
                onPressed: () => setState(() => _showHistory = true),
                tooltip: '会话历史',
              ),
        title: _showHistory
            ? const Text('会话历史')
            : Text(_currentSession?.title ?? 'AI 对话'),
        actions: [
          // New session button
          IconButton(
            icon: const Icon(Icons.add_comment, size: 22),
            onPressed: _newSession,
            tooltip: '新建会话',
          ),
          // Model selector (always show)
          if (configs.isNotEmpty)
            PopupMenuButton<String>(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy, size: 18, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(selectedConfig?.name ?? '', style: const TextStyle(fontSize: 12)),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
              onSelected: (value) {
                if (value == 'add_new') {
                  // 提示用户去 profile 页面添加新模型
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请到「我的」页面添加新模型配置')),
                  );
                } else if (value != 'settings') {
                  final config = configs.firstWhere((c) => c.id == value);
                  ref.read(selectedAiConfigProvider.notifier).state = config;
                }
              },
              itemBuilder: (context) => [
                // Add a "go to settings" option
                if (configs.isEmpty)
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings, size: 16),
                        SizedBox(width: 8),
                        Text('去配置模型'),
                      ],
                    ),
                  ),
                ...configs.map((c) => PopupMenuItem(
                  value: c.id,
                  child: Row(
                    children: [
                      Icon(c.id == selectedConfig?.id ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 16, color: c.id == selectedConfig?.id ? AppColors.primary : Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.name, style: const TextStyle(fontSize: 14)),
                          Text('${c.modelName}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ]),
                      ),
                    ],
                  ),
                )),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'add_new',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('添加新模型', style: TextStyle(color: AppColors.primary)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _showHistory ? _buildHistoryView() : _buildChatView(messages, currentPreset),
    );
  }

  Widget _buildHistoryView() {
    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 16),
            Text('暂无会话历史', style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        final msgCount = session.messages.length;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _currentSession?.id == session.id ? AppColors.primary : Colors.grey[200],
            child: Icon(Icons.chat, size: 18,
                color: _currentSession?.id == session.id ? Colors.white : Colors.grey),
          ),
          title: Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('$msgCount 条消息 · ${session.createdAt.month}/${session.createdAt.day}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () async {
              // 从本地存储删除
              await _historyRepo.deleteSession(session.id);
              setState(() {
                _sessions.removeAt(index);
                if (_currentSession?.id == session.id) {
                  _currentSession = _sessions.isNotEmpty ? _sessions.first : null;
                }
              });
            },
          ),
          onTap: () {
            setState(() {
              _currentSession = session;
              _showHistory = false;
            });
          },
        );
      },
    );
  }

  Widget _buildChatView(List<Map<String, String>> messages, dynamic currentPreset) {
    return Column(
      children: [
        // Messages
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[200]),
                      const SizedBox(height: 16),
                      Text('开始和AI对话吧', style: TextStyle(fontSize: 16, color: Colors.grey[400])),
                      const SizedBox(height: 8),
                      Text(currentPreset != null ? '当前风格: ${currentPreset.name}' : '默认写作助手',
                          style: TextStyle(fontSize: 13, color: Colors.grey[350])),
                      const SizedBox(height: 24),
                      // Quick actions
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _QuickAction(label: '帮我构思剧情', onTap: () { _inputCtrl.text = '帮我构思一个有趣的剧情'; _sendMessage(); }),
                          _QuickAction(label: '起个书名', onTap: () { _inputCtrl.text = '帮我起5个吸引人的书名'; _sendMessage(); }),
                          _QuickAction(label: '角色设计', onTap: () { _inputCtrl.text = '帮我设计一个有意思的主角'; _sendMessage(); }),
                          _QuickAction(label: '大纲生成', onTap: () { _inputCtrl.text = '帮我写一个小说大纲'; _sendMessage(); }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Workflow quick actions
                      Text('自动化工作流', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: WorkflowPresets.all.map((w) => _QuickAction(
                          label: '${w.icon} ${w.name}',
                          onTap: () => _runWorkflow(w),
                        )).toList(),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 12),
                          Text('思考中...', style: TextStyle(color: Colors.grey)),
                        ]),
                      );
                    }
                    final msg = messages[index];
                    final isUser = msg['role'] == 'user';
                    final matchedForThis = _skillMatches[index];
                    return Column(
                      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (matchedForThis != null && matchedForThis.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4, left: 4),
                            child: SkillIndicator(matchedSkills: matchedForThis),
                          ),
                        Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isUser ? AppColors.primary : Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(msg['content']!, style: TextStyle(
                                color: isUser ? Colors.white : Colors.black87, fontSize: 14, height: 1.5)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        // Input
        Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Row(
            children: [
              // + 按钮
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 28),
                color: AppColors.primary,
                onPressed: () => _showAttachMenu(context),
              ),
              // 通话按钮（实时语音通话）- 仅在配置了语音模型时可用
              Builder(
                builder: (context) {
                  final voiceConfig = ref.watch(selectedVoiceConfigProvider);
                  final hasVoiceModel = voiceConfig != null;
                  return IconButton(
                    icon: Icon(
                      Icons.phone_in_talk,
                      color: hasVoiceModel ? Colors.grey[600] : Colors.grey[300],
                      size: 24,
                    ),
                    onPressed: hasVoiceModel ? _openVoiceCall : null,
                    tooltip: hasVoiceModel ? '语音通话' : '请先配置语音模型',
                  );
                },
              ),
              // ⚡ Skill按钮
              IconButton(
                icon: const Icon(Icons.auto_awesome, size: 24),
                color: AppColors.tomatoOrange,
                tooltip: '调用Skill',
                onPressed: _showAgentSelector,
              ),
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  maxLines: null,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: '输入消息...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: _isLoading ? Colors.grey : AppColors.primary,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// + 按钮底部菜单：文件 + 技能
  void _showAttachMenu(BuildContext context) {
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
                subtitle: const Text('选择 TXT、DOCX 等文件', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFile();
                },
              ),
              // 技能选项
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.secondary),
                ),
                title: const Text('Skill', style: TextStyle(fontSize: 16)),
                subtitle: const Text('AI 写作技巧和预设', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAgentSelector();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Agent选择器 — 底部弹窗
  void _showAgentSelector() {
    final agents = ref.read(tomatoAgentsProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示条
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 20, color: AppColors.tomatoOrange),
                  SizedBox(width: 8),
                  Text('调用Skill', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Text('选择Agent执行专项任务', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: agents.length,
                itemBuilder: (context, index) {
                  final agent = agents[index];
                  return ListTile(
                    leading: Text(agent.icon, style: const TextStyle(fontSize: 28)),
                    title: Text(agent.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(agent.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    trailing: const Icon(Icons.play_circle_outline, color: AppColors.tomatoOrange),
                    onTap: () {
                      Navigator.pop(ctx);
                      _invokeAgent(agent);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 调用Agent — 用Agent的system prompt + 当前对话上下文
  Future<void> _invokeAgent(TomatoAgent agent) async {
    final config = ref.read(selectedAiConfigProvider);
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在"我的"页面配置AI模型')),
      );
      return;
    }

    // Auto-create session if none
    if (_currentSession == null) _newSession();

    // 显示Agent调用提示
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
      // 构建对话上下文（取最近20条消息）
      final recentMsgs = _currentSession!.messages
          .where((m) => m != _currentSession!.messages.last)
          .toList();
      final contextMsgs = recentMsgs.length > 20
          ? recentMsgs.sublist(recentMsgs.length - 20)
          : recentMsgs;

      // 加载记忆
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

      // 构建消息列表：Agent的system prompt + 对话历史 + 当前请求
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

  /// 执行工作流
  Future<void> _runWorkflow(Workflow workflow) async {
    final config = ref.read(selectedAiConfigProvider);
    if (config == null) {
      TopNotification.error(context, '请先在"我的"页面配置AI模型');
      return;
    }

    final novel = ref.read(selectedNovelProvider);
    if (novel == null) {
      TopNotification.error(context, '请先选择一部小说');
      return;
    }

    if (_currentSession == null) _newSession();

    setState(() {
      _currentSession!.messages.add({'role': 'user', 'content': '${workflow.icon} 执行工作流：${workflow.name}'});
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final agent = WorkspaceAgent();
      registerAllToolExecutors(agent: agent, novelId: novel.id, novelTitle: novel.title);

      // 依次执行工作流步骤
      final results = <String>[];
      for (final step in workflow.steps) {
        final executor = agent.getExecutor(step.toolName);
        if (executor != null) {
          try {
            final result = await executor(step.toolArgs);
            results.add('${result.success ? "✅" : "❌"} **${step.name}**：${result.message}');
          } catch (e) {
            results.add('❌ **${step.name}**：执行失败 $e');
          }
        } else {
          results.add('⚠️ **${step.name}**：工具未注册');
        }
      }

      // 让AI总结工作流结果
      final aiService = ref.read(aiServiceProvider);
      final summary = await aiService.send(
        config: config,
        systemPrompt: '你是一个写作助手。请根据以下工作流执行结果，给用户一个简洁友好的总结和建议。',
        userMessage: '工作流「${workflow.name}」执行结果：\n${results.join("\n")}',
        taskType: 'workflow',
      );

      setState(() {
        _currentSession!.messages.add({
          'role': 'assistant',
          'content': '${workflow.icon} **${workflow.name}** 执行完成\n\n${results.join("\n")}\n\n---\n**AI总结：**\n$summary',
        });
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _currentSession!.messages.add({'role': 'assistant', 'content': '工作流执行失败: $e'});
        _isLoading = false;
      });
    }
  }

  /// 语音输入切换
  void _toggleVoiceInput() async {
    if (_isVoiceListening) {
      await _voiceService.stopListening();
      setState(() => _isVoiceListening = false);
    } else {
      setState(() => _isVoiceListening = true);
      _voiceService.onResult = (text) {
        setState(() => _inputCtrl.text = text);
      };
      _voiceService.onListeningEnd = () {
        setState(() => _isVoiceListening = false);
      };
      await _voiceService.startListening();
    }
  }

  /// 打开语音通话
  void _openVoiceCall() async {
    final voiceConfig = ref.read(selectedVoiceConfigProvider);
    if (voiceConfig == null) {
      TopNotification.error(context, '请先在设置中配置语音模型');
      return;
    }
    final config = ref.read(selectedAiConfigProvider);
    if (config == null) {
      TopNotification.error(context, '请先配置文本AI模型');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceCallPage(
          onCallEnd: (transcript, aiResponse) {
            // 通话结束后，将记录发到聊天
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

  /// 选择文件
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择文件',
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'docx'],
    );
    if (result != null && result.files.single.path != null) {
      // 将文件内容作为消息发送到 AI 对话
      final file = result.files.single;
      final name = file.name;
      setState(() {
        _inputCtrl.text = '[文件] $name\n请分析这个文件的内容';
      });
    }
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      onPressed: onTap,
      backgroundColor: AppColors.primary.withOpacity(0.1),
    );
  }
}
