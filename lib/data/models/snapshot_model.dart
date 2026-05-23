import 'package:freezed_annotation/freezed_annotation.dart';

part 'snapshot_model.freezed.dart';
part 'snapshot_model.g.dart';

@freezed
class ChapterSnapshot with _$ChapterSnapshot {
  factory ChapterSnapshot({
    required String id,
    required String chapterId,
    required String content,
    required DateTime createdAt,
  }) = _ChapterSnapshot;

  factory ChapterSnapshot.fromJson(Map<String, dynamic> json) => _$ChapterSnapshotFromJson(json);
}
