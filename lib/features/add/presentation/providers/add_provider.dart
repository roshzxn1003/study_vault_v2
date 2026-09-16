import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/providers/database_providers.dart';

final addActionProvider = Provider((ref) {
  return AddActions(
    createFolder: ref.read(folderRepositoryProvider).createFolder,
    createNote: ref.read(noteRepositoryProvider).createNote,
    uploadFile: ref.read(storageRepositoryProvider).uploadFile,
  );
});

class AddActions {
  final Future<void> Function({required String name, String? parentId}) createFolder;
  final Future<void> Function({required String title, required String content, String? folderId}) createNote;
  final Future<String> Function({required String filePath, required String fileName, required String folderId, required int fileSize, required String mimeType}) uploadFile;

  AddActions({required this.createFolder, required this.createNote, required this.uploadFile});
}
