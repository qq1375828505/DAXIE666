import 'package:freezed_annotation/freezed_annotation.dart';

part 'tomato_agent_model.freezed.dart';
part 'tomato_agent_model.g.dart';

@freezed
class TomatoAgent with _$TomatoAgent {
  factory TomatoAgent({
    required String id,
    required String name,
    required String icon,
    required String description,
    required String systemPrompt,
    @Default(true) bool isBuiltin,
    @Default([]) List<String> parameterPrompts,
  }) = _TomatoAgent;

  factory TomatoAgent.fromJson(Map<String, dynamic> json) => _$TomatoAgentFromJson(json);
}
