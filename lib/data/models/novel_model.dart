import 'package:freezed_annotation/freezed_annotation.dart';

part 'novel_model.freezed.dart';
part 'novel_model.g.dart';

@freezed
class Novel with _$Novel {
  factory Novel({
    required String id,
    required String title,
    String? author,
    String? description,
    String? category,
    @Default(0) int totalWordCount,
    @Default(0) int chapterCount,
    String? coverPath,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default('draft') String status,
  }) = _Novel;

  factory Novel.fromJson(Map<String, dynamic> json) => _$NovelFromJson(json);
}
