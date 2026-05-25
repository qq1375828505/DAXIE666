import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:novel_ide/data/models/ai_config_model.dart';

/// Test API connection and fetch available models.
class ModelTestService {
  final Dio _dio = Dio();

  /// Test connection to the API. Returns success message or throws error.
  Future<String> testConnection(AiConfig config) async {
    try {
      final response = await _dio.post(
        config.apiUrl,
        options: Options(
          headers: _buildHeaders(config),
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
        data: _buildTestPayload(config),
      );

      if (response.statusCode == 200) {
        final content = response.data['choices']?[0]?['message']?['content'] ?? '';
        return '连接成功! 模型响应: ${content.substring(0, content.length.clamp(0, 50))}';
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
      throw Exception('连接失败: ${e.message}');
    }
  }

  /// Fetch available model list from the API.
  Future<List<String>> fetchModels(AiConfig config) async {
    try {
      // Try OpenAI-compatible /models endpoint
      final modelsUrl = config.apiUrl.replaceAll(RegExp(r'/chat/completions.*'), '') + '/models';
      final response = await _dio.get(
        modelsUrl,
        options: Options(
          headers: _buildHeaders(config),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        final models = (response.data['data'] as List)
            .map((m) => m['id'] as String)
            .toList();
        models.sort();
        return models;
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
