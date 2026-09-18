import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';

final searchProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final q = query.trim();

  final authRepo = ref.read(authRepositoryProvider);
  final currentUser = authRepo.getCurrentUser();
  final isGuest = ref.read(guestModeProvider);
  final userId = currentUser?.id ?? (isGuest ? 'guest' : null);
  if (userId == null) return [];

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

  final List<Map<String, dynamic>> results = [
    ...localMaterials,
    ...localFolders,
    ...localNotes,
    ...localFiles,
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
  } catch (_) {}

  return results;
});
