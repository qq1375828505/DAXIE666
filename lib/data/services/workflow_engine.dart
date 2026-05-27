import 'dart:convert';

/// Workflow步骤定义
class WorkflowStep {
  final String id;
  final String name;
  final String description;
  final String toolName; // 要调用的Agent工具名
  final Map<String, String> toolArgs; // 工具参数（支持变量替换）
  final bool waitForUser; // 是否需要用户确认

  const WorkflowStep({
    required this.id,
    required this.name,
    required this.description,
    required this.toolName,
    this.toolArgs = const {},
    this.waitForUser = false,
  });
}

/// Workflow定义
class Workflow {
  final String id;
  final String name;
  final String description;
  final String icon;
  final List<WorkflowStep> steps;

  const Workflow({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.steps,
  });
}

/// Workflow执行结果
class WorkflowResult {
  final String workflowId;
  final String workflowName;
  final bool success;
  final List<StepResult> stepResults;
  final String? errorMessage;

  const WorkflowResult({
    required this.workflowId,
    required this.workflowName,
    required this.success,
    required this.stepResults,
    this.errorMessage,
  });
}

class StepResult {
  final String stepId;
  final String stepName;
  final bool success;
  final String message;
  final Duration duration;

  const StepResult({
    required this.stepId,
    required this.stepName,
    required this.success,
    required this.message,
    required this.duration,
  });
}

/// Workflow执行进度回调
typedef WorkflowProgressCallback = void Function(int current, int total, String stepName);

/// 预定义工作流
class WorkflowPresets {
  /// 章节检查：写完一章后自动检查
  static const postChapterCheck = Workflow(
    id: 'post_chapter_check',
    name: '章节检查',
    description: '写完章节后自动检查伏笔、角色一致性、更新记忆包',
    icon: '📝',
    steps: [
      WorkflowStep(
        id: 'check_hooks',
        name: '检查伏笔状态',
        description: '查看是否有闲置伏笔需要处理',
        toolName: 'check_idle_hooks',
      ),
      WorkflowStep(
        id: 'analyze_consistency',
        name: '剧情一致性分析',
        description: '检查设定矛盾和角色行为不一致',
        toolName: 'analyze_plot_consistency',
      ),
      WorkflowStep(
        id: 'update_memory',
        name: '更新记忆包',
        description: '将最新章节内容同步到记忆包',
        toolName: 'get_memory',
      ),
    ],
  );

  /// 全文审查：全面检查整部小说
  static const fullReview = Workflow(
    id: 'full_review',
    name: '全文审查',
    description: '全面审查小说的伏笔、角色、设定、节奏',
    icon: '🔍',
    steps: [
      WorkflowStep(
        id: 'get_info',
        name: '获取小说概览',
        description: '了解小说基本信息',
        toolName: 'get_novel_info',
      ),
      WorkflowStep(
        id: 'get_characters',
        name: '审查角色',
        description: '检查角色设定和关系',
        toolName: 'get_characters',
      ),
      WorkflowStep(
        id: 'check_hooks',
        name: '审查伏笔',
        description: '检查伏笔埋设和回收情况',
        toolName: 'check_idle_hooks',
      ),
      WorkflowStep(
        id: 'get_settings',
        name: '审查设定',
        description: '检查世界观和设定一致性',
        toolName: 'get_settings',
      ),
      WorkflowStep(
        id: 'analyze_consistency',
        name: '综合分析',
        description: 'AI综合分析所有数据，给出审查报告',
        toolName: 'analyze_plot_consistency',
      ),
    ],
  );

  /// 大纲刷新：根据最新内容刷新大纲
  static const outlineRefresh = Workflow(
    id: 'outline_refresh',
    name: '大纲刷新',
    description: '根据最新章节内容，重新生成或更新大纲',
    icon: '📋',
    steps: [
      WorkflowStep(
        id: 'get_chapters',
        name: '获取章节列表',
        description: '了解当前章节进度',
        toolName: 'get_chapters',
      ),
      WorkflowStep(
        id: 'get_hooks',
        name: '获取伏笔状态',
        description: '了解伏笔进度',
        toolName: 'get_hooks',
      ),
      WorkflowStep(
        id: 'gen_outline',
        name: '生成大纲',
        description: 'AI根据最新内容生成大纲',
        toolName: 'generate_chapter_outline',
      ),
    ],
  );

  /// 角色审查：专门检查角色相关
  static const characterReview = Workflow(
    id: 'character_review',
    name: '角色审查',
    description: '检查角色设定、关系、行为一致性',
    icon: '👤',
    steps: [
      WorkflowStep(
        id: 'get_characters',
        name: '获取角色列表',
        description: '查看所有角色信息',
        toolName: 'get_characters',
      ),
      WorkflowStep(
        id: 'relationship_map',
        name: '分析角色关系',
        description: 'AI分析角色之间的关系图谱',
        toolName: 'character_relationship_map',
      ),
    ],
  );

  /// 获取所有预定义工作流
  static const List<Workflow> all = [
    postChapterCheck,
    fullReview,
    outlineRefresh,
    characterReview,
  ];
}
