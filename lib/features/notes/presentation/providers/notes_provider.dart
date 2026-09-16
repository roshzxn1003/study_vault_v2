import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/providers/database_providers.dart';

final allNotesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(noteRepositoryProvider);
  return await repo.getNotes();
});

final noteDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.watch(noteRepositoryProvider);
  final note = await repo.getNoteById(id);
  if (note == null) throw Exception("Note not found");
  return note;
});

