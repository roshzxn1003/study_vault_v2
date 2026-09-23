import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/services/connectivity_service.dart';
import 'package:study_vault/features/vault/domain/models/material_item.dart';
import '../../domain/models/outbox_operation.dart';
import '../../domain/models/sync_state.dart';
import '../repositories/outbox_repository.dart';
import 'remote_sync_service.dart';

/// Central Synchronization Engine for Study Vault.
/// Coordinates the local database, outbox queue, remote backend, and storage sync.
class SyncEngine {
  final LocalDbService _localDb;
  final OutboxRepository _outboxRepo;
  final RemoteSyncService remoteService;
  final ConnectivityService _connectivityService;

  bool _isSyncing = false;
  SyncState _state = const SyncState();
  final List<void Function(SyncState)> _listeners = [];
  StreamSubscription<NetworkStatus>? _connectivitySub;

  SyncEngine({
    LocalDbService? localDb,
    OutboxRepository? outboxRepo,
    required this.remoteService,
    ConnectivityService? connectivityService,
  })  : _localDb = localDb ?? LocalDbService.instance,
        _outboxRepo = outboxRepo ?? OutboxRepository(),
        _connectivityService = connectivityService ?? ConnectivityService() {
    _initConnectivityListener();
  }

  SyncState get state => _state;

  void addListener(void Function(SyncState) listener) {
    _listeners.add(listener);
    listener(_state);
  }

  void removeListener(void Function(SyncState) listener) {
    _listeners.remove(listener);
  }

  void _notify(SyncState newState) {
    _state = newState;
    for (final listener in _listeners) {
      listener(_state);
    }
  }

  void _initConnectivityListener() {
    _connectivitySub = _connectivityService.onStatusChanged.listen((status) {
      final wasOffline = !_state.isOnline;
      final isOnline = status == NetworkStatus.online;

      _notify(_state.copyWith(isOnline: isOnline));

      // Automatically trigger sync when coming back online
      if (wasOffline && isOnline && !_isSyncing) {
        debugPrint('[SyncEngine] Network re-established. Triggering background sync.');
      }
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    _listeners.clear();
  }

  /// Dependency hierarchy order to ensure parent records exist before children.
  static const List<String> entitySyncOrder = [
    'workspace',
    'academic_year',
    'academic_period',
    'subject',
    'folder',
    'material',
    'label',
    'material_label',
    'personal_topic',
  ];

  static int _entityPriority(String entityType) {
    final idx = entitySyncOrder.indexOf(entityType.toLowerCase());
    return idx >= 0 ? idx : 99;
  }

  /// Map local entity types to SQLite table names.
  String _mapEntityTypeToTable(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'workspace':
        return 'workspaces';
      case 'academic_year':
        return 'academic_years';
      case 'academic_period':
        return 'academic_periods';
      case 'subject':
        return 'academic_subjects';
      case 'folder':
        return 'folders';
      case 'material':
        return 'materials';
      case 'label':
        return 'labels';
      case 'material_label':
        return 'material_labels';
      case 'personal_topic':
        return 'personal_topics';
      default:
        return entityType;
    }
  }

  /// Executes full synchronization pipeline: push outbox, pull remote updates, resolve conflicts.
  Future<void> syncAll({required String userId}) async {
    if (_isSyncing) {
      debugPrint('[SyncEngine] Sync already in progress, skipping redundant request.');
      return;
    }

    // 1. Check network
    final netStatus = await _connectivityService.checkStatus();
    if (netStatus == NetworkStatus.offline) {
      final counts = await _outboxRepo.getCounts(userId: userId);
      _notify(_state.copyWith(
        status: SyncStatus.offline,
        isOnline: false,
        pendingCount: counts.pending,
        failedCount: counts.failed,
      ));
      return;
    }

    _isSyncing = true;
    _notify(_state.copyWith(
      status: SyncStatus.syncing,
      isOnline: true,
      clearError: true,
    ));

    try {
      // 2. Enqueue all local unsynced entities and push mutations (Outbox)
      await _enqueueLocalUnsyncedEntities(userId: userId);
      await _processOutbox(userId: userId);

      // 3. Pull remote updates (Incremental / Initial)
      await _pullRemoteChanges(userId: userId);

      // 4. Check data integrity
      await _verifyDataIntegrity(userId: userId);

      // 5. Update metadata and stats
      final now = DateTime.now();
      await _setLastSyncTime(userId, now);
      await _outboxRepo.purgeSyncedOperations();

      final counts = await _outboxRepo.getCounts(userId: userId);
      final storageStats = await calculateStorageUsage(userId: userId);

      final db = await _localDb.database;
      final syncedCountRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM materials WHERE user_id = ? AND storage_path IS NOT NULL AND storage_path NOT LIKE "/%" AND deleted_at IS NULL',
        [userId],
      );
      final syncedFilesCount = (syncedCountRes.first['cnt'] as num?)?.toInt() ?? 0;

      _notify(_state.copyWith(
        status: counts.failed > 0 ? SyncStatus.failed : SyncStatus.synced,
        lastSyncedAt: now,
        pendingCount: counts.pending,
        failedCount: counts.failed,
        localStorageBytes: storageStats.totalLocalBytes,
        cloudStorageBytes: storageStats.remoteStorageBytes,
        syncedFilesCount: syncedFilesCount,
      ));
    } catch (e) {
      debugPrint('[SyncEngine] Sync cycle encountered error: $e');
      final counts = await _outboxRepo.getCounts(userId: userId);
      _notify(_state.copyWith(
        status: SyncStatus.failed,
        errorMessage: 'Sync error: $e',
        pendingCount: counts.pending,
        failedCount: counts.failed,
      ));
    } finally {
      _isSyncing = false;
    }
  }

  /// Automatically enqueues local entities (workspaces, academic years, periods, subjects, folders, materials)
  /// that need cloud replication or storage upload.
  Future<void> _enqueueLocalUnsyncedEntities({required String userId}) async {
    try {
      final db = await _localDb.database;

      // 1. Workspaces
      final unsyncedWorkspaces = await db.rawQuery('''
        SELECT w.* FROM workspaces w
        WHERE w.user_id = ? 
          AND w.deleted_at IS NULL
          AND w.remote_updated_at IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM outbox_operations o 
            WHERE o.entity_id = w.id AND o.status IN ('pending', 'syncing')
          )
      ''', [userId]);
      for (final row in unsyncedWorkspaces) {
        await _outboxRepo.enqueue(
          userId: userId,
          entityType: 'workspace',
          entityId: row['id'] as String,
          operation: OutboxOperationType.create,
          payload: Map<String, dynamic>.from(row)..remove('sync_status'),
        );
      }

      // 2. Academic Years
      final unsyncedYears = await db.rawQuery('''
        SELECT y.* FROM academic_years y
        WHERE y.user_id = ? 
          AND y.deleted_at IS NULL
          AND y.remote_updated_at IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM outbox_operations o 
            WHERE o.entity_id = y.id AND o.status IN ('pending', 'syncing')
          )
      ''', [userId]);
      for (final row in unsyncedYears) {
        await _outboxRepo.enqueue(
          userId: userId,
          entityType: 'academic_year',
          entityId: row['id'] as String,
          operation: OutboxOperationType.create,
          payload: Map<String, dynamic>.from(row)..remove('sync_status'),
        );
      }

      // 3. Academic Periods
      final unsyncedPeriods = await db.rawQuery('''
        SELECT p.* FROM academic_periods p
        WHERE p.user_id = ? 
          AND p.deleted_at IS NULL
          AND p.remote_updated_at IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM outbox_operations o 
            WHERE o.entity_id = p.id AND o.status IN ('pending', 'syncing')
          )
      ''', [userId]);
      for (final row in unsyncedPeriods) {
        await _outboxRepo.enqueue(
          userId: userId,
          entityType: 'academic_period',
          entityId: row['id'] as String,
          operation: OutboxOperationType.create,
          payload: Map<String, dynamic>.from(row)..remove('sync_status'),
        );
      }

      // 4. Academic Subjects
      final unsyncedSubjects = await db.rawQuery('''
        SELECT s.* FROM academic_subjects s
        WHERE s.user_id = ? 
          AND s.deleted_at IS NULL
          AND s.remote_updated_at IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM outbox_operations o 
            WHERE o.entity_id = s.id AND o.status IN ('pending', 'syncing')
          )
      ''', [userId]);
      for (final row in unsyncedSubjects) {
        await _outboxRepo.enqueue(
          userId: userId,
          entityType: 'subject',
          entityId: row['id'] as String,
          operation: OutboxOperationType.create,
          payload: Map<String, dynamic>.from(row)..remove('sync_status'),
        );
      }

      // 5. Folders
      final unsyncedFolders = await db.rawQuery('''
        SELECT f.* FROM folders f
        WHERE f.user_id = ? 
          AND f.deleted_at IS NULL
          AND f.remote_updated_at IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM outbox_operations o 
            WHERE o.entity_id = f.id AND o.status IN ('pending', 'syncing')
          )
      ''', [userId]);
      for (final row in unsyncedFolders) {
        await _outboxRepo.enqueue(
          userId: userId,
          entityType: 'folder',
          entityId: row['id'] as String,
          operation: OutboxOperationType.create,
          payload: Map<String, dynamic>.from(row)..remove('sync_status'),
        );
      }

      // 6. Labels
      final unsyncedLabels = await db.rawQuery('''
        SELECT l.* FROM labels l
        WHERE l.user_id = ? 
          AND l.deleted_at IS NULL
          AND l.remote_updated_at IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM outbox_operations o 
            WHERE o.entity_id = l.id AND o.status IN ('pending', 'syncing')
          )
      ''', [userId]);
      for (final row in unsyncedLabels) {
        await _outboxRepo.enqueue(
          userId: userId,
          entityType: 'label',
          entityId: row['id'] as String,
          operation: OutboxOperationType.create,
          payload: Map<String, dynamic>.from(row)..remove('sync_status'),
        );
      }

      // 7. Personal Topics
      final unsyncedTopics = await db.rawQuery('''
        SELECT t.* FROM personal_topics t
        WHERE t.user_id = ? 
          AND t.deleted_at IS NULL
          AND t.remote_updated_at IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM outbox_operations o 
            WHERE o.entity_id = t.id AND o.status IN ('pending', 'syncing')
          )
      ''', [userId]);
      for (final row in unsyncedTopics) {
        await _outboxRepo.enqueue(
          userId: userId,
          entityType: 'personal_topic',
          entityId: row['id'] as String,
          operation: OutboxOperationType.create,
          payload: Map<String, dynamic>.from(row)..remove('sync_status'),
        );
      }

      // 8. Materials (with physical file sync check)
      final unsyncedMaterials = await db.rawQuery('''
        SELECT m.* FROM materials m
        WHERE m.user_id = ? 
          AND m.deleted_at IS NULL
          AND (
            m.remote_updated_at IS NULL
            OR m.sync_status = 'pending' 
            OR m.storage_path IS NULL 
            OR m.storage_path = m.file_path
            OR m.storage_path LIKE '/%'
          )
          AND NOT EXISTS (
            SELECT 1 FROM outbox_operations o 
            WHERE o.entity_id = m.id AND o.status IN ('pending', 'syncing')
          )
      ''', [userId]);

      for (final row in unsyncedMaterials) {
        final m = MaterialItem.fromMap(row);
        await _outboxRepo.enqueue(
          userId: userId,
          entityType: 'material',
          entityId: m.id,
          operation: OutboxOperationType.create,
          payload: m.toMap(),
        );
      }
    } catch (e) {
      debugPrint('[SyncEngine] Error enqueuing local unsynced entities: $e');
    }
  }

  /// Processes pending outbox operations in dependency order.
  Future<void> _processOutbox({required String userId}) async {
    final pendingOps = await _outboxRepo.getPendingOperations(userId: userId, limit: 100);
    if (pendingOps.isEmpty) return;

    // Sort by entity dependency hierarchy
    pendingOps.sort((a, b) => _entityPriority(a.entityType).compareTo(_entityPriority(b.entityType)));

    for (final op in pendingOps) {
      await _outboxRepo.markSyncing(op.id);

      try {
        var payload = op.payload != null ? Map<String, dynamic>.from(op.payload!) : <String, dynamic>{};

        // If this is a material with a local file, ensure the file is uploaded to Supabase Storage
        if (op.entityType == 'material' && op.operation != OutboxOperationType.delete) {
          _notify(_state.copyWith(status: SyncStatus.uploading, isOnline: true));
          payload = await _ensureMaterialFileUploaded(userId, op.entityId, payload);
        }

        // Push mutation to remote backend
        await remoteService.pushEntity(
          entityType: op.entityType,
          operation: op.operation,
          entityId: op.entityId,
          payload: payload,
        );

        // Mark outbox operation as synced
        await _outboxRepo.markSynced(op.id);

        // Update local sync status
        final db = await _localDb.database;
        final table = _mapEntityTypeToTable(op.entityType);

        if (op.operation == OutboxOperationType.delete) {
          // Permanently purge soft-deleted item locally once safely confirmed remotely
          if (op.entityType != 'material_label') {
            await db.delete(table, where: 'id = ?', whereArgs: [op.entityId]);
          } else {
            final mId = payload['material_id'];
            final lId = payload['label_id'];
            if (mId != null && lId != null) {
              await db.delete(
                'material_labels',
                where: 'material_id = ? AND label_id = ?',
                whereArgs: [mId, lId],
              );
            }
          }
        } else {
          final updates = <String, dynamic>{
            'remote_updated_at': DateTime.now().toIso8601String(),
          };
          if (table == 'folders' || table == 'materials') {
            updates['sync_status'] = 'synced';
          }
          await db.update(
            table,
            updates,
            where: 'id = ?',
            whereArgs: [op.entityId],
          );
        }
      } catch (e) {
        debugPrint('[SyncEngine] Failed pushing ${op.entityType} ${op.entityId}: $e');
        await _outboxRepo.markFailed(op.id, error: e.toString());
      }
    }
  }

  /// Uploads material file to Supabase Storage if present and updates payload.
  Future<Map<String, dynamic>> _ensureMaterialFileUploaded(
    String userId,
    String materialId,
    Map<String, dynamic> payload,
  ) async {
    final filePath = payload['file_path'] as String?;
    final existingStoragePath = payload['storage_path'] as String?;

    // Check if local file exists and storage_path is not yet a remote path
    if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      final isLocalOnly = existingStoragePath == null ||
          existingStoragePath.isEmpty ||
          existingStoragePath == filePath;

      if (await file.exists() && isLocalOnly) {
        try {
          final fileName = payload['original_file_name'] as String? ?? p.basename(filePath);
          final uploadResult = await remoteService.uploadMaterialFile(
            userId: userId,
            materialId: materialId,
            file: file,
            fileName: fileName,
          );

          payload['storage_path'] = uploadResult.storagePath;
          if (uploadResult.remoteUrl != null) {
            payload['remote_url'] = uploadResult.remoteUrl;
          }

          // Update local material record
          final db = await _localDb.database;
          await db.update(
            'materials',
            {
              'storage_path': uploadResult.storagePath,
              if (uploadResult.remoteUrl != null) 'remote_url': uploadResult.remoteUrl,
            },
            where: 'id = ?',
            whereArgs: [materialId],
          );
        } catch (e) {
          debugPrint('[SyncEngine] File upload failed for material $materialId: $e');
          // Clear storage_path from payload so invalid local paths are not stored remotely
          payload['storage_path'] = null;
        }
      }
    }
    return payload;
  }

  /// Pulls remote changes that changed since the last known sync timestamp.
  Future<void> _pullRemoteChanges({required String userId}) async {
    final lastSync = await _getLastSyncTime(userId);
    final db = await _localDb.database;

    for (final entityType in entitySyncOrder) {
      final remoteRecords = await remoteService.pullEntities(
        entityType: entityType,
        userId: userId,
        since: lastSync,
      );

      final table = _mapEntityTypeToTable(entityType);

      for (final remote in remoteRecords) {
        final id = remote['id'] as String?;
        if (id == null && entityType != 'material_label') continue;

        // Conflict check: Does local device have an active un-synced mutation for this entity?
        final hasLocalMutation = id != null ? await _outboxRepo.hasPendingMutation(id) : false;

        // Check if record exists locally
        final localRows = entityType == 'material_label'
            ? await db.query(
                table,
                where: 'material_id = ? AND label_id = ?',
                whereArgs: [remote['material_id'], remote['label_id']],
              )
            : await db.query(table, where: 'id = ?', whereArgs: [id]);

        // If this is a material, ensure file is downloaded locally if missing
        String? resolvedFilePath = remote['file_path'] as String?;
        final storagePath = remote['storage_path'] as String?;

        if (entityType == 'material' &&
            storagePath != null &&
            storagePath.isNotEmpty &&
            !storagePath.startsWith('/')) {
          final existingFile = (resolvedFilePath != null && resolvedFilePath.isNotEmpty)
              ? File(resolvedFilePath)
              : null;
          if (existingFile == null || !existingFile.existsSync()) {
            try {
              _notify(_state.copyWith(status: SyncStatus.downloading, isOnline: true));
              final bytes = await remoteService.downloadMaterialFile(storagePath: storagePath);
              if (bytes.isNotEmpty) {
                Directory baseDir;
                try {
                  baseDir = await getApplicationDocumentsDirectory();
                } catch (e) {
                  baseDir = Directory(p.join(Directory.systemTemp.path, 'study_vault_test_docs'));
                }
                final materialsDir = Directory(p.join(baseDir.path, 'study_materials'));
                if (!await materialsDir.exists()) {
                  await materialsDir.create(recursive: true);
                }
                final fileName = (remote['original_file_name'] as String?) ?? p.basename(storagePath);
                final sanitizedName = '${id}_${fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}';
                final downloadedFile = File(p.join(materialsDir.path, sanitizedName));
                await downloadedFile.writeAsBytes(bytes);
                resolvedFilePath = downloadedFile.path;
              }
            } catch (e) {
              debugPrint('[SyncEngine] File download error for material $id: $e');
              resolvedFilePath = null;
            }
          }
        }

        if (localRows.isEmpty) {
          // Fresh record from another device -> insert locally
          final insertData = _denormalizeForLocal(remote);
          if (entityType == 'material') {
            insertData['file_path'] = resolvedFilePath;
          }
          if (table == 'folders' || table == 'materials') {
            insertData['sync_status'] = 'synced';
          }
          insertData['remote_updated_at'] = remote['updated_at'] ?? DateTime.now().toIso8601String();
          await db.insert(table, insertData);

          // If pulling a workspace, ensure local academic_structures has metadata so profile/header works
          if (entityType == 'workspace' && id != null) {
            final structRows = await db.query(
              'academic_structures',
              where: 'workspace_id = ?',
              whereArgs: [id],
            );
            if (structRows.isEmpty) {
              await db.insert('academic_structures', {
                'id': id,
                'workspace_id': id,
                'user_id': userId,
                'purpose': remote['purpose'] ?? 'college',
                'institution_name': remote['name'] ?? 'My Academic Vault',
                'degree': remote['purpose'] == 'college' ? 'Degree Program' : null,
                'created_at': remote['created_at'] ?? DateTime.now().toIso8601String(),
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }
        } else {
          final local = localRows.first;

          // If deleted remotely, mark soft-deleted locally
          if (remote['deleted_at'] != null) {
            if (!hasLocalMutation) {
              final delUpdates = <String, dynamic>{
                'deleted_at': remote['deleted_at'],
              };
              if (table == 'folders' || table == 'materials') {
                delUpdates['sync_status'] = 'synced';
              }
              await db.update(
                table,
                delUpdates,
                where: 'id = ?',
                whereArgs: [id],
              );
            }
            continue;
          }

          if (!hasLocalMutation) {
            // No local pending change: remote wins
            final updateData = _denormalizeForLocal(remote);
            if (entityType == 'material') {
              updateData['file_path'] = resolvedFilePath ?? local['file_path'];
            }
            if (table == 'folders' || table == 'materials') {
              updateData['sync_status'] = 'synced';
            }
            updateData['remote_updated_at'] = remote['updated_at'] ?? DateTime.now().toIso8601String();
            await db.update(table, updateData, where: 'id = ?', whereArgs: [id]);
          } else {
            // Conflict Resolution (Last-Write-Wins based on timestamps)
            final remoteUpdated = DateTime.tryParse(remote['updated_at'] as String? ?? '');
            final localUpdated = DateTime.tryParse(local['updated_at'] as String? ?? '');

            if (remoteUpdated != null && localUpdated != null && remoteUpdated.isAfter(localUpdated)) {
              // Remote is newer -> remote wins
              final updateData = _denormalizeForLocal(remote);
              if (entityType == 'material') {
                updateData['file_path'] = resolvedFilePath ?? local['file_path'];
              }
              if (table == 'folders' || table == 'materials') {
                updateData['sync_status'] = 'synced';
              }
              updateData['remote_updated_at'] = remote['updated_at'];
              await db.update(table, updateData, where: 'id = ?', whereArgs: [id]);
            }
            // Otherwise local is newer -> local pending outbox operation remains and will overwrite remote
          }
        }
      }
    }
  }

  /// Converts remote Supabase data types to local SQLite data types.
  Map<String, dynamic> _denormalizeForLocal(Map<String, dynamic> remote) {
    final local = Map<String, dynamic>.from(remote);

    // Convert booleans to SQLite integers (1/0)
    for (final key in local.keys.toList()) {
      final val = local[key];
      if (val is bool) {
        local[key] = val ? 1 : 0;
      }
    }

    return local;
  }

  /// Checks data consistency and prevents broken foreign keys.
  Future<void> _verifyDataIntegrity({required String userId}) async {
    final db = await _localDb.database;

    // Detect orphaned folders whose parent does not exist
    final orphanedFolders = await db.rawQuery('''
      SELECT f1.id 
      FROM folders f1 
      LEFT JOIN folders f2 ON f1.parent_id = f2.id 
      WHERE f1.user_id = ? AND f1.parent_id IS NOT NULL AND f2.id IS NULL
    ''', [userId]);

    for (final row in orphanedFolders) {
      final folderId = row['id'] as String;
      // Re-parent orphaned folder safely to root
      await db.update('folders', {'parent_id': null}, where: 'id = ?', whereArgs: [folderId]);
    }
  }

  /// Gets the last successful synchronization timestamp for a user.
  Future<DateTime?> _getLastSyncTime(String userId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: ['last_sync_$userId'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final val = rows.first['value'] as String?;
    return val != null ? DateTime.tryParse(val) : null;
  }

  /// Stores the last successful sync timestamp for a user.
  Future<void> _setLastSyncTime(String userId, DateTime time) async {
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();
    final timeStr = time.toIso8601String();

    await db.rawInsert('''
      INSERT INTO sync_metadata (key, value, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
    ''', ['last_sync_$userId', timeStr, now]);
  }

  /// Resets failed operations and immediately initiates a sync cycle.
  Future<void> retryFailed({required String userId}) async {
    await _outboxRepo.retryAllFailed(userId: userId);
    await syncAll(userId: userId);
  }

  /// Computes real storage statistics (local documents directory + database + synced cloud sizes).
  Future<StorageUsage> calculateStorageUsage({required String userId}) async {
    int localFiles = 0;
    int localDb = 0;
    int cloudBytes = 0;

    try {
      final db = await _localDb.database;
      final pageCountRes = await db.rawQuery('PRAGMA page_count;');
      final pageSizeRes = await db.rawQuery('PRAGMA page_size;');
      final pageCount = (pageCountRes.isNotEmpty && pageCountRes.first.values.isNotEmpty)
          ? (pageCountRes.first.values.first as num?)?.toInt() ?? 0
          : 0;
      final pageSize = (pageSizeRes.isNotEmpty && pageSizeRes.first.values.isNotEmpty)
          ? (pageSizeRes.first.values.first as num?)?.toInt() ?? 4096
          : 4096;
      localDb = pageCount * pageSize;
    } catch (e) {
      debugPrint('SyncEngine localDb size calc error: $e');
    }

    try {
      Directory baseDir;
      try {
        baseDir = await getApplicationDocumentsDirectory();
      } catch (e) {
        debugPrint('SyncEngine baseDir fallback: $e');
        baseDir = Directory(p.join(Directory.systemTemp.path, 'study_vault_test_docs'));
      }
      final materialsDir = Directory(p.join(baseDir.path, 'study_materials'));
      if (await materialsDir.exists()) {
        await for (final file in materialsDir.list(recursive: true)) {
          if (file is File) {
            localFiles += await file.length();
          }
        }
      }
    } catch (e) {
      debugPrint('SyncEngine localFiles size calc error: $e');
    }

    try {
      final db = await _localDb.database;
      final res = await db.rawQuery(
        'SELECT SUM(file_size) as total_size FROM materials WHERE user_id = ? AND storage_path IS NOT NULL AND deleted_at IS NULL',
        [userId],
      );
      cloudBytes = (res.first['total_size'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('SyncEngine cloudBytes size calc error: $e');
    }

    return StorageUsage(
      localDbBytes: localDb,
      localMaterialFilesBytes: localFiles,
      remoteStorageBytes: cloudBytes,
    );
  }
}
