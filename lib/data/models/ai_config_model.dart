import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_config_model.freezed.dart';
part 'ai_config_model.g.dart';

/// API protocol types.
enum ApiProtocol {
  openaiCompatible,  // OpenAI / DeepSeek / 通义千问 / Moonshot 等
  anthropic,         // Claude API
}

@freezed
class AiConfig with _$AiConfig {
  factory AiConfig({
    required String id,
    required String name,
    required String apiUrl,
    required String modelName,
    String? apiKey,
    @Default(1.0) double temperature,
    @Default(4096) int maxTokens,
    @Default(false) bool isLocal,
    @Default(ApiProtocol.openaiCompatible) ApiProtocol protocol,
  }) = _AiConfig;

  factory AiConfig.fromJson(Map<String, dynamic> json) => _$AiConfigFromJson(json);
}
