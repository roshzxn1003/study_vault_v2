import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import '../../domain/models/outbox_operation.dart';

/// Repository managing the deterministic mutation outbox queue.
class OutboxRepository {
  final LocalDbService _localDb;
  final Uuid _uuid = const Uuid();

  OutboxRepository({LocalDbService? localDb})
      : _localDb = localDb ?? LocalDbService.instance;

  static const int maxRetryAttempts = 5;

  /// Enqueues a local mutation for future cloud synchronization.
  Future<OutboxOperation> enqueue({
    required String userId,
    required String entityType,
    required String entityId,
    required OutboxOperationType operation,
    Map<String, dynamic>? payload,
  }) async {
    final db = await _localDb.database;
    final now = DateTime.now();

    // Check if an un-synced operation already exists for this entity
    final existingRows = await db.query(
      'outbox_operations',
      where: "user_id = ? AND entity_type = ? AND entity_id = ? AND status IN ('pending', 'failed')",
      whereArgs: [userId, entityType, entityId],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (existingRows.isNotEmpty) {
      final existing = OutboxOperation.fromMap(existingRows.first);

      // Coalesce operations:
      // If previous was CREATE and current is UPDATE -> update payload and keep CREATE
      if (existing.operation == OutboxOperationType.create &&
          operation == OutboxOperationType.update) {
        final mergedPayload = {
          ...?existing.payload,
          ...?payload,
        };
        final updated = existing.copyWith(
          payload: mergedPayload,
          updatedAt: now,
          status: OutboxStatus.pending,
          clearLastError: true,
          clearNextRetryAt: true,
        );
        await db.update(
          'outbox_operations',
          updated.toMap(),
          where: 'id = ?',
          whereArgs: [existing.id],
        );
        return updated;
      }

      // If previous was CREATE and current is DELETE -> delete outbox record (never reached remote)
      if (existing.operation == OutboxOperationType.create &&
          operation == OutboxOperationType.delete) {
        await db.delete('outbox_operations', where: 'id = ?', whereArgs: [existing.id]);
        return existing.copyWith(status: OutboxStatus.synced);
      }

      // If previous was UPDATE and current is UPDATE -> overwrite payload
      if (existing.operation == OutboxOperationType.update &&
          operation == OutboxOperationType.update) {
        final mergedPayload = {
          ...?existing.payload,
          ...?payload,
        };
        final updated = existing.copyWith(
          payload: mergedPayload,
          updatedAt: now,
          status: OutboxStatus.pending,
          clearLastError: true,
          clearNextRetryAt: true,
        );
        await db.update(
          'outbox_operations',
          updated.toMap(),
          where: 'id = ?',
          whereArgs: [existing.id],
        );
        return updated;
      }
    }

    // Otherwise, create a fresh outbox operation
    final op = OutboxOperation(
      id: _uuid.v4(),
      userId: userId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      createdAt: now,
      updatedAt: now,
      attemptCount: 0,
      status: OutboxStatus.pending,
    );

    await db.insert('outbox_operations', op.toMap());
    return op;
  }

  /// Retrieves pending operations ready for synchronization.
  Future<List<OutboxOperation>> getPendingOperations({
    String? userId,
    int limit = 50,
  }) async {
    final db = await _localDb.database;
    final nowIso = DateTime.now().toIso8601String();

    String whereClause = "(status = 'pending' OR (status = 'failed' AND attempt_count < $maxRetryAttempts AND next_retry_at IS NOT NULL AND next_retry_at <= ?))";
    List<dynamic> whereArgs = [nowIso];

    if (userId != null && userId.isNotEmpty) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }

    final rows = await db.query(
      'outbox_operations',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return rows.map((r) => OutboxOperation.fromMap(r)).toList();
  }

  /// Marks an operation as actively syncing.
  Future<void> markSyncing(String id) async {
    final db = await _localDb.database;
    await db.update(
      'outbox_operations',
      {
        'status': OutboxStatus.syncing.toDbString(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marks an operation as successfully synced.
  Future<void> markSynced(String id) async {
    final db = await _localDb.database;
    await db.update(
      'outbox_operations',
      {
        'status': OutboxStatus.synced.toDbString(),
        'updated_at': DateTime.now().toIso8601String(),
        'last_error': null,
        'next_retry_at': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Records an operation failure and applies exponential backoff or sets to failed.
  Future<void> markFailed(
    String id, {
    required String error,
    Duration? customDelay,
  }) async {
    final db = await _localDb.database;
    final now = DateTime.now();

    final row = await db.query(
      'outbox_operations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (row.isEmpty) return;

    final currentAttempts = (row.first['attempt_count'] as num?)?.toInt() ?? 0;
    final newAttempts = currentAttempts + 1;

    final isTerminalFailure = newAttempts >= maxRetryAttempts;

    // Exponential backoff delays: 5s, 15s, 60s, 300s, 900s
    final delaySeconds = customDelay?.inSeconds ??
        switch (newAttempts) {
          1 => 5,
          2 => 15,
          3 => 60,
          4 => 300,
          _ => 900,
        };

    final nextRetry = isTerminalFailure ? null : now.add(Duration(seconds: delaySeconds));

    await db.update(
      'outbox_operations',
      {
        'attempt_count': newAttempts,
        'status': OutboxStatus.failed.toDbString(),
        'last_error': error,
        'next_retry_at': nextRetry?.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Resets all failed operations to pending to allow immediate manual retry.
  Future<int> retryAllFailed({String? userId}) async {
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();

    String whereClause = "status = 'failed'";
    List<dynamic> whereArgs = [];
    if (userId != null && userId.isNotEmpty) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }

    return await db.update(
      'outbox_operations',
      {
        'status': OutboxStatus.pending.toDbString(),
        'attempt_count': 0,
        'last_error': null,
        'next_retry_at': null,
        'updated_at': now,
      },
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  /// Checks if an active un-synced outbox mutation exists for an entity.
  Future<bool> hasPendingMutation(String entityId) async {
    final db = await _localDb.database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM outbox_operations WHERE entity_id = ? AND status IN ('pending', 'syncing', 'failed')",
      [entityId],
    );
    return (Sqflite.firstIntValue(res) ?? 0) > 0;
  }

  /// Returns total counts of pending, failed, and syncing operations.
  Future<({int pending, int failed, int syncing, int total})> getCounts({String? userId}) async {
    final db = await _localDb.database;

    String wherePrefix = '';
    List<dynamic> args = [];
    if (userId != null && userId.isNotEmpty) {
      wherePrefix = 'WHERE user_id = ?';
      args.add(userId);
    }

    final rows = await db.rawQuery('''
      SELECT status, COUNT(*) as cnt 
      FROM outbox_operations 
      $wherePrefix
      GROUP BY status
    ''', args);

    int pending = 0;
    int failed = 0;
    int syncing = 0;

    for (final row in rows) {
      final s = (row['status'] as String? ?? '').toLowerCase();
      final count = (row['cnt'] as num?)?.toInt() ?? 0;
      if (s == 'pending') pending += count;
      if (s == 'failed') failed += count;
      if (s == 'syncing') syncing += count;
    }

    return (
      pending: pending,
      failed: failed,
      syncing: syncing,
      total: pending + failed + syncing,
    );
  }

  /// Cleans up old successfully synced operations to conserve SQLite storage.
  Future<int> purgeSyncedOperations({Duration olderThan = const Duration(days: 7)}) async {
    final db = await _localDb.database;
    final threshold = DateTime.now().subtract(olderThan).toIso8601String();
    return await db.delete(
      'outbox_operations',
      where: "status = 'synced' AND updated_at < ?",
      whereArgs: [threshold],
    );
  }
}
