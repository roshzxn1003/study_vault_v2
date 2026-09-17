import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/academic/domain/models/models.dart';
import 'package:study_vault/features/onboarding/domain/models/onboarding_models.dart';
import 'package:study_vault/features/sync/data/repositories/outbox_repository.dart';
import 'package:study_vault/features/sync/domain/models/outbox_operation.dart';

/// Repository managing academic workspaces, academic years, semesters/classes,
/// subject lifecycle, long-term academic history, and personal learning topics.
class AcademicWorkspaceRepository {
  final LocalDbService _localDb;
  final OutboxRepository _outboxRepo;
  final Uuid _uuid = const Uuid();

  AcademicWorkspaceRepository({
    LocalDbService? localDb,
    OutboxRepository? outboxRepo,
  })  : _localDb = localDb ?? LocalDbService.instance,
        _outboxRepo = outboxRepo ?? OutboxRepository(localDb: localDb ?? LocalDbService.instance);

  // ===========================================================================
  // 1. WORKSPACE INITIALIZATION & MIGRATION
  // ===========================================================================

  /// Ensures user workspaces exist and bootstraps Phase 3 onboarding data
  /// into full Phase 4 academic years and periods.
  Future<void> ensureInitialized({required String userId}) async {
    try {
      final db = await _localDb.database;
      final now = DateTime.now().toIso8601String();

      // Check existing workspaces
      final existingWorkspaces = await db.query(
        'workspaces',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      String workspaceId;
      if (existingWorkspaces.isEmpty) {
        workspaceId = _uuid.v4();
        await db.insert('workspaces', {
          'id': workspaceId,
          'user_id': userId,
          'name': 'My Academic Vault',
          'purpose': 'college',
          'created_at': now,
          'updated_at': now,
        });
      } else {
        workspaceId = existingWorkspaces.first['id'] as String;
      }

      // Check academic structures from Phase 3 onboarding
      final structures = await db.query(
        'academic_structures',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      for (final struct in structures) {
        final structId = struct['id'] as String;
        final structWorkspaceId = struct['workspace_id'] as String? ?? workspaceId;
        final purpose = struct['purpose'] as String? ?? 'college';
        final yearName = (struct['academic_year'] as String?)?.trim() ?? '2026–27';
        final periodName = (struct['semester_or_class'] as String?)?.trim() ??
            (purpose == 'school' ? 'Class 12' : 'Semester 1');

        if (purpose == 'personal' || purpose == 'personal_learning') {
          // Sync any personal learning topics if needed
          continue;
        }

        // 1. Ensure Academic Year exists
        final existingYears = await db.query(
          'academic_years',
          where: 'workspace_id = ? AND year_name = ?',
          whereArgs: [structWorkspaceId, yearName],
        );

        String yearId;
        if (existingYears.isEmpty) {
          yearId = _uuid.v4();
          await db.insert('academic_years', {
            'id': yearId,
            'workspace_id': structWorkspaceId,
            'user_id': userId,
            'year_name': yearName,
            'is_current': 1,
            'created_at': now,
          });
        } else {
          yearId = existingYears.first['id'] as String;
        }

        // 2. Ensure Academic Period exists
        final existingPeriods = await db.query(
          'academic_periods',
          where: 'academic_year_id = ? AND name = ?',
          whereArgs: [yearId, periodName],
        );

        String periodId;
        if (existingPeriods.isEmpty) {
          periodId = _uuid.v4();
          await db.insert('academic_periods', {
            'id': periodId,
            'workspace_id': structWorkspaceId,
            'academic_year_id': yearId,
            'user_id': userId,
            'name': periodName,
            'period_type': purpose == 'school' ? 'class' : 'semester',
            'is_current': 1,
            'created_at': now,
            'updated_at': now,
          });
        } else {
          periodId = existingPeriods.first['id'] as String;
        }

        // 3. Migrate subjects referencing old academic_structure_id to periodId
        await db.update(
          'academic_subjects',
          {
            'academic_period_id': periodId,
            'updated_at': now,
          },
          where: 'academic_structure_id = ? AND (academic_period_id IS NULL OR academic_period_id = "")',
          whereArgs: [structId],
        );
      }
    } catch (e) {
      debugPrint('Error bootstrapping academic workspace: $e');
    }
  }

  // ===========================================================================
  // 2. WORKSPACES
  // ===========================================================================

  /// Fetches all workspaces for the authenticated user.
  Future<List<AcademicWorkspace>> getWorkspaces(String userId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'workspaces',
      where: 'user_id = ? AND deleted_at IS NULL',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => AcademicWorkspace.fromJson(r)).toList();
  }

  /// Creates a new workspace (e.g. for multiple purposes).
  Future<AcademicWorkspace> createWorkspace({
    required String userId,
    required String name,
    required OnboardingPurpose purpose,
  }) async {
    final db = await _localDb.database;
    final now = DateTime.now();
    final workspace = AcademicWorkspace(
      id: _uuid.v4(),
      userId: userId,
      name: name,
      purpose: purpose,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('workspaces', workspace.toJson());

    await _outboxRepo.enqueue(
      userId: userId,
      entityType: 'workspace',
      entityId: workspace.id,
      operation: OutboxOperationType.create,
      payload: workspace.toJson(),
    );

    return workspace;
  }

  // ===========================================================================
  // 3. ACADEMIC STRUCTURE (PROFILES)
  // ===========================================================================

  /// Fetches academic structure metadata (institution, degree, branch, etc.).
  Future<Map<String, dynamic>?> getAcademicStructure(String workspaceId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'academic_structures',
      where: 'workspace_id = ?',
      whereArgs: [workspaceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Updates profile metadata (Degree, Branch, Institution, etc.).
  Future<void> updateAcademicProfile({
    required String structureId,
    String? institutionName,
    String? degree,
    String? branch,
    String? stream,
  }) async {
    final db = await _localDb.database;
    final updates = <String, dynamic>{};
    if (institutionName != null) updates['institution_name'] = institutionName.trim();
    if (degree != null) updates['degree'] = degree.trim();
    if (branch != null) updates['branch'] = branch.trim();
    if (stream != null) updates['stream'] = stream.trim();

    if (updates.isNotEmpty) {
      await db.update(
        'academic_structures',
        updates,
        where: 'id = ?',
        whereArgs: [structureId],
      );
    }
  }

  // ===========================================================================
  // 4. ACADEMIC YEARS & PERIODS
  // ===========================================================================

  /// Fetches all academic years for a workspace.
  Future<List<AcademicYearEntity>> getAcademicYears(String workspaceId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'academic_years',
      where: 'workspace_id = ? AND deleted_at IS NULL',
      whereArgs: [workspaceId],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => AcademicYearEntity.fromJson(r)).toList();
  }

  /// Creates a new academic year.
  Future<AcademicYearEntity> createAcademicYear({
    required String workspaceId,
    required String userId,
    required String yearName,
    bool isCurrent = false,
  }) async {
    final db = await _localDb.database;
    final trimmed = yearName.trim();

    // Check duplicate year name
    final existing = await db.query(
      'academic_years',
      where: 'workspace_id = ? AND year_name = ? AND deleted_at IS NULL',
      whereArgs: [workspaceId, trimmed],
    );
    if (existing.isNotEmpty) {
      return AcademicYearEntity.fromJson(existing.first);
    }

    final entity = AcademicYearEntity(
      id: _uuid.v4(),
      workspaceId: workspaceId,
      userId: userId,
      yearName: trimmed,
      isCurrent: isCurrent,
      createdAt: DateTime.now(),
    );

    await db.insert('academic_years', entity.toJson());

    await _outboxRepo.enqueue(
      userId: userId,
      entityType: 'academic_year',
      entityId: entity.id,
      operation: OutboxOperationType.create,
      payload: entity.toJson(),
    );

    return entity;
  }

  /// Fetches all academic periods for a given year.
  Future<List<AcademicPeriodEntity>> getPeriodsForYear(String academicYearId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'academic_periods',
      where: 'academic_year_id = ? AND deleted_at IS NULL',
      whereArgs: [academicYearId],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => AcademicPeriodEntity.fromJson(r)).toList();
  }

  /// Gets the designated CURRENT academic period for a workspace.
  Future<AcademicPeriodEntity?> getCurrentPeriod(String workspaceId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'academic_periods',
      where: 'workspace_id = ? AND is_current = 1 AND deleted_at IS NULL',
      whereArgs: [workspaceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AcademicPeriodEntity.fromJson(rows.first);
  }

  /// Fetches an academic period by ID.
  Future<AcademicPeriodEntity?> getPeriodById(String periodId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'academic_periods',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [periodId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AcademicPeriodEntity.fromJson(rows.first);
  }

  /// Builds the full academic history tree: years grouped with periods and subject counts.
  Future<List<AcademicYearWithPeriods>> getAcademicHistory(String workspaceId) async {
    final db = await _localDb.database;
    final years = await getAcademicYears(workspaceId);
    final history = <AcademicYearWithPeriods>[];

    for (final year in years) {
      final periods = await getPeriodsForYear(year.id);
      final periodsWithCount = <AcademicPeriodWithCount>[];

      for (final period in periods) {
        final countResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM academic_subjects WHERE academic_period_id = ? AND is_archived = 0 AND deleted_at IS NULL',
          [period.id],
        );
        final count = Sqflite.firstIntValue(countResult) ?? 0;
        periodsWithCount.add(AcademicPeriodWithCount(
          period: period,
          subjectCount: count,
        ));
      }

      history.add(AcademicYearWithPeriods(
        year: year,
        periods: periodsWithCount,
      ));
    }

    return history;
  }

  // ===========================================================================
  // 5. SAFE SEMESTER / CLASS PROGRESSION
  // ===========================================================================

  /// Starts a new academic period (e.g. Semester 4).
  ///
  /// CRITICAL RULES:
  /// - Old period becomes PREVIOUS (is_current = 0).
  /// - New period becomes CURRENT (is_current = 1).
  /// - NEVER moves, renames, merges, or deletes previous subjects.
  /// - Optional copy creates BRAND NEW subject records in the new period.
  Future<AcademicPeriodEntity> startNewPeriod({
    required String workspaceId,
    required String userId,
    required String academicYearId,
    required String newPeriodName,
    AcademicPeriodType periodType = AcademicPeriodType.semester,
    List<String>? subjectsToCopy,
  }) async {
    final db = await _localDb.database;
    final now = DateTime.now();
    final trimmedName = newPeriodName.trim();

    // Check duplicate period name in this academic year
    final existing = await db.query(
      'academic_periods',
      where: 'academic_year_id = ? AND LOWER(name) = ? AND deleted_at IS NULL',
      whereArgs: [academicYearId, trimmedName.toLowerCase()],
    );
    if (existing.isNotEmpty) {
      throw ArgumentError('Academic period "$trimmedName" already exists in this academic year.');
    }

    // 1. Mark all previous periods in workspace as not current
    await db.update(
      'academic_periods',
      {'is_current': 0, 'updated_at': now.toIso8601String()},
      where: 'workspace_id = ? AND deleted_at IS NULL',
      whereArgs: [workspaceId],
    );

    // 2. Create the new current period
    final newPeriodId = _uuid.v4();
    final newPeriod = AcademicPeriodEntity(
      id: newPeriodId,
      workspaceId: workspaceId,
      academicYearId: academicYearId,
      userId: userId,
      name: trimmedName,
      periodType: periodType,
      isCurrent: true,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('academic_periods', newPeriod.toJson());

    await _outboxRepo.enqueue(
      userId: userId,
      entityType: 'academic_period',
      entityId: newPeriodId,
      operation: OutboxOperationType.create,
      payload: newPeriod.toJson(),
    );

    // 3. Keep academic_structures in sync for header widgets
    await db.update(
      'academic_structures',
      {'semester_or_class': trimmedName},
      where: 'workspace_id = ?',
      whereArgs: [workspaceId],
    );

    // 4. Optionally copy subjects: creates BRAND NEW subject records
    if (subjectsToCopy != null && subjectsToCopy.isNotEmpty) {
      for (int i = 0; i < subjectsToCopy.length; i++) {
        final subName = subjectsToCopy[i].trim();
        if (subName.isEmpty) continue;

        // Query metadata from any previous instance
        final prevInstances = await db.query(
          'academic_subjects',
          where: 'user_id = ? AND LOWER(name) = ? AND deleted_at IS NULL',
          whereArgs: [userId, subName.toLowerCase()],
          limit: 1,
        );

        String? code;
        String? desc;
        if (prevInstances.isNotEmpty) {
          code = prevInstances.first['code'] as String?;
          desc = prevInstances.first['description'] as String?;
        }

        // Insert new record specifically tied to newPeriodId
        final subId = _uuid.v4();
        final subjectEntity = AcademicSubjectEntity(
          id: subId,
          academicPeriodId: newPeriodId,
          userId: userId,
          name: subName,
          code: code,
          description: desc,
          orderIndex: i,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        );

        await db.insert('academic_subjects', subjectEntity.toJson());

        await _outboxRepo.enqueue(
          userId: userId,
          entityType: 'subject',
          entityId: subId,
          operation: OutboxOperationType.create,
          payload: subjectEntity.toJson(),
        );
      }
    }

    return newPeriod;
  }

  /// Switches which period is designated as the active CURRENT period.
  Future<void> switchCurrentPeriod({
    required String workspaceId,
    required String targetPeriodId,
  }) async {
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();

    // Verify target exists
    final target = await getPeriodById(targetPeriodId);
    if (target == null) throw ArgumentError('Target academic period not found.');

    // Reset current flag
    await db.update(
      'academic_periods',
      {'is_current': 0, 'updated_at': now},
      where: 'workspace_id = ?',
      whereArgs: [workspaceId],
    );

    // Set new current
    await db.update(
      'academic_periods',
      {'is_current': 1, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [targetPeriodId],
    );

    // Update academic structure semester_or_class
    await db.update(
      'academic_structures',
      {'semester_or_class': target.name},
      where: 'workspace_id = ?',
      whereArgs: [workspaceId],
    );
  }

  // ===========================================================================
  // 6. SUBJECT MANAGEMENT
  // ===========================================================================

  /// Fetches active subjects for a specific academic period.
  Future<List<AcademicSubjectEntity>> getSubjectsForPeriod(String periodId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'academic_subjects',
      where: 'academic_period_id = ? AND is_archived = 0 AND deleted_at IS NULL',
      whereArgs: [periodId],
      orderBy: 'order_index ASC',
    );
    return rows.map((r) => AcademicSubjectEntity.fromJson(r)).toList();
  }

  /// Adds a new subject to an academic period.
  ///
  /// DUPLICATE RULE:
  /// - Duplicate subject in the SAME academic period is PREVENTED.
  /// - Same subject in a DIFFERENT academic period is ALLOWED.
  Future<AcademicSubjectEntity> addSubject({
    required String periodId,
    required String userId,
    required String name,
    String? code,
    String? description,
  }) async {
    final db = await _localDb.database;
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Subject name cannot be empty.');
    }

    // Duplicate check in this period only
    final existing = await db.query(
      'academic_subjects',
      where: 'academic_period_id = ? AND LOWER(name) = ? AND is_archived = 0 AND deleted_at IS NULL',
      whereArgs: [periodId, trimmedName.toLowerCase()],
    );
    if (existing.isNotEmpty) {
      throw ArgumentError('Subject "$trimmedName" already exists in this semester.');
    }

    // Determine next order_index
    final maxOrderQuery = await db.rawQuery(
      'SELECT MAX(order_index) as max_order FROM academic_subjects WHERE academic_period_id = ? AND is_archived = 0 AND deleted_at IS NULL',
      [periodId],
    );
    final maxOrder = Sqflite.firstIntValue(maxOrderQuery) ?? -1;
    final now = DateTime.now();

    final subject = AcademicSubjectEntity(
      id: _uuid.v4(),
      academicPeriodId: periodId,
      userId: userId,
      name: trimmedName,
      code: code?.trim().isEmpty == true ? null : code?.trim(),
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      orderIndex: maxOrder + 1,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('academic_subjects', subject.toJson());

    await _outboxRepo.enqueue(
      userId: userId,
      entityType: 'subject',
      entityId: subject.id,
      operation: OutboxOperationType.create,
      payload: subject.toJson(),
    );

    // Mirror to folders for backwards compatibility
    final existingFolder = await db.query(
      'folders',
      where: 'user_id = ? AND LOWER(name) = ? AND deleted_at IS NULL',
      whereArgs: [userId, trimmedName.toLowerCase()],
    );
    if (existingFolder.isEmpty) {
      final folderId = _uuid.v4();
      final folderData = {
        'id': folderId,
        'user_id': userId,
        'name': trimmedName,
        'parent_id': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'sync_status': 'synced',
      };
      await db.insert('folders', folderData);

      await _outboxRepo.enqueue(
        userId: userId,
        entityType: 'folder',
        entityId: folderId,
        operation: OutboxOperationType.create,
        payload: folderData,
      );
    }

    return subject;
  }

  /// Renames or updates metadata for an existing subject.
  Future<void> renameSubject({
    required String subjectId,
    required String newName,
    String? code,
    String? description,
  }) async {
    final db = await _localDb.database;
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Subject name cannot be empty.');
    }

    // Get current subject
    final rows = await db.query('academic_subjects', where: 'id = ? AND deleted_at IS NULL', whereArgs: [subjectId]);
    if (rows.isEmpty) throw ArgumentError('Subject not found.');
    final current = AcademicSubjectEntity.fromJson(rows.first);

    // Duplicate check excluding self
    if (current.academicPeriodId != null) {
      final duplicate = await db.query(
        'academic_subjects',
        where: 'academic_period_id = ? AND LOWER(name) = ? AND id != ? AND is_archived = 0 AND deleted_at IS NULL',
        whereArgs: [current.academicPeriodId, trimmedName.toLowerCase(), subjectId],
      );
      if (duplicate.isNotEmpty) {
        throw ArgumentError('Subject "$trimmedName" already exists in this semester.');
      }
    }

    final nowIso = DateTime.now().toIso8601String();
    final updates = <String, dynamic>{
      'name': trimmedName,
      'code': code?.trim().isEmpty == true ? null : code?.trim(),
      'description': description?.trim().isEmpty == true ? null : description?.trim(),
      'updated_at': nowIso,
    };

    await db.update('academic_subjects', updates, where: 'id = ?', whereArgs: [subjectId]);

    await _outboxRepo.enqueue(
      userId: current.userId,
      entityType: 'subject',
      entityId: subjectId,
      operation: OutboxOperationType.update,
      payload: {
        'id': subjectId,
        'name': trimmedName,
        'code': code?.trim().isEmpty == true ? null : code?.trim(),
        'description': description?.trim().isEmpty == true ? null : description?.trim(),
        'updated_at': nowIso,
      },
    );
  }

  /// Safely archives a subject without deleting associated future materials.
  Future<void> removeSubject(String subjectId) async {
    final db = await _localDb.database;
    final rows = await db.query('academic_subjects', where: 'id = ?', whereArgs: [subjectId]);
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'academic_subjects',
      {
        'is_archived': 1,
        'deleted_at': nowIso,
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [subjectId],
    );

    if (rows.isNotEmpty) {
      final userId = rows.first['user_id'] as String;
      await _outboxRepo.enqueue(
        userId: userId,
        entityType: 'subject',
        entityId: subjectId,
        operation: OutboxOperationType.delete,
      );
    }
  }

  /// Reorders subjects for clean presentation.
  Future<void> reorderSubjects({
    required String periodId,
    required List<String> orderedSubjectIds,
  }) async {
    final db = await _localDb.database;
    final batch = db.batch();
    for (int i = 0; i < orderedSubjectIds.length; i++) {
      batch.update(
        'academic_subjects',
        {'order_index': i},
        where: 'id = ?',
        whereArgs: [orderedSubjectIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  // ===========================================================================
  // 7. PERSONAL LEARNING TOPICS
  // ===========================================================================

  /// Fetches topics for a Personal Learning workspace.
  Future<List<PersonalTopicEntity>> getPersonalTopics(String workspaceId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'personal_topics',
      where: 'workspace_id = ? AND deleted_at IS NULL',
      whereArgs: [workspaceId],
      orderBy: 'order_index ASC',
    );
    return rows.map((r) => PersonalTopicEntity.fromJson(r)).toList();
  }

  /// Adds a learning topic with duplicate check.
  Future<PersonalTopicEntity> addPersonalTopic({
    required String workspaceId,
    required String userId,
    required String name,
    String? description,
  }) async {
    final db = await _localDb.database;
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Topic name cannot be empty.');

    final existing = await db.query(
      'personal_topics',
      where: 'workspace_id = ? AND LOWER(name) = ? AND deleted_at IS NULL',
      whereArgs: [workspaceId, trimmed.toLowerCase()],
    );
    if (existing.isNotEmpty) {
      throw ArgumentError('Topic "$trimmed" already added.');
    }

    final maxOrderQuery = await db.rawQuery(
      'SELECT MAX(order_index) as max_order FROM personal_topics WHERE workspace_id = ? AND deleted_at IS NULL',
      [workspaceId],
    );
    final maxOrder = Sqflite.firstIntValue(maxOrderQuery) ?? -1;
    final now = DateTime.now();

    final topic = PersonalTopicEntity(
      id: _uuid.v4(),
      workspaceId: workspaceId,
      userId: userId,
      name: trimmed,
      description: description?.trim(),
      orderIndex: maxOrder + 1,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('personal_topics', topic.toJson());

    await _outboxRepo.enqueue(
      userId: userId,
      entityType: 'personal_topic',
      entityId: topic.id,
      operation: OutboxOperationType.create,
      payload: topic.toJson(),
    );

    return topic;
  }

  /// Renames a personal topic.
  Future<void> renamePersonalTopic({
    required String topicId,
    required String newName,
  }) async {
    final db = await _localDb.database;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw ArgumentError('Topic name cannot be empty.');

    final current = await db.query('personal_topics', where: 'id = ? AND deleted_at IS NULL', whereArgs: [topicId]);
    if (current.isEmpty) throw ArgumentError('Topic not found.');
    final workspaceId = current.first['workspace_id'] as String;
    final userId = current.first['user_id'] as String;

    final duplicate = await db.query(
      'personal_topics',
      where: 'workspace_id = ? AND LOWER(name) = ? AND id != ? AND deleted_at IS NULL',
      whereArgs: [workspaceId, trimmed.toLowerCase(), topicId],
    );
    if (duplicate.isNotEmpty) {
      throw ArgumentError('Topic "$trimmed" already exists.');
    }

    final nowIso = DateTime.now().toIso8601String();
    await db.update(
      'personal_topics',
      {'name': trimmed, 'updated_at': nowIso},
      where: 'id = ?',
      whereArgs: [topicId],
    );

    await _outboxRepo.enqueue(
      userId: userId,
      entityType: 'personal_topic',
      entityId: topicId,
      operation: OutboxOperationType.update,
      payload: {
        'id': topicId,
        'name': trimmed,
        'updated_at': nowIso,
      },
    );
  }

  /// Removes a personal topic.
  Future<void> removePersonalTopic(String topicId) async {
    final db = await _localDb.database;
    final current = await db.query('personal_topics', where: 'id = ?', whereArgs: [topicId]);
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'personal_topics',
      {
        'deleted_at': nowIso,
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [topicId],
    );

    if (current.isNotEmpty) {
      final userId = current.first['user_id'] as String;
      await _outboxRepo.enqueue(
        userId: userId,
        entityType: 'personal_topic',
        entityId: topicId,
        operation: OutboxOperationType.delete,
      );
    }
  }

  /// Reorders personal topics.
  Future<void> reorderPersonalTopics({
    required String workspaceId,
    required List<String> orderedTopicIds,
  }) async {
    final db = await _localDb.database;
    final batch = db.batch();
    for (int i = 0; i < orderedTopicIds.length; i++) {
      batch.update(
        'personal_topics',
        {'order_index': i},
        where: 'id = ?',
        whereArgs: [orderedTopicIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }
}
