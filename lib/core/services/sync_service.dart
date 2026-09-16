import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/services/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SyncStatus { pending, syncing, synced, failed }

class SyncService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalDbService _localDb = LocalDbService.instance;

  Future<void> syncAll() async {
    final connectivity = ConnectivityService();
    if (await connectivity.checkStatus() == NetworkStatus.offline) return;

    await _syncFolders();
    await _syncNotes();
  }

  Future<void> _syncFolders() async {
    final db = await _localDb.database;
    final pending = await db.query('folders', where: 'sync_status = ?', whereArgs: ['pending']);

    for (var folder in pending) {
      try {
        await _supabase.from('folders').upsert(folder);
        await db.update('folders', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [folder['id']]);
      } catch (e) {
        await db.update('folders', {'sync_status': 'failed'}, where: 'id = ?', whereArgs: [folder['id']]);
      }
    }
  }

  Future<void> _syncNotes() async {
    final db = await _localDb.database;
    final pending = await db.query('notes', where: 'sync_status = ?', whereArgs: ['pending']);

    for (var note in pending) {
      try {
        await _supabase.from('notes').upsert(note);
        await db.update('notes', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [note['id']]);
      } catch (e) {
        await db.update('notes', {'sync_status': 'failed'}, where: 'id = ?', whereArgs: [note['id']]);
      }
    }
  }
}

final syncServiceProvider = Provider((ref) => SyncService());
