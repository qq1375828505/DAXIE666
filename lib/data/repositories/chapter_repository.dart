import 'package:sqflite/sqflite.dart';
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/datasources/local_file_datasource.dart';
import 'package:novel_ide/data/models/chapter_model.dart';
import 'package:novel_ide/data/models/snapshot_model.dart';
import 'package:uuid/uuid.dart';

class ChapterRepository {
  final _db = DatabaseHelper();
  final _fs = LocalFileDataSource();
  final _uuid = const Uuid();

  Future<List<Chapter>> getChaptersByNovel(String novelId) async {
    final db = await _db.database;
    final maps = await db.query(
      'chapters',
      where: 'novel_id = ?',
      whereArgs: [novelId],
      orderBy: 'order_index ASC',
    );
    return maps.map((m) => Chapter(
      id: m['id'] as String,
      novelId: m['novel_id'] as String,
      volumeId: m['volume_id'] as String,
      title: m['title'] as String,
      wordCount: m['word_count'] as int? ?? 0,
      status: m['status'] as String? ?? 'draft',
      orderIndex: m['order_index'] as int? ?? 0,
      summary: m['summary'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
    )).toList();
  }

  Future<List<Chapter>> getChaptersByVolume(String volumeId) async {
    final db = await _db.database;
    final maps = await db.query(
      'chapters',
      where: 'volume_id = ?',
      whereArgs: [volumeId],
      orderBy: 'order_index ASC',
    );
    return maps.map((m) => Chapter(
      id: m['id'] as String,
      novelId: m['novel_id'] as String,
      volumeId: m['volume_id'] as String,
      title: m['title'] as String,
      wordCount: m['word_count'] as int? ?? 0,
      status: m['status'] as String? ?? 'draft',
      orderIndex: m['order_index'] as int? ?? 0,
      summary: m['summary'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
    )).toList();
  }

  Future<Chapter?> getChapter(String chapterId) async {
    final db = await _db.database;
    final maps = await db.query('chapters', where: 'id = ?', whereArgs: [chapterId]);
    if (maps.isEmpty) return null;
    final m = maps.first;
    final projectPath = await _fs.getProjectDir(m['novel_id'] as String, '');
    final content = await _fs.readChapterContent(projectPath, chapterId);
    return Chapter(
      id: m['id'] as String,
      novelId: m['novel_id'] as String,
      volumeId: m['volume_id'] as String,
      title: m['title'] as String,
      content: content,
      wordCount: m['word_count'] as int? ?? 0,
      status: m['status'] as String? ?? 'draft',
      orderIndex: m['order_index'] as int? ?? 0,
      summary: m['summary'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
    );
  }

  Future<Chapter> createChapter({
    required String novelId,
    required String volumeId,
    required String title,
    int orderIndex = 0,
    String? summary,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final chapter = Chapter(
      id: id,
      novelId: novelId,
      volumeId: volumeId,
      title: title,
      orderIndex: orderIndex,
      summary: summary,
      createdAt: now,
      updatedAt: now,
    );

    final db = await _db.database;
    await db.insert('chapters', {
      'id': chapter.id,
      'novel_id': chapter.novelId,
      'volume_id': chapter.volumeId,
      'title': chapter.title,
      'order_index': chapter.orderIndex,
      'summary': chapter.summary,
      'created_at': chapter.createdAt.millisecondsSinceEpoch,
      'updated_at': chapter.updatedAt.millisecondsSinceEpoch,
    });

    return chapter;
  }

  Future<void> updateChapter(Chapter chapter, String novelTitle) async {
    final db = await _db.database;
    final now = DateTime.now();
    await db.update('chapters', {
      'title': chapter.title,
      'word_count': chapter.wordCount,
      'status': chapter.status,
      'order_index': chapter.orderIndex,
      'summary': chapter.summary,
      'updated_at': now.millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [chapter.id]);

    final projectPath = await _fs.getProjectDir(chapter.novelId, novelTitle);
    await _fs.saveChapterContent(projectPath, chapter.id, chapter.content);
  }

  Future<void> deleteChapter(String chapterId) async {
    final db = await _db.database;
    await db.delete('chapters', where: 'id = ?', whereArgs: [chapterId]);
  }

  Future<void> createSnapshot(String chapterId, String content) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final db = await _db.database;
    await db.insert('chapter_snapshots', {
      'id': id,
      'chapter_id': chapterId,
      'content': content,
      'created_at': now.millisecondsSinceEpoch,
    });

    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM chapter_snapshots WHERE chapter_id = ?',
      [chapterId],
    )) ?? 0;

    if (count > 20) {
      final old = await db.query(
        'chapter_snapshots',
        where: 'chapter_id = ?',
        whereArgs: [chapterId],
        orderBy: 'created_at ASC',
        limit: count - 20,
      );
      for (final row in old) {
        await db.delete('chapter_snapshots', where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }

  Future<List<ChapterSnapshot>> getSnapshots(String chapterId) async {
    final db = await _db.database;
    final maps = await db.query(
      'chapter_snapshots',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => ChapterSnapshot(
      id: m['id'] as String,
      chapterId: m['chapter_id'] as String,
      content: m['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
    )).toList();
  }
}
