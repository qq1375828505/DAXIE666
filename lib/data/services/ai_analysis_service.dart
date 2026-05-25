import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/data/models/material_models.dart';
import 'package:novel_ide/data/repositories/material_repository.dart';
import 'package:novel_ide/data/services/ai_service.dart';

/// AI 分析服务
/// 分析小说章节内容，自动提取角色、设定、地点、势力、道具、伏笔等资料
class AiAnalysisService {
  static final _uuid = Uuid();
  final AiService _aiService = AiService();
  final MaterialRepository _repo = MaterialRepository();

  /// 分析结果
  AnalysisResult? _lastResult;

  AnalysisResult? get lastResult => _lastResult;

  /// 分析小说内容并自动填充资料库
  /// [content] 小说全文或前N章内容
  /// [config] AI 配置
  /// [novelId] 作品ID
  /// [onProgress] 进度回调（0.0 ~ 1.0）
  Future<AnalysisResult> analyzeAndFillMaterials({
    required String content,
    required AiConfig config,
    required String novelId,
    void Function(String step, double progress)? onProgress,
  }) async {
    // 截取内容（避免超出 token 限制）
    final maxChars = 15000;
    final analysisContent = content.length > maxChars
        ? '${content.substring(0, maxChars)}\n\n...（内容过长，仅分析前${maxChars}字）'
        : content;

    _lastResult = AnalysisResult();

    // Step 1: 提取角色
    onProgress?.call('正在分析角色...', 0.1);
    final characters = await _extractCharacters(config, analysisContent);
    if (characters.isNotEmpty) {
      final existing = await _repo.getCharacters(novelId);
      final existingNames = existing.map((c) => c.name).toSet();
      final newChars = characters.where((c) => !existingNames.contains(c.name)).toList();
      if (newChars.isNotEmpty) {
        await _repo.saveCharacters(novelId, [...existing, ...newChars]);
        _lastResult!.charactersAdded = newChars.length;
      }
    }

    // Step 2: 提取设定
    onProgress?.call('正在分析世界观设定...', 0.3);
    final settings = await _extractSettings(config, analysisContent);
    if (settings.isNotEmpty) {
      final existing = await _repo.getSettingCards(novelId);
      final existingNames = existing.map((s) => s.name).toSet();
      final newSettings = settings.where((s) => !existingNames.contains(s.name)).toList();
      if (newSettings.isNotEmpty) {
        await _repo.saveSettingCards(novelId, [...existing, ...newSettings]);
        _lastResult!.settingsAdded = newSettings.length;
      }
    }

    // Step 3: 提取地点
    onProgress?.call('正在分析地点...', 0.5);
    final locations = await _extractLocations(config, analysisContent);
    if (locations.isNotEmpty) {
      final existing = await _repo.getLocations(novelId);
      final existingNames = existing.map((l) => l.name).toSet();
      final newLocs = locations.where((l) => !existingNames.contains(l.name)).toList();
      if (newLocs.isNotEmpty) {
        await _repo.saveLocations(novelId, [...existing, ...newLocs]);
        _lastResult!.locationsAdded = newLocs.length;
      }
    }

    // Step 4: 提取势力
    onProgress?.call('正在分析势力...', 0.65);
    final factions = await _extractFactions(config, analysisContent);
    if (factions.isNotEmpty) {
      final existing = await _repo.getFactions(novelId);
      final existingNames = existing.map((f) => f.name).toSet();
      final newFactions = factions.where((f) => !existingNames.contains(f.name)).toList();
      if (newFactions.isNotEmpty) {
        await _repo.saveFactions(novelId, [...existing, ...newFactions]);
        _lastResult!.factionsAdded = newFactions.length;
      }
    }

    // Step 5: 提取道具
    onProgress?.call('正在分析道具...', 0.8);
    final items = await _extractItems(config, analysisContent);
    if (items.isNotEmpty) {
      final existing = await _repo.getItems(novelId);
      final existingNames = existing.map((i) => i.name).toSet();
      final newItems = items.where((i) => !existingNames.contains(i.name)).toList();
      if (newItems.isNotEmpty) {
        await _repo.saveItems(novelId, [...existing, ...newItems]);
        _lastResult!.itemsAdded = newItems.length;
      }
    }

    // Step 6: 提取伏笔
    onProgress?.call('正在分析伏笔...', 0.9);
    final hooks = await _extractHooks(config, analysisContent);
    if (hooks.isNotEmpty) {
      final existing = await _repo.getPlotHooks(novelId);
      final existingTitles = existing.map((h) => h.title).toSet();
      final newHooks = hooks.where((h) => !existingTitles.contains(h.title)).toList();
      if (newHooks.isNotEmpty) {
        await _repo.savePlotHooks(novelId, [...existing, ...newHooks]);
        _lastResult!.hooksAdded = newHooks.length;
      }
    }

    onProgress?.call('分析完成！', 1.0);
    return _lastResult!;
  }

  // --- AI 提取方法 ---

  Future<List<Character>> _extractCharacters(AiConfig config, String content) async {
    final response = await _aiService.send(
      config: config,
      systemPrompt: '你是一位小说分析专家。请从以下小说内容中提取所有重要角色信息。'
          '输出严格的JSON数组格式，每个角色包含：name(名字)、role(定位：主角/女主/反派/配角/龙套)、'
          'description(简介50字内)、appearance(外貌50字内)、personality(性格50字内)、background(背景50字内)。'
          '只提取有名字的角色，忽略路人。如果没有角色返回空数组[]。',
      userMessage: content,
      taskType: 'analysis',
    );

    return _parseJsonList(response, (json) => Character(
      id: _uuid.v4(),
      novelId: '', // 会在调用处设置
      name: json['name'] as String? ?? '',
      role: json['role'] as String?,
      description: json['description'] as String?,
      appearance: json['appearance'] as String?,
      personality: json['personality'] as String?,
      background: json['background'] as String?,
    )).where((c) => c.name.isNotEmpty).toList();
  }

  Future<List<SettingCard>> _extractSettings(AiConfig config, String content) async {
    final response = await _aiService.send(
      config: config,
      systemPrompt: '你是一位小说分析专家。请从以下小说内容中提取所有重要的世界观设定。'
          '输出严格的JSON数组格式，每个设定包含：name(设定名称)、category(分类：世界观/战力体系/修炼等级/社会制度/科技水平/其他)、'
          'description(描述100字内)。只提取对剧情有重要影响的设定。如果没有返回空数组[]。',
      userMessage: content,
      taskType: 'analysis',
    );

    return _parseJsonList(response, (json) => SettingCard(
      id: _uuid.v4(),
      novelId: '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String?,
      description: json['description'] as String?,
    )).where((s) => s.name.isNotEmpty).toList();
  }

  Future<List<Location>> _extractLocations(AiConfig config, String content) async {
    final response = await _aiService.send(
      config: config,
      systemPrompt: '你是一位小说分析专家。请从以下小说内容中提取所有重要的地点。'
          '输出严格的JSON数组格式，每个地点包含：name(地点名)、category(分类：城市/宗门/秘境/国家/山脉/海域/其他)、'
          'description(描述80字内)、features(特征50字内)、rules(特殊规则50字内)。只提取有具体名字的地点。如果没有返回空数组[]。',
      userMessage: content,
      taskType: 'analysis',
    );

    return _parseJsonList(response, (json) => Location(
      id: _uuid.v4(),
      novelId: '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String?,
      description: json['description'] as String?,
      features: json['features'] as String?,
      rules: json['rules'] as String?,
    )).where((l) => l.name.isNotEmpty).toList();
  }

  Future<List<Faction>> _extractFactions(AiConfig config, String content) async {
    final response = await _aiService.send(
      config: config,
      systemPrompt: '你是一位小说分析专家。请从以下小说内容中提取所有重要的势力/组织。'
          '输出严格的JSON数组格式，每个势力包含：name(势力名)、category(分类：正道/魔道/中立/国家/门派/家族/其他)、'
          'description(描述80字内)、leader(首领名)、strength(实力等级)。只提取有名字的组织。如果没有返回空数组[]。',
      userMessage: content,
      taskType: 'analysis',
    );

    return _parseJsonList(response, (json) => Faction(
      id: _uuid.v4(),
      novelId: '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String?,
      description: json['description'] as String?,
      leader: json['leader'] as String?,
      strength: json['strength'] as String?,
    )).where((f) => f.name.isNotEmpty).toList();
  }

  Future<List<Item>> _extractItems(AiConfig config, String content) async {
    final response = await _aiService.send(
      config: config,
      systemPrompt: '你是一位小说分析专家。请从以下小说内容中提取所有重要的道具/物品/法宝/武器。'
          '输出严格的JSON数组格式，每个道具包含：name(道具名)、category(分类：武器/法宝/丹药/功法/阵法/其他)、'
          'description(描述80字内)、powerLevel(品阶)、owner(持有者)、isKeyItem(是否关键道具true/false)。'
          '只提取有具体名字的道具。如果没有返回空数组[]。',
      userMessage: content,
      taskType: 'analysis',
    );

    return _parseJsonList(response, (json) => Item(
      id: _uuid.v4(),
      novelId: '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String?,
      description: json['description'] as String?,
      powerLevel: json['powerLevel'] as String?,
      owner: json['owner'] as String?,
      isKeyItem: json['isKeyItem'] as bool? ?? false,
    )).where((i) => i.name.isNotEmpty).toList();
  }

  Future<List<PlotHook>> _extractHooks(AiConfig config, String content) async {
    final response = await _aiService.send(
      config: config,
      systemPrompt: '你是一位小说分析专家。请从以下小说内容中提取所有伏笔和悬念。'
          '输出严格的JSON数组格式，每个伏笔包含：title(伏笔标题)、description(描述100字内)。'
          '伏笔是指作者埋下的、尚未完全揭示的线索或悬念。如果没有返回空数组[]。',
      userMessage: content,
      taskType: 'analysis',
    );

    return _parseJsonList(response, (json) => PlotHook(
      id: _uuid.v4(),
      novelId: '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
    )).where((h) => h.title.isNotEmpty).toList();
  }

  /// 安全解析 AI 返回的 JSON 数组
  List<T> _parseJsonList<T>(String response, T Function(Map<String, dynamic>) fromJson) {
    try {
      // 提取 JSON 数组部分（AI 可能在 JSON 前后添加文字）
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch == null) return [];

      final list = jsonDecode(jsonMatch.group(0)!) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    } catch (e) {
      // JSON 解析失败，返回空列表
      return [];
    }
  }
}

/// 分析结果统计
class AnalysisResult {
  int charactersAdded = 0;
  int settingsAdded = 0;
  int locationsAdded = 0;
  int factionsAdded = 0;
  int itemsAdded = 0;
  int hooksAdded = 0;

  int get totalAdded =>
      charactersAdded + settingsAdded + locationsAdded +
      factionsAdded + itemsAdded + hooksAdded;

  @override
  String toString() {
    final parts = <String>[];
    if (charactersAdded > 0) parts.add('角色 $charactersAdded 个');
    if (settingsAdded > 0) parts.add('设定 $settingsAdded 个');
    if (locationsAdded > 0) parts.add('地点 $locationsAdded 个');
    if (factionsAdded > 0) parts.add('势力 $factionsAdded 个');
    if (itemsAdded > 0) parts.add('道具 $itemsAdded 个');
    if (hooksAdded > 0) parts.add('伏笔 $hooksAdded 个');
    return parts.isEmpty ? '未发现新资料' : '共提取 ${parts.join('、')}';
  }
}
