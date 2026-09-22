import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/theme/app_colors.dart';
import 'package:study_vault/core/utils/permission_utils.dart';
import 'package:study_vault/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:study_vault/features/folders/presentation/providers/folders_provider.dart';
import 'package:study_vault/features/home/presentation/providers/home_provider.dart';
import 'package:study_vault/features/import/data/services/import_storage_service.dart';
import 'package:study_vault/features/inbox/presentation/providers/inbox_provider.dart';
import 'package:study_vault/features/sync/presentation/providers/sync_provider.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';
import 'package:study_vault/features/vault/presentation/providers/subject_vault_provider.dart';

final materialUploadServiceProvider = Provider<MaterialUploadService>((ref) {
  return MaterialUploadService(ref);
});

/// Comprehensive service providing file picking, internal storage persistence,
/// database record creation, outbox queuing, and background sync to Supabase.
class MaterialUploadService {
  final Ref _ref;
  final ImportStorageService _storageService = ImportStorageService();

  MaterialUploadService(this._ref);

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? 'guest';

  /// Picks one or more files from device storage, requests necessary permissions,
  /// saves them to persistent app storage, creates database records, and triggers cloud sync.
  Future<List<MaterialItem>> pickAndUploadFiles({
    BuildContext? context,
    String? subjectId,
    String? folderId,
    String? workspaceId,
    String? academicPeriodId,
    List<String> labelIds = const [],
    bool allowMultiple = true,
    List<String>? customAllowedExtensions,
  }) async {
    // 1. Check and request storage permissions
    final hasPermission = await PermissionUtils.requestFileStoragePermission(context: context);
    if (!hasPermission && context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Storage permission is required to access files.'),
          backgroundColor: AppColors.rose,
        ),
      );
    }

    // 2. Launch system file picker
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        type: FileType.custom,
        allowedExtensions: customAllowedExtensions ?? [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
          'txt',
          'md',
          'rtf',
          'jpg',
          'jpeg',
          'png',
          'webp',
          'mp3',
          'm4a',
          'wav',
          'aac',
          'epub',
          'csv',
        ],
      );
    } catch (e) {
      debugPrint('[MaterialUploadService] FilePicker error: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file picker: $e'),
            backgroundColor: AppColors.rose,
          ),
        );
      }
      return [];
    }

    if (result == null || result.files.isEmpty) {
      return [];
    }

    final uploadedMaterials = <MaterialItem>[];
    final vaultRepo = _ref.read(vaultRepositoryProvider);

    for (final pickedFile in result.files) {
      if (pickedFile.path == null) continue;

      final sourceFile = File(pickedFile.path!);
      if (!await sourceFile.exists()) continue;

      try {
        final rawFileName = pickedFile.name;
        final cleanTitle = p.basenameWithoutExtension(rawFileName).replaceAll('_', ' ').trim();
        final ext = pickedFile.extension?.toLowerCase() ?? '';

        // 3. Persist into app's permanent storage
        final savedFile = await _storageService.copyToMaterialsStorage(
          sourceFile: sourceFile,
          targetFileName: rawFileName,
        );

        final fileSize = await savedFile.length();
        final contentHash = await _storageService.calculateFileHash(savedFile);
        final materialType = _storageService.detectMaterialType(
          fileName: rawFileName,
          mimeType: _getMimeType(ext),
        );

        // 4. Extract text if PDF or text for local search indexing
        String? extractedText;
        try {
          if (ext == 'pdf') {
            final bytes = await savedFile.readAsBytes();
            final pdfDoc = PdfDocument(inputBytes: bytes);
            final buffer = StringBuffer();
            final maxPages = pdfDoc.pages.count > 50 ? 50 : pdfDoc.pages.count;
            for (int i = 0; i < maxPages; i++) {
              final pageText = PdfTextExtractor(pdfDoc).extractText(startPageIndex: i, endPageIndex: i);
              if (pageText.trim().isNotEmpty) {
                buffer.writeln(pageText);
              }
            }
            pdfDoc.dispose();
            extractedText = buffer.toString();
          } else if (ext == 'txt' || ext == 'md') {
            extractedText = await savedFile.readAsString();
          }
        } catch (e) {
          debugPrint('[MaterialUploadService] Text extraction skipped: $e');
        }

        // 5. Create canonical material in SQLite & enqueue outbox sync
        final material = await vaultRepo.createMaterial(
          userId: _currentUserId,
          workspaceId: workspaceId,
          academicPeriodId: academicPeriodId,
          subjectId: subjectId,
          folderId: folderId,
          title: cleanTitle.isEmpty ? rawFileName : cleanTitle,
          originalFileName: rawFileName,
          type: materialType,
          filePath: savedFile.path,
          storagePath: savedFile.path,
          mimeType: _getMimeType(ext),
          fileSize: fileSize,
          content: extractedText,
          contentHash: contentHash,
          labelIds: labelIds,
          isInbox: folderId == null && subjectId == null,
          source: 'Storage',
        );

        // 6. Mirror into files table for backward compatibility
        try {
          final db = await LocalDbService.instance.database;
          await db.insert(
            'files',
            {
              'id': material.id,
              'user_id': _currentUserId,
              'folder_id': folderId,
              'name': rawFileName,
              'storage_path': savedFile.path,
              'mime_type': _getMimeType(ext),
              'file_size': fileSize,
              'file_type': ext.toUpperCase(),
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
              'sync_status': _currentUserId != 'guest' ? 'pending' : 'synced',
            },
          );
        } catch (e) {
          debugPrint('[MaterialUploadService] Legacy files table insert note: $e');
        }

        uploadedMaterials.add(material);
      } catch (e) {
        debugPrint('[MaterialUploadService] Failed processing file ${pickedFile.name}: $e');
      }
    }

    if (uploadedMaterials.isNotEmpty) {
      // 7. Refresh Riverpod state
      _invalidateProviders(subjectId);

      // 8. Trigger background cloud sync
      try {
        _ref.read(syncProvider.notifier).syncNow();
      } catch (e) {
        debugPrint('[MaterialUploadService] Sync trigger skipped: $e');
      }

      // 9. User confirmation
      if (context != null && context.mounted) {
        final count = uploadedMaterials.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count == 1
                  ? 'Added "${uploadedMaterials.first.title}" to Study Vault!'
                  : 'Added $count materials to Study Vault!',
            ),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }

    return uploadedMaterials;
  }

  /// Picks images from gallery and uploads them as study materials.
  Future<List<MaterialItem>> pickFromGallery({
    BuildContext? context,
    String? subjectId,
    String? folderId,
    String? workspaceId,
    String? academicPeriodId,
  }) async {
    try {
      final picker = ImagePicker();
      final pickedImages = await picker.pickMultiImage();

      if (pickedImages.isEmpty) return [];

      final uploaded = <MaterialItem>[];
      final vaultRepo = _ref.read(vaultRepositoryProvider);

      for (final image in pickedImages) {
        final sourceFile = File(image.path);
        if (!await sourceFile.exists()) continue;

        final rawFileName = p.basename(image.path);
        final cleanTitle = p.basenameWithoutExtension(rawFileName).replaceAll('_', ' ').trim();
        final ext = p.extension(image.path).toLowerCase();

        final savedFile = await _storageService.copyToMaterialsStorage(
          sourceFile: sourceFile,
          targetFileName: rawFileName,
        );

        final fileSize = await savedFile.length();
        final contentHash = await _storageService.calculateFileHash(savedFile);

        final material = await vaultRepo.createMaterial(
          userId: _currentUserId,
          workspaceId: workspaceId,
          academicPeriodId: academicPeriodId,
          subjectId: subjectId,
          folderId: folderId,
          title: cleanTitle.isEmpty ? 'Image Material' : cleanTitle,
          originalFileName: rawFileName,
          type: VaultMaterialType.image,
          filePath: savedFile.path,
          storagePath: savedFile.path,
          mimeType: _getMimeType(ext),
          fileSize: fileSize,
          contentHash: contentHash,
          isInbox: folderId == null && subjectId == null,
          source: 'Gallery',
        );

        uploaded.add(material);
      }

      if (uploaded.isNotEmpty) {
        _invalidateProviders(subjectId);
        try {
          _ref.read(syncProvider.notifier).syncNow();
        } catch (e) {
          debugPrint('[MaterialUploadService] Gallery background sync note: $e');
        }

        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${uploaded.length} image(s) to Study Vault!'),
              backgroundColor: AppColors.emerald,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      return uploaded;
    } catch (e) {
      debugPrint('[MaterialUploadService] Gallery pick error: $e');
      return [];
    }
  }

  /// Adds a web link or URL reference as a study material.
  Future<MaterialItem?> addLinkMaterial({
    BuildContext? context,
    required String title,
    required String url,
    String? subjectId,
    String? folderId,
    String? workspaceId,
    String? academicPeriodId,
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return null;
    final cleanTitle = title.trim().isNotEmpty ? title.trim() : cleanUrl;
    final vaultRepo = _ref.read(vaultRepositoryProvider);

    try {
      final material = await vaultRepo.createMaterial(
        userId: _currentUserId,
        workspaceId: workspaceId,
        academicPeriodId: academicPeriodId,
        subjectId: subjectId,
        folderId: folderId,
        title: cleanTitle,
        type: VaultMaterialType.link,
        remoteUrl: cleanUrl,
        source: 'Link',
        isInbox: folderId == null && subjectId == null,
      );

      _invalidateProviders(subjectId);
      try {
        _ref.read(syncProvider.notifier).syncNow();
      } catch (e) {
        debugPrint('[MaterialUploadService] Link background sync note: $e');
      }

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added link "$cleanTitle" to Study Vault!'),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return material;
    } catch (e) {
      debugPrint('[MaterialUploadService] addLinkMaterial error: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not add link: $e'),
            backgroundColor: AppColors.rose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }

  /// Creates a markdown note, writes it to persistent storage, records in SQLite, and triggers cloud sync.
  Future<MaterialItem?> createMarkdownNote({
    BuildContext? context,
    required String title,
    required String content,
    String? subjectId,
    String? folderId,
    String? workspaceId,
    String? academicPeriodId,
  }) async {
    try {
      final cleanTitle = title.trim().isEmpty ? 'Untitled Study Note' : title.trim();
      final dir = await _storageService.getMaterialsDirectory();
      final safeName = _storageService.sanitizeFileName(cleanTitle);
      final fileName = '${safeName}_${DateTime.now().millisecondsSinceEpoch}.md';
      final file = File(p.join(dir.path, fileName));
      await file.writeAsString(content);

      final fileSize = await file.length();
      final contentHash = _storageService.calculateStringHash(content);
      final vaultRepo = _ref.read(vaultRepositoryProvider);

      final material = await vaultRepo.createMaterial(
        userId: _currentUserId,
        workspaceId: workspaceId,
        academicPeriodId: academicPeriodId,
        subjectId: subjectId,
        folderId: folderId,
        title: cleanTitle,
        originalFileName: fileName,
        type: VaultMaterialType.note,
        filePath: file.path,
        storagePath: file.path,
        mimeType: 'text/markdown',
        fileSize: fileSize,
        content: content,
        contentHash: contentHash,
        isInbox: folderId == null && subjectId == null,
        source: 'Note',
      );

      _invalidateProviders(subjectId);
      try {
        _ref.read(syncProvider.notifier).syncNow();
      } catch (e) {
        debugPrint('[MaterialUploadService] Note sync trigger note: $e');
      }

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved note "$cleanTitle" to Study Vault!'),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return material;
    } catch (e) {
      debugPrint('[MaterialUploadService] createMarkdownNote error: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save note: $e'),
            backgroundColor: AppColors.rose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }

  void _invalidateProviders(String? subjectId) {
    _ref.invalidate(vaultProvider);
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(inboxProvider);
    _ref.invalidate(foldersProvider);
    _ref.invalidate(homeDataProvider);
    _ref.invalidate(allFilesProvider);
    _ref.invalidate(vaultStatsProvider);
    if (subjectId != null) {
      _ref.invalidate(subjectVaultProvider(subjectId));
    }
  }

  String _getMimeType(String ext) {
    switch (ext.replaceAll('.', '').toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'md':
        return 'text/markdown';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }
}
