import 'dart:convert';
import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/data/models/proactive_question_model.dart';
import 'package:novel_ide/data/models/writing_skill_model.dart';
import 'package:novel_ide/data/services/ai_service.dart';

/// 模糊需求识别服务
/// 使用AI分析用户输入，判断是否需要主动提问，并生成个性化选项
class FuzzyNeedDetector {
  final AiService _aiService = AiService();

  /// 快速关键词预检测（避免不必要的AI调用）
  /// 只有匹配到模糊模式时才调用AI进行深度分析
  static const Map<String, List<String>> _quickPatterns = {
    'novel_genre': ['写小说', '写一本', '创作小说', '新小说', '开始写', '想写小说', '帮我写小说'],
    'agent_select': ['生成大纲', '生成角色', '检查爽点', '检测水文', '生成标题', '自动生成'],
    'skill_select': ['优化', '改进', '提升', '润色', '重写'],
    'clarify': ['帮忙', '帮我', '能不能', '怎么', '如何'],
  };

  /// 快速预检测：是否可能需要主动提问
  /// 返回匹配到的类别，null表示不需要
  String? _quickDetect(String userInput) {
    for (final entry in _quickPatterns.entries) {
      for (final pattern in entry.value) {
        if (userInput.contains(pattern)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// 检测用户输入是否为模糊需求（AI驱动）
  /// 返回需要提问的类型，null表示需求明确不需要提问
  Future<ProactiveQuestionType?> detect(
    String userInput, {
    AiConfig? config,
    String? userMemory,
    String? novelContext,
  }) async {
    // 第一步：快速预检测
    final quickMatch = _quickDetect(userInput);
    if (quickMatch == null) return null;

    // 如果没有AI配置，回退到简单关键词匹配
    if (config == null) {
      return _fallbackDetect(userInput);
    }

    // 第二步：AI深度分析
    try {
      final contextBuffer = StringBuffer();
      if (userMemory != null && userMemory.isNotEmpty) {
        contextBuffer.writeln('用户历史偏好：\n$userMemory');
      }
      if (novelContext != null && novelContext.isNotEmpty) {
        contextBuffer.writeln('当前小说上下文：\n$novelContext');
      }

      final response = await _aiService.send(
        config: config,
        systemPrompt: '''你是一个需求分析助手。分析用户输入是否需要进一步提问来明确需求。

判断规则：
- 如果用户需求已经非常具体明确（包含类型、风格、目标等），返回 "clear"
- 如果用户需求模糊，缺少关键信息，返回对应类型：
  - "novel_genre" - 需要确认小说类型
  - "agent_select" - 需要选择智能体/工具
  - "skill_select" - 需要选择写作技能
  - "clarify" - 需要进一步澄清需求

只返回类型关键词，不要返回其他内容。''',
        userMessage: '用户输入："$userInput"\n\n$contextBuffer',
        taskType: 'analysis',
      );

      final result = response.trim().toLowerCase();
      if (result == 'clear') return null;

      // 映射AI返回的类型
      switch (result) {
        case 'novel_genre':
          return ProactiveQuestionType.novelGenre;
        case 'agent_select':
          return ProactiveQuestionType.agentSelection;
        case 'skill_select':
          return ProactiveQuestionType.skillSelection;
        case 'clarify':
          return ProactiveQuestionType.custom;
        default:
          return null;
      }
    } catch (_) {
      // AI调用失败，回退到简单匹配
      return _fallbackDetect(userInput);
    }
  }

  /// 回退的简单关键词检测
  ProactiveQuestionType? _fallbackDetect(String userInput) {
    final quickMatch = _quickDetect(userInput);
    switch (quickMatch) {
      case 'novel_genre':
        // 检查是否已经指定了类型
        const genres = ['玄幻', '都市', '言情', '历史', '科幻', '武侠', '灵异', '军事', '仙侠', '奇幻'];
        if (genres.any((g) => userInput.contains(g))) return null;
        return ProactiveQuestionType.novelGenre;
      case 'agent_select':
        return ProactiveQuestionType.agentSelection;
      case 'skill_select':
        return ProactiveQuestionType.skillSelection;
      case 'clarify':
        return ProactiveQuestionType.custom;
      default:
        return null;
    }
  }

  /// 使用AI生成个性化选项
  Future<ProactiveQuestion?> generateQuestion(
    String userInput,
    ProactiveQuestionType type, {
    AiConfig? config,
    String? userMemory,
    String? novelContext,
    List<WritingSkill>? availableSkills,
  }) async {
    // 如果有AI配置，使用AI生成个性化选项
    if (config != null) {
      try {
        return await _aiGenerateQuestion(
          userInput,
          type,
          config: config,
          userMemory: userMemory,
          novelContext: novelContext,
          availableSkills: availableSkills,
        );
      } catch (_) {
        // AI生成失败，回退到预设模板
      }
    }

    // 回退到预设模板
    return _fallbackGenerateQuestion(type, userMemory, availableSkills);
  }

  /// AI生成个性化问题
  Future<ProactiveQuestion?> _aiGenerateQuestion(
    String userInput,
    ProactiveQuestionType type, {
    required AiConfig config,
    String? userMemory,
    String? novelContext,
    List<WritingSkill>? availableSkills,
  }) async {
    final typeDescription = _getTypeDescription(type);

    final contextBuffer = StringBuffer();
    if (userMemory != null && userMemory.isNotEmpty) {
      contextBuffer.writeln('用户历史偏好：\n$userMemory');
    }
    if (novelContext != null && novelContext.isNotEmpty) {
      contextBuffer.writeln('当前小说上下文：\n$novelContext');
    }
    if (availableSkills != null && availableSkills.isNotEmpty) {
      final enabledSkills = availableSkills.where((s) => s.isEnabled).toList();
      if (enabledSkills.isNotEmpty) {
        contextBuffer.writeln('可用技能：${enabledSkills.map((s) => '${s.name}(${s.category})').join('、')}');
      }
    }

    final response = await _aiService.send(
      config: config,
      systemPrompt: '''你是一个智能交互设计助手。根据用户输入和上下文，生成个性化的选择选项。

要求：
1. 生成4-8个选项，每个选项包含id、label、description
2. 选项要基于用户历史偏好进行个性化排序（偏好的放前面）
3. 选项要结合当前小说上下文（如果有的话）
4. 最后一个选项应该是"其他"（allowCustomInput为true时）

严格按以下JSON格式返回，不要返回其他内容：
{
  "title": "问题标题",
  "subtitle": "副标题/提示",
  "options": [
    {"id": "opt1", "label": "选项名", "description": "简短描述"},
    {"id": "opt2", "label": "选项名", "description": "简短描述"}
  ],
  "allowCustomInput": true,
  "customInputPlaceholder": "自定义输入提示"
}''',
      userMessage: '用户输入："$userInput"\n问题类型：$typeDescription\n\n$contextBuffer',
      taskType: 'analysis',
    );

    return _parseAiQuestion(response, type);
  }

  /// 解析AI返回的JSON问题
  ProactiveQuestion? _parseAiQuestion(String response, ProactiveQuestionType type) {
    try {
      // 提取JSON（AI可能返回markdown代码块）
      String jsonStr = response.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceAll(RegExp(r'^```\w*\n?'), '').replaceAll(RegExp(r'\n?```$'), '');
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final options = (data['options'] as List).map((o) {
        final opt = o as Map<String, dynamic>;
        return ProactiveOption(
          id: opt['id'] as String? ?? 'opt_${opt['label']}',
          label: opt['label'] as String,
          description: opt['description'] as String?,
        );
      }).toList();

      return ProactiveQuestion(
        id: 'ai_generated_${type.name}',
        title: data['title'] as String? ?? '请选择',
        subtitle: data['subtitle'] as String?,
        type: type,
        options: options,
        allowCustomInput: data['allowCustomInput'] as bool? ?? true,
        customInputPlaceholder: data['customInputPlaceholder'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// 获取类型描述
  String _getTypeDescription(ProactiveQuestionType type) {
    switch (type) {
      case ProactiveQuestionType.novelGenre:
        return '小说类型选择 - 帮用户明确想写什么类型的小说';
      case ProactiveQuestionType.agentSelection:
        return '智能体选择 - 帮用户选择合适的AI工具/智能体';
      case ProactiveQuestionType.skillSelection:
        return '技能选择 - 帮用户选择合适的写作技能';
      case ProactiveQuestionType.outputFormat:
        return '输出格式选择 - 帮用户选择输出格式';
      case ProactiveQuestionType.custom:
        return '需求澄清 - 进一步了解用户的具体需求';
    }
  }

  /// 回退的预设模板生成
  ProactiveQuestion? _fallbackGenerateQuestion(
    ProactiveQuestionType type,
    String? userMemory,
    List<WritingSkill>? availableSkills,
  ) {
    switch (type) {
      case ProactiveQuestionType.novelGenre:
        return _generateGenreQuestion(userMemory);
      case ProactiveQuestionType.agentSelection:
        return ProactiveQuestion.agentSelectionQuestion;
      case ProactiveQuestionType.skillSelection:
        if (availableSkills != null && availableSkills.isNotEmpty) {
          return ProactiveQuestion.forSkills(
            availableSkills.where((s) => s.isEnabled).toList(),
          );
        }
        return null;
      case ProactiveQuestionType.outputFormat:
        return null;
      case ProactiveQuestionType.custom:
        return null;
    }
  }

  /// 生成小说类型选择问题（结合用户记忆）
  ProactiveQuestion _generateGenreQuestion(String? userMemory) {
    final preferredGenres = <String>[];
    if (userMemory != null) {
      const genreKeywords = {
        '玄幻': ['玄幻', '修仙', '仙侠'],
        '都市': ['都市', '现代'],
        '言情': ['言情', '恋爱', '爱情'],
        '历史': ['历史', '古代'],
        '科幻': ['科幻', '未来'],
      };
      for (final entry in genreKeywords.entries) {
        if (entry.value.any((k) => userMemory.contains(k))) {
          preferredGenres.add(entry.key);
        }
      }
    }

    final options = List<ProactiveOption>.from(ProactiveQuestion.novelGenreQuestion.options);
    if (preferredGenres.isNotEmpty) {
      options.sort((a, b) {
        final aP = preferredGenres.contains(a.label);
        final bP = preferredGenres.contains(b.label);
        if (aP && !bP) return -1;
        if (!aP && bP) return 1;
        return 0;
      });
    }

    return ProactiveQuestion(
      id: 'novel_genre',
      title: '选择小说类型',
      subtitle: preferredGenres.isNotEmpty
          ? '根据您的偏好，推荐：${preferredGenres.join('、')}'
          : '请选择您想写的小说类型',
      type: ProactiveQuestionType.novelGenre,
      options: options,
      allowCustomInput: true,
      customInputPlaceholder: '其他类型...',
    );
  }

  /// 检测是否需要触发Workspace Agent
  bool shouldTriggerWorkspaceAgent(String userInput) {
    const triggerPatterns = [
      '生成', '创建', '分析', '检查', '优化',
      '帮我', '自动', '一键',
    ];
    return triggerPatterns.any((p) => userInput.contains(p));
  }

  /// 从用户输入提取任务意图
  Map<String, dynamic> extractIntent(String userInput) {
    final intent = <String, dynamic>{};
    if (userInput.contains('大纲')) intent['task'] = 'generate_outline';
    else if (userInput.contains('角色')) intent['task'] = 'generate_character';
    else if (userInput.contains('标题')) intent['task'] = 'generate_title';
    else if (userInput.contains('检查') || userInput.contains('分析')) intent['task'] = 'analyze';
    else if (userInput.contains('优化') || userInput.contains('改进')) intent['task'] = 'optimize';

    if (userInput.contains('章节')) intent['target'] = 'chapter';
    else if (userInput.contains('小说') || userInput.contains('作品')) intent['target'] = 'novel';
    else if (userInput.contains('角色') || userInput.contains('人物')) intent['target'] = 'character';

    return intent;
  }
}
