import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/services/ai_service.dart';
import 'package:novel_ide/data/services/novel_memory.dart';

/// Dedicated AI chat page with model switching.
class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  void _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    final config = ref.read(selectedAiConfigProvider);
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在"我的"页面配置AI模型')),
      );
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'content': text});
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

      final aiService = ref.read(aiServiceProvider);
      final aiText = await aiService.send(
        config: config,
        systemPrompt: '$systemPrompt\n\n小说记忆文件（当前状态）：\n$memoryContext',
        userMessage: text,
        taskType: 'chat',
      );

      setState(() {
        _messages.add({'role': 'assistant', 'content': aiText});
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': '请求失败: $e'});
        _isLoading = false;
      });
    }
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 对话'),
        actions: [
          // Model selector
          if (configs.length > 1)
            PopupMenuButton<String>(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy, size: 18, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    selectedConfig?.name ?? '选择模型',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
              onSelected: (configId) {
                final config = configs.firstWhere((c) => c.id == configId);
                ref.read(selectedAiConfigProvider.notifier).state = config;
              },
              itemBuilder: (context) => configs.map((c) => PopupMenuItem(
                value: c.id,
                child: Row(
                  children: [
                    Icon(
                      c.id == selectedConfig?.id ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 16,
                      color: c.id == selectedConfig?.id ? AppColors.primary : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: const TextStyle(fontSize: 14)),
                        Text('${c.modelName} · ${c.isLocal ? "本地" : "云端"}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    )),
                  ],
                ),
              )).toList(),
            ),
          // Style preset indicator
          if (currentPreset != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.tomatoOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(currentPreset.name, style: TextStyle(fontSize: 11, color: AppColors.tomatoOrange)),
                ),
              ),
            ),
          // Clear chat
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () {
              setState(() => _messages.clear());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[200]),
                        const SizedBox(height: 16),
                        Text('开始和AI对话吧', style: TextStyle(fontSize: 16, color: Colors.grey[400])),
                        const SizedBox(height: 8),
                        Text(
                          currentPreset != null ? '当前风格: ${currentPreset.name}' : '默认写作助手',
                          style: TextStyle(fontSize: 13, color: Colors.grey[350]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        // Loading indicator
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 12),
                              Text('思考中...', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }
                      final msg = _messages[index];
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
                          child: Text(
                            msg['content']!,
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
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
                    icon: Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
