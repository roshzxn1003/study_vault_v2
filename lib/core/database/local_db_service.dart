import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  static LocalDbService get instance => _instance;

  LocalDbService._internal();

  Database? _database;
  String? _customPath;

  @visibleForTesting
  void setCustomPathForTesting(String? path) {
    _customPath = path;
    _database = null;
  }

  @visibleForTesting
  Future<void> closeForTesting() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = _customPath ?? join(await getDatabasesPath(), 'study_vault_local.db');
    return await openDatabase(
      path,
      version: 3,
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

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS outbox_operations (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          operation TEXT NOT NULL,
          payload TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          attempt_count INTEGER DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'pending',
          last_error TEXT,
          next_retry_at TEXT
        )
      ''');
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_outbox_user_status ON outbox_operations(user_id, status)');
      } catch (_) {}
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_outbox_retry ON outbox_operations(status, next_retry_at)');
      } catch (_) {}

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_metadata (
          key TEXT PRIMARY KEY,
          value TEXT,
          updated_at TEXT NOT NULL
        )
      ''');

      const tables = [
        'workspaces',
        'academic_years',
        'academic_periods',
        'academic_subjects',
        'folders',
        'materials',
        'labels',
        'material_labels',
        'personal_topics',
      ];
      for (final tbl in tables) {
        try {
          await db.execute('ALTER TABLE $tbl ADD COLUMN deleted_at TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE $tbl ADD COLUMN remote_updated_at TEXT');
        } catch (_) {}
      }
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workspaces (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT,
        purpose TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    try {
      await db.execute('ALTER TABLE workspaces ADD COLUMN purpose TEXT');
    } catch (_) {}

    await db.execute('''
      CREATE TABLE IF NOT EXISTS academic_structures (
        id TEXT PRIMARY KEY,
        workspace_id TEXT,
        user_id TEXT,
        purpose TEXT,
        institution_name TEXT,
        degree TEXT,
        branch TEXT,
        academic_year TEXT,
        semester_or_class TEXT,
        stream TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS academic_years (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        year_name TEXT NOT NULL,
        is_current INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS academic_periods (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        academic_year_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        period_type TEXT NOT NULL,
        is_current INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS academic_subjects (
        id TEXT PRIMARY KEY,
        academic_structure_id TEXT,
        academic_period_id TEXT,
        user_id TEXT,
        name TEXT,
        code TEXT,
        description TEXT,
        order_index INTEGER DEFAULT 0,
        is_archived INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    try {
      await db.execute('ALTER TABLE academic_subjects ADD COLUMN academic_period_id TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE academic_subjects ADD COLUMN code TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE academic_subjects ADD COLUMN description TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE academic_subjects ADD COLUMN is_archived INTEGER DEFAULT 0');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE academic_subjects ADD COLUMN updated_at TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE files ADD COLUMN subject_id TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE notes ADD COLUMN subject_id TEXT');
    } catch (_) {}

    // Phase 6: Folders enhancements
    try {
      await db.execute('ALTER TABLE folders ADD COLUMN workspace_id TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE folders ADD COLUMN academic_period_id TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE folders ADD COLUMN subject_id TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE folders ADD COLUMN order_index INTEGER DEFAULT 0');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE folders ADD COLUMN is_archived INTEGER DEFAULT 0');
    } catch (_) {}

    // Phase 6: Materials library
    await db.execute('''
      CREATE TABLE IF NOT EXISTS materials (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        workspace_id TEXT,
        academic_period_id TEXT,
        subject_id TEXT,
        folder_id TEXT,
        title TEXT NOT NULL,
        description TEXT,
        original_file_name TEXT,
        type TEXT NOT NULL,
        content TEXT,
        file_path TEXT,
        storage_path TEXT,
        mime_type TEXT,
        file_size INTEGER DEFAULT 0,
        remote_url TEXT,
        is_favorite INTEGER DEFAULT 0,
        is_archived INTEGER DEFAULT 0,
        last_opened_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');

    // Phase 6: Labels & Many-to-Many Material-Label associations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS labels (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        workspace_id TEXT,
        name TEXT NOT NULL,
        color_hex TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS material_labels (
        material_id TEXT NOT NULL,
        label_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY (material_id, label_id)
      )
    ''');

    // Phase 7: Universal Import & Inbox support
    try {
      await db.execute('ALTER TABLE materials ADD COLUMN is_inbox INTEGER DEFAULT 0');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE materials ADD COLUMN source TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE materials ADD COLUMN import_status TEXT DEFAULT "imported"');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE materials ADD COLUMN content_hash TEXT');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_materials_user_inbox ON materials(user_id, is_inbox)');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_materials_hash ON materials(content_hash)');
    } catch (_) {}

    await db.execute('''
      CREATE TABLE IF NOT EXISTS personal_topics (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        order_index INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Safe migration from legacy files and notes into materials if not already present
    try {
      await db.execute('''
        INSERT OR IGNORE INTO materials (
          id, user_id, subject_id, folder_id, title, original_file_name, type, storage_path, mime_type, file_size, created_at, updated_at, sync_status
        )
        SELECT id, user_id, subject_id, folder_id, name, name, 'PDF', storage_path, mime_type, file_size, created_at, updated_at, sync_status FROM files;
      ''');
      await db.execute('''
        INSERT OR IGNORE INTO materials (
          id, user_id, subject_id, folder_id, title, original_file_name, type, content, created_at, updated_at, sync_status
        )
        SELECT id, user_id, subject_id, folder_id, title, title, 'NOTE', content, created_at, updated_at, sync_status FROM notes;
      ''');
    } catch (_) {}

    // Phase 8: Outbox pattern for reliable offline-first sync
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outbox_operations (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        attempt_count INTEGER DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        last_error TEXT,
        next_retry_at TEXT
      )
    ''');
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_outbox_user_status ON outbox_operations(user_id, status)');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_outbox_retry ON outbox_operations(status, next_retry_at)');
    } catch (_) {}

    // Phase 8: Sync Metadata
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    const synchronizableTables = [
      'workspaces',
      'academic_years',
      'academic_periods',
      'academic_subjects',
      'folders',
      'materials',
      'labels',
      'material_labels',
      'personal_topics',
    ];
    for (final tbl in synchronizableTables) {
      try {
        await db.execute('ALTER TABLE $tbl ADD COLUMN deleted_at TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE $tbl ADD COLUMN remote_updated_at TEXT');
      } catch (_) {}
    }

    // Clean up any legacy preseeded items if they exist
    await db.delete('folders', where: "id IN ('folder_dbms', 'folder_os', 'folder_cn', 'folder_ai')");
    await db.delete('files', where: "id IN ('file_dbms_1', 'file_dbms_2', 'file_os_1', 'file_cn_1')");
    await db.delete('notes', where: "id IN ('note_acid', 'note_deadlock', 'note_tcp')");
  }

  /// Securely purges all user-scoped records from local storage on logout/account switch.
  Future<void> clearUserData(String userId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('outbox_operations', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('material_labels', where: 'material_id IN (SELECT id FROM materials WHERE user_id = ?)', whereArgs: [userId]);
      await txn.delete('materials', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('folders', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('labels', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('academic_subjects', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('academic_periods', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('academic_years', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('academic_structures', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('workspaces', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('personal_topics', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('sync_metadata', where: 'key LIKE ?', whereArgs: ['%_$userId']);
    });
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
