import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/providers/database_providers.dart';

final foldersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(folderRepositoryProvider);
  return await repo.getFolders();
});

final createFolderProvider = Provider((ref) {
  return ref.read(folderRepositoryProvider).createFolder;
});

final deleteFolderProvider = Provider((ref) {
  return ref.read(folderRepositoryProvider).deleteFolder;
});
