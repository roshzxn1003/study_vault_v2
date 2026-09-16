import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/features/files/data/repositories/file_repository.dart';

class StorageRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FileRepository _fileRepo = FileRepository();

  Future<String> uploadFile({
    required String filePath,
    required String fileName,
    required String folderId,
    required int fileSize,
    required String mimeType,
  }) async {
    final user = _supabase.auth.currentUser;
    String finalStoragePath = filePath;

    if (user != null) {
      final String fileId = DateTime.now().millisecondsSinceEpoch.toString();
      final String remoteStoragePath = '${user.id}/$folderId/${fileId}_$fileName';

      try {
        await _supabase.storage.from('study-files').upload(
          remoteStoragePath,
          File(filePath),
          fileOptions: const FileOptions(upsert: true),
        );
        finalStoragePath = remoteStoragePath;
      } catch (e) {
        // Fallback to local path if remote upload fails
        finalStoragePath = filePath;
      }
    }

    await _fileRepo.uploadFileMetadata(
      name: fileName,
      type: fileName.split('.').last.toUpperCase(),
      storagePath: finalStoragePath,
      folderId: folderId,
      size: fileSize,
      mimeType: mimeType,
    );

    return finalStoragePath;
  }

  Future<void> deleteFile(String fileId, String storagePath) async {
    await _fileRepo.deleteFile(fileId, storagePath);
  }
}
