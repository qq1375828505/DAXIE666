import 'package:freezed_annotation/freezed_annotation.dart';

part 'chapter_model.freezed.dart';
part 'chapter_model.g.dart';

@freezed
class Chapter with _$Chapter {
  factory Chapter({
    required String id,
    required String novelId,
    required String volumeId,
    required String title,
    @Default('') String content,
    @Default(0) int wordCount,
    @Default('draft') String status,
    @Default(0) int orderIndex,
    String? summary,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Chapter;

  factory Chapter.fromJson(Map<String, dynamic> json) => _$ChapterFromJson(json);
}

enum ChapterStatus {
  unwritten,
  draft,
  polishing,
  completed,
  exported,
}

extension ChapterStatusExt on ChapterStatus {
  String get label {
    switch (this) {
      case ChapterStatus.unwritten: return '未写';
      case ChapterStatus.draft: return '草稿';
      case ChapterStatus.polishing: return '待精修';
      case ChapterStatus.completed: return '已完成';
      case ChapterStatus.exported: return '已导出';
    }
  }

  Color get color {
    switch (this) {
      case ChapterStatus.unwritten: return Colors.grey;
      case ChapterStatus.draft: return Colors.orange;
      case ChapterStatus.polishing: return Colors.blue;
      case ChapterStatus.completed: return Colors.green;
      case ChapterStatus.exported: return Colors.purple;
    }
  }
}
