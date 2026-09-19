import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/services/material_upload_service.dart';

final documentImportServiceProvider = Provider<DocumentImportService>((ref) {
  return DocumentImportService(ref);
});

/// Bridge service providing compatibility for document imports across existing screens
/// while routing through the robust [MaterialUploadService].
class DocumentImportService {
  final Ref _ref;
  DocumentImportService(this._ref);

  /// Launches the system file picker to import any document (PDF, Markdown, TXT, DOCX)
  /// into the local Study Vault database, persists it into app storage, and syncs it with Supabase.
  Future<Map<String, dynamic>?> pickAndImportDocument({
    String? folderId,
    String? subjectId,
    BuildContext? context,
  }) async {
    final uploadService = _ref.read(materialUploadServiceProvider);
    final materials = await uploadService.pickAndUploadFiles(
      context: context,
      folderId: folderId,
      subjectId: subjectId,
      allowMultiple: false,
    );

    if (materials.isEmpty) return null;

    final m = materials.first;
    return {
      'id': m.id,
      'user_id': m.userId,
      'folder_id': m.folderId,
      'name': m.originalFileName ?? m.title,
      'storage_path': m.filePath ?? m.storagePath ?? '',
      'mime_type': m.mimeType ?? 'application/pdf',
      'file_size': m.fileSize,
      'file_type': m.type.name.toUpperCase(),
      'created_at': m.createdAt.toIso8601String(),
      'updated_at': m.updatedAt.toIso8601String(),
    };
  }
}
