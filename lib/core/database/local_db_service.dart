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
      version: 5,
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

    if (oldVersion < 4) {
      await _createPhase9Tables(db);
    }

    if (oldVersion < 5) {
      await _createPhase11Tables(db);
    }
  }

  Future<void> _createPhase9Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_profiles (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE,
        full_name TEXT,
        avatar_url TEXT,
        institution TEXT,
        degree TEXT,
        branch TEXT,
        semester TEXT,
        is_searchable INTEGER DEFAULT 1,
        allow_group_invites TEXT DEFAULT 'anyone',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_student_profiles_username ON student_profiles(username)');
    } catch (_) {}

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shares (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        recipient_id TEXT,
        resource_type TEXT NOT NULL DEFAULT 'material',
        resource_id TEXT NOT NULL,
        permission TEXT NOT NULL DEFAULT 'view',
        status TEXT NOT NULL DEFAULT 'active',
        message TEXT,
        owner_username TEXT,
        owner_name TEXT,
        recipient_username TEXT,
        resource_title TEXT,
        created_at TEXT NOT NULL,
        expires_at TEXT,
        revoked_at TEXT,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_shares_owner ON shares(owner_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_shares_recipient ON shares(recipient_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_shares_resource ON shares(resource_id)');
    } catch (_) {}

    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_groups (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        member_count INTEGER DEFAULT 1,
        owner_username TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_study_groups_owner ON study_groups(owner_id)');
    } catch (_) {}

    await db.execute('''
      CREATE TABLE IF NOT EXISTS group_members (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        username TEXT,
        full_name TEXT,
        role TEXT NOT NULL DEFAULT 'member',
        status TEXT NOT NULL DEFAULT 'invited',
        created_at TEXT NOT NULL,
        joined_at TEXT,
        UNIQUE(group_id, user_id)
      )
    ''');
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_group_members_group_user ON group_members(group_id, user_id)');
    } catch (_) {}

    await db.execute('''
      CREATE TABLE IF NOT EXISTS group_resources (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        resource_id TEXT NOT NULL,
        resource_type TEXT NOT NULL DEFAULT 'material',
        shared_by TEXT NOT NULL,
        shared_by_username TEXT,
        resource_title TEXT,
        permission TEXT NOT NULL DEFAULT 'view',
        created_at TEXT NOT NULL,
        expires_at TEXT,
        UNIQUE(group_id, resource_id)
      )
    ''');
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_group_resources_group ON group_resources(group_id)');
    } catch (_) {}

    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_packs (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        owner_username TEXT,
        name TEXT NOT NULL,
        description TEXT,
        item_count INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_study_packs_owner ON study_packs(owner_id)');
    } catch (_) {}

    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_pack_items (
        id TEXT PRIMARY KEY,
        study_pack_id TEXT NOT NULL,
        material_id TEXT NOT NULL,
        material_title TEXT,
        material_type TEXT,
        order_index INTEGER DEFAULT 0,
        UNIQUE(study_pack_id, material_id)
      )
    ''');
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_study_pack_items_pack ON study_pack_items(study_pack_id)');
    } catch (_) {}

    await db.execute('''
      CREATE TABLE IF NOT EXISTS share_notifications (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        reference_id TEXT,
        reference_type TEXT,
        is_read INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_share_notifications_user_read ON share_notifications(user_id, is_read)');
    } catch (_) {}
  }

  Future<void> _createPhase11Tables(Database db) async {
    // Document Chunks for Local Vector & Hybrid RAG Retrieval
    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_chunks (
        id TEXT PRIMARY KEY,
        material_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        workspace_id TEXT,
        academic_period_id TEXT,
        subject_id TEXT,
        folder_id TEXT,
        page_number INTEGER DEFAULT 1,
        chunk_index INTEGER DEFAULT 0,
        text TEXT NOT NULL,
        embedding TEXT,
        token_count INTEGER DEFAULT 0,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_doc_chunks_user_material ON document_chunks(user_id, material_id)');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_doc_chunks_user_ws ON document_chunks(user_id, workspace_id)');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_doc_chunks_user_subj ON document_chunks(user_id, subject_id)');
    } catch (_) {}

    // Phase 11 AI Conversation Sessions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_conversations (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        workspace_id TEXT,
        subject_id TEXT,
        material_id TEXT,
        title TEXT NOT NULL,
        mode TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ai_conversations_user ON ai_conversations(user_id)');
    } catch (_) {}

    // Phase 11 AI Messages
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        sources TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ai_messages_conv ON ai_messages(conversation_id)');
    } catch (_) {}

    // Material indexing status columns
    try {
      await db.execute("ALTER TABLE materials ADD COLUMN indexing_status TEXT DEFAULT 'NOT_INDEXED'");
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE materials ADD COLUMN indexing_error TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE materials ADD COLUMN indexed_at TEXT');
    } catch (_) {}

    // AI Study Artifacts: Study Plans & Quizzes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_study_plans (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        workspace_id TEXT,
        subject_id TEXT,
        title TEXT NOT NULL,
        plan_data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_quizzes (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        workspace_id TEXT,
        subject_id TEXT,
        material_id TEXT,
        title TEXT NOT NULL,
        questions_data TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onOpen(Database db) async {
    // Ensure Phase 9 collaboration tables exist
    await _createPhase9Tables(db);
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
        is_inbox INTEGER DEFAULT 0,
        source TEXT,
        import_status TEXT DEFAULT 'imported',
        content_hash TEXT,
        indexing_status TEXT DEFAULT 'NOT_INDEXED',
        indexing_error TEXT,
        indexed_at TEXT,
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
      await db.execute("ALTER TABLE materials ADD COLUMN indexing_status TEXT DEFAULT 'NOT_INDEXED'");
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE materials ADD COLUMN indexing_error TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE materials ADD COLUMN indexed_at TEXT');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_materials_user_inbox ON materials(user_id, is_inbox)');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_materials_hash ON materials(content_hash)');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_materials_user_ws ON materials(user_id, workspace_id)');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_materials_user_subj ON materials(user_id, subject_id)');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_materials_user_folder ON materials(user_id, folder_id)');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_materials_user_period ON materials(user_id, academic_period_id)');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_folders_user_parent ON folders(user_id, parent_id)');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_subjects_user_period ON academic_subjects(user_id, academic_period_id)');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_periods_user_year ON academic_periods(user_id, academic_year_id)');
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

    // Ensure Phase 11 AI & RAG tables exist
    await _createPhase11Tables(db);

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
      await txn.delete('notes', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('files', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('flashcards', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('academic_subjects', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('academic_periods', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('academic_years', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('academic_structures', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('workspaces', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('personal_topics', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('shares', where: 'owner_id = ? OR recipient_id = ?', whereArgs: [userId, userId]);
      await txn.delete('study_pack_items', where: 'study_pack_id IN (SELECT id FROM study_packs WHERE owner_id = ?)', whereArgs: [userId]);
      await txn.delete('study_packs', where: 'owner_id = ?', whereArgs: [userId]);
      await txn.delete('group_resources', where: 'shared_by = ? OR group_id IN (SELECT id FROM study_groups WHERE owner_id = ?)', whereArgs: [userId, userId]);
      await txn.delete('group_members', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('study_groups', where: 'owner_id = ?', whereArgs: [userId]);
      await txn.delete('share_notifications', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('document_chunks', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('ai_conversations', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('ai_messages', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('ai_study_plans', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('ai_quizzes', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('student_profiles', where: 'id = ?', whereArgs: [userId]);
      await txn.delete('sync_metadata', where: 'key LIKE ?', whereArgs: ['%_$userId']);
    });
  }

  /// Exports all local user data in a portable structured map, ensuring zero credentials or secrets are leaked.
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    final db = await database;
    final workspaces = await db.query('workspaces', where: 'user_id = ?', whereArgs: [userId]);
    final years = await db.query('academic_years', where: 'user_id = ?', whereArgs: [userId]);
    final periods = await db.query('academic_periods', where: 'user_id = ?', whereArgs: [userId]);
    final subjects = await db.query('academic_subjects', where: 'user_id = ?', whereArgs: [userId]);
    final folders = await db.query('folders', where: 'user_id = ?', whereArgs: [userId]);
    final materials = await db.query('materials', where: 'user_id = ?', whereArgs: [userId]);
    final labels = await db.query('labels', where: 'user_id = ?', whereArgs: [userId]);
    final notes = await db.query('notes', where: 'user_id = ?', whereArgs: [userId]);
    final files = await db.query('files', where: 'user_id = ?', whereArgs: [userId]);
    final flashcards = await db.query('flashcards', where: 'user_id = ?', whereArgs: [userId]);
    final studyPacks = await db.query('study_packs', where: 'owner_id = ?', whereArgs: [userId]);
    final studyPlans = await db.query('ai_study_plans', where: 'user_id = ?', whereArgs: [userId]);
    final quizzes = await db.query('ai_quizzes', where: 'user_id = ?', whereArgs: [userId]);

    return {
      'user_id': userId,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'version': '1.0.0',
      'workspaces': workspaces,
      'academic_years': years,
      'academic_periods': periods,
      'academic_subjects': subjects,
      'folders': folders,
      'materials': materials,
      'labels': labels,
      'notes': notes,
      'files': files,
      'flashcards': flashcards,
      'study_packs': studyPacks,
      'study_plans': studyPlans,
      'quizzes': quizzes,
    };
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
    await db.transaction((txn) async {
      await txn.delete('folders');
      await txn.delete('notes');
      await txn.delete('files');
      await txn.delete('flashcards');
      await txn.delete('study_stats');
      await txn.delete('scratchpad');
      await txn.delete('exam_goals');
      await txn.delete('outbox_operations');
      await txn.delete('material_labels');
      await txn.delete('materials');
      await txn.delete('labels');
      await txn.delete('academic_subjects');
      await txn.delete('academic_periods');
      await txn.delete('academic_years');
      await txn.delete('academic_structures');
      await txn.delete('workspaces');
      await txn.delete('personal_topics');
      await txn.delete('sync_metadata');
      await txn.delete('student_profiles');
      await txn.delete('shares');
      await txn.delete('study_groups');
      await txn.delete('group_members');
      await txn.delete('group_resources');
      await txn.delete('study_packs');
      await txn.delete('study_pack_items');
      await txn.delete('share_notifications');
      await txn.delete('document_chunks');
      await txn.delete('ai_conversations');
      await txn.delete('ai_messages');
      await txn.delete('ai_study_plans');
      await txn.delete('ai_quizzes');
    });
  }
}
