import 'package:sqflite/sqflite.dart';
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/models/volume_model.dart';
import 'package:uuid/uuid.dart';

class VolumeRepository {
  final _db = DatabaseHelper();
  final _uuid = const Uuid();

  Future<List<Volume>> getVolumesByNovel(String novelId) async {
    final db = await _db.database;
    final maps = await db.query(
      'volumes',
      where: 'novel_id = ?',
      whereArgs: [novelId],
      orderBy: 'order_index ASC',
    );
    return maps.map((m) => Volume(
      id: m['id'] as String,
      novelId: m['novel_id'] as String,
      title: m['title'] as String,
      orderIndex: m['order_index'] as int? ?? 0,
      summary: m['summary'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
    )).toList();
  }

  Future<Volume> createVolume({
    required String novelId,
    required String title,
    int orderIndex = 0,
    String? summary,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final volume = Volume(
      id: id,
      novelId: novelId,
      title: title,
      orderIndex: orderIndex,
      summary: summary,
      createdAt: now,
    );
    final db = await _db.database;
    await db.insert('volumes', {
      'id': volume.id,
      'novel_id': volume.novelId,
      'title': volume.title,
      'order_index': volume.orderIndex,
      'summary': volume.summary,
      'created_at': volume.createdAt.millisecondsSinceEpoch,
    });
    return volume;
  }

  Future<void> updateVolume(Volume volume) async {
    final db = await _db.database;
    await db.update('volumes', {
      'title': volume.title,
      'order_index': volume.orderIndex,
      'summary': volume.summary,
    }, where: 'id = ?', whereArgs: [volume.id]);
  }

  Future<void> deleteVolume(String volumeId) async {
    final db = await _db.database;
    await db.delete('volumes', where: 'id = ?', whereArgs: [volumeId]);
  }
}
