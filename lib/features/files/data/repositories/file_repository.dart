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

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        return await _supabase.from('files').select().eq('id', id).single();
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

    final user = _supabase.auth.currentUser;
    if (user != null && await _connectivity.checkStatus() == NetworkStatus.online) {
      try {
        await _supabase.storage.from('study_materials').remove([storagePath]);
        await _supabase.from('files').delete().eq('id', id);
      } catch (e) {
        debugPrint('Remote file delete failed: $e');
      }
    }
  }

  String getAuthenticatedUrl(String storagePath) {
    try {
      return _supabase.storage.from('study_materials').getPublicUrl(storagePath);
    } catch (_) {
      return storagePath;
    }
  }
}

