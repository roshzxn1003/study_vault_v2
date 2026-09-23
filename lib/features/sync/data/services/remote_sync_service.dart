import 'dart:io';
import '../../domain/models/outbox_operation.dart';

/// Abstract contract for remote cloud backend synchronization.
abstract class RemoteSyncService {
  /// Pushes a create, update, or delete operation for an entity.
  Future<void> pushEntity({
    required String entityType,
    required OutboxOperationType operation,
    required String entityId,
    required Map<String, dynamic> payload,
  });

  /// Uploads a physical material file to cloud storage bucket.
  Future<({String storagePath, String? remoteUrl})> uploadMaterialFile({
    required String userId,
    required String materialId,
    required File file,
    required String fileName,
  });

  /// Downloads a physical material file from cloud storage bucket as bytes.
  Future<List<int>> downloadMaterialFile({
    required String storagePath,
  });

  /// Pulls remote records that changed since the specified timestamp.
  Future<List<Map<String, dynamic>>> pullEntities({
    required String entityType,
    required String userId,
    DateTime? since,
  });
}
