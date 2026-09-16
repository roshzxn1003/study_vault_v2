import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/database/local_db_service.dart';

final searchProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final q = query.trim();

  final db = await LocalDbService.instance.database;

  // Search Local DB
  final localNotes = await db.query(
    'notes',
    where: 'title LIKE ? OR content LIKE ?',
    whereArgs: ['%$q%', '%$q%'],
  );

  final localFiles = await db.query(
    'files',
    where: 'name LIKE ?',
    whereArgs: ['%$q%'],
  );

  final localFolders = await db.query(
    'folders',
    where: 'name LIKE ?',
    whereArgs: ['%$q%'],
  );

  final List<Map<String, dynamic>> results = [
    ...localNotes,
    ...localFiles,
    ...localFolders,
  ];

  // If local results found, return them
  if (results.isNotEmpty) return results;

  // Otherwise try Supabase if connected
  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user != null) {
      final remoteNotes = await supabase
          .from('notes')
          .select()
          .ilike('title', '%$q%');
      final remoteFiles = await supabase
          .from('files')
          .select()
          .ilike('name', '%$q%');
      final remoteFolders = await supabase
          .from('folders')
          .select()
          .ilike('name', '%$q%');
      return [...remoteNotes, ...remoteFiles, ...remoteFolders];
    }
  } catch (_) {}

  return results;
});

