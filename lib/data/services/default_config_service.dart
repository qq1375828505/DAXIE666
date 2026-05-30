import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/data/datasources/secure_storage_datasource.dart';
import 'package:novel_ide/data/datasources/database_helper.dart';

/// 默认配置服务
/// 内置开箱即用的AI模型配置（无内置API Key，用户需自行配置）
class DefaultConfigService {
  /// 内置模型列表（仅提供模型信息，不含API Key）
  static final List<Map<String, String>> _builtinModels = [
    {
      'id': 'glm-4.7-flash',
      'name': 'GLM-4.7-Flash',
      'desc': '最新版，128K上下文',
      'apiUrl': 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    },
    {
      'id': 'glm-4.6v-flash',
      'name': 'GLM-4.6V-Flash',
      'desc': '多模态版，支持图片理解',
      'apiUrl': 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    },
    {
      'id': 'glm-4.1v-thinking-flash',
      'name': 'GLM-4.1V-Thinking-Flash',
      'desc': '思考版，推理能力强',
      'apiUrl': 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    },
    {
      'id': 'glm-4-flash-250414',
      'name': 'GLM-4-Flash-250414',
      'desc': '稳定版，128K上下文',
      'apiUrl': 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    },
    {
      'id': 'glm-4v-flash',
      'name': 'GLM-4V-Flash',
      'desc': '视觉版，支持图文对话',
      'apiUrl': 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    },
  ];

  /// 检查并初始化默认配置
  /// 如果用户没有配置任何AI模型，提示用户去配置
  static Future<void> initDefaultConfig() async {
    try {
      final db = DatabaseHelper();
      final configs = await db.getAllAiConfigs();

      // 如果已有配置，不覆盖
      if (configs.isNotEmpty) return;

      // 不再自动添加内置模型，用户需自行配置
      print('DefaultConfigService: 用户尚未配置AI模型');
    } catch (e) {
      print('DefaultConfigService init error: $e');
    }
  }

  /// 获取所有内置模型列表（用于用户选择添加）
  static List<Map<String, String>> getAllBuiltinModels() {
    return _builtinModels.map((m) => {
      'id': m['id']!,
      'name': m['name']!,
      'desc': m['desc']!,
      'apiUrl': m['apiUrl']!,
    }).toList();
  }

  /// 检查是否是内置模型ID
  static bool isBuiltinModel(String modelId) {
    return _builtinModels.any((m) => m['id'] == modelId);
  }
}
