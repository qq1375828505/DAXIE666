import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'novel_ide.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE novels (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT,
        description TEXT,
        category TEXT,
        total_word_count INTEGER DEFAULT 0,
        chapter_count INTEGER DEFAULT 0,
        cover_path TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        status TEXT DEFAULT 'draft'
      )
    ''');

    await db.execute('''
      CREATE TABLE volumes (
        id TEXT PRIMARY KEY,
        novel_id TEXT NOT NULL,
        title TEXT NOT NULL,
        order_index INTEGER DEFAULT 0,
        summary TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (novel_id) REFERENCES novels(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE chapters (
        id TEXT PRIMARY KEY,
        novel_id TEXT NOT NULL,
        volume_id TEXT NOT NULL,
        title TEXT NOT NULL,
        word_count INTEGER DEFAULT 0,
        status TEXT DEFAULT 'draft',
        order_index INTEGER DEFAULT 0,
        summary TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (novel_id) REFERENCES novels(id) ON DELETE CASCADE,
        FOREIGN KEY (volume_id) REFERENCES volumes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE chapter_snapshots (
        id TEXT PRIMARY KEY,
        chapter_id TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_configs (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        api_url TEXT NOT NULL,
        model_name TEXT NOT NULL,
        temperature REAL DEFAULT 1.0,
        max_tokens INTEGER DEFAULT 4096,
        is_local INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_chapters_novel ON chapters(novel_id);
    ''');
    await db.execute('''
      CREATE INDEX idx_chapters_volume ON chapters(volume_id);
    ''');
    await db.execute('''
      CREATE INDEX idx_snapshots_chapter ON chapter_snapshots(chapter_id);
    ''');
  }
}
