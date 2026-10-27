import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';

final searchProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final q = query.trim();

  String userId = 'guest';
  try {
    final authRepo = ref.read(authRepositoryProvider);
    final currentUser = authRepo.getCurrentUser();
    final isGuest = ref.read(guestModeProvider);
    userId = currentUser?.id ?? (isGuest ? 'guest' : 'guest');
  } catch (_) {
    userId = 'guest';
  }

  final db = await LocalDbService.instance.database;

  // Search local materials (Phase 6 unified materials table) scoped strictly to userId
  final localMaterials = await db.query(
    'materials',
    where: 'user_id = ? AND (title LIKE ? OR original_file_name LIKE ?)',
    whereArgs: [userId, '%$q%', '%$q%'],
  );

  // Search local folders scoped strictly to userId
  final localFolders = await db.query(
    'folders',
    where: 'user_id = ? AND name LIKE ?',
    whereArgs: [userId, '%$q%'],
  );

  // Search legacy notes and files scoped strictly to userId
  final localNotes = await db.query(
    'notes',
    where: 'user_id = ? AND (title LIKE ? OR content LIKE ?)',
    whereArgs: [userId, '%$q%', '%$q%'],
  );

  final localFiles = await db.query(
    'files',
    where: 'user_id = ? AND name LIKE ?',
    whereArgs: [userId, '%$q%'],
  );

  // Search within document chunks (PDF pages, lecture notes, textbook extracts)
  List<Map<String, dynamic>> chunkResults = [];
  try {
    final chunkRows = await db.rawQuery('''
      SELECT dc.id, dc.material_id, dc.page_number, dc.text, m.title as material_title, m.original_file_name, m.type as material_type
      FROM document_chunks dc
      JOIN materials m ON dc.material_id = m.id
      WHERE (dc.user_id = ? OR dc.user_id = 'guest' OR m.user_id = ?) AND dc.text LIKE ?
      LIMIT 10
    ''', [userId, userId, '%$q%']);

    chunkResults = chunkRows.map((row) {
      final rawText = (row['text'] as String?) ?? '';
      final matchIdx = rawText.toLowerCase().indexOf(q.toLowerCase());
      String snippet = rawText;
      if (matchIdx != -1) {
        final start = (matchIdx - 30).clamp(0, rawText.length);
        final end = (matchIdx + q.length + 50).clamp(0, rawText.length);
        snippet = '${start > 0 ? "..." : ""}${rawText.substring(start, end).replaceAll('\n', ' ').trim()}${end < rawText.length ? "..." : ""}';
      } else if (rawText.length > 80) {
        snippet = '${rawText.substring(0, 80).replaceAll('\n', ' ').trim()}...';
      }

      return {
        'id': row['id'],
        'material_id': row['material_id'],
        'title': row['material_title'] ?? row['original_file_name'] ?? 'Document',
        'page_number': row['page_number'] ?? 1,
        'type': 'document_chunk',
        'snippet': snippet,
        'query': q,
      };
    }).toList();
  } catch (e) {
    debugPrint('SearchProvider document_chunks query note: $e');
  }

  final List<Map<String, dynamic>> results = [
    ...localMaterials,
    ...localFolders,
    ...localNotes,
    ...localFiles,
    ...chunkResults,
  ];

  if (results.isNotEmpty) return results;

  // Otherwise query Supabase with user_id scope if connected
  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user != null && user.id == userId) {
      final remoteMaterials = await supabase
          .from('materials')
          .select()
          .eq('user_id', userId)
          .ilike('title', '%$q%');
      final remoteFolders = await supabase
          .from('folders')
          .select()
          .eq('user_id', userId)
          .ilike('name', '%$q%');
      return [...remoteMaterials, ...remoteFolders];
    }
  } catch (e) {
    debugPrint('SearchProvider: Failed to query remote search results: $e');
  }

  return results;
});
