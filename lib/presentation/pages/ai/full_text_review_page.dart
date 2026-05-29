import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';
import 'package:novel_ide/data/services/ai_service.dart';
import 'package:novel_ide/presentation/widgets/top_notification.dart';

/// Full-text review page - scans all chapters for consistency issues.
class FullTextReviewPage extends ConsumerStatefulWidget {
  final String novelId;
  final String novelTitle;

  const FullTextReviewPage({super.key, required this.novelId, required this.novelTitle});

  @override
  ConsumerState<FullTextReviewPage> createState() => _FullTextReviewPageState();
}

class _FullTextReviewPageState extends ConsumerState<FullTextReviewPage> {
  bool _isLoading = false;
  String _result = '';
  String _selectedCheck = 'conflict';

  static const _checks = {
    'conflict': '设定冲突检测',
    'power': '战力一致性',
    'hook': '伏笔追踪',
    'character': '角色一致性',
  };

  Future<void> _runReview() async {
    final config = ref.read(selectedAiConfigProvider);
    if (config == null) {
      TopNotification.success(context, '请先配置AI模型');
      return;
    }

    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      // Load all chapters (await if not yet loaded)
      final chaptersAsync = ref.read(chaptersProvider(widget.novelId));
      final chapters = chaptersAsync.valueOrNull ?? await ref.read(chaptersProvider(widget.novelId).future) ?? [];
      if (chapters.isEmpty) {
        setState(() {
          _isLoading = false;
          _result = '暂无章节内容可供审查';
        });
        return;
      }

      // Combine chapter content (limit to avoid token overflow)
      final allContent = chapters.take(20).map((c) =>
        '【${c.title}】\n${c.content.length > 2000 ? c.content.substring(0, 2000) + '...' : c.content}'
      ).join('\n\n');

      // Load materials for context (ensure loaded)
      if (ref.read(charactersProvider(widget.novelId)).isEmpty) {
        await loadNovelMaterials(ref, widget.novelId);
      }
      final characters = ref.read(charactersProvider(widget.novelId));
      final settings = ref.read(settingCardsProvider(widget.novelId));
      final hooks = ref.read(plotHooksProvider(widget.novelId));

      final materialContext = StringBuffer();
      if (characters.isNotEmpty) {
        materialContext.writeln('角色卡：${characters.map((c) => '${c.name}(${c.role ?? ""})').join('、')}');
      }
      if (settings.isNotEmpty) {
        materialContext.writeln('设定：${settings.map((s) => '${s.name}(${s.category ?? ""})').join('、')}');
      }
      if (hooks.isNotEmpty) {
        materialContext.writeln('伏笔：${hooks.map((h) => '${h.title}(${h.isRevealed ? "已回收" : "未回收"})').join('、')}');
      }

      final prompts = {
        'conflict': '你是小说设定审查专家。请检查以下章节内容是否存在设定矛盾、逻辑漏洞、前后不一致的问题。列出每个冲突的具体位置和描述。',
        'power': '你是战力体系审查专家。请检查以下章节中的战力描写是否一致，是否有战力崩坏、越级不合理等问题。',
        'hook': '你是伏笔追踪专家。请检查以下章节中埋下的伏笔，哪些已经回收，哪些闲置超过5章需要关注。',
        'character': '你是角色一致性审查专家。请检查以下章节中的角色行为、性格、能力是否前后一致。',
      };

      final aiService = ref.read(aiServiceProvider);
      final response = await aiService.send(
        config: config,
        systemPrompt: '${prompts[_selectedCheck]}\n\n角色资料：\n${materialContext.toString()}',
        userMessage: '请审查以下小说内容：\n\n$allContent',
        taskType: 'analysis',
      );

      setState(() {
        _result = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _result = '审查失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('全文审查')),
      body: Column(
        children: [
          // Check type selector
          Container(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: _checks.entries.map((e) => ChoiceChip(
                label: Text(e.value, style: const TextStyle(fontSize: 13)),
                selected: _selectedCheck == e.key,
                selectedColor: AppColors.primary,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedCheck = e.key);
                },
              )).toList(),
            ),
          ),
          // Run button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow),
                label: Text(_isLoading ? '审查中...' : '开始审查'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: _isLoading ? null : _runReview,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Results
          Expanded(
            child: _result.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fact_check, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('选择审查类型，点击开始', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(_selectedCheck == 'conflict' ? Icons.warning_amber :
                                       _selectedCheck == 'power' ? Icons.trending_up :
                                       _selectedCheck == 'hook' ? Icons.link :
                                       Icons.person, size: 20, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(_checks[_selectedCheck]!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Divider(),
                              Text(_result, style: const TextStyle(fontSize: 14, height: 1.6)),
                            ],
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
}
