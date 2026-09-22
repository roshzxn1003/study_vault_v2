import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/services/connectivity_service.dart';
import 'package:uuid/uuid.dart';

class FileRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalDbService _localDb = LocalDbService.instance;
  final ConnectivityService _connectivity = ConnectivityService();

  Future<List<Map<String, dynamic>>> getFiles({String? folderId}) async {
    final db = await _localDb.database;

    try {
      final user = _supabase.auth.currentUser;
      if (user != null && await _connectivity.checkStatus() == NetworkStatus.online) {
        var query = _supabase.from('files').select().eq('user_id', user.id);
        if (folderId != null) query = query.eq('folder_id', folderId);
        final remoteFiles = await query.order('created_at');

        for (var file in remoteFiles) {
          await db.insert('files', file, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (e) {
      debugPrint('Remote files fetch skipped/failed, using local cache: $e');
    }

    final currentUserId = _supabase.auth.currentUser?.id ?? 'guest';
    if (folderId != null) {
      return await db.query(
        'files',
        where: 'user_id = ? AND folder_id = ?',
        whereArgs: [currentUserId, folderId],
        orderBy: 'created_at DESC',
      );
    }
    return await db.query(
      'files',
      where: 'user_id = ?',
      whereArgs: [currentUserId],
      orderBy: 'created_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getFileById(String id) async {
    final db = await _localDb.database;
    final results = await db.query('files', where: 'id = ?', whereArgs: [id]);
    if (results.isNotEmpty) return results.first;

    // Phase 6 unified materials table lookup
    try {
      final matResults = await db.query('materials', where: 'id = ?', whereArgs: [id]);
      if (matResults.isNotEmpty) {
        final m = matResults.first;
        return {
          'id': m['id'],
          'name': m['title'] ?? m['original_file_name'] ?? 'Material',
          'file_type': m['type'] ?? 'PDF',
          'storage_path': (m['file_path'] != null && (m['file_path'] as String).isNotEmpty)
              ? m['file_path']
              : (m['storage_path'] ?? m['remote_url'] ?? ''),
          'folder_id': m['folder_id'],
          'file_size': m['file_size'] ?? 0,
          'mime_type': m['mime_type'],
          'created_at': m['created_at'],
          'updated_at': m['updated_at'],
          'remote_url': m['remote_url'],
          'content': m['content'],
        };
      }
    } catch (e) {
      debugPrint('FileRepository: Local materials query error: $e');
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        try {
          return await _supabase.from('files').select().eq('id', id).single();
        } catch (_) {}

        final remoteMat = await _supabase.from('materials').select().eq('id', id).single();
        return {
          'id': remoteMat['id'],
          'name': remoteMat['title'] ?? remoteMat['original_file_name'] ?? 'Material',
          'file_type': remoteMat['type'] ?? 'PDF',
          'storage_path': (remoteMat['file_path'] != null && (remoteMat['file_path'] as String).isNotEmpty)
              ? remoteMat['file_path']
              : (remoteMat['storage_path'] ?? remoteMat['remote_url'] ?? ''),
          'folder_id': remoteMat['folder_id'],
          'file_size': remoteMat['file_size'] ?? 0,
          'mime_type': remoteMat['mime_type'],
          'created_at': remoteMat['created_at'],
          'updated_at': remoteMat['updated_at'],
          'remote_url': remoteMat['remote_url'],
          'content': remoteMat['content'],
        };
      }
    } catch (e) {
      debugPrint('Error getting file by id: $e');
    }
    return null;
  }

  Future<String> uploadFileMetadata({
    required String name,
    required String type,
    required String storagePath,
    required String folderId,
    required int size,
    String? mimeType,
  }) async {
    final user = _supabase.auth.currentUser;
    final userId = user?.id ?? 'guest';
    final fileId = const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    final fileData = {
      'id': fileId,
      'user_id': userId,
      'folder_id': folderId,
      'name': name,
      'file_type': type,
      'storage_path': storagePath,
      'file_size': size,
      'mime_type': mimeType ?? 'application/pdf',
      'created_at': now,
      'updated_at': now,
      'sync_status': user != null ? 'pending' : 'synced',
    };

    final db = await _localDb.database;
    await db.insert('files', fileData);

    if (user != null && await _connectivity.checkStatus() == NetworkStatus.online) {
      try {
        await _supabase.from('files').insert(fileData);
        await db.update('files', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [fileId]);
      } catch (e) {
        debugPrint('File metadata sync failed: $e');
      }
    }

    return fileId;
  }

  Future<void> deleteFile(String id, String storagePath) async {
    final db = await _localDb.database;
    await db.delete('files', where: 'id = ?', whereArgs: [id]);
    await db.delete('materials', where: 'id = ?', whereArgs: [id]);

    final user = _supabase.auth.currentUser;
    if (user != null && await _connectivity.checkStatus() == NetworkStatus.online) {
      try {
        if (storagePath.isNotEmpty && !storagePath.startsWith('/')) {
          await _supabase.storage.from('study_materials').remove([storagePath]);
        }
        await _supabase.from('files').delete().eq('id', id);
        await _supabase.from('materials').delete().eq('id', id);
      } catch (e) {
        debugPrint('Remote file delete failed: $e');
      }
    }
  }

  Future<String> getAuthenticatedUrl(String storagePath) async {
    if (storagePath.isEmpty) return '';
    if (storagePath.startsWith('http://') || storagePath.startsWith('https://')) {
      return storagePath;
    }
    try {
      return await _supabase.storage.from('study_materials').createSignedUrl(storagePath, 3600);
    } catch (e) {
      debugPrint('FileRepository: Failed to create signed URL for $storagePath: $e');
      return storagePath;
    }
  }
}

