import 'package:freezed_annotation/freezed_annotation.dart';

part 'tomato_preset_model.freezed.dart';
part 'tomato_preset_model.g.dart';

@freezed
class TomatoPreset with _$TomatoPreset {
  factory TomatoPreset({
    required String id,
    required String name,
    required String category,
    required String description,
    required String systemPrompt,
    required List<String> tags,
    @Default(true) bool isBuiltin,
    @Default(false) bool isCustom,
  }) = _TomatoPreset;

  factory TomatoPreset.fromJson(Map<String, dynamic> json) => _$TomatoPresetFromJson(json);
}
