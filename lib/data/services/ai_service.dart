import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/data/services/cost_tracker.dart';

/// Unified AI service with cost tracking.
class AiService {
  final Dio _dio = Dio();
  final CostTracker _costTracker = CostTracker();

  /// 智能补全 API 地址（兼容旧配置）
  /// 根据协议类型自动补全为完整路径
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

  /// Send a chat completion request. Tracks cost automatically.
  Future<String> chat(AiConfig config, List<Map<String, String>> messages, {String taskType = 'chat'}) async {
    // 兼容旧配置：确保 URL 已补全
    final normalizedUrl = _normalizeApiUrl(config.apiUrl, config.protocol);

    try {
      final response = await _dio.post(
        normalizedUrl,
        options: Options(headers: _buildHeaders(config)),
        data: _buildPayload(config, messages),
      );

      final content = _parseResponse(config, response);

      // Track usage
      final usage = response.data['usage'];
      final tokenCount = (usage?['total_tokens'] as int?) ?? content.length ~/ 2;
      _costTracker.recordUsage(
        configId: config.id,
        model: config.modelName,
        taskType: taskType,
        tokenCount: tokenCount,
      );

      return content;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        throw Exception('API Key 无效或认证失败 (401)，请检查API Key是否正确');
      }
      if (statusCode == 403) {
        throw Exception('API Key 无权限访问该资源 (403)');
      }
      if (statusCode == 404) {
        throw Exception('API地址错误 (404)，请检查URL配置');
      }
      if (statusCode == 429) {
        throw Exception('请求频率超限 (429)，请稍后再试');
      }
      if (statusCode == 402) {
        throw Exception('API 余额不足 (402)，请充值后重试');
      }
      throw Exception('请求失败: ${e.message}');
    }
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
      'api-key': config.apiKey ?? '',  // 兼容小米 MiMo 等使用 api-key 头的服务
      'Content-Type': 'application/json',
    };
  }

  Map<String, dynamic> _buildPayload(AiConfig config, List<Map<String, String>> messages) {
    if (config.protocol == ApiProtocol.anthropic) {
      final systemMsg = messages.firstWhere(
        (m) => m['role'] == 'system',
        orElse: () => {'role': 'user', 'content': ''},
      );
      final userMessages = messages.where((m) => m['role'] != 'system').toList();
      return {
        'model': config.modelName,
        'max_tokens': config.maxTokens,
        'system': systemMsg['content'],
        'messages': userMessages,
      };
    }
    return {
      'model': config.modelName,
      'messages': messages,
      'temperature': config.temperature,
      'max_tokens': config.maxTokens,
    };
  }

  String _parseResponse(AiConfig config, dynamic response) {
    if (config.protocol == ApiProtocol.anthropic) {
      final content = response.data['content'];
      if (content is List && content.isNotEmpty) {
        return content[0]['text'] ?? '生成失败';
      }
      return '生成失败，请检查API配置';
    }
    return response.data['choices']?[0]?['message']?['content'] ?? '生成失败，请检查API配置';
  }

  /// Convenience: send with system prompt + user message.
  Future<String> send({
    required AiConfig config,
    required String systemPrompt,
    required String userMessage,
    String taskType = 'chat',
  }) async {
    return chat(config, [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userMessage},
    ], taskType: taskType);
  }
}

final aiServiceProvider = Provider((ref) => AiService());
