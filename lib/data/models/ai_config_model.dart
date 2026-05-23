import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_config_model.freezed.dart';
part 'ai_config_model.g.dart';

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
  }) = _AiConfig;

  factory AiConfig.fromJson(Map<String, dynamic> json) => _$AiConfigFromJson(json);
}
