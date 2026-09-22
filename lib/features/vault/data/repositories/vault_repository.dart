import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/sync/data/repositories/outbox_repository.dart';
import 'package:study_vault/features/sync/domain/models/outbox_operation.dart';
import '../../domain/models/models.dart';

/// Repository coordinating Vault materials, hierarchical folders, and academic labels.
/// Strictly enforces zero fake data generation and relational integrity.
class VaultRepository {
  final LocalDbService _localDb;
  final OutboxRepository _outboxRepo;
  static const _uuid = Uuid();

  VaultRepository({
    LocalDbService? localDb,
    OutboxRepository? outboxRepo,
  })  : _localDb = localDb ?? LocalDbService.instance,
        _outboxRepo = outboxRepo ?? OutboxRepository(localDb: localDb ?? LocalDbService.instance);

  // ===========================================================================
  // 1. INITIALIZATION & DEFAULT LABELS
  // ===========================================================================

  /// Seeds standard default academic labels for the user if none exist.
  Future<void> ensureInitialized({
    required String userId,
    String? workspaceId,
  }) async {
    final db = await _localDb.database;

    final existing = await db.query(
      'labels',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (existing.isEmpty) {
      final defaultLabels = [
        {'name': 'Notes', 'color': '#3B82F6'},
        {'name': 'Assignment', 'color': '#F59E0B'},
        {'name': 'Exam', 'color': '#EF4444'},
        {'name': 'Revision', 'color': '#10B981'},
        {'name': 'Important', 'color': '#EC4899'},
        {'name': 'Lab', 'color': '#8B5CF6'},
        {'name': 'Question Paper', 'color': '#6366F1'},
        {'name': 'Reference', 'color': '#14B8A6'},
        {'name': 'Project', 'color': '#F97316'},
      ];

      final now = DateTime.now().toIso8601String();
      final batch = db.batch();
      for (final dl in defaultLabels) {
        batch.insert('labels', {
          'id': _uuid.v4(),
          'user_id': userId,
          'workspace_id': workspaceId,
          'name': dl['name'],
          'color_hex': dl['color'],
          'created_at': now,
          'updated_at': now,
        });
      }
      await batch.commit(noResult: true);
    }
  }

  // ===========================================================================
  // 2. LABELS CRUD
  // ===========================================================================

  /// Fetches all available labels for the user.
  Future<List<VaultLabel>> getLabels({
    required String userId,
    String? workspaceId,
  }) async {
    final db = await _localDb.database;
    String where = 'user_id = ? AND deleted_at IS NULL';
    List<dynamic> whereArgs = [userId];

    if (workspaceId != null) {
      where += ' AND (workspace_id IS NULL OR workspace_id = ?)';
      whereArgs.add(workspaceId);
    }

    final rows = await db.query(
      'labels',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map((r) => VaultLabel.fromMap(r)).toList();
  }

  /// Creates a new custom label.
  Future<VaultLabel> createLabel({
    required String userId,
    required String name,
    String? colorHex,
    String? workspaceId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Label name cannot be empty.');
    }

    final db = await _localDb.database;
    final now = DateTime.now();
    final label = VaultLabel(
      id: _uuid.v4(),
      userId: userId,
      workspaceId: workspaceId,
      name: trimmed,
      colorHex: colorHex ?? '#6366F1',
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('labels', label.toMap());

    await _outboxRepo.enqueue(
      userId: userId,
      entityType: 'label',
      entityId: label.id,
      operation: OutboxOperationType.create,
      payload: label.toMap(),
    );

    return label;
  }

  /// Renames an existing label.
  Future<void> renameLabel(String labelId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Label name cannot be empty.');
    }

    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'labels',
      {
        'name': trimmed,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [labelId],
    );

    final row = await db.query('labels', where: 'id = ?', whereArgs: [labelId]);
    if (row.isNotEmpty) {
      final userId = row.first['user_id'] as String;
      await _outboxRepo.enqueue(
        userId: userId,
        entityType: 'label',
        entityId: labelId,
        operation: OutboxOperationType.update,
        payload: Map<String, dynamic>.from(row.first),
      );
    }
  }

  /// Deletes a label without affecting underlying materials.
  Future<void> deleteLabel(String labelId) async {
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();
    final row = await db.query('labels', where: 'id = ?', whereArgs: [labelId]);
    final userId = row.isNotEmpty ? (row.first['user_id'] as String) : 'default_user';

    await db.transaction((txn) async {
      await txn.update(
        'labels',
        {'deleted_at': now},
        where: 'id = ?',
        whereArgs: [labelId],
      );
      await txn.update(
        'material_labels',
        {'deleted_at': now},
        where: 'label_id = ?',
        whereArgs: [labelId],
      );
    });

    await _outboxRepo.enqueue(
      userId: userId,
      entityType: 'label',
      entityId: labelId,
      operation: OutboxOperationType.delete,
    );
  }

  /// Fetches all labels attached to a specific material.
  Future<List<VaultLabel>> getMaterialLabels(String materialId) async {
    final db = await _localDb.database;
    final rows = await db.rawQuery('''
      SELECT l.* FROM labels l
      INNER JOIN material_labels ml ON ml.label_id = l.id
      WHERE ml.material_id = ? AND l.deleted_at IS NULL AND ml.deleted_at IS NULL
      ORDER BY l.name COLLATE NOCASE ASC
    ''', [materialId]);

    return rows.map((r) => VaultLabel.fromMap(r)).toList();
  }

  /// Sets all labels for a material in a single transaction.
  Future<void> setMaterialLabels(String materialId, List<String> labelIds) async {
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete('material_labels', where: 'material_id = ?', whereArgs: [materialId]);
      for (final lid in labelIds) {
        await txn.insert('material_labels', {
          'material_id': materialId,
          'label_id': lid,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  /// Adds a single label to a material.
  Future<void> addLabelToMaterial(String materialId, String labelId) async {
    final db = await _localDb.database;
    await db.insert('material_labels', {
      'material_id': materialId,
      'label_id': labelId,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Removes a label from a material.
  Future<void> removeLabelFromMaterial(String materialId, String labelId) async {
    final db = await _localDb.database;
    await db.delete(
      'material_labels',
      where: 'material_id = ? AND label_id = ?',
      whereArgs: [materialId, labelId],
    );
  }

  // ===========================================================================
  // 3. FOLDERS CRUD & HIERARCHY
  // ===========================================================================

  /// Fetches folders matching given criteria, with real material and subfolder counts.
  Future<List<VaultFolder>> getFolders({
    required String userId,
    String? workspaceId,
    String? subjectId,
    String? parentId,
  }) async {
    final db = await _localDb.database;

    final whereParts = <String>['user_id = ?', 'is_archived = 0', 'deleted_at IS NULL'];
    final whereArgs = <dynamic>[userId];

    if (workspaceId != null) {
      whereParts.add('workspace_id = ?');
      whereArgs.add(workspaceId);
    }
    if (subjectId != null) {
      whereParts.add('subject_id = ?');
      whereArgs.add(subjectId);
    }
    if (parentId != null) {
      whereParts.add('parent_id = ?');
      whereArgs.add(parentId);
    } else {
      whereParts.add('(parent_id IS NULL OR parent_id = \'\')');
    }

    final rows = await db.query(
      'folders',
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'order_index ASC, name COLLATE NOCASE ASC',
    );

    if (rows.isEmpty) return [];

    // Aggregate material and subfolder counts for each folder
    final folderIds = rows.map((r) => r['id'] as String).toList();
    final placeholders = List.filled(folderIds.length, '?').join(',');

    final matCountMap = <String, int>{};
    try {
      final matRows = await db.rawQuery('''
        SELECT folder_id, COUNT(*) as cnt
        FROM materials
        WHERE folder_id IN ($placeholders) AND is_archived = 0 AND deleted_at IS NULL
        GROUP BY folder_id
      ''', folderIds);
      for (final r in matRows) {
        final fId = r['folder_id'] as String?;
        final cnt = (r['cnt'] as num?)?.toInt() ?? 0;
        if (fId != null) matCountMap[fId] = cnt;
      }
    } catch (e) {
      debugPrint('VaultRepository: Error counting folder contents: $e');
    }

    final subCountMap = <String, int>{};
    try {
      final subRows = await db.rawQuery('''
        SELECT parent_id, COUNT(*) as cnt
        FROM folders
        WHERE parent_id IN ($placeholders) AND is_archived = 0 AND deleted_at IS NULL
        GROUP BY parent_id
      ''', folderIds);
      for (final r in subRows) {
        final pId = r['parent_id'] as String?;
        final cnt = (r['cnt'] as num?)?.toInt() ?? 0;
        if (pId != null) subCountMap[pId] = cnt;
      }
    } catch (e) {
      debugPrint('VaultRepository: Error counting folder contents: $e');
    }

    return rows.map((r) {
      final id = r['id'] as String;
      return VaultFolder.fromMap(
        r,
        materialCount: matCountMap[id] ?? 0,
        subfolderCount: subCountMap[id] ?? 0,
      );
    }).toList();
  }

  /// Fetches a single folder by ID.
  Future<VaultFolder?> getFolderById(String folderId) async {
    final db = await _localDb.database;
    final rows = await db.query('folders', where: 'id = ? AND deleted_at IS NULL', whereArgs: [folderId]);
    if (rows.isEmpty) return null;

    final counts = await getFolderContentCounts(folderId);
    return VaultFolder.fromMap(
      rows.first,
      materialCount: counts['materials'] ?? 0,
      subfolderCount: counts['subfolders'] ?? 0,
    );
  }

  /// Retrieves the hierarchical breadcrumb trail from root to the given folder.
  Future<List<VaultFolder>> getBreadcrumbs(String folderId) async {
    final db = await _localDb.database;
    final trail = <VaultFolder>[];

    String? currentId = folderId;
    while (currentId != null && currentId.isNotEmpty) {
      final rows = await db.query('folders', where: 'id = ? AND deleted_at IS NULL', whereArgs: [currentId]);
      if (rows.isEmpty) break;
      final folder = VaultFolder.fromMap(rows.first);
      trail.insert(0, folder);
      currentId = folder.parentId;
    }

    return trail;
  }

  /// Creates a new user folder with non-empty name validation.
  Future<VaultFolder> createFolder({
    required String userId,
    required String name,
    String? workspaceId,
    String? academicPeriodId,
    String? subjectId,
    String? parentId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Folder name cannot be empty.');
    }

    final db = await _localDb.database;
    final now = DateTime.now();
    final folder = VaultFolder(
      id: _uuid.v4(),
      userId: userId,
      workspaceId: workspaceId,
      academicPeriodId: academicPeriodId,
      subjectId: subjectId,
      name: trimmed,
      parentId: parentId,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('folders', folder.toMap());

    await _outboxRepo.enqueue(
      userId: userId,
      entityType: 'folder',
      entityId: folder.id,
      operation: OutboxOperationType.create,
      payload: folder.toMap(),
    );

    return folder;
  }

  /// Renames an existing folder safely.
  Future<void> renameFolder(String folderId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Folder name cannot be empty.');
    }

    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'folders',
      {
        'name': trimmed,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [folderId],
    );

    final f = await getFolderById(folderId);
    if (f != null) {
      await _outboxRepo.enqueue(
        userId: f.userId,
        entityType: 'folder',
        entityId: folderId,
        operation: OutboxOperationType.update,
        payload: f.toMap(),
      );
    }
  }

  /// Moves a folder to a new parent folder, with strict cycle prevention.
  Future<void> moveFolder(String folderId, String? newParentId) async {
    if (newParentId == folderId) {
      throw ArgumentError('A folder cannot be moved into itself.');
    }

    final db = await _localDb.database;

    // Check if newParentId is a descendant of folderId (Cycle Prevention)
    if (newParentId != null && newParentId.isNotEmpty) {
      String? checkId = newParentId;
      while (checkId != null && checkId.isNotEmpty) {
        if (checkId == folderId) {
          throw ArgumentError('A folder cannot be moved into one of its subfolders.');
        }
        final parentRows = await db.query(
          'folders',
          columns: ['parent_id'],
          where: 'id = ?',
          whereArgs: [checkId],
        );
        if (parentRows.isEmpty) break;
        checkId = parentRows.first['parent_id'] as String?;
      }
    }

    final now = DateTime.now().toIso8601String();
    await db.update(
      'folders',
      {
        'parent_id': newParentId,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [folderId],
    );

    final f = await getFolderById(folderId);
    if (f != null) {
      await _outboxRepo.enqueue(
        userId: f.userId,
        entityType: 'folder',
        entityId: folderId,
        operation: OutboxOperationType.update,
        payload: f.toMap(),
      );
    }
  }

  /// Returns real counts of materials and subfolders inside a folder.
  Future<Map<String, int>> getFolderContentCounts(String folderId) async {
    final db = await _localDb.database;

    final matCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM materials WHERE folder_id = ? AND is_archived = 0 AND deleted_at IS NULL',
      [folderId],
    )) ?? 0;

    final subCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM folders WHERE parent_id = ? AND is_archived = 0 AND deleted_at IS NULL',
      [folderId],
    )) ?? 0;

    return {'materials': matCount, 'subfolders': subCount};
  }

  /// Soft deletes a folder with safe handling of its contents and enqueues outbox operation.
  Future<void> deleteFolder(
    String folderId, {
    bool deleteContents = false,
    String? moveContentsToParentId,
  }) async {
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();

    final target = await getFolderById(folderId);
    final userId = target?.userId ?? 'default_user';

    await db.transaction((txn) async {
      if (moveContentsToParentId != null) {
        // Move all materials and subfolders to destination parent
        await txn.update(
          'materials',
          {'folder_id': moveContentsToParentId, 'updated_at': now},
          where: 'folder_id = ? AND deleted_at IS NULL',
          whereArgs: [folderId],
        );
        await txn.update(
          'folders',
          {'parent_id': moveContentsToParentId, 'updated_at': now},
          where: 'parent_id = ? AND deleted_at IS NULL',
          whereArgs: [folderId],
        );
      } else if (deleteContents) {
        // Recursively delete subfolders and materials
        final subfolders = await txn.query(
          'folders',
          columns: ['id'],
          where: 'parent_id = ? AND deleted_at IS NULL',
          whereArgs: [folderId],
        );
        for (final sub in subfolders) {
          final sId = sub['id'] as String;
          await deleteFolder(sId, deleteContents: true);
        }

        // Soft-delete materials in this folder
        await txn.update(
          'materials',
          {'deleted_at': now, 'sync_status': 'pending'},
          where: 'folder_id = ? AND deleted_at IS NULL',
          whereArgs: [folderId],
        );
      }

      await txn.update(
        'folders',
        {'deleted_at': now, 'sync_status': 'pending'},
        where: 'id = ?',
        whereArgs: [folderId],
      );
    });

    await _outboxRepo.enqueue(
      userId: userId,
      entityType: 'folder',
      entityId: folderId,
      operation: OutboxOperationType.delete,
    );
  }

  // ===========================================================================
  // 4. MATERIALS CRUD, SEARCH, FILTER & SORT
  // ===========================================================================

  /// Queries materials matching filters, search queries, and sorting strategies.
  Future<List<MaterialItem>> getMaterials({
    required String userId,
    String? workspaceId,
    String? subjectId,
    String? folderId,
    MaterialFilter? filter,
    MaterialSortOption sort = MaterialSortOption.recentlyUpdated,
    int? limit,
    int? offset,
  }) async {
    final db = await _localDb.database;

    final whereParts = <String>['m.user_id = ?', 'm.deleted_at IS NULL'];
    final whereArgs = <dynamic>[userId];

    // Workspace scoping
    if (workspaceId != null) {
      whereParts.add('(m.workspace_id IS NULL OR m.workspace_id = ?)');
      whereArgs.add(workspaceId);
    }

    // Direct Subject scoping
    final activeSubjectId = filter?.subjectId ?? subjectId;
    if (activeSubjectId != null && activeSubjectId.isNotEmpty) {
      whereParts.add('m.subject_id = ?');
      whereArgs.add(activeSubjectId);
    }

    // Direct Academic Period scoping
    if (filter?.academicPeriodId != null && filter!.academicPeriodId!.isNotEmpty) {
      whereParts.add('m.academic_period_id = ?');
      whereArgs.add(filter.academicPeriodId);
    }

    // Direct Folder scoping
    final activeFolderId = filter?.folderId ?? folderId;
    if (activeFolderId != null && activeFolderId.isNotEmpty) {
      whereParts.add('m.folder_id = ?');
      whereArgs.add(activeFolderId);
    }

    // Type filter
    if (filter?.type != null) {
      whereParts.add('m.type = ?');
      whereArgs.add(filter!.type!.toDbString());
    }

    // Favorite only
    if (filter != null && filter.isFavoriteOnly) {
      whereParts.add('m.is_favorite = 1');
    }

    // Archive filter
    if (filter != null && filter.isArchivedOnly) {
      whereParts.add('m.is_archived = 1');
    } else {
      whereParts.add('m.is_archived = 0');
    }

    // Inbox filter
    if (filter != null && filter.isInbox != null) {
      if (filter.isInbox!) {
        whereParts.add('m.is_inbox = 1');
      } else {
        whereParts.add('(m.is_inbox IS NULL OR m.is_inbox = 0)');
      }
    }

    // Label filter (material must have at least one or all selected labels)
    if (filter != null && filter.labelIds.isNotEmpty) {
      final labelPlaceholders = List.filled(filter.labelIds.length, '?').join(',');
      whereParts.add('''
        m.id IN (
          SELECT material_id FROM material_labels
          WHERE label_id IN ($labelPlaceholders)
        )
      ''');
      whereArgs.addAll(filter.labelIds);
    }

    // Search query matching title, description, or original file name
    final search = filter?.searchQuery?.trim();
    if (search != null && search.isNotEmpty) {
      whereParts.add('''
        (
          m.title LIKE ? OR
          m.description LIKE ? OR
          m.original_file_name LIKE ? OR
          s.name LIKE ? OR
          f.name LIKE ?
        )
      ''');
      final term = '%$search%';
      whereArgs.addAll([term, term, term, term, term]);
    }

    // Order By
    String orderBy;
    switch (sort) {
      case MaterialSortOption.recentlyUpdated:
        orderBy = 'm.updated_at DESC';
        break;
      case MaterialSortOption.recentlyOpened:
        orderBy = 'COALESCE(m.last_opened_at, m.updated_at) DESC';
        break;
      case MaterialSortOption.nameAsc:
        orderBy = 'm.title COLLATE NOCASE ASC';
        break;
      case MaterialSortOption.nameDesc:
        orderBy = 'm.title COLLATE NOCASE DESC';
        break;
    }

    final querySql = '''
      SELECT 
        m.*,
        s.name as subject_name,
        f.name as folder_name
      FROM materials m
      LEFT JOIN academic_subjects s ON s.id = m.subject_id
      LEFT JOIN folders f ON f.id = m.folder_id
      WHERE ${whereParts.join(' AND ')}
      ORDER BY $orderBy
      ${limit != null ? 'LIMIT $limit' : ''}
      ${offset != null ? 'OFFSET $offset' : ''}
    ''';

    final rows = await db.rawQuery(querySql, whereArgs);
    if (rows.isEmpty) return [];

    // Batch load labels for all returned materials
    final materialIds = rows.map((r) => r['id'] as String).toList();
    final labelsMap = await _getBatchMaterialLabels(db, materialIds);

    return rows.map((r) {
      final id = r['id'] as String;
      return MaterialItem.fromMap(
        r,
        labels: labelsMap[id] ?? [],
        subjectName: r['subject_name'] as String?,
        folderName: r['folder_name'] as String?,
      );
    }).toList();
  }

  Future<Map<String, List<VaultLabel>>> _getBatchMaterialLabels(
    Database db,
    List<String> materialIds,
  ) async {
    if (materialIds.isEmpty) return {};
    final placeholders = List.filled(materialIds.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT ml.material_id, l.*
      FROM labels l
      INNER JOIN material_labels ml ON ml.label_id = l.id
      WHERE ml.material_id IN ($placeholders) AND l.deleted_at IS NULL AND ml.deleted_at IS NULL
      ORDER BY l.name COLLATE NOCASE ASC
    ''', materialIds);

    final map = <String, List<VaultLabel>>{};
    for (final r in rows) {
      final mId = r['material_id'] as String;
      final label = VaultLabel.fromMap(r);
      map.putIfAbsent(mId, () => []).add(label);
    }
    return map;
  }

  /// Retrieves a single material by ID.
  Future<MaterialItem?> getMaterialById(String id) async {
    final db = await _localDb.database;
    final rows = await db.rawQuery('''
      SELECT 
        m.*,
        s.name as subject_name,
        f.name as folder_name
      FROM materials m
      LEFT JOIN academic_subjects s ON s.id = m.subject_id
      LEFT JOIN folders f ON f.id = m.folder_id
      WHERE m.id = ? AND m.deleted_at IS NULL
    ''', [id]);

    if (rows.isEmpty) return null;

    final labels = await getMaterialLabels(id);
    return MaterialItem.fromMap(
      rows.first,
      labels: labels,
      subjectName: rows.first['subject_name'] as String?,
      folderName: rows.first['folder_name'] as String?,
    );
  }

  /// Creates a new academic material record.
  Future<MaterialItem> createMaterial({
    required String userId,
    required String title,
    required VaultMaterialType type,
    String? workspaceId,
    String? academicPeriodId,
    String? subjectId,
    String? folderId,
    String? description,
    String? originalFileName,
    String? content,
    String? filePath,
    String? storagePath,
    String? mimeType,
    int fileSize = 0,
    String? remoteUrl,
    List<String> labelIds = const [],
    bool isFavorite = false,
    bool isInbox = false,
    String? source,
    String? importStatus = 'imported',
    String? contentHash,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Material title cannot be empty.');
    }

    final db = await _localDb.database;
    final now = DateTime.now();
    final item = MaterialItem(
      id: _uuid.v4(),
      userId: userId,
      workspaceId: workspaceId,
      academicPeriodId: academicPeriodId,
      subjectId: subjectId,
      folderId: folderId,
      title: trimmedTitle,
      description: description,
      originalFileName: originalFileName ?? trimmedTitle,
      type: type,
      content: content,
      filePath: filePath,
      storagePath: storagePath,
      mimeType: mimeType,
      fileSize: fileSize,
      remoteUrl: remoteUrl,
      isFavorite: isFavorite,
      isInbox: isInbox,
      source: source,
      importStatus: importStatus,
      contentHash: contentHash,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('materials', item.toMap());

    if (labelIds.isNotEmpty) {
      await setMaterialLabels(item.id, labelIds);
    }

    // Enqueue outbox operation for cloud synchronization
    await _outboxRepo.enqueue(
      userId: userId,
      entityType: 'material',
      entityId: item.id,
      operation: OutboxOperationType.create,
      payload: item.toMap(),
    );

    return (await getMaterialById(item.id)) ?? item;
  }

  /// Renames the logical display title of a material without affecting physical file paths.
  Future<void> renameMaterial(String id, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Material title cannot be empty.');
    }

    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'materials',
      {
        'title': trimmed,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    final mat = await getMaterialById(id);
    if (mat != null) {
      await _outboxRepo.enqueue(
        userId: mat.userId,
        entityType: 'material',
        entityId: id,
        operation: OutboxOperationType.update,
        payload: mat.toMap(),
      );
    }
  }

  /// Moves a material to another subject or folder while preserving all other metadata.
  Future<void> moveMaterial(
    String id, {
    String? workspaceId,
    String? academicPeriodId,
    String? subjectId,
    String? folderId,
  }) async {
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();
    final updates = <String, dynamic>{
      'updated_at': now,
    };

    if (workspaceId != null) updates['workspace_id'] = workspaceId;
    if (academicPeriodId != null) updates['academic_period_id'] = academicPeriodId;
    updates['subject_id'] = subjectId;
    updates['folder_id'] = folderId;

    await db.update('materials', updates, where: 'id = ?', whereArgs: [id]);

    final mat = await getMaterialById(id);
    if (mat != null) {
      await _outboxRepo.enqueue(
        userId: mat.userId,
        entityType: 'material',
        entityId: id,
        operation: OutboxOperationType.update,
        payload: mat.toMap(),
      );
    }
  }

  /// Toggles favorite status for a material.
  Future<void> toggleFavorite(String id, bool isFavorite) async {
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'materials',
      {
        'is_favorite': isFavorite ? 1 : 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    final mat = await getMaterialById(id);
    if (mat != null) {
      await _outboxRepo.enqueue(
        userId: mat.userId,
        entityType: 'material',
        entityId: id,
        operation: OutboxOperationType.update,
        payload: mat.toMap(),
      );
    }
  }

  /// Archives a material (hides from active subject views without deleting).
  Future<void> archiveMaterial(String id) async {
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'materials',
      {
        'is_archived': 1,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    final mat = await getMaterialById(id);
    if (mat != null) {
      await _outboxRepo.enqueue(
        userId: mat.userId,
        entityType: 'material',
        entityId: id,
        operation: OutboxOperationType.update,
        payload: mat.toMap(),
      );
    }
  }

  /// Restores an archived material back to active organization.
  Future<void> restoreMaterial(String id) async {
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'materials',
      {
        'is_archived': 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    final mat = await getMaterialById(id);
    if (mat != null) {
      await _outboxRepo.enqueue(
        userId: mat.userId,
        entityType: 'material',
        entityId: id,
        operation: OutboxOperationType.update,
        payload: mat.toMap(),
      );
    }
  }

  /// Updates last_opened_at timestamp when a material is viewed or opened.
  Future<void> markOpened(String id) async {
    final db = await _localDb.database;
    await db.update(
      'materials',
      {'last_opened_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Soft deletes a material and enqueues outbox operation.
  Future<void> deleteMaterial(String id) async {
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();
    final mat = await getMaterialById(id);
    final userId = mat?.userId ?? 'default_user';

    await db.transaction((txn) async {
      await txn.update(
        'materials',
        {'deleted_at': now, 'sync_status': 'pending'},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'material_labels',
        {'deleted_at': now},
        where: 'material_id = ?',
        whereArgs: [id],
      );
    });

    await _outboxRepo.enqueue(
      userId: userId,
      entityType: 'material',
      entityId: id,
      operation: OutboxOperationType.delete,
      payload: mat != null ? {'storage_path': mat.storagePath, 'file_path': mat.filePath} : {},
    );
  }

  // ===========================================================================
  // 5. BULK ACTIONS
  // ===========================================================================

  /// Bulk moves selected materials to a new subject or folder.
  Future<void> bulkMove(
    List<String> ids, {
    String? workspaceId,
    String? academicPeriodId,
    String? subjectId,
    String? folderId,
  }) async {
    if (ids.isEmpty) return;
    final db = await _localDb.database;
    final placeholders = List.filled(ids.length, '?').join(',');

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
      'subject_id': subjectId,
      'folder_id': folderId,
    };
    if (workspaceId != null) updates['workspace_id'] = workspaceId;
    if (academicPeriodId != null) updates['academic_period_id'] = academicPeriodId;

    await db.update(
      'materials',
      updates,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// Bulk attaches labels to selected materials.
  Future<void> bulkAddLabels(List<String> ids, List<String> labelIds) async {
    if (ids.isEmpty || labelIds.isEmpty) return;
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();

    final batch = db.batch();
    for (final mId in ids) {
      for (final lId in labelIds) {
        batch.insert('material_labels', {
          'material_id': mId,
          'label_id': lId,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
    await batch.commit(noResult: true);
  }

  /// Bulk archives selected materials.
  Future<void> bulkArchive(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _localDb.database;
    final placeholders = List.filled(ids.length, '?').join(',');

    await db.update(
      'materials',
      {
        'is_archived': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// Bulk deletes selected materials with their label associations and enqueues outbox operations.
  Future<void> bulkDelete(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();
    final placeholders = List.filled(ids.length, '?').join(',');

    final rows = await db.query(
      'materials',
      columns: ['id', 'user_id', 'storage_path', 'file_path'],
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );

    await db.transaction((txn) async {
      await txn.update(
        'materials',
        {'deleted_at': now, 'sync_status': 'pending'},
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
      await txn.update(
        'material_labels',
        {'deleted_at': now},
        where: 'material_id IN ($placeholders)',
        whereArgs: ids,
      );
    });

    for (final row in rows) {
      final id = row['id'] as String;
      final userId = row['user_id'] as String? ?? 'default_user';
      final storagePath = row['storage_path'] as String?;
      final filePath = row['file_path'] as String?;

      final payload = <String, dynamic>{};
      if (storagePath != null) payload['storage_path'] = storagePath;
      if (filePath != null) payload['file_path'] = filePath;

      await _outboxRepo.enqueue(
        userId: userId,
        entityType: 'material',
        entityId: id,
        operation: OutboxOperationType.delete,
        payload: payload,
      );
    }
  }

  // ===========================================================================
  // 6. PHASE 7: INBOX, IMPORT & DUPLICATE MANAGEMENT
  // ===========================================================================

  /// Searches for an existing non-archived material matching by contentHash OR (originalFileName + fileSize).
  Future<MaterialItem?> findDuplicateMaterial({
    required String userId,
    String? contentHash,
    String? originalFileName,
    int? fileSize,
  }) async {
    final db = await _localDb.database;

    if (contentHash != null && contentHash.isNotEmpty) {
      final rows = await db.rawQuery('''
        SELECT m.*, s.name as subject_name, f.name as folder_name
        FROM materials m
        LEFT JOIN academic_subjects s ON s.id = m.subject_id
        LEFT JOIN folders f ON f.id = m.folder_id
        WHERE m.user_id = ? AND m.content_hash = ? AND m.is_archived = 0 AND m.deleted_at IS NULL
        LIMIT 1
      ''', [userId, contentHash]);
      if (rows.isNotEmpty) {
        final id = rows.first['id'] as String;
        final labels = await getMaterialLabels(id);
        return MaterialItem.fromMap(
          rows.first,
          labels: labels,
          subjectName: rows.first['subject_name'] as String?,
          folderName: rows.first['folder_name'] as String?,
        );
      }
    }

    if (originalFileName != null && originalFileName.isNotEmpty && fileSize != null && fileSize > 0) {
      final rows = await db.rawQuery('''
        SELECT m.*, s.name as subject_name, f.name as folder_name
        FROM materials m
        LEFT JOIN academic_subjects s ON s.id = m.subject_id
        LEFT JOIN folders f ON f.id = m.folder_id
        WHERE m.user_id = ? AND m.original_file_name = ? AND m.file_size = ? AND m.is_archived = 0 AND m.deleted_at IS NULL
        LIMIT 1
      ''', [userId, originalFileName, fileSize]);
      if (rows.isNotEmpty) {
        final id = rows.first['id'] as String;
        final labels = await getMaterialLabels(id);
        return MaterialItem.fromMap(
          rows.first,
          labels: labels,
          subjectName: rows.first['subject_name'] as String?,
          folderName: rows.first['folder_name'] as String?,
        );
      }
    }

    return null;
  }

  /// Retrieves materials currently residing in the user's Inbox awaiting organization.
  Future<List<MaterialItem>> getInboxMaterials({
    required String userId,
    String? workspaceId,
    MaterialSortOption sort = MaterialSortOption.recentlyUpdated,
    int? limit,
    int? offset,
  }) async {
    return getMaterials(
      userId: userId,
      workspaceId: workspaceId,
      filter: const MaterialFilter(isInbox: true),
      sort: sort,
      limit: limit,
      offset: offset,
    );
  }

  /// Returns count of pending unorganized materials in the inbox.
  Future<int> getInboxCount({
    required String userId,
    String? workspaceId,
  }) async {
    final db = await _localDb.database;
    final whereParts = <String>['user_id = ?', 'is_inbox = 1', 'is_archived = 0', 'deleted_at IS NULL'];
    final whereArgs = <dynamic>[userId];
    if (workspaceId != null) {
      whereParts.add('(workspace_id IS NULL OR workspace_id = ?)');
      whereArgs.add(workspaceId);
    }
    final res = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM materials
      WHERE ${whereParts.join(' AND ')}
    ''', whereArgs);
    return (res.first['cnt'] as num?)?.toInt() ?? 0;
  }

  /// Moves an inbox material into a permanent academic subject, folder, and attaches labels.
  Future<void> organizeMaterial(
    String materialId, {
    required String workspaceId,
    required String academicPeriodId,
    required String subjectId,
    String? folderId,
    List<String>? labelIds,
  }) async {
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'materials',
      {
        'workspace_id': workspaceId,
        'academic_period_id': academicPeriodId,
        'subject_id': subjectId,
        'folder_id': folderId,
        'is_inbox': 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [materialId],
    );

    if (labelIds != null) {
      await setMaterialLabels(materialId, labelIds);
    }

    final mat = await getMaterialById(materialId);
    if (mat != null) {
      await _outboxRepo.enqueue(
        userId: mat.userId,
        entityType: 'material',
        entityId: materialId,
        operation: OutboxOperationType.update,
        payload: mat.toMap(),
      );
    }
  }

  /// Bulk organizes multiple inbox materials into an academic subject and folder with optional labels.
  Future<void> bulkOrganizeMaterials(
    List<String> materialIds, {
    required String workspaceId,
    required String academicPeriodId,
    required String subjectId,
    String? folderId,
    List<String>? labelIds,
  }) async {
    if (materialIds.isEmpty) return;
    final db = await _localDb.database;
    final placeholders = List.filled(materialIds.length, '?').join(',');
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        'materials',
        {
          'workspace_id': workspaceId,
          'academic_period_id': academicPeriodId,
          'subject_id': subjectId,
          'folder_id': folderId,
          'is_inbox': 0,
          'updated_at': now,
        },
        where: 'id IN ($placeholders)',
        whereArgs: materialIds,
      );

      if (labelIds != null && labelIds.isNotEmpty) {
        for (final mId in materialIds) {
          for (final lId in labelIds) {
            await txn.insert(
              'material_labels',
              {
                'material_id': mId,
                'label_id': lId,
                'created_at': now,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
      }
    });

    for (final mId in materialIds) {
      final mat = await getMaterialById(mId);
      if (mat != null) {
        await _outboxRepo.enqueue(
          userId: mat.userId,
          entityType: 'material',
          entityId: mId,
          operation: OutboxOperationType.update,
          payload: mat.toMap(),
        );
      }
    }
  }

  /// Removes an item from the Inbox without organizing it into a subject.
  Future<void> removeFromInbox(String materialId) async {
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'materials',
      {
        'is_inbox': 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [materialId],
    );

    final mat = await getMaterialById(materialId);
    if (mat != null) {
      await _outboxRepo.enqueue(
        userId: mat.userId,
        entityType: 'material',
        entityId: materialId,
        operation: OutboxOperationType.update,
        payload: mat.toMap(),
      );
    }
  }
}
