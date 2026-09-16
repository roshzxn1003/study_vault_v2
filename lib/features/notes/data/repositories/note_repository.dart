import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/services/connectivity_service.dart';
import 'package:uuid/uuid.dart';

class NoteRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalDbService _localDb = LocalDbService.instance;
  final ConnectivityService _connectivity = ConnectivityService();

  Future<List<Map<String, dynamic>>> getNotes({String? folderId}) async {
    final db = await _localDb.database;

    // Try remote fetch if online and authenticated
    try {
      final user = _supabase.auth.currentUser;
      if (user != null && await _connectivity.checkStatus() == NetworkStatus.online) {
        var query = _supabase.from('notes').select().eq('user_id', user.id);
        if (folderId != null) query = query.eq('folder_id', folderId);
        final remoteNotes = await query.order('updated_at');

        for (var note in remoteNotes) {
          await db.insert('notes', note, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (e) {
      debugPrint('Remote notes fetch skipped/failed, using local cache: $e');
    }

    if (folderId != null) {
      return await db.query('notes', where: 'folder_id = ?', whereArgs: [folderId], orderBy: 'updated_at DESC');
    }
    return await db.query('notes', orderBy: 'updated_at DESC');
  }

  Future<Map<String, dynamic>?> getNoteById(String id) async {
    final db = await _localDb.database;
    final results = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (results.isNotEmpty) return results.first;

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        return await _supabase.from('notes').select().eq('id', id).single();
      }
    } catch (e) {
      debugPrint('Error getting note by id: $e');
    }
    return null;
  }

  Future<String> createNote({
    required String title,
    required String content,
    String? folderId,
  }) async {
    final user = _supabase.auth.currentUser;
    final userId = user?.id ?? 'guest';
    final noteId = const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    final noteData = {
      'id': noteId,
      'user_id': userId,
      'folder_id': folderId,
      'title': title,
      'content': content,
      'created_at': now,
      'updated_at': now,
      'sync_status': user != null ? 'pending' : 'synced',
    };

    final db = await _localDb.database;
    await db.insert('notes', noteData);

    if (user != null && await _connectivity.checkStatus() == NetworkStatus.online) {
      try {
        await _supabase.from('notes').insert(noteData);
        await db.update('notes', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [noteId]);
      } catch (e) {
        debugPrint('Immediate note sync failed: $e');
      }
    }

    return noteId;
  }

  Future<void> updateNote(String id, {String? title, String? content}) async {
    final db = await _localDb.database;
    final Map<String, dynamic> updates = {};
    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    updates['updated_at'] = DateTime.now().toIso8601String();
    updates['sync_status'] = 'pending';

    await db.update('notes', updates, where: 'id = ?', whereArgs: [id]);

    final user = _supabase.auth.currentUser;
    if (user != null && await _connectivity.checkStatus() == NetworkStatus.online) {
      try {
        await _supabase.from('notes').update(updates).eq('id', id);
        await db.update('notes', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        debugPrint('Note sync update failed: $e');
      }
    }
  }

  Future<void> deleteNote(String id) async {
    final db = await _localDb.database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);

    final user = _supabase.auth.currentUser;
    if (user != null && await _connectivity.checkStatus() == NetworkStatus.online) {
      try {
        await _supabase.from('notes').delete().eq('id', id);
      } catch (e) {
        debugPrint('Note delete sync failed: $e');
      }
    }
  }
}

