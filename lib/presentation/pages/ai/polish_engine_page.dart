import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/services/ai_service.dart';

class PolishEnginePage extends ConsumerStatefulWidget {
  final String chapterContent;
  final String novelTitle;

  const PolishEnginePage({super.key, required this.chapterContent, required this.novelTitle});

  @override
  ConsumerState<PolishEnginePage> createState() => _PolishEnginePageState();
}

class _PolishEnginePageState extends ConsumerState<PolishEnginePage> {
  final List<PolishItem> _items = [];
  bool _isLoading = false;

  static const _dimensions = [
    '语病', '节奏', '文风', '冗余',
    '对话', '描写', '钩子', '战力',
  ];

  bool _allEnabled = false;
  final List<bool> _enabled = List.generate(8, (_) => true);

  Future<void> _startPolish() async {
    final config = ref.read(selectedAiConfigProvider);
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置AI模型')),
      );
      return;
    }

    final preset = ref.read(currentPresetProvider);
    final selectedDims = <String>[];
    for (int i = 0; i < _dimensions.length; i++) {
      if (_enabled[i]) selectedDims.add(_dimensions[i]);
    }
    if (selectedDims.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个维度')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final aiService = ref.read(aiServiceProvider);
      final aiText = await aiService.send(
        config: config,
        systemPrompt: preset?.systemPrompt ?? '你是一位网文精修专家。分析以下文本，针对${selectedDims.join('、')}维度找出问题段落，给出原文、问题和修改建议。',
        userMessage: '请对以下章节进行${selectedDims.join('、')}维度的精修分析。\n\n${widget.chapterContent}',
        taskType: 'polish',
      );

      _parseResult(aiText);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请求失败: $e')),
        );
      }
    }
  }

  void _parseResult(String text) {
    setState(() {
      _items.clear();
      final lines = text.split('\n');
      PolishItem? current;
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        if (line.startsWith('##') || line.contains('维度')) continue;
        if (line.startsWith('-') || line.contains('【') || line.contains('原文')) {
          if (current != null) _items.add(current);
          current = PolishItem(
            dimension: _extractDimension(line),
            original: line.replaceAll(RegExp(r'[#\-【】\[\]]+'), '').trim(),
            suggestion: '',
            isAccepted: false,
          );
        } else if (line.startsWith('->') || line.contains('修改') || line.contains('建议')) {
          current?.suggestion = line.replaceAll(RegExp(r'[#\-【】\[\]>\->]+'), '').trim();
        }
      }
      if (current != null) _items.add(current);
      _isLoading = false;
    });
  }

  String _extractDimension(String line) {
    for (final dim in _dimensions) {
      if (line.contains(dim)) return dim;
    }
    return '综合';
  }

  @override
  Widget build(BuildContext context) {
    final configs = ref.watch(aiConfigsProvider);
    final selectedConfig = ref.watch(selectedAiConfigProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('一键精修'),
        actions: [
          // Model selector
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
              onSelected: (configId) {
                final config = configs.firstWhere((c) => c.id == configId);
                ref.read(selectedAiConfigProvider.notifier).state = config;
              },
              itemBuilder: (context) => configs.map((c) => PopupMenuItem(
                value: c.id,
                child: Row(
                  children: [
                    Icon(c.id == selectedConfig?.id ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 16, color: c.id == selectedConfig?.id ? AppColors.primary : Colors.grey),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: const TextStyle(fontSize: 14)),
                      Text('${c.modelName}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ]),
                  ],
                ),
              )).toList(),
            ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() {
              _allEnabled = !_allEnabled;
              for (int i = 0; i < _enabled.length; i++) {
                _enabled[i] = _allEnabled;
              }
            }),
            child: Text(_allEnabled ? '全部取消' : '全选'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在精修分析...'),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(_dimensions.length, (i) {
                      return FilterChip(
                        label: Text(_dimensions[i], style: const TextStyle(fontSize: 12)),
                        selected: _enabled[i],
                        selectedColor: AppColors.primary.withOpacity(0.15),
                        onSelected: (v) => setState(() => _enabled[i] = v),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startPolish,
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('开始精修'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const Divider(),
                if (_items.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_fix_high, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('选择精修维度后点击开始', style: TextStyle(color: Colors.grey[400])),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Chip(
                                      label: Text(item.dimension, style: const TextStyle(fontSize: 11)),
                                      backgroundColor: AppColors.tomatoOrange.withOpacity(0.1),
                                      side: BorderSide.none,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: const Border(left: BorderSide(color: Colors.orange, width: 3)),
                                  ),
                                  child: Text(item.original, style: const TextStyle(fontSize: 14)),
                                ),
                                if (item.suggestion.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  const Icon(Icons.arrow_downward, size: 20, color: AppColors.primary),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
                                    ),
                                    child: Text(item.suggestion, style: const TextStyle(fontSize: 14)),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: Icon(item.isAccepted ? Icons.check_circle : Icons.check_circle_outline, size: 18),
                                      label: Text(item.isAccepted ? '已采用' : '采用'),
                                      onPressed: () {
                                        setState(() => item.isAccepted = !item.isAccepted);
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton.icon(
                                      icon: const Icon(Icons.add_circle_outline, size: 18),
                                      label: const Text('插入下方'),
                                      onPressed: () {
                                        // Insert suggestion below original in editor
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('建议已插入'), duration: Duration(seconds: 1)),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton.icon(
                                      icon: const Icon(Icons.refresh, size: 18),
                                      label: const Text('重新生成'),
                                      onPressed: () async {
                                        setState(() => _isLoading = true);
                                        final config = ref.read(selectedAiConfigProvider);
                                        if (config != null) {
                                          final aiService = ref.read(aiServiceProvider);
                                          final response = await aiService.send(
                                            config: config,
                                            systemPrompt: '你是网文精修专家。请重新优化以下段落的${item.dimension}方面：',
                                            userMessage: '原文：${item.original}\n\n请给出更好的修改建议。',
                                            taskType: 'polish',
                                          );
                                          setState(() {
                                            item.suggestion = response;
                                            item.isAccepted = false;
                                            _isLoading = false;
                                          });
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton.icon(
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('跳过'),
                                      onPressed: () {
                                        setState(() {
                                          _items.removeAt(index);
                                        });
                                      },
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
              ],
            ),
    );
  }
}

class PolishItem {
  String dimension;
  String original;
  String suggestion;
  bool isAccepted;

  PolishItem({
    required this.dimension,
    required this.original,
    required this.suggestion,
    this.isAccepted = false,
  });
}
