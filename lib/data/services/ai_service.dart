import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/data/models/ai_config_model.dart';

/// Unified AI service - replaces duplicate Dio.post calls in 3 places.
class AiService {
  final Dio _dio = Dio();

  /// Send a chat completion request to the configured AI API.
  ///
  /// [config] - AI model configuration (API URL, model, key, etc.)
  /// [messages] - List of chat messages [{role, content}, ...]
  /// Returns the assistant's reply text, or throws on failure.
  Future<String> chat(AiConfig config, List<Map<String, String>> messages) async {
    final response = await _dio.post(
      config.apiUrl,
      options: Options(headers: {
        'Authorization': 'Bearer ${config.apiKey ?? ''}',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': config.modelName,
        'messages': messages,
        'temperature': config.temperature,
        'max_tokens': config.maxTokens,
      },
    );

    return response.data['choices']?[0]?['message']?['content'] ?? '生成失败，请检查API配置';
  }

  /// Convenience: send with system prompt + user message.
  Future<String> send({
    required AiConfig config,
    required String systemPrompt,
    required String userMessage,
  }) async {
    return chat(config, [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userMessage},
    ]);
  }
}

final aiServiceProvider = Provider((ref) => AiService());
