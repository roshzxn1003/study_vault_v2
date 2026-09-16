import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/services/connectivity_service.dart';
import 'package:uuid/uuid.dart';

class FolderRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalDbService _localDb = LocalDbService.instance;
  final ConnectivityService _connectivity = ConnectivityService();

  Future<List<Map<String, dynamic>>> getFolders() async {
    final db = await _localDb.database;

    // Try to refresh from remote if online and user is logged in
    try {
      final user = _supabase.auth.currentUser;
      if (user != null && await _connectivity.checkStatus() == NetworkStatus.online) {
        final remoteFolders = await _supabase
            .from('folders')
            .select()
            .eq('user_id', user.id)
            .order('created_at');

        for (var folder in remoteFolders) {
          await db.insert('folders', folder, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (e) {
      debugPrint('Remote folder fetch skipped/failed, using local cache: $e');
    }

    final local = await db.query('folders', orderBy: 'created_at DESC');
    return local;
  }

  Future<void> createFolder({required String name, String? parentId}) async {
    final user = _supabase.auth.currentUser;
    final userId = user?.id ?? 'guest';

    final folderData = {
      'id': const Uuid().v4(),
      'user_id': userId,
      'name': name,
      'parent_id': parentId,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'sync_status': user != null ? 'pending' : 'synced',
    };

    // Save local first
    final db = await _localDb.database;
    await db.insert('folders', folderData);

    // Try sync immediately if online and authenticated
    if (user != null && await _connectivity.checkStatus() == NetworkStatus.online) {
      try {
        await _supabase.from('folders').insert(folderData);
        await db.update('folders', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [folderData['id']]);
      } catch (e) {
        debugPrint('Immediate folder sync failed: $e');
      }
    }
  }

  Future<void> renameFolder(String id, String newName) async {
    final db = await _localDb.database;
    final updatedAt = DateTime.now().toIso8601String();
    
    await db.update('folders', 
      {'name': newName, 'updated_at': updatedAt, 'sync_status': 'pending'}, 
      where: 'id = ?', 
      whereArgs: [id]
    );

    final user = _supabase.auth.currentUser;
    if (user != null && await _connectivity.checkStatus() == NetworkStatus.online) {
      try {
        await _supabase.from('folders').update({'name': newName, 'updated_at': updatedAt}).eq('id', id);
        await db.update('folders', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        debugPrint('Sync failed: $e');
      }
    }
  }

  Future<void> deleteFolder(String id) async {
    final db = await _localDb.database;
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
    await db.delete('notes', where: 'folder_id = ?', whereArgs: [id]);
    await db.delete('files', where: 'folder_id = ?', whereArgs: [id]);

    final user = _supabase.auth.currentUser;
    if (user != null && await _connectivity.checkStatus() == NetworkStatus.online) {
      try {
        await _supabase.from('folders').delete().eq('id', id);
      } catch (e) {
        debugPrint('Remote delete failed: $e');
      }
    }
  }
}

