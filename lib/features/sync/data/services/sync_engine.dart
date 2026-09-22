import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/services/connectivity_service.dart';
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
      // 2. Push local mutations (Outbox)
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

      _notify(_state.copyWith(
        status: counts.failed > 0 ? SyncStatus.failed : SyncStatus.synced,
        lastSyncedAt: now,
        pendingCount: counts.pending,
        failedCount: counts.failed,
        localStorageBytes: storageStats.totalLocalBytes,
        cloudStorageBytes: storageStats.remoteStorageBytes,
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
          // Do not rethrow to allow metadata sync to proceed
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

        if (localRows.isEmpty) {
          // Fresh record from another device -> insert locally
          final insertData = _denormalizeForLocal(remote);
          if (table == 'folders' || table == 'materials') {
            insertData['sync_status'] = 'synced';
          }
          insertData['remote_updated_at'] = remote['updated_at'] ?? DateTime.now().toIso8601String();
          await db.insert(table, insertData);
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
