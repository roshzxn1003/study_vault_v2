import 'dart:convert';

/// Possible mutation types recorded in the Outbox queue.
enum OutboxOperationType {
  create,
  update,
  delete;

  static OutboxOperationType fromString(String value) {
    switch (value.trim().toUpperCase()) {
      case 'CREATE':
        return OutboxOperationType.create;
      case 'UPDATE':
        return OutboxOperationType.update;
      case 'DELETE':
        return OutboxOperationType.delete;
      default:
        return OutboxOperationType.create;
    }
  }

  String toDbString() => name.toUpperCase();
}

/// Outbox operation synchronization lifecycle status.
enum OutboxStatus {
  pending,
  syncing,
  synced,
  failed;

  static OutboxStatus fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'syncing':
        return OutboxStatus.syncing;
      case 'synced':
        return OutboxStatus.synced;
      case 'failed':
        return OutboxStatus.failed;
      case 'pending':
      default:
        return OutboxStatus.pending;
    }
  }

  String toDbString() => name.toLowerCase();
}

/// A single atomic mutation event waiting to be pushed to Supabase.
class OutboxOperation {
  final String id;
  final String userId;
  final String entityType; // 'workspace', 'academic_year', 'academic_period', 'subject', 'folder', 'material', 'label', 'material_label', 'personal_topic'
  final String entityId;
  final OutboxOperationType operation;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int attemptCount;
  final OutboxStatus status;
  final String? lastError;
  final DateTime? nextRetryAt;

  const OutboxOperation({
    required this.id,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.payload,
    required this.createdAt,
    required this.updatedAt,
    this.attemptCount = 0,
    this.status = OutboxStatus.pending,
    this.lastError,
    this.nextRetryAt,
  });

  OutboxOperation copyWith({
    String? id,
    String? userId,
    String? entityType,
    String? entityId,
    OutboxOperationType? operation,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? attemptCount,
    OutboxStatus? status,
    String? lastError,
    DateTime? nextRetryAt,
    bool clearLastError = false,
    bool clearNextRetryAt = false,
  }) {
    return OutboxOperation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attemptCount: attemptCount ?? this.attemptCount,
      status: status ?? this.status,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      nextRetryAt: clearNextRetryAt ? null : (nextRetryAt ?? this.nextRetryAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation.toDbString(),
      'payload': payload != null ? jsonEncode(payload) : null,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'attempt_count': attemptCount,
      'status': status.toDbString(),
      'last_error': lastError,
      'next_retry_at': nextRetryAt?.toIso8601String(),
    };
  }

  factory OutboxOperation.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? parsedPayload;
    if (map['payload'] != null && (map['payload'] as String).isNotEmpty) {
      try {
        parsedPayload = jsonDecode(map['payload'] as String) as Map<String, dynamic>;
      } catch (_) {
        parsedPayload = null;
      }
    }

    return OutboxOperation(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      operation: OutboxOperationType.fromString(map['operation'] as String? ?? 'CREATE'),
      payload: parsedPayload,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      attemptCount: (map['attempt_count'] as num?)?.toInt() ?? 0,
      status: OutboxStatus.fromString(map['status'] as String? ?? 'pending'),
      lastError: map['last_error'] as String?,
      nextRetryAt: map['next_retry_at'] != null ? DateTime.parse(map['next_retry_at'] as String) : null,
    );
  }
}
