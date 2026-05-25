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

      if (response.statusCode == 200 || response.statusCode == 201) {
        String? content;
        // 解析响应内容
        if (config.protocol == ApiProtocol.anthropic) {
          // 解析 Anthropic 响应格式
          final responseData = response.data;
          if (responseData is Map && responseData['content'] is List && (responseData['content'] as List).isNotEmpty) {
            final firstContent = (responseData['content'] as List);
            if (firstContent[0] is Map && firstContent[0]['text'] is String) {
              content = firstContent[0]['text'] as String?;
            }
          }
        } else {
          // 解析 OpenAI 兼容格式
          if (response.data is Map) {
            final choices = response.data['choices'];
            if (choices is List && choices.isNotEmpty && choices[0] is Map) {
              final message = choices[0]['message'];
              if (message is Map && message['content'] is String) {
                content = message['content'] as String?;
              }
            }
          }
        }
        // 如果没有解析到内容，也返回成功
        return content != null && content.isNotEmpty
            ? '连接成功! 模型响应: ${content.substring(0, content.length.clamp(0, 50))}'
            : '连接成功！';
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
      // 改进错误信息显示
      String errorMsg = '连接失败';
      if (e.response?.data != null) {
        try {
          final errorData = e.response?.data;
          if (errorData is Map && errorData['error'] != null) {
            final error = errorData['error'];
            if (error is Map && error['message'] is String) {
              errorMsg += ': ${error['message']}';
            }
          } else if (errorData is String) {
            errorMsg += ': $errorData';
          }
        } catch (_) {
          // 忽略解析错误
        }
      }
      if (errorMsg == '连接失败' && e.message != null) {
        errorMsg += ': ${e.message}';
      }
      throw Exception(errorMsg);
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
