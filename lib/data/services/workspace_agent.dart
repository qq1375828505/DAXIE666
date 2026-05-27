import 'dart:convert';
import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/data/services/ai_service.dart' show AiService, ToolCallInfo;

/// Agent工具定义
class AgentTool {
  final String name;
  final String description;
  final Map<String, String> parameters;

  const AgentTool({
    required this.name,
    required this.description,
    this.parameters = const {},
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

/// Workspace Agent - 全能AI助手
/// 支持function calling，能操作资料库、编辑章节等
class WorkspaceAgent {
  final AiService _aiService = AiService();

  /// 所有可用工具
  static final List<AgentTool> tools = [
    // ====== 读取类工具 ======
    AgentTool(
      name: 'get_novel_info',
      description: '获取当前小说的基本信息，包括标题、简介、章节数等',
    ),
    AgentTool(
      name: 'get_characters',
      description: '获取小说的所有角色列表，包括名称、定位、描述',
    ),
    AgentTool(
      name: 'get_settings',
      description: '获取小说的所有设定卡，包括世界观、战力体系等',
    ),
    AgentTool(
      name: 'get_locations',
      description: '获取小说的所有地点',
    ),
    AgentTool(
      name: 'get_factions',
      description: '获取小说的所有势力/组织',
    ),
    AgentTool(
      name: 'get_items',
      description: '获取小说的所有道具/物品',
    ),
    AgentTool(
      name: 'get_hooks',
      description: '获取小说的所有伏笔，包括状态（已埋/已收/闲置）',
    ),
    AgentTool(
      name: 'get_references',
      description: '获取小说的所有参考资料',
    ),
    AgentTool(
      name: 'get_chapters',
      description: '获取小说的章节列表，包括标题和字数',
    ),
    AgentTool(
      name: 'get_chapter_content',
      description: '获取指定章节的内容',
      parameters: {
        'chapter_title': '章节标题',
      },
    ),
    AgentTool(
      name: 'get_memory',
      description: '获取小说的记忆包内容（AI自动生成的小说状态摘要）',
    ),

    // ====== 写入类工具 ======
    AgentTool(
      name: 'add_character',
      description: '添加一个新角色到资料库',
      parameters: {
        'name': '角色名称',
        'role': '角色定位（如：主角/反派/配角）',
        'description': '角色描述（外貌、性格、背景等）',
      },
    ),
    AgentTool(
      name: 'add_setting',
      description: '添加一个新设定到资料库',
      parameters: {
        'name': '设定名称',
        'category': '分类（如：世界观/战力/势力）',
        'description': '设定描述',
      },
    ),
    AgentTool(
      name: 'add_location',
      description: '添加一个新地点到资料库',
      parameters: {
        'name': '地点名称',
        'category': '分类（如：宗门/城市/秘境）',
        'description': '地点描述',
      },
    ),
    AgentTool(
      name: 'add_faction',
      description: '添加一个新势力/组织到资料库',
      parameters: {
        'name': '势力名称',
        'category': '分类（如：正道/魔道/中立）',
        'description': '势力描述',
        'leader': '首领名称（可选）',
      },
    ),
    AgentTool(
      name: 'add_item',
      description: '添加一个新道具/物品到资料库',
      parameters: {
        'name': '道具名称',
        'category': '分类（如：武器/丹药/法宝）',
        'description': '道具描述',
      },
    ),
    AgentTool(
      name: 'add_hook',
      description: '添加一个新伏笔',
      parameters: {
        'title': '伏笔标题',
        'description': '伏笔描述',
      },
    ),
    AgentTool(
      name: 'add_reference',
      description: '添加一条参考资料',
      parameters: {
        'title': '参考标题',
        'content': '参考内容',
      },
    ),

    // ====== 编辑类工具 ======
    AgentTool(
      name: 'update_character',
      description: '更新已有角色的信息',
      parameters: {
        'name': '要更新的角色名称',
        'role': '新的角色定位（可选）',
        'description': '新的角色描述（可选）',
      },
    ),
    AgentTool(
      name: 'update_hook_status',
      description: '更新伏笔状态',
      parameters: {
        'title': '伏笔标题',
        'status': '新状态：planted（已埋）/ resolved（已收）/ idle（闲置）',
      },
    ),

    // ====== 分析类工具 ======
    AgentTool(
      name: 'analyze_plot_consistency',
      description: '分析当前小说的剧情一致性，检查设定矛盾、角色行为不一致等问题',
    ),
    AgentTool(
      name: 'check_idle_hooks',
      description: '检查闲置伏笔（已埋但超过3章未回收的伏笔）',
    ),
    AgentTool(
      name: 'generate_chapter_outline',
      description: '根据当前剧情和设定，生成下一章的写作大纲',
      parameters: {
        'direction': '写作方向或要求（可选）',
      },
    ),
    AgentTool(
      name: 'character_relationship_map',
      description: '分析并输出当前所有角色之间的关系图谱',
    ),

    // ====== 子代理工具 ======
    AgentTool(
      name: 'delegate_to_sub_agent',
      description: '将复杂任务委派给子代理执行。子代理是专门处理特定任务的AI助手，可以独立思考和调用工具。',
      parameters: {
        'task_type': '子代理类型：outline_editor（大纲编辑）/ continuity_checker（连续性检查）/ character_analyst（角色分析师）/ pacing_advisor（节奏顾问）',
        'instruction': '给子代理的具体指令',
      },
    ),
    AgentTool(
      name: 'run_workflow',
      description: '触发一个预定义的自动化工作流',
      parameters: {
        'workflow_name': '工作流名称：post_chapter_check（章节检查）/ full_review（全文审查）/ outline_refresh（大纲刷新）',
      },
    ),

    // ====== Skill工具 ======
    AgentTool(
      name: 'get_skills',
      description: '获取所有已启用的写作技能，包括内置和自定义技能',
    ),
    AgentTool(
      name: 'add_skill',
      description: '添加一个自定义写作技能',
      parameters: {
        'name': '技能名称',
        'category': '分类（如：剧情技巧/文笔技巧/角色技巧）',
        'description': '技能描述',
        'content': '技能详细内容',
      },
    ),
  ];

  /// 工具执行器映射
  final Map<String, ToolExecutor> _executors = {};

  /// 注册工具执行器
  void registerExecutor(String toolName, ToolExecutor executor) {
    _executors[toolName] = executor;
  }

  /// 获取工具执行器
  ToolExecutor? getExecutor(String toolName) => _executors[toolName];

  /// 发送Agent请求（带function calling）
  Future<AgentResponse> chat({
    required AiConfig config,
    required List<Map<String, String>> messages,
    String? systemPrompt,
    int maxToolRounds = 5,
  }) async {
    final effectiveSystemPrompt = systemPrompt ?? _defaultSystemPrompt;

    List<Map<String, dynamic>> apiMessages = [
      {'role': 'system', 'content': effectiveSystemPrompt},
      ...messages.map((m) => {'role': m['role'], 'content': m['content']}).toList(),
    ];

    final toolCalls = <String, String>{};
    final toolResults = <ToolResult>[];

    for (int round = 0; round < maxToolRounds; round++) {
      // 构建请求
      final availableTools = _executors.isNotEmpty
          ? tools.where((t) => _executors.containsKey(t.name)).toList()
          : <AgentTool>[];

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

        // 执行每个工具
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

              // 添加工具结果
              apiMessages.add({
                'role': 'tool',
                'tool_call_id': tc.id,
                'content': result.message,
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

  static const String _defaultSystemPrompt = '''你是一个全能AI写作助手（Workspace Agent），深度参与小说创作。

你的能力：
1. 读取小说的全部数据（角色、设定、地点、伏笔、章节、记忆包）
2. 操作资料库（添加角色、设定、地点、伏笔）
3. 分析章节内容，给出写作建议
4. 检查伏笔状态，提醒闲置伏笔
5. 帮助构思剧情、生成大纲

工作原则：
- 主动分析小说状态，发现潜在问题
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
