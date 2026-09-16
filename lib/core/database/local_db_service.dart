import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  static LocalDbService get instance => _instance;

  LocalDbService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'study_vault_local.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Folders
    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT,
        parent_id TEXT,
        created_at TEXT,
        updated_at TEXT,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');

    // Notes
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        folder_id TEXT,
        title TEXT,
        content TEXT,
        created_at TEXT,
        updated_at TEXT,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');

    // File Metadata
    await db.execute('''
      CREATE TABLE files (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        folder_id TEXT,
        name TEXT,
        storage_path TEXT,
        mime_type TEXT,
        file_size INTEGER DEFAULT 0,
        file_type TEXT DEFAULT 'PDF',
        created_at TEXT,
        updated_at TEXT,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');

    // Flashcards
    await db.execute('''
      CREATE TABLE IF NOT EXISTS flashcards (
        id TEXT PRIMARY KEY,
        user_id TEXT DEFAULT 'guest',
        folder_id TEXT,
        topic TEXT,
        front TEXT,
        back TEXT,
        mastery_level INTEGER DEFAULT 0,
        created_at TEXT,
        last_reviewed TEXT
      )
    ''');

    // Study Activity & Stats
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_stats (
        key TEXT PRIMARY KEY,
        value_int INTEGER DEFAULT 0,
        value_text TEXT,
        updated_at TEXT
      )
    ''');

    // Quick Scratchpad / Sticky Notes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scratchpad (
        id TEXT PRIMARY KEY,
        title TEXT,
        content TEXT,
        updated_at TEXT
      )
    ''');

    // Exam Goals
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exam_goals (
        id TEXT PRIMARY KEY,
        title TEXT,
        subject TEXT,
        target_date TEXT,
        syllabus_percent INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS flashcards (
          id TEXT PRIMARY KEY,
          user_id TEXT DEFAULT 'guest',
          folder_id TEXT,
          topic TEXT,
          front TEXT,
          back TEXT,
          mastery_level INTEGER DEFAULT 0,
          created_at TEXT,
          last_reviewed TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS study_stats (
          key TEXT PRIMARY KEY,
          value_int INTEGER DEFAULT 0,
          value_text TEXT,
          updated_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS scratchpad (
          id TEXT PRIMARY KEY,
          title TEXT,
          content TEXT,
          updated_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS exam_goals (
          id TEXT PRIMARY KEY,
          title TEXT,
          subject TEXT,
          target_date TEXT,
          syllabus_percent INTEGER DEFAULT 0,
          created_at TEXT
        )
      ''');
    }
  }

  Future<void> _onOpen(Database db) async {
    // Ensure all tables exist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS flashcards (
        id TEXT PRIMARY KEY,
        user_id TEXT DEFAULT 'guest',
        folder_id TEXT,
        topic TEXT,
        front TEXT,
        back TEXT,
        mastery_level INTEGER DEFAULT 0,
        created_at TEXT,
        last_reviewed TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_stats (
        key TEXT PRIMARY KEY,
        value_int INTEGER DEFAULT 0,
        value_text TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scratchpad (
        id TEXT PRIMARY KEY,
        title TEXT,
        content TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exam_goals (
        id TEXT PRIMARY KEY,
        title TEXT,
        subject TEXT,
        target_date TEXT,
        syllabus_percent INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    // Clean up any legacy preseeded items if they exist
    await db.delete('folders', where: "id IN ('folder_dbms', 'folder_os', 'folder_cn', 'folder_ai')");
    await db.delete('files', where: "id IN ('file_dbms_1', 'file_dbms_2', 'file_os_1', 'file_cn_1')");
    await db.delete('notes', where: "id IN ('note_acid', 'note_deadlock', 'note_tcp')");
  }

  // --- STATS & METRICS ---
  Future<Map<String, dynamic>> getVaultStats() async {
    final db = await database;
    final folderCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM folders')) ?? 0;
    final noteCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM notes')) ?? 0;
    final fileCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM files')) ?? 0;
    final cardCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM flashcards')) ?? 0;

    final streakRow = await db.query('study_stats', where: 'key = ?', whereArgs: ['streak_days']);
    final streak = streakRow.isNotEmpty ? (streakRow.first['value_int'] as int? ?? 1) : 1;

    final dailyDoneRow = await db.query('study_stats', where: 'key = ?', whereArgs: ['today_actions']);
    final dailyDone = dailyDoneRow.isNotEmpty ? (dailyDoneRow.first['value_int'] as int? ?? 0) : 0;

    return {
      'folderCount': folderCount,
      'noteCount': noteCount,
      'fileCount': fileCount,
      'cardCount': cardCount,
      'streak': streak < 1 ? 1 : streak,
      'dailyProgress': (dailyDone / 5.0).clamp(0.0, 1.0),
      'dailyActions': dailyDone,
    };
  }

  Future<void> recordStudyAction(String actionType) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.rawInsert('''
      INSERT INTO study_stats (key, value_int, updated_at)
      VALUES ('today_actions', 1, ?)
      ON CONFLICT(key) DO UPDATE SET value_int = value_int + 1, updated_at = ?
    ''', [now, now]);

    await db.rawInsert('''
      INSERT INTO study_stats (key, value_int, updated_at)
      VALUES ('total_study_actions', 1, ?)
      ON CONFLICT(key) DO UPDATE SET value_int = value_int + 1, updated_at = ?
    ''', [now, now]);
  }

  // --- FLASHCARDS ---
  Future<List<Map<String, dynamic>>> getFlashcards({String? topic}) async {
    final db = await database;
    if (topic != null && topic.isNotEmpty) {
      return await db.query('flashcards', where: 'topic = ?', whereArgs: [topic], orderBy: 'created_at DESC');
    }
    return await db.query('flashcards', orderBy: 'created_at DESC');
  }

  Future<void> saveFlashcards(List<Map<String, dynamic>> cards) async {
    final db = await database;
    final batch = db.batch();
    for (final c in cards) {
      batch.insert('flashcards', c, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // --- SCRATCHPAD ---
  Future<String> getScratchpadContent() async {
    final db = await database;
    final rows = await db.query('scratchpad', where: 'id = ?', whereArgs: ['main_scratchpad']);
    if (rows.isNotEmpty) {
      return rows.first['content'] as String? ?? '';
    }
    return '';
  }

  Future<void> saveScratchpadContent(String content) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('scratchpad', {
      'id': 'main_scratchpad',
      'title': 'Quick Scratchpad',
      'content': content,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- EXAM GOALS ---
  Future<List<Map<String, dynamic>>> getExamGoals() async {
    final db = await database;
    return await db.query('exam_goals', orderBy: 'target_date ASC');
  }

  Future<void> saveExamGoal({
    required String id,
    required String title,
    required String subject,
    required String targetDate,
    int syllabusPercent = 0,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('exam_goals', {
      'id': id,
      'title': title,
      'subject': subject,
      'target_date': targetDate,
      'syllabus_percent': syllabusPercent,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteExamGoal(String id) async {
    final db = await database;
    await db.delete('exam_goals', where: 'id = ?', whereArgs: [id]);
  }

  // --- CLEAR ALL DATA ---
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('folders');
    await db.delete('notes');
    await db.delete('files');
    await db.delete('flashcards');
    await db.delete('study_stats');
    await db.delete('scratchpad');
    await db.delete('exam_goals');
  }
}
