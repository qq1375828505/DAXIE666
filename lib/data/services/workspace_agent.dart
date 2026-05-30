import 'dart:convert';
import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/data/services/ai_service.dart' show AiService;

/// Agent工具定义
class AgentTool {
  final String name;
  final String description;
  final Map<String, String> parameters;
  final String category; // 工具分类，用于按需加载

  const AgentTool({
    required this.name,
    required this.description,
    this.parameters = const {},
    this.category = 'general',
  });

  Map<String, dynamic> toOpenAiFormat() {
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': {
          'type': 'object',
          'properties': parameters,
          'required': parameters.keys.toList(),
        },
      },
    };
  }
}

/// Agent工具执行结果
class ToolResult {
  final String toolName;
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  const ToolResult({
    required this.toolName,
    required this.success,
    required this.message,
    this.data,
  });
}

/// Agent工具执行器接口
typedef ToolExecutor = Future<ToolResult> Function(Map<String, dynamic> args);

/// 工具分类常量
class ToolCategories {
  static const String read = 'read';           // 读取类
  static const String write = 'write';          // 写入类
  static const String edit = 'edit';            // 编辑类
  static const String analyze = 'analyze';      // 分析类
  static const String agent = 'agent';          // 子代理
  static const String skill = 'skill';          // 技能
  static const String config = 'config';        // 配置管理
  static const String project = 'project';      // 项目管理
  static const String editor = 'editor';        // 编辑器
}

/// Workspace Agent - AI IDE 核心协调层
/// 架构：主对话轻量 → 按需加载工具 → 独立执行 → 结果回传
class WorkspaceAgent {
  final AiService _aiService = AiService();

  /// 所有可用工具（按分类组织）
  static final List<AgentTool> tools = [
    // ====== 读取类工具 ======
    AgentTool(name: 'get_novel_info', description: '获取当前小说的基本信息', category: ToolCategories.read),
    AgentTool(name: 'get_characters', description: '获取小说的所有角色列表', category: ToolCategories.read),
    AgentTool(name: 'get_settings', description: '获取小说的所有设定卡', category: ToolCategories.read),
    AgentTool(name: 'get_locations', description: '获取小说的所有地点', category: ToolCategories.read),
    AgentTool(name: 'get_factions', description: '获取小说的所有势力/组织', category: ToolCategories.read),
    AgentTool(name: 'get_items', description: '获取小说的所有道具/物品', category: ToolCategories.read),
    AgentTool(name: 'get_hooks', description: '获取小说的所有伏笔', category: ToolCategories.read),
    AgentTool(name: 'get_references', description: '获取小说的所有参考资料', category: ToolCategories.read),
    AgentTool(name: 'get_chapters', description: '获取小说的章节列表', category: ToolCategories.read),
    AgentTool(name: 'get_chapter_content', description: '获取指定章节的内容', parameters: {'chapter_title': '章节标题'}, category: ToolCategories.read),
    AgentTool(name: 'get_memory', description: '获取小说的记忆包内容', category: ToolCategories.read),

    // ====== 写入类工具 ======
    AgentTool(name: 'add_character', description: '添加新角色到资料库', parameters: {'name': '角色名称', 'role': '角色定位', 'description': '角色描述'}, category: ToolCategories.write),
    AgentTool(name: 'add_setting', description: '添加新设定到资料库', parameters: {'name': '设定名称', 'category': '分类', 'description': '设定描述'}, category: ToolCategories.write),
    AgentTool(name: 'add_location', description: '添加新地点到资料库', parameters: {'name': '地点名称', 'category': '分类', 'description': '地点描述'}, category: ToolCategories.write),
    AgentTool(name: 'add_faction', description: '添加新势力到资料库', parameters: {'name': '势力名称', 'category': '分类', 'description': '势力描述', 'leader': '首领名称（可选）'}, category: ToolCategories.write),
    AgentTool(name: 'add_item', description: '添加新道具到资料库', parameters: {'name': '道具名称', 'category': '分类', 'description': '道具描述'}, category: ToolCategories.write),
    AgentTool(name: 'add_hook', description: '添加新伏笔', parameters: {'title': '伏笔标题', 'description': '伏笔描述'}, category: ToolCategories.write),
    AgentTool(name: 'add_reference', description: '添加参考资料', parameters: {'title': '参考标题', 'content': '参考内容'}, category: ToolCategories.write),

    // ====== 编辑类工具 ======
    AgentTool(name: 'update_character', description: '更新已有角色信息', parameters: {'name': '角色名称', 'role': '新定位（可选）', 'description': '新描述（可选）', 'personality': '性格特征（可选）', 'appearance': '外貌描述（可选）', 'background': '背景故事（可选）'}, category: ToolCategories.edit),
    AgentTool(name: 'update_hook_status', description: '更新伏笔状态', parameters: {'title': '伏笔标题', 'status': 'planted/resolved/idle'}, category: ToolCategories.edit),
    AgentTool(name: 'update_setting', description: '更新已有设定信息', parameters: {'name': '设定名称', 'category': '新分类（可选）', 'description': '新描述（可选）'}, category: ToolCategories.edit),
    AgentTool(name: 'update_location', description: '更新已有地点信息', parameters: {'name': '地点名称', 'category': '新分类（可选）', 'description': '新描述（可选）', 'features': '地理特征（可选）', 'rules': '特殊规则（可选）'}, category: ToolCategories.edit),
    AgentTool(name: 'update_faction', description: '更新已有势力信息', parameters: {'name': '势力名称', 'category': '新分类（可选）', 'description': '新描述（可选）', 'leader': '新首领（可选）', 'strength': '新战力（可选）'}, category: ToolCategories.edit),
    AgentTool(name: 'update_item', description: '更新已有道具信息', parameters: {'name': '道具名称', 'category': '新分类（可选）', 'description': '新描述（可选）', 'powerLevel': '新品阶（可选）', 'owner': '新持有者（可选）', 'isKeyItem': '是否关键道具（可选）'}, category: ToolCategories.edit),
    AgentTool(name: 'update_reference', description: '更新已有参考资料', parameters: {'title': '参考标题', 'content': '新内容（可选）', 'source': '新来源（可选）', 'sourceUrl': '新来源URL（可选）'}, category: ToolCategories.edit),
    AgentTool(name: 'delete_character', description: '删除指定角色', parameters: {'name': '角色名称'}, category: ToolCategories.edit),
    AgentTool(name: 'delete_setting', description: '删除指定设定', parameters: {'name': '设定名称'}, category: ToolCategories.edit),
    AgentTool(name: 'delete_location', description: '删除指定地点', parameters: {'name': '地点名称'}, category: ToolCategories.edit),
    AgentTool(name: 'delete_faction', description: '删除指定势力', parameters: {'name': '势力名称'}, category: ToolCategories.edit),
    AgentTool(name: 'delete_item', description: '删除指定道具', parameters: {'name': '道具名称'}, category: ToolCategories.edit),
    AgentTool(name: 'delete_hook', description: '删除指定伏笔', parameters: {'title': '伏笔标题'}, category: ToolCategories.edit),
    AgentTool(name: 'delete_reference', description: '删除指定参考资料', parameters: {'title': '参考标题'}, category: ToolCategories.edit),

    // ====== 分析类工具 ======
    AgentTool(name: 'analyze_plot_consistency', description: '分析剧情一致性', category: ToolCategories.analyze),
    AgentTool(name: 'check_idle_hooks', description: '检查闲置伏笔', category: ToolCategories.analyze),
    AgentTool(name: 'generate_chapter_outline', description: '生成下一章大纲', parameters: {'direction': '写作方向（可选）'}, category: ToolCategories.analyze),
    AgentTool(name: 'character_relationship_map', description: '分析角色关系图谱', category: ToolCategories.analyze),

    // ====== 子代理工具 ======
    AgentTool(name: 'delegate_to_sub_agent', description: '委派任务给子代理', parameters: {'task_type': 'outline_editor/continuity_checker/character_analyst/pacing_advisor', 'instruction': '具体指令'}, category: ToolCategories.agent),
    AgentTool(name: 'run_workflow', description: '触发自动化工作流', parameters: {'workflow_name': 'post_chapter_check/full_review/outline_refresh'}, category: ToolCategories.agent),

    // ====== Skill工具 ======
    AgentTool(name: 'get_skills', description: '获取所有已启用的Skill', category: ToolCategories.skill),
    AgentTool(name: 'add_skill', description: '添加自定义Skill', parameters: {'name': '名称', 'category': '分类', 'description': '描述', 'content': '内容'}, category: ToolCategories.skill),

    // ====== 文本处理工具 ======
    AgentTool(
      name: 'humanize_text',
      description: '''去AI味：将AI生成的文本改写为自然人类风格。核心规则：
1. 删除过度强调词：stands as, is a testament, crucial/pivotal/key role, underscores, highlights its significance, reflects broader, symbolizing, contributing to, setting the stage for, marking a shift, focal point, indelible mark, deeply rooted
2. 删除空洞评价：This is important, It is worth noting, It goes without saying, In today's world, At the end of the day
3. 删除AI典型三项排比：把"A, B, and C"结构改为更自然的表达
4. 减少破折号滥用：用逗号或句号替代不必要的em-dash
5. 删除虚假归因：研究表明/专家认为/有人说是（无具体来源时删除）
6. 打破句子同质化：混合长短句，加入个人视角和口语化表达
7. 注入个性和情感：加入主观评价、幽默、不确定感，而非中性报道
8. 保留核心含义，保持原文语气风格''',
      parameters: {'text': '需要去AI味的文本内容'},
      category: ToolCategories.analyze,
    ),

    // ====== 系统配置工具 ======
    AgentTool(name: 'get_ai_configs', description: '获取所有AI模型配置', category: ToolCategories.config),
    AgentTool(name: 'add_ai_config', description: '添加AI模型配置', parameters: {'name': '名称', 'api_url': 'API地址', 'model_name': '模型ID', 'model_type': 'text/tts/stt', 'api_key': 'API Key'}, category: ToolCategories.config),
    AgentTool(name: 'set_active_ai_config', description: '设置当前使用的AI模型', parameters: {'config_id': '配置ID', 'purpose': 'text/voice'}, category: ToolCategories.config),

    // ====== 项目管理工具 ======
    AgentTool(name: 'list_novels', description: '获取小说项目列表', category: ToolCategories.project),
    AgentTool(name: 'create_novel', description: '创建新小说项目', parameters: {'title': '标题', 'genre': '类型', 'description': '简介'}, category: ToolCategories.project),
    AgentTool(name: 'switch_novel', description: '切换当前小说项目', parameters: {'novel_id': '小说ID'}, category: ToolCategories.project),

    // ====== 编辑器工具 ======
    AgentTool(name: 'write_chapter_content', description: '写入章节内容', parameters: {'chapter_id': '章节ID', 'content': '正文内容'}, category: ToolCategories.editor),
    AgentTool(name: 'create_chapter', description: '创建新章节', parameters: {'volume_id': '卷ID', 'title': '章节标题', 'content': '正文（可选）'}, category: ToolCategories.editor),
  ];

  /// 工具执行器映射
  final Map<String, ToolExecutor> _executors = {};

  /// 注册工具执行器
  void registerExecutor(String toolName, ToolExecutor executor) {
    _executors[toolName] = executor;
  }

  /// 获取工具执行器
  ToolExecutor? getExecutor(String toolName) => _executors[toolName];

  /// 获取已注册工具的分类列表
  Set<String> get registeredCategories {
    final cats = <String>{};
    for (final name in _executors.keys) {
      final tool = tools.where((t) => t.name == name).firstOrNull;
      if (tool != null) cats.add(tool.category);
    }
    return cats;
  }

  // ========== 核心架构：轻量主对话 + 按需工具调度 ==========

  /// 发送Agent请求（轻量架构）
  ///
  /// 架构流程：
  /// 1. 主对话请求（轻量，只传对话历史 + 工具摘要列表，不传完整工具定义）
  /// 2. AI返回工具调用意图
  /// 3. 独立执行工具（不占用对话payload）
  /// 4. 将工具结果摘要回传对话
  /// 5. AI根据结果生成最终回复
  Future<AgentResponse> chat({
    required AiConfig config,
    required List<Map<String, String>> messages,
    String? systemPrompt,
    int maxToolRounds = 5,
  }) async {
    final effectiveSystemPrompt = systemPrompt ?? _defaultSystemPrompt;

    // 构建轻量消息列表
    List<Map<String, dynamic>> apiMessages = [
      {'role': 'system', 'content': effectiveSystemPrompt},
      ...messages.map((m) => {'role': m['role'], 'content': m['content']}).toList(),
    ];

    final toolCalls = <String, String>{};
    final toolResults = <ToolResult>[];

    for (int round = 0; round < maxToolRounds; round++) {
      // 只传已注册工具的定义（按需，不是全部）
      final availableTools = _getRegisteredTools();

      final response = await _aiService.chatWithTools(
        config: config,
        messages: apiMessages,
        tools: availableTools.isNotEmpty ? availableTools : null,
      );

      // 检查是否有工具调用
      if (response.toolCalls != null && response.toolCalls!.isNotEmpty) {
        // 添加助手消息（含tool_calls）
        apiMessages.add({
          'role': 'assistant',
          'content': response.content,
          'tool_calls': response.toolCalls!.map((tc) => {
            'id': tc.id,
            'type': 'function',
            'function': {
              'name': tc.functionName,
              'arguments': tc.arguments is String ? tc.arguments : jsonEncode(tc.arguments),
            },
          }).toList(),
        });

        // 独立执行每个工具（不占用对话payload）
        for (final tc in response.toolCalls!) {
          toolCalls[tc.functionName] = tc.arguments is String ? tc.arguments : jsonEncode(tc.arguments);
          final executor = _executors[tc.functionName];
          if (executor != null) {
            try {
              final args = tc.arguments is String
                  ? jsonDecode(tc.arguments as String)
                  : (tc.arguments as Map<String, dynamic>? ?? {});
              final result = await executor(args);
              toolResults.add(result);

              // 工具结果摘要回传（截断过长内容，避免payload膨胀）
              apiMessages.add({
                'role': 'tool',
                'tool_call_id': tc.id,
                'content': _summarizeToolResult(result),
              });
            } catch (e) {
              toolResults.add(ToolResult(
                toolName: tc.functionName,
                success: false,
                message: '执行失败: $e',
              ));
              apiMessages.add({
                'role': 'tool',
                'tool_call_id': tc.id,
                'content': '执行失败: $e',
              });
            }
          } else {
            // 关键修复：工具不存在时也必须返回tool消息，否则API 400崩溃
            apiMessages.add({
              'role': 'tool',
              'tool_call_id': tc.id,
              'content': '工具 ${tc.functionName} 不存在，请不要调用此工具。',
            });
          }
        }
      } else {
        // 没有工具调用，返回最终回复
        return AgentResponse(
          content: response.content ?? '',
          toolCalls: toolCalls,
          toolResults: toolResults,
        );
      }
    }

    // 达到最大轮次
    return AgentResponse(
      content: '已达到最大工具调用轮次（$maxToolRounds轮），请简化你的需求。',
      toolCalls: toolCalls,
      toolResults: toolResults,
    );
  }

  /// 获取已注册工具的OpenAI格式定义（只传已注册的，不是全部）
  List<Map<String, dynamic>> _getRegisteredTools() {
    return tools
        .where((t) => _executors.containsKey(t.name))
        .map((t) => t.toOpenAiFormat())
        .toList();
  }

  /// 工具结果摘要（截断过长内容，避免payload膨胀）
  String _summarizeToolResult(ToolResult result) {
    final content = result.message;
    if (content.length <= 500) return content;
    // 超过500字时截断，保留开头和结尾
    return '${content.substring(0, 300)}\n...（省略${content.length - 500}字）...\n${content.substring(content.length - 200)}';
  }

  /// 轻量模式：只发对话，不传工具定义
  /// 用于普通闲聊场景，完全不占用工具payload
  Future<String> chatLite({
    required AiConfig config,
    required List<Map<String, String>> messages,
    String? systemPrompt,
  }) async {
    final effectiveSystemPrompt = systemPrompt ?? _defaultSystemPrompt;

    final conversationText = messages.map((m) => '${m["role"]}: ${m["content"]}').join('\n\n');

    return await _aiService.send(
      config: config,
      systemPrompt: effectiveSystemPrompt,
      userMessage: conversationText,
      taskType: 'chat',
    );
  }

  static const String _defaultSystemPrompt = '''你是一个全能AI写作助手（Workspace Agent），是网文AI IDE的核心。

你的能力：
1. 读取小说的全部数据（角色、设定、地点、伏笔、章节、记忆包）
2. 操作资料库（添加角色、设定、地点、伏笔）
3. 分析章节内容，给出写作建议
4. 检查伏笔状态，提醒闲置伏笔
5. 帮助构思剧情、生成大纲
6. 管理AI模型配置
7. 创建和管理小说项目
8. 直接编辑和创建章节内容

工作原则：
- 主动分析小说状态，发现潜在问题
- 需要操作时直接调用工具，不要让用户手动操作
- 给出具体可操作的建议
- 保持创作连贯性，参考已有设定
- 用中文回复，语气友好专业''';
}

/// Agent响应结果
class AgentResponse {
  final String content;
  final Map<String, String> toolCalls;
  final List<ToolResult> toolResults;

  const AgentResponse({
    required this.content,
    this.toolCalls = const {},
    this.toolResults = const [],
  });
}
