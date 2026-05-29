import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/data/services/cost_tracker.dart';

/// Unified AI service with cost tracking.
/// 自适应兼容所有主流 API 厂商（OpenAI / Anthropic / 小米MiMo / DeepSeek / 通义千问 / Moonshot 等）
class AiService {
  final Dio _dio = Dio();
  final CostTracker _costTracker = CostTracker();

  AiService() {
    // 添加重试拦截器：网络波动自动重试
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        // 只对网络错误重试，不对4xx/5xx重试
        if (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout) {
          try {
            // 最多重试2次，间隔递增
            final retryCount = error.requestOptions.extra['retryCount'] as int? ?? 0;
            if (retryCount < 2) {
              final delay = Duration(seconds: (retryCount + 1) * 2);
              await Future.delayed(delay);
              error.requestOptions.extra['retryCount'] = retryCount + 1;
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            }
          } catch (_) {}
        }
        handler.next(error);
      },
    ));
  }

  /// 智能补全 API 地址
  /// 根据协议类型自动补全为完整路径
  String _normalizeApiUrl(String url, ApiProtocol protocol) {
    url = url.trim().replaceAll(RegExp(r'/+$'), ''); // 去除末尾斜杠
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
    final normalizedUrl = _normalizeApiUrl(config.apiUrl, config.protocol);

    try {
      final response = await _dio.post(
        normalizedUrl,
        options: Options(
          headers: _buildHeaders(config),
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 120),
        ),
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
      final respBody = e.response?.data?.toString() ?? '';
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
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout) {
        throw Exception('连接超时，请检查网络或API地址');
      }
      if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('服务器响应超时，可能是max_tokens过大或模型负载高');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw Exception('无法连接到服务器，请检查API地址和网络');
      }
      // 尝试从 response body 提取更具体的错误信息
      if (respBody.isNotEmpty && respBody.length < 500) {
        throw Exception('API错误 ($statusCode): $respBody');
      }
      if (statusCode != null) {
        throw Exception('请求失败: HTTP $statusCode');
      }
      throw Exception('网络错误: ${e.message ?? "连接异常"}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('未知错误: $e');
    }
  }

  /// 构建认证头
  /// 同时发送多种认证头，兼容所有主流 API 厂商：
  /// - Authorization: Bearer xxx  → OpenAI / DeepSeek / 通义千问 / Moonshot 等
  /// - api-key: xxx             → 小米 MiMo / 部分国内厂商
  /// - x-api-key: xxx           → Anthropic Claude
  /// 服务端只会识别自己需要的头，其他头会被忽略
  Map<String, String> _buildHeaders(AiConfig config) {
    final apiKey = config.apiKey ?? '';
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (config.protocol == ApiProtocol.anthropic) {
      headers['x-api-key'] = apiKey;
      headers['anthropic-version'] = '2023-06-01';
    } else {
      // OpenAI 兼容协议：同时发送 Bearer 和 api-key，兼容所有厂商
      headers['Authorization'] = 'Bearer $apiKey';
      headers['api-key'] = apiKey;
    }

    return headers;
  }

  Map<String, dynamic> _buildPayload(AiConfig config, List<Map<String, String>> messages) {
    // 所有协议统一：从 messages 中提取 system 消息，作为单独字段传递
    String? systemContent;
    final nonSystemMessages = <Map<String, String>>[];

    for (final msg in messages) {
      if (msg['role'] == 'system' && systemContent == null) {
        systemContent = msg['content'];
      } else {
        nonSystemMessages.add(msg);
      }
    }

    // OpenAI 兼容协议
    final payload = <String, dynamic>{
      'model': config.modelName,
      'messages': nonSystemMessages,
      'temperature': config.temperature,
      'max_tokens': config.maxTokens,
    };

    if (systemContent != null && systemContent.isNotEmpty) {
      if (config.protocol == ApiProtocol.anthropic) {
        payload['system'] = systemContent;
      } else {
        // OpenAI 兼容：系统提示作为第一条 system message
        payload['messages'] = [
          {'role': 'system', 'content': systemContent},
          ...nonSystemMessages,
        ];
      }
    }

    return payload;
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

  /// Send chat with function calling (OpenAI compatible).
  /// Returns parsed response with optional tool_calls.
  Future<_ToolChatResponse> chatWithTools({
    required AiConfig config,
    required List<Map<String, dynamic>> messages,
    List<dynamic>? tools,
    String taskType = 'agent',
  }) async {
    final normalizedUrl = _normalizeApiUrl(config.apiUrl, config.protocol);
    // 判断是否发送 tools（先尝试发送）
    final bool shouldSendTools = config.protocol != ApiProtocol.anthropic
        && tools != null && tools.isNotEmpty;

    Future<_ToolChatResponse> doRequest({required bool withTools}) async {
      final payload = <String, dynamic>{
        'model': config.modelName,
        'messages': messages,
        'temperature': config.temperature,
        'max_tokens': config.maxTokens,
      };
      if (withTools) {
        payload['tools'] = tools;
      }

      final response = await _dio.post(
        normalizedUrl,
        options: Options(
          headers: _buildHeaders(config),
          receiveTimeout: const Duration(seconds: 120),
        ),
        data: payload,
      );

      // Track usage
      final usage = response.data['usage'];
      final tokenCount = (usage?['total_tokens'] as int?) ?? 0;
      _costTracker.recordUsage(
        configId: config.id,
        model: config.modelName,
        taskType: taskType,
        tokenCount: tokenCount > 0 ? tokenCount : 100,
      );

      // Parse response
      final choice = response.data['choices']?[0];
      final message = choice?['message'];
      final content = message?['content'] as String?;

      // Parse tool_calls
      List<ToolCallInfo>? toolCalls;
      if (withTools) {
        final rawToolCalls = message?['tool_calls'];
        if (rawToolCalls != null && rawToolCalls is List && rawToolCalls.isNotEmpty) {
          toolCalls = rawToolCalls.map((tc) => ToolCallInfo(
            id: tc['id'] as String? ?? '',
            functionName: tc['function']?['name'] as String? ?? '',
            arguments: tc['function']?['arguments'] ?? '{}',
          )).toList();
        }
      }

      return _ToolChatResponse(content: content, toolCalls: toolCalls);
    }

    try {
      return await doRequest(withTools: shouldSendTools);
    } on DioException catch (e) {
      // 如果带 tools 失败（MiMo等不支持tools的API），去掉 tools 重试
      if (shouldSendTools && (e.response?.statusCode == 400 || e.response?.statusCode == 422)) {
        try {
          return await doRequest(withTools: false);
        } catch (_) {
          // 重试也失败，抛出原始错误
        }
      }

      final statusCode = e.response?.statusCode;
      final respBody = e.response?.data?.toString() ?? '';
      if (statusCode == 401) throw Exception('API Key 无效或认证失败 (401)');
      if (statusCode == 403) throw Exception('API Key 无权限访问该资源 (403)');
      if (statusCode == 404) throw Exception('API地址错误 (404)');
      if (statusCode == 429) throw Exception('请求频率超限 (429)，请稍后再试');
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout) {
        throw Exception('连接超时，请检查网络或API地址');
      }
      if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('服务器响应超时，可能是max_tokens过大或模型负载高');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw Exception('无法连接到服务器，请检查API地址和网络');
      }
      if (respBody.isNotEmpty && respBody.length < 300) {
        throw Exception('请求失败 ($statusCode): $respBody');
      }
      throw Exception('请求失败: ${e.message ?? e.type.name}');
    }
  }
}

/// Tool calling response
class _ToolChatResponse {
  final String? content;
  final List<ToolCallInfo>? toolCalls;

  const _ToolChatResponse({this.content, this.toolCalls});
}

/// Tool call info parsed from API response
class ToolCallInfo {
  final String id;
  final String functionName;
  final dynamic arguments;

  const ToolCallInfo({
    required this.id,
    required this.functionName,
    required this.arguments,
  });
}

final aiServiceProvider = Provider((ref) => AiService());
