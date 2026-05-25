import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/services/ai_service.dart';
import 'package:novel_ide/data/services/novel_memory.dart';

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

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<AiChatSession> _sessions = [];
  AiChatSession? _currentSession;
  bool _isLoading = false;
  bool _showHistory = false;

  void _newSession() {
    final session = AiChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '新会话 ${_sessions.length + 1}',
    );
    setState(() {
      _sessions.insert(0, session);
      _currentSession = session;
      _showHistory = false;
    });
  }

  void _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    // Auto-create session if none
    if (_currentSession == null) _newSession();

    final config = ref.read(selectedAiConfigProvider);
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在"我的"页面配置AI模型')),
      );
      return;
    }

    setState(() {
      _currentSession!.messages.add({'role': 'user', 'content': text});
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
      final systemPrompt = preset?.systemPrompt ?? '你是一位专业的网文写作助手，擅长帮助作者构思剧情、润色文字、生成大纲和角色设定。请用中文回复。';

      // Load novel memory for context
      String memoryContext = '';
      try {
        final novel = ref.read(selectedNovelProvider);
        if (novel != null) {
          memoryContext = await NovelMemory.getForAiContext(novel.id, novel.title);
        }
      } catch (_) {}

      // Auto-compact if too many messages (>20 pairs = 40 messages)
      if (_currentSession!.messages.length > 40) {
        await _compactMessages(config);
      }

      final aiService = ref.read(aiServiceProvider);
      final aiText = await aiService.send(
        config: config,
        systemPrompt: '$systemPrompt\n\n小说记忆文件（当前状态）：\n$memoryContext',
        userMessage: text,
        taskType: 'chat',
      );

      setState(() {
        _currentSession!.messages.add({'role': 'assistant', 'content': aiText});
        _isLoading = false;
      });
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
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
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
            onPressed: () {
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
                    return Align(
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
