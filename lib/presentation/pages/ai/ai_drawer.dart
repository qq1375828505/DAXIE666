import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/services/ai_service.dart';
import 'package:novel_ide/presentation/pages/tomato/shuangdian_report_page.dart';
import 'package:novel_ide/presentation/pages/tomato/water_report_page.dart';
import 'package:novel_ide/presentation/pages/tomato/title_generator_result_page.dart';

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

      final aiService = ref.read(aiServiceProvider);
      final aiText = await aiService.send(
        config: config,
        systemPrompt: systemPrompt,
        userMessage: '当前章节内容：\n$context\n\n用户请求：$text',
      );
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

  // --- V2: Report-generating quick actions ---

  Future<void> _runShuangdianCheck() async {
    final config = ref.read(selectedAiConfigProvider);
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先配置AI模型')));
      return;
    }
    final content = widget.controller.text;
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先输入章节内容')));
      return;
    }
    widget.onClose();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在分析爽点...'), duration: Duration(seconds: 3)));
    try {
      final aiService = ref.read(aiServiceProvider);
      final response = await aiService.send(
        config: config,
        systemPrompt: '你是番茄小说爽点密度检查器。分析规则：\n1. 爽点分类：身份揭露、打脸、实力碾压、财富展示、情感反转、系统奖励\n2. 密度标准：每3000字至少2-3个爽点\n3. 评分标准：0-10分\n4. 输出格式：评分数+爽点列表(位置/类型/强度)+优化建议',
        userMessage: '请分析以下章节的爽点密度：\n\n$content',
      );
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ShuangdianReportPage(chapterContent: content, aiResponse: response),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('分析失败: $e')));
    }
  }

  Future<void> _runWaterCheck() async {
    final config = ref.read(selectedAiConfigProvider);
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先配置AI模型')));
      return;
    }
    final content = widget.controller.text;
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先输入章节内容')));
      return;
    }
    widget.onClose();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在检测水文...'), duration: Duration(seconds: 3)));
    try {
      final aiService = ref.read(aiServiceProvider);
      final response = await aiService.send(
        config: config,
        systemPrompt: '你是番茄小说水文检测器。检测规则：\n1. 水文分类：废话对话、冗余环境描写、无推进日常、重复说明\n2. 水文率：<15%优秀，15-25%及格，>25%需精简\n3. 输出格式：水文率+水文段落列表+优化方案',
        userMessage: '请检测以下章节的水文：\n\n$content',
      );
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => WaterReportPage(chapterContent: content, aiResponse: response),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('检测失败: $e')));
    }
  }

  Future<void> _runTitleGeneration() async {
    final config = ref.read(selectedAiConfigProvider);
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先配置AI模型')));
      return;
    }
    final content = widget.controller.text;
    widget.onClose();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在生成标题...'), duration: Duration(seconds: 3)));
    try {
      final aiService = ref.read(aiServiceProvider);
      final response = await aiService.send(
        config: config,
        systemPrompt: '你是番茄小说爆款标题生成器。标题要求：\n1. 长度：8-15字\n2. 风格：悬念式、爽点式、反转式\n3. 生成5个标题，按吸引力排序',
        userMessage: content.isEmpty ? '请生成5个爆款标题' : '请根据以下章节内容生成5个爆款标题：\n\n$content',
      );
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => TitleGeneratorResultPage(aiResponse: response),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('生成失败: $e')));
    }
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
                _ActionChip(label: '起标题', icon: Icons.title, onTap: () => _runTitleGeneration()),
                const SizedBox(width: 8),
                _ActionChip(label: '爽点检查', icon: Icons.bolt, onTap: () => _runShuangdianCheck()),
                const SizedBox(width: 8),
                _ActionChip(label: '水文检测', icon: Icons.water_drop, onTap: () => _runWaterCheck()),
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
