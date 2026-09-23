import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/outbox_operation.dart';
import 'remote_sync_service.dart';

/// Implementation of RemoteSyncService using Supabase database and storage.
class SupabaseSyncService implements RemoteSyncService {
  final SupabaseClient? customClient;

  SupabaseSyncService({this.customClient});

  SupabaseClient get client => customClient ?? Supabase.instance.client;

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

  Map<String, dynamic> _normalizePayloadForRemote(
    String table,
    Map<String, dynamic> rawPayload,
  ) {
    final data = Map<String, dynamic>.from(rawPayload);

    // Strip local-only metadata
    data.remove('sync_status');
    data.remove('remote_updated_at');

    // Convert empty string foreign keys/dates to null for Postgres types
    for (final key in data.keys.toList()) {
      if (data[key] == '') {
        data[key] = null;
      }
    }

    // Normalize boolean columns (SQLite integers 0/1 -> Supabase booleans)
    const boolFields = [
      'is_current',
      'is_archived',
      'is_favorite',
      'is_inbox',
    ];
    for (final field in boolFields) {
      if (data.containsKey(field) && data[field] is int) {
        data[field] = data[field] == 1;
      }
    }

    return data;
  }

  @override
  Future<void> pushEntity({
    required String entityType,
    required OutboxOperationType operation,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    final table = _mapEntityTypeToTable(entityType);

    if (operation == OutboxOperationType.delete) {
      if (entityType == 'material_label') {
        final matId = payload['material_id'] as String?;
        final lblId = payload['label_id'] as String?;
        if (matId != null && lblId != null) {
          await client
              .from(table)
              .delete()
              .eq('material_id', matId)
              .eq('label_id', lblId);
        }
      } else {
        if (entityType == 'material') {
          final storagePath = payload['storage_path'] as String?;
          if (storagePath != null &&
              storagePath.isNotEmpty &&
              !storagePath.startsWith('/') &&
              !storagePath.startsWith('http')) {
            try {
              await client.storage.from('study_materials').remove([storagePath]);
            } catch (e) {
              debugPrint('Remote storage file deletion skipped/failed: $e');
            }
          }
        }
        await client.from(table).delete().eq('id', entityId);
      }
    } else {
      // Create or Update -> Upsert for idempotency
      final normalized = _normalizePayloadForRemote(table, payload);
      await client.from(table).upsert(normalized);
    }
  }

  @override
  Future<({String storagePath, String? remoteUrl})> uploadMaterialFile({
    required String userId,
    required String materialId,
    required File file,
    required String fileName,
  }) async {
    final cleanFileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final storagePath = '$userId/${materialId}_$cleanFileName';
    final bytes = await file.readAsBytes();

    await client.storage.from('study_materials').uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    String? publicUrl;
    try {
      publicUrl = client.storage.from('study_materials').getPublicUrl(storagePath);
    } catch (_) {
      publicUrl = null;
    }

    return (storagePath: storagePath, remoteUrl: publicUrl);
  }

  @override
  Future<List<int>> downloadMaterialFile({
    required String storagePath,
  }) async {
    return await client.storage.from('study_materials').download(storagePath);
  }

  @override
  Future<List<Map<String, dynamic>>> pullEntities({
    required String entityType,
    required String userId,
    DateTime? since,
  }) async {
    final table = _mapEntityTypeToTable(entityType);

    try {
      dynamic query = client.from(table).select();

      // Filter by user_id where applicable
      if (entityType != 'material_label') {
        query = query.eq('user_id', userId);
      }

      if (since != null) {
        query = query.gt('updated_at', since.toIso8601String());
      }

      final response = await query;
      if (response is List) {
        return List<Map<String, dynamic>>.from(
          response.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
      return [];
    } catch (e) {
      debugPrint('Error pulling remote entities for $table: $e');
      return [];
    }
  }
}
