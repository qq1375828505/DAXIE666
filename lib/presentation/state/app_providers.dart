import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/data/models/novel_model.dart';
import 'package:novel_ide/data/models/chapter_model.dart';
import 'package:novel_ide/data/models/volume_model.dart';
import 'package:novel_ide/data/models/tomato_preset_model.dart';
import 'package:novel_ide/data/models/tomato_agent_model.dart';
import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/data/models/material_models.dart';
import 'package:novel_ide/data/presets/tomato_presets_data.dart';
import 'package:novel_ide/data/repositories/novel_repository.dart';
import 'package:novel_ide/data/repositories/chapter_repository.dart';
import 'package:novel_ide/data/repositories/volume_repository.dart';
import 'package:novel_ide/data/repositories/material_repository.dart';
import 'package:novel_ide/data/repositories/stats_repository.dart';
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/services/config_service.dart';

final novelRepoProvider = Provider((ref) => NovelRepository());
final chapterRepoProvider = Provider((ref) => ChapterRepository());
final volumeRepoProvider = Provider((ref) => VolumeRepository());
final materialRepoProvider = Provider((ref) => MaterialRepository());

final novelsProvider = FutureProvider<List<Novel>>((ref) async {
  return await ref.read(novelRepoProvider).getAllNovels();
});
final selectedNovelProvider = StateProvider<Novel?>((ref) => null);

final chaptersProvider = FutureProvider.family<List<Chapter>, String>((ref, novelId) async {
  return await ref.read(chapterRepoProvider).getChaptersByNovel(novelId);
});
final selectedChapterProvider = StateProvider<Chapter?>((ref) => null);

final volumesProvider = FutureProvider.family<List<Volume>, String>((ref, novelId) async {
  return await ref.read(volumeRepoProvider).getVolumesByNovel(novelId);
});

final editorContentProvider = StateProvider<String>((ref) => '');
final saveStatusProvider = StateProvider<String>((ref) => '已保存');
final wordCountProvider = StateProvider<int>((ref) => 0);

// Tomato Presets - 25 full presets
final tomatoPresetsProvider = StateProvider<List<TomatoPreset>>((ref) => allTomatoPresets());
final currentPresetProvider = StateProvider<TomatoPreset?>((ref) => null);

// Tomato Agents
final tomatoAgentsProvider = StateProvider<List<TomatoAgent>>((ref) => [
  TomatoAgent(
    id: 'outline_generator',
    name: '番茄大纲生成器',
    icon: '\u{1F4CB}',
    description: '根据当前章节生成黄金三章大纲、分卷大纲和章节概略',
    systemPrompt: '你是番茄小说专属大纲生成器。根据用户提供的信息生成：\n'
        '1. 黄金三章结构：开篇钩子→冲突升级→世界观暗示\n'
        '2. 爽点分布：每章标注3-4个爽点位置\n'
        '3. 反转节点：标注关键反转位置\n'
        '4. 分卷建议：基于当前内容推荐分卷节点',
    parameterPrompts: ['请提供主角设定', '请提供故事背景', '请提供目标字数'],
  ),
  TomatoAgent(
    id: 'character_generator',
    name: '番茄角色生成器',
    icon: '\u{1F9D1}',
    description: '自动生成符合番茄风格的角色卡，包括主角、配角、反派',
    systemPrompt: '你是番茄小说专属角色生成器。生成的角色必须满足：\n'
        '1. 主角：有隐藏身份/能力，初始被低估\n'
        '2. 反派：分层次设计（小反派→中Boss→最终Boss）\n'
        '3. 感情线角色：有反转空间\n'
        '4. 每个角色附带：姓名、年龄、外貌、性格、背景、爽点相关设定',
    parameterPrompts: ['请提供故事类型', '请提供主角性别', '请提供特殊要求'],
  ),
  TomatoAgent(
    id: 'shuangdian_checker',
    name: '爽点密度检查器',
    icon: '\u{26A1}',
    description: '分析章节爽点密度、类型分布，给出评分和优化建议',
    systemPrompt: '你是番茄小说爽点密度检查器。分析规则：\n'
        '1. 爽点分类：身份揭露、打脸、实力碾压、财富展示、情感反转、系统奖励\n'
        '2. 密度标准：每3000字至少2-3个爽点\n'
        '3. 评分标准：0-10分，<6分建议重写，6-7分及格，8-9分优秀，10分爆款\n'
        '4. 输出格式：评分数+爽点列表(位置/类型/强度)+优化建议',
    parameterPrompts: ['请粘贴章节内容'],
  ),
  TomatoAgent(
    id: 'water_detector',
    name: '水文检测器',
    icon: '\u{1F4A7}',
    description: '检测水文段落，标记冗余描写、废话对话、无意义场景',
    systemPrompt: '你是番茄小说水文检测器。检测规则：\n'
        '1. 水文分类：废话对话、冗余环境描写、无推进日常、重复说明、废话心理描写\n'
        '2. 水文率：<15%优秀，15-25%及格，>25%需要精简\n'
        '3. 标记格式：位置(行号/百分比)+类型+字数+精简建议\n'
        '4. 输出格式：水文率+水文段落列表+优化方案',
    parameterPrompts: ['请粘贴章节内容'],
  ),
  TomatoAgent(
    id: 'title_generator',
    name: '爆款标题生成器',
    icon: '\u{1F4DD}',
    description: '生成10个番茄风格的爆款标题，含分析说明',
    systemPrompt: '你是番茄小说爆款标题生成器。标题要求：\n'
        '1. 长度：8-15字，适合移动端显示\n'
        '2. 风格：悬念式、爽点式、反转式、身份揭露式、数字式\n'
        '3. 每个标题附带：吸引点击的理由（1句话）\n'
        '4. 生成10个标题，按点击率预估排序\n'
        '5. 目标读者：18-35岁，男女通吃',
    parameterPrompts: ['请提供章节内容摘要', '请提供故事类型'],
  ),
]);

// Materials
final charactersProvider = StateProvider.family<List<Character>, String>((ref, novelId) => []);
final settingCardsProvider = StateProvider.family<List<SettingCard>, String>((ref, novelId) => []);
final plotHooksProvider = StateProvider.family<List<PlotHook>, String>((ref, novelId) => []);
final referencesProvider = StateProvider.family<List<ReferenceMaterial>, String>((ref, novelId) => []);
final settingRemindersProvider = StateProvider.family<List<SettingReminder>, String>((ref, novelId) => []);

// AI Config
final aiConfigsProvider = StateProvider<List<AiConfig>>((ref) => []);
final selectedAiConfigProvider = StateProvider<AiConfig?>((ref) => null);

// Network status
final isOnlineProvider = StateProvider<bool>((ref) => true);

// Notifications
final wordGoalProvider = StateProvider<int>((ref) => 3000);
final streakDaysProvider = StateProvider<int>((ref) => 0);

// Navigation
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

// Dark Mode - persistent via Hive
final darkModeProvider = StateProvider<bool>((ref) => false);

// Font settings
final fontSizeProvider = StateProvider<double>((ref) => 18);
final fontFamilyProvider = StateProvider<String>((ref) => 'NotoSerifSC');
final lineHeightProvider = StateProvider<double>((ref) => 1.8);

// Category filter for presets
final categoryFilterProvider = StateProvider<String>((ref) => 'all');

// --- Data Loading on Startup ---

/// Load AI configs from SQLite into provider
Future<void> loadAiConfigs(WidgetRef ref) async {
  final db = DatabaseHelper();
  final rows = await db.getAllAiConfigs();
  final configs = rows.map((row) => AiConfig(
    id: row['id'] as String,
    name: row['name'] as String,
    apiUrl: row['api_url'] as String,
    modelName: row['model_name'] as String,
    temperature: (row['temperature'] as num).toDouble(),
    maxTokens: row['max_tokens'] as int,
    isLocal: (row['is_local'] as int) == 1,
  )).toList();
  ref.read(aiConfigsProvider.notifier).state = configs;
  // Auto-select first config if none selected
  if (configs.isNotEmpty && ref.read(selectedAiConfigProvider) == null) {
    ref.read(selectedAiConfigProvider.notifier).state = configs.first;
  }
}

/// Load materials for a novel from filesystem into providers
Future<void> loadNovelMaterials(WidgetRef ref, String novelId) async {
  final repo = MaterialRepository();
  ref.read(charactersProvider(novelId).notifier).state = await repo.getCharacters(novelId);
  ref.read(settingCardsProvider(novelId).notifier).state = await repo.getSettingCards(novelId);
  ref.read(plotHooksProvider(novelId).notifier).state = await repo.getPlotHooks(novelId);
  ref.read(referencesProvider(novelId).notifier).state = await repo.getReferences(novelId);
  ref.read(settingRemindersProvider(novelId).notifier).state = await repo.getSettingReminders(novelId);
}

/// Load all data on app startup
Future<void> loadAllData(WidgetRef ref) async {
  await loadAiConfigs(ref);
  // Load streak from persistence
  ref.read(streakDaysProvider.notifier).state = ConfigService.streakDays;
}

// --- Stats ---
final statsRepoProvider = Provider((ref) => StatsRepository());
final todayWordsProvider = StateProvider<int>((ref) => 0);
final totalWordsProvider = StateProvider<int>((ref) => 0);
