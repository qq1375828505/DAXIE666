import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/data/datasources/secure_storage_datasource.dart';
import 'package:novel_ide/data/datasources/database_helper.dart';

/// 默认配置服务
/// 内置开箱即用的AI模型配置
class DefaultConfigService {
  static const String _defaultZhipuId = 'default_zhipu_glm4_flash';
  
  /// 内置的智谱AI API Key
  /// 注意：此API Key为共享密钥，有额度限制
  static const String _builtinZhipuKey = 'aee835b112ca4afe8ba81acede4b05df.GV9QQ4RFWhyjY1CA';
  
  /// 智谱AI所有免费Flash模型列表
  /// 根据官网 https://open.bigmodel.cn/ 免费模型列表
  static final List<Map<String, String>> _freeZhipuModels = [
    {
      'id': 'glm-4.7-flash',
      'name': 'GLM-4.7-Flash',
      'desc': '最新版，128K上下文',
    },
    {
      'id': 'glm-4.6v-flash',
      'name': 'GLM-4.6V-Flash',
      'desc': '多模态版，支持图片理解',
    },
    {
      'id': 'glm-4.1v-thinking-flash',
      'name': 'GLM-4.1V-Thinking-Flash',
      'desc': '思考版，推理能力强',
    },
    {
      'id': 'glm-4-flash-250414',
      'name': 'GLM-4-Flash-250414',
      'desc': '稳定版，128K上下文',
    },
    {
      'id': 'glm-4v-flash',
      'name': 'GLM-4V-Flash',
      'desc': '视觉版，支持图文对话',
    },
    {
      'id': 'cogview-3-flash',
      'name': 'CogView-3-Flash',
      'desc': 'AI绘画，文生图',
    },
    {
      'id': 'cogvideox-flash',
      'name': 'CogVideoX-Flash',
      'desc': 'AI视频，文生视频',
    },
  ];
  
  /// 检查并初始化默认配置
  /// 如果用户没有配置任何AI模型，自动添加智谱AI
  static Future<void> initDefaultConfig() async {
    try {
      final db = DatabaseHelper();
      final configs = await db.getAiConfigs();
      
      // 如果已有配置，不覆盖
      if (configs.isNotEmpty) return;
      
      // 添加默认智谱AI配置（使用第一个模型作为默认）
      final defaultModel = _freeZhipuModels.first;
      final defaultConfig = AiConfig(
        id: _defaultZhipuId,
        name: '智谱AI ${defaultModel['name']} (内置免费)',
        apiUrl: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
        modelName: defaultModel['id']!,
        protocol: ApiProtocol.openaiCompatible,
      );
      
      // 保存配置到数据库
      await db.insertAiConfig(db.toDbMap(defaultConfig));
      
      // 保存API Key到SecureStorage
      await SecureStorageDataSource().writeApiKey(_defaultZhipuId, _builtinZhipuKey);
      
      print('DefaultConfigService: 已添加默认智谱AI配置');
    } catch (e) {
      print('DefaultConfigService init error: $e');
    }
  }
  
  /// 获取所有免费模型列表（用于用户切换）
  static List<Map<String, String>> getAllFreeModels() {
    return List.from(_freeZhipuModels);
  }
  
  /// 获取内置API Key
  static String? getBuiltinKey() => _builtinZhipuKey;
  
  /// 检查是否是内置配置
  static bool isBuiltinConfig(String configId) => configId == _defaultZhipuId;
  
  /// 添加额外的免费模型配置（供用户手动添加）
  static Future<void> addExtraFreeModel(String modelId) async {
    final model = _freeZhipuModels.firstWhere(
      (m) => m['id'] == modelId,
      orElse: () => _freeZhipuModels.first,
    );
    
    final db = DatabaseHelper();
    final config = AiConfig(
      id: 'zhipu_${model['id']}',
      name: '智谱AI ${model['name']} (免费)',
      apiUrl: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      modelName: model['id']!,
      protocol: ApiProtocol.openaiCompatible,
    );
    
    await db.insertAiConfig(db.toDbMap(config));
    await SecureStorageDataSource().writeApiKey(config.id, _builtinZhipuKey);
  }
}
