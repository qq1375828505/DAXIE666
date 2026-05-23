import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:dio/dio.dart';

class AiDrawer extends ConsumerStatefulWidget {
  final String novelId;
  final String chapterId;
  final TextEditingController controller;
  final VoidCallback onClose;

  const AiDrawer({
    super.key,
    required this.novelId,
    required this.chapterId,
    required this.controller,
    required this.onClose,
  });

  @override
  ConsumerState<AiDrawer> createState() => _AiDrawerState();
}

class _AiDrawerState extends ConsumerState<AiDrawer> {
  final TextEditingController _promptCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  final Dio _dio = Dio();

  Future<void> _sendMessage({String? presetAction}) async {
    final text = presetAction ?? _promptCtrl.text.trim();
    if (text.isEmpty) return;

    final preset = ref.read(currentPresetProvider);
    final config = ref.read(selectedAiConfigProvider);

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _promptCtrl.clear();

    try {
      if (config == null) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': '请先配置AI模型（我的 → AI设置）'});
          _isLoading = false;
        });
        return;
      }

      final systemPrompt = preset?.systemPrompt ?? '你是一位网文写作助手，帮助作者润色、扩写、续写和检查小说内容。';
      final context = widget.controller.text.length > 2000
          ? widget.controller.text.substring(widget.controller.text.length - 2000)
          : widget.controller.text;

      final response = await _dio.post(
        config.apiUrl,
        options: Options(headers: {
          'Authorization': 'Bearer ${config.apiKey ?? ''}',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': config.modelName,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': '当前章节内容：\n$context\n\n用户请求：$text'},
          ],
          'temperature': config.temperature,
          'max_tokens': config.maxTokens,
        },
      );

      final aiText = response.data['choices']?[0]?['message']?['content'] ?? '生成失败，请检查API配置';
      setState(() {
        _messages.add({'role': 'assistant', 'content': aiText});
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': '请求失败: $e\n请检查网络或API配置'});
        _isLoading = false;
      });
    }
  }

  void _insertToEditor(String text) {
    final current = widget.controller.text;
    final selection = widget.controller.selection;
    final newText = current.substring(0, selection.start) + text + current.substring(selection.end);
    widget.controller.text = newText;
    widget.controller.selection = TextSelection.collapsed(offset: selection.start + text.length);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Column(
        children: [
          // 拖动条
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text('AI写作助手', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          // 快捷动作
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _ActionChip(label: '续写', icon: Icons.arrow_forward, onTap: () => _sendMessage(presetAction: '请根据上文续写下一部分内容，保持风格一致')),
                const SizedBox(width: 8),
                _ActionChip(label: '润色', icon: Icons.brush, onTap: () => _sendMessage(presetAction: '请润色以下段落，改善语病、节奏和描写')),
                const SizedBox(width: 8),
                _ActionChip(label: '起标题', icon: Icons.title, onTap: () => _sendMessage(presetAction: '请为当前章节生成5个吸引人的标题')),
                const SizedBox(width: 8),
                _ActionChip(label: '爽点检查', icon: Icons.bolt, onTap: () => _sendMessage(presetAction: '分析当前章节的爽点密度，给出评分和优化建议')),
                const SizedBox(width: 8),
                _ActionChip(label: '水文检测', icon: Icons.water_drop, onTap: () => _sendMessage(presetAction: '检测当前章节是否存在水文段落，给出精简建议')),
              ],
            ),
          ),
          const Divider(height: 1),
          // 消息列表
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('选择上方快捷动作或输入指令', style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser
                                ? AppColors.primary.withOpacity(0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['content'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isUser ? AppColors.primary : Colors.black87,
                                ),
                              ),
                              if (!isUser)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.content_copy, size: 16),
                                      label: const Text('复制', style: TextStyle(fontSize: 12)),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: msg['content']));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('已复制')),
                                        );
                                      },
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('插入', style: TextStyle(fontSize: 12)),
                                      onPressed: () => _insertToEditor(msg['content']),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(minHeight: 2),
          // 输入框
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptCtrl,
                    decoration: InputDecoration(
                      hintText: '输入AI指令...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: () => _sendMessage(),
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

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.primary),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: AppColors.primary.withOpacity(0.05),
      side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
      onPressed: onTap,
    );
  }
}
