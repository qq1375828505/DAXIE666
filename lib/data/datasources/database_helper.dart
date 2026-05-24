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
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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

    // V2: daily writing stats
    await _createDailyWordsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createDailyWordsTable(db);
    }
  }

  Future<void> _createDailyWordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE daily_words (
        date TEXT NOT NULL,
        novel_id TEXT NOT NULL,
        word_count INTEGER DEFAULT 0,
        PRIMARY KEY (date, novel_id)
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_daily_words_date ON daily_words(date);
    ''');
  }

  // --- AI Config CRUD ---

  Future<List<Map<String, dynamic>>> getAllAiConfigs() async {
    final db = await database;
    return await db.query('ai_configs');
  }

  Future<void> insertAiConfig(Map<String, dynamic> config) async {
    final db = await database;
    await db.insert('ai_configs', config, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteAiConfig(String id) async {
    final db = await database;
    await db.delete('ai_configs', where: 'id = ?', whereArgs: [id]);
  }

  // --- Daily Words CRUD ---

  /// Record word count for a day. Accumulates if already exists.
  Future<void> recordDailyWords(String date, String novelId, int wordCount) async {
    final db = await database;
    await db.rawInsert('''
      INSERT INTO daily_words (date, novel_id, word_count)
      VALUES (?, ?, ?)
      ON CONFLICT(date, novel_id) DO UPDATE SET word_count = word_count + ?
    ''', [date, novelId, wordCount, wordCount]);
  }

  /// Get daily word counts for a date range.
  Future<List<Map<String, dynamic>>> getDailyWords({String? startDate, String? endDate}) async {
    final db = await database;
    String where = '';
    List<dynamic> args = [];
    if (startDate != null) {
      where = 'date >= ?';
      args.add(startDate);
    }
    if (endDate != null) {
      where += (where.isEmpty ? '' : ' AND ') + 'date <= ?';
      args.add(endDate);
    }
    return await db.query('daily_words', where: where.isEmpty ? null : where, whereArgs: args.isEmpty ? null : args, orderBy: 'date ASC');
  }

  /// Get total word count across all days.
  Future<int> getTotalWords() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COALESCE(SUM(word_count), 0) as total FROM daily_words');
    return (result.first['total'] as int?) ?? 0;
  }

  /// Get today's word count.
  Future<int> getTodayWords(String date) async {
    final db = await database;
    final result = await db.rawQuery('SELECT COALESCE(SUM(word_count), 0) as total FROM daily_words WHERE date = ?', [date]);
    return (result.first['total'] as int?) ?? 0;
  }
}
