import 'package:dio/dio.dart';
import 'package:novel_ide/data/models/ai_config_model.dart';

/// Test API connection and fetch available models.
class ModelTestService {
  final Dio _dio = Dio();

  /// 智能补全 API 地址（兼容旧配置）
  String _normalizeApiUrl(String url, ApiProtocol protocol) {
    url = url.trim();
    if (url.isEmpty) return url;

    // 已经是完整路径，直接返回
    if (url.contains('/chat/completions')) return url;
    if (url.contains('/v1/messages')) return url;

    // Anthropic 协议特殊处理
    if (protocol == ApiProtocol.anthropic) {
      if (url.endsWith('/anthropic')) return '$url/v1/messages';
      if (url.endsWith('/v1')) return '$url/messages';
      if (!url.endsWith('/')) url = '$url/';
      return '${url}v1/messages';
    }

    // OpenAI 兼容协议
    if (url.endsWith('/v1')) return '$url/chat/completions';
    if (!url.endsWith('/')) url = '$url/';
    return '${url}v1/chat/completions';
  }

  /// Test connection to the API. Returns success message or throws error.
  Future<String> testConnection(AiConfig config) async {
    // 兼容旧配置：确保 URL 已补全
    final normalizedUrl = _normalizeApiUrl(config.apiUrl, config.protocol);

    try {
      final response = await _dio.post(
        normalizedUrl,
        options: Options(
          headers: _buildHeaders(config),
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
        data: _buildTestPayload(config),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return '连接成功！';
      }
      return '连接成功 (HTTP ${response.statusCode})';
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('连接超时，请检查API地址是否正确');
      }
      if (e.response?.statusCode == 401) {
        throw Exception('API Key 无效 (401 Unauthorized)');
      }
      if (e.response?.statusCode == 403) {
        throw Exception('API Key 无权限 (403 Forbidden)');
      }
      if (e.response?.statusCode == 404) {
        throw Exception('API地址错误 (404 Not Found)，请检查URL是否正确');
      }
      throw Exception('连接失败: ${e.message}');
    }
  }

  /// Fetch available model list from the API.
  Future<List<String>> fetchModels(AiConfig config) async {
    // 兼容旧配置：确保 URL 已补全
    final normalizedUrl = _normalizeApiUrl(config.apiUrl, config.protocol);

    try {
      // Try OpenAI-compatible /models endpoint
      final modelsUrl = normalizedUrl.replaceAll(RegExp(r'/chat/completions.*'), '') + '/models';
      final response = await _dio.get(
        modelsUrl,
        options: Options(
          headers: _buildHeaders(config),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['data'] is List) {
          final modelsList = data['data'] as List;
          final models = <String>[];
          for (final m in modelsList) {
            if (m is Map && m['id'] is String) {
              models.add(m['id'] as String);
            }
          }
          models.sort();
          return models;
        }
      }
    } catch (_) {}

    // If /models fails, return the current model name as fallback
    return [config.modelName];
  }

  Map<String, String> _buildHeaders(AiConfig config) {
    if (config.protocol == ApiProtocol.anthropic) {
      return {
        'x-api-key': config.apiKey ?? '',
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      };
    }
    return {
      'Authorization': 'Bearer ${config.apiKey ?? ''}',
      'Content-Type': 'application/json',
    };
  }

  Map<String, dynamic> _buildTestPayload(AiConfig config) {
    if (config.protocol == ApiProtocol.anthropic) {
      return {
        'model': config.modelName,
        'max_tokens': 10,
        'messages': [
          {'role': 'user', 'content': 'Hi'},
        ],
      };
    }
    return {
      'model': config.modelName,
      'messages': [
        {'role': 'user', 'content': 'Hi'},
      ],
      'max_tokens': 10,
    };
  }
}
