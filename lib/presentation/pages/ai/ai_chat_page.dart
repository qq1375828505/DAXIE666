import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:novel_ide/presentation/pages/profile/voice_config_page.dart';
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
  bool _showSidebar = false;
  bool _showBottomSheet = false;
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

    final config = ref.read(effectiveAiConfigProvider);
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

      // Auto-compact if too many messages (>300 pairs = 600 messages)
      if (_currentSession!.messages.length > 600) {
        await _compactMessages(config);
      }

      // 智能判断是否需要 Agent 模式（带工具能力）
      // 只有检测到明确的任务意图时才启用 Agent 模式（避免每条消息都传26个工具到API导致卡死）
      // - 普通闲聊、写作指导、问题解答 → 普通模式（省 token、更快）
      // - 明确的工具调用请求 → Agent 模式
      final novel = ref.read(selectedNovelProvider);
      final needsAgent = shouldTriggerAgent;

      if (needsAgent) {
        final agent = WorkspaceAgent();
        if (novel != null) {
          registerAllToolExecutors(agent: agent, novelId: novel.id, novelTitle: novel.title);
        } else {
          // 没选中小说时，注册通用工具执行器（配置管理等）
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
        // 普通模式：闲聊、简单问答（使用chatLite，不传工具定义，省token）
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
      // 用 user 角色做摘要（避免和 agent 的 system prompt 冲突）
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
    final novels = ref.watch(novelsProvider).valueOrNull ?? [];
    final selectedNovel = ref.watch(selectedNovelProvider);

    // 使用 _showSidebar 而不是 _showHistory，保持功能向后兼容
    final showSidebar = _showHistory || _showSidebar;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 主聊天区域
          Column(
            children: [
              // 顶部模型选择栏
              GestureDetector(
                onTap: () => setState(() => _showSidebar = !_showSidebar),
                child: Container(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.menu, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            // 显示模型选择器
                            if (configs.isNotEmpty) {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => Container(
                                  decoration: BoxDecoration(
                                    color: Color(0xFF1F1F1F),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                  ),
                                  child: SafeArea(
                                    child: ListView(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 4,
                                          margin: EdgeInsets.symmetric(horizontal: 150, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[600],
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...configs.map((c) => ListTile(
                                          title: Text(c.name, style: TextStyle(color: Colors.white)),
                                          subtitle: Text(c.modelName, style: TextStyle(color: Colors.grey[500])),
                                          trailing: selectedConfig?.id == c.id
                                              ? Icon(Icons.check, color: Color(0xFF10A37F))
                                              : null,
                                          onTap: () {
                                            ref.read(selectedAiConfigProvider.notifier).state = c;
                                            Navigator.pop(ctx);
                                          },
                                        )),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                selectedConfig?.name ?? '选择模型',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.expand_more, color: Colors.grey[500]),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, color: Colors.white),
                        onPressed: _newSession,
                      ),
                    ],
                  ),
                ),
              ),
              // 聊天内容
              Expanded(
                child: messages.isEmpty
                    ? _buildEmptyState(currentPreset)
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: EdgeInsets.all(16),
                        itemCount: messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10A37F))),
                                  SizedBox(width: 12),
                                  Text('思考中...', style: TextStyle(color: Colors.grey[500])),
                                ],
                              ),
                            );
                          }
                          final msg = messages[index];
                          final isUser = msg['role'] == 'user';
                          final matchedForThis = _skillMatches[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (matchedForThis != null && matchedForThis.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(bottom: 4),
                                  child: SkillIndicator(matchedSkills: matchedForThis),
                                ),
                              Container(
                                width: MediaQuery.of(context).size.width,
                                constraints: BoxConstraints(maxWidth: 800),
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                color: isUser ? Colors.transparent : Color(0xFF2F2F2F),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      margin: EdgeInsets.only(right: 16),
                                      decoration: BoxDecoration(
                                        color: isUser ? Color(0xFF10A37F) : Color(0xFF404040),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        isUser ? Icons.person : Icons.smart_toy,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        msg['content']!,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              // 底部输入栏
              Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
                color: Colors.black,
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxWidth: 800),
                  decoration: BoxDecoration(
                    color: Color(0xFF2F2F2F),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(Icons.add, color: Colors.grey[400]),
                        onPressed: () {
                          setState(() => _showBottomSheet = true);
                          // 显示底部菜单
                          _showAttachMenu(context);
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          maxLines: null,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: '消息 Novel IDE...',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_upward, color: Colors.white),
                        onPressed: _isLoading ? null : _sendMessage,
                        padding: EdgeInsets.all(8),
                        constraints: BoxConstraints(),
                        color: Color(0xFF10A37F),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 侧边栏
          if (showSidebar)
            Positioned.fill(
              child: Row(
                children: [
                  Container(
                    width: 280,
                    color: Color(0xFF171717),
                    child: Column(
                      children: [
                        SizedBox(height: 12),
                        // 新建会话按钮
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: GestureDetector(
                            onTap: () {
                              _newSession();
                              setState(() => _showSidebar = false);
                            },
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[700]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.add, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text('新建会话', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _sessions.length + novels.length + 2,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Padding(
                                  padding: EdgeInsets.only(top: 12, bottom: 8, left: 8),
                                  child: Text('历史会话', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                );
                              }
                              if (index <= _sessions.length) {
                                final sessionIndex = index - 1;
                                final session = _sessions[sessionIndex];
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _currentSession = session;
                                      _showSidebar = false;
                                      _showHistory = false;
                                      _skillMatches.clear();
                                    });
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _currentSession?.id == session.id ? Color(0xFF2F2F2F) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      session.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white, fontSize: 14),
                                    ),
                                  ),
                                );
                              }
                              if (index == _sessions.length + 1) {
                                return Padding(
                                  padding: EdgeInsets.only(top: 16, bottom: 8, left: 8),
                                  child: Text('我的作品', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                );
                              }
                              final novelIndex = index - _sessions.length - 2;
                              if (novelIndex < novels.length) {
                                final novel = novels[novelIndex];
                                return GestureDetector(
                                  onTap: () {
                                    ref.read(selectedNovelProvider.notifier).state = novel;
                                    setState(() => _showSidebar = false);
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: selectedNovel?.id == novel.id ? Color(0xFF2F2F2F) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.book, color: Colors.grey[400], size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            novel.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: Colors.white, fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return SizedBox.shrink();
                            },
                          ),
                        ),
                        Divider(color: Colors.grey[800]),
                        // 资料库入口
                        ListTile(
                          leading: Icon(Icons.library_books, color: Colors.grey[400]),
                          title: Text('资料库', style: TextStyle(color: Colors.white)),
                          onTap: () {
                            setState(() => _showSidebar = false);
                            // 切换到资料库 tab
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showSidebar = false),
                      child: Container(color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(dynamic currentPreset) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(maxWidth: 800),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit, size: 48, color: Colors.grey[700]),
              const SizedBox(height: 24),
              Text('Novel IDE', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(currentPreset != null ? '当前风格: ${currentPreset.name}' : '专业网文写作助手',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 32),
              // 快捷操作卡片
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _QuickActionCard(
                    '💡 构思剧情',
                    '帮我构思一个有趣的剧情',
                    () { _inputCtrl.text = '帮我构思一个有趣的剧情'; _sendMessage(); },
                  ),
                  _QuickActionCard(
                    '📖 起个书名',
                    '帮我起5个吸引人的书名',
                    () { _inputCtrl.text = '帮我起5个吸引人的书名'; _sendMessage(); },
                  ),
                  _QuickActionCard(
                    '👤 设计角色',
                    '帮我设计一个有意思的主角',
                    () { _inputCtrl.text = '帮我设计一个有意思的主角'; _sendMessage(); },
                  ),
                  _QuickActionCard(
                    '📝 生成大纲',
                    '帮我写一个小说大纲',
                    () { _inputCtrl.text = '帮我写一个小说大纲'; _sendMessage(); },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
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
              _skillMatches.clear(); // 切换对话时清空旧skill记录
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
                          child: GestureDetector(
                            onLongPress: () {
                              _showMessageMenu(context, index, msg['content']!);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isUser ? AppColors.primary : Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: SelectableText(
                                msg['content']!,
                                style: TextStyle(
                                  color: isUser ? Colors.white : Colors.black87,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
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
                    onPressed: hasVoiceModel
                        ? _openVoiceCall
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('语音通话需要配置语音模型，请前往 我的 → 语音配置'),
                                duration: const Duration(seconds: 3),
                                action: SnackBarAction(
                                  label: '去配置',
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => const VoiceConfigPage(),
                                    ));
                                  },
                                ),
                              ),
                            );
                          },
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
              // 选择资料选项
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.library_books, color: Colors.teal),
                ),
                title: const Text('选择资料', style: TextStyle(fontSize: 16)),
                subtitle: const Text('选择角色、设定等资料作为上下文', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showMaterialPicker();
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
              // 去AI味选项
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology_outlined, color: Colors.orange),
                ),
                title: const Text('去AI味', style: TextStyle(fontSize: 16)),
                subtitle: const Text('消除AI写作痕迹，让文本更自然', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _humanizeText();
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
    final config = ref.read(effectiveAiConfigProvider);
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
    final config = ref.read(effectiveAiConfigProvider);
    if (config == null) {
      TopNotification.error(context, '请先在"我的"页面配置AI模型');
      return;
    }

    final novel = ref.read(selectedNovelProvider);
    if (novel == null) {
      _showNeedNovelDialog('执行工作流需要先选择一部作品，是否前往创建？');
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

  /// 显示消息长按菜单（复制、撤回）
  void _showMessageMenu(BuildContext context, int index, String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.black87),
                title: const Text('复制'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: content));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
                  );
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
        title: const Text('撤回消息'),
        content: const Text('确定要撤回这条消息吗？'),
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
                // 同时删除对应的技能匹配记录
                _skillMatches.remove(index);
                // 更新其他记录的索引
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('消息已撤回'), duration: Duration(seconds: 1)),
              );
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 提示需要选择作品，引导用户前往作品页
  void _showNeedNovelDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需要选择作品'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(bottomNavIndexProvider.notifier).state = 0;
            },
            child: const Text('前往作品页'),
          ),
        ],
      ),
    );
  }

  /// 去AI味：将AI生成的文本改写为自然人类风格
  void _humanizeText() {
    final inputText = _inputCtrl.text.trim();
    if (inputText.isEmpty) {
      TopNotification.success(context, '请先在输入框中粘贴需要去AI味的文本');
      return;
    }
    // 构造去AI味的请求，直接发给AI
    final humanizePrompt = '''请对以下文本进行去AI味改写，遵循这些规则：
1. 删除过度强调词（crucial/pivotal/stands as/is a testament/reflects broader）
2. 删除空洞评价（This is important/It is worth noting/In today's world）
3. 删除AI典型三项排比，改为更自然的表达
4. 减少破折号滥用，用逗号或句号替代
5. 删除虚假归因（研究表明/专家认为 无具体来源时）
6. 打破句子同质化，混合长短句，加入个人视角
7. 注入个性和情感，而非中性报道
8. 保留核心含义，保持原文语气风格

原文本：
$inputText''';

    _inputCtrl.text = humanizePrompt;
    _sendMessage();
  }

  /// 选择资料作为AI上下文
  void _showMaterialPicker() {
    final novel = ref.read(selectedNovelProvider);
    if (novel == null) {
      _showNeedNovelDialog('选择资料需要先选择一部作品，是否前往创建？');
      return;
    }
    final novelId = novel.id;

    final characters = ref.read(charactersProvider(novelId));
    final settings = ref.read(settingCardsProvider(novelId));
    final locations = ref.read(locationsProvider(novelId));
    final factions = ref.read(factionsProvider(novelId));
    final items = ref.read(itemsProvider(novelId));
    final hooks = ref.read(plotHooksProvider(novelId));
    final references = ref.read(referencesProvider(novelId));
    final customFolders = ref.read(customFoldersProvider);

    final tabNames = ['角色', '设定', '地点', '势力', '道具', '伏笔', '参考', ...customFolders.map((f) => f.name)];
    final selectedIds = <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPickerState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.library_books, size: 20, color: Colors.teal),
                    const SizedBox(width: 8),
                    const Text('选择资料', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${selectedIds.length} 项已选', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: tabNames.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Chip(
                        label: Text(tabNames[index], style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    _buildSectionHeader('角色'),
                    for (final c in characters)
                      CheckboxListTile(
                        value: selectedIds.contains(c.id),
                        onChanged: (v) => setPickerState(() {
                          v == true ? selectedIds.add(c.id) : selectedIds.remove(c.id);
                        }),
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: _buildPreview('${c.role ?? ""} ${c.description ?? ""}'.trim()),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    _buildSectionHeader('设定'),
                    for (final s in settings)
                      CheckboxListTile(
                        value: selectedIds.contains(s.id),
                        onChanged: (v) => setPickerState(() {
                          v == true ? selectedIds.add(s.id) : selectedIds.remove(s.id);
                        }),
                        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: _buildPreview(s.description ?? ''),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    _buildSectionHeader('地点'),
                    for (final l in locations)
                      CheckboxListTile(
                        value: selectedIds.contains(l.id),
                        onChanged: (v) => setPickerState(() {
                          v == true ? selectedIds.add(l.id) : selectedIds.remove(l.id);
                        }),
                        title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: _buildPreview(l.description ?? ''),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    _buildSectionHeader('势力'),
                    for (final f in factions)
                      CheckboxListTile(
                        value: selectedIds.contains(f.id),
                        onChanged: (v) => setPickerState(() {
                          v == true ? selectedIds.add(f.id) : selectedIds.remove(f.id);
                        }),
                        title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: _buildPreview(f.description ?? ''),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    _buildSectionHeader('道具'),
                    for (final i in items)
                      CheckboxListTile(
                        value: selectedIds.contains(i.id),
                        onChanged: (v) => setPickerState(() {
                          v == true ? selectedIds.add(i.id) : selectedIds.remove(i.id);
                        }),
                        title: Text(i.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: _buildPreview(i.description ?? ''),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    _buildSectionHeader('伏笔'),
                    for (final h in hooks)
                      CheckboxListTile(
                        value: selectedIds.contains(h.id),
                        onChanged: (v) => setPickerState(() {
                          v == true ? selectedIds.add(h.id) : selectedIds.remove(h.id);
                        }),
                        title: Text(h.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: _buildPreview(h.description ?? ''),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    _buildSectionHeader('参考'),
                    for (final r in references)
                      CheckboxListTile(
                        value: selectedIds.contains(r.id),
                        onChanged: (v) => setPickerState(() {
                          v == true ? selectedIds.add(r.id) : selectedIds.remove(r.id);
                        }),
                        title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: _buildPreview(r.content ?? ''),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    for (final folder in customFolders) ...[
                      _buildSectionHeader(folder.name),
                      for (final item in folder.items)
                        CheckboxListTile(
                          value: selectedIds.contains(item.id),
                          onChanged: (v) => setPickerState(() {
                            v == true ? selectedIds.add(item.id) : selectedIds.remove(item.id);
                          }),
                          title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: _buildPreview(item.content),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
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
                          if (s.category != null) buffer.writeln('分类: ${s.category}');
                          if (s.description != null) buffer.writeln(s.description);
                          buffer.writeln();
                        }
                        for (final l in locations.where((l) => selectedIds.contains(l.id))) {
                          buffer.writeln('## 地点：${l.name}');
                          if (l.category != null) buffer.writeln('分类: ${l.category}');
                          if (l.description != null) buffer.writeln(l.description);
                          buffer.writeln();
                        }
                        for (final f in factions.where((f) => selectedIds.contains(f.id))) {
                          buffer.writeln('## 势力：${f.name}');
                          if (f.description != null) buffer.writeln(f.description);
                          buffer.writeln();
                        }
                        for (final i in items.where((i) => selectedIds.contains(i.id))) {
                          buffer.writeln('## 道具：${i.name}');
                          if (i.description != null) buffer.writeln(i.description);
                          buffer.writeln();
                        }
                        for (final h in hooks.where((h) => selectedIds.contains(h.id))) {
                          buffer.writeln('## 伏笔：${h.title}');
                          if (h.description != null) buffer.writeln(h.description);
                          buffer.writeln();
                        }
                        for (final r in references.where((r) => selectedIds.contains(r.id))) {
                          buffer.writeln('## 参考：${r.title}');
                          if (r.content != null) buffer.writeln(r.content);
                          buffer.writeln();
                        }
                        for (final folder in customFolders) {
                          for (final item in folder.items.where((i) => selectedIds.contains(i.id))) {
                            buffer.writeln('## ${folder.name}：${item.title}');
                            buffer.writeln(item.content);
                            buffer.writeln();
                          }
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
    );
  }

  Widget _buildPreview(String text) {
    return Text(
      text.isEmpty ? '无描述' : text.substring(0, text.length.clamp(0, 30)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
    );
  }

  /// 选择文件
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择文件',
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'docx'],
    );
    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      final name = file.name;
      try {
        final content = await File(file.path!).readAsString();
        setState(() {
          _inputCtrl.text = '[文件: $name]\n$content\n\n请分析以上文件内容';
        });
      } catch (e) {
        setState(() {
          _inputCtrl.text = '[文件: $name]\n读取失败: $e\n请分析这个文件的内容';
        });
      }
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

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String defaultMessage;
  final VoidCallback onTap;

  const _QuickActionCard(this.title, this.defaultMessage, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 156,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[700]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              defaultMessage,
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
