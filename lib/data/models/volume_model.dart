import 'package:freezed_annotation/freezed_annotation.dart';

part 'volume_model.freezed.dart';
part 'volume_model.g.dart';

@freezed
class Volume with _$Volume {
  factory Volume({
    required String id,
    required String novelId,
    required String title,
    @Default(0) int orderIndex,
    String? summary,
    required DateTime createdAt,
  }) = _Volume;

  factory Volume.fromJson(Map<String, dynamic> json) => _$VolumeFromJson(json);
}
