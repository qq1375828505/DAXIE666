import 'package:sqflite/sqflite.dart';
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/datasources/local_file_datasource.dart';
import 'package:novel_ide/data/models/novel_model.dart';
import 'package:uuid/uuid.dart';

class NovelRepository {
  final _db = DatabaseHelper();
  final _fs = LocalFileDataSource();
  final _uuid = const Uuid();

  Future<List<Novel>> getAllNovels() async {
    final db = await _db.database;
    final maps = await db.query('novels', orderBy: 'updated_at DESC');
    return maps.map((m) => Novel(
      id: m['id'] as String,
      title: m['title'] as String,
      author: m['author'] as String?,
      description: m['description'] as String?,
      category: m['category'] as String?,
      totalWordCount: m['total_word_count'] as int? ?? 0,
      chapterCount: m['chapter_count'] as int? ?? 0,
      coverPath: m['cover_path'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
      status: m['status'] as String? ?? 'draft',
    )).toList();
  }

  Future<Novel> createNovel({required String title, String? author, String? description, String? category}) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final novel = Novel(
      id: id,
      title: title,
      author: author,
      description: description,
      category: category,
      createdAt: now,
      updatedAt: now,
    );

    final db = await _db.database;
    await db.insert('novels', {
      'id': novel.id,
      'title': novel.title,
      'author': novel.author,
      'description': novel.description,
      'category': novel.category,
      'created_at': novel.createdAt.millisecondsSinceEpoch,
      'updated_at': novel.updatedAt.millisecondsSinceEpoch,
    });

    await _fs.createProjectDir(id, title);
    await _fs.saveProjectJson(await _fs.getProjectDir(id, title), {
      'id': id,
      'title': title,
      'author': author,
      'description': description,
      'category': category,
      'created_at': now.toIso8601String(),
    });

    return novel;
  }

  Future<void> updateNovel(Novel novel) async {
    final db = await _db.database;
    await db.update('novels', {
      'title': novel.title,
      'author': novel.author,
      'description': novel.description,
      'category': novel.category,
      'total_word_count': novel.totalWordCount,
      'chapter_count': novel.chapterCount,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [novel.id]);
  }

  Future<void> deleteNovel(String novelId, String title) async {
    final db = await _db.database;
    await db.delete('novels', where: 'id = ?', whereArgs: [novelId]);
    final path = await _fs.getProjectDir(novelId, title);
    await _fs.deleteProjectDir(path);
  }
}
