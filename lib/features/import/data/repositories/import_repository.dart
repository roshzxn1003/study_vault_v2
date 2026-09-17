import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:study_vault/features/vault/data/repositories/vault_repository.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';
import '../../domain/models/import_item.dart';
import '../services/import_storage_service.dart';

/// Repository coordinating file validation, duplicate checks, filesystem storage,
/// and material persistence in SQLite.
class ImportRepository {
  final VaultRepository _vaultRepository;
  final ImportStorageService _storageService;

  ImportRepository({
    VaultRepository? vaultRepository,
    ImportStorageService? storageService,
  })  : _vaultRepository = vaultRepository ?? VaultRepository(),
        _storageService = storageService ?? ImportStorageService();

  /// Inspects and stages incoming items with hashes, validation, and duplicate detection.
  Future<List<ImportItem>> validateAndStageItems(
    List<ImportItem> items, {
    required String userId,
  }) async {
    final staged = <ImportItem>[];

    for (final item in items) {
      // 1. Validate file format if it's a file
      if (item.filePath != null && item.filePath!.isNotEmpty) {
        final supported = _storageService.isSupportedFile(
          fileName: item.originalFileName ?? item.title,
          mimeType: item.mimeType,
        );

        if (!supported) {
          staged.add(item.copyWith(
            status: ImportItemStatus.failed,
            errorMessage: "This file type isn't supported yet.",
          ));
          continue;
        }

        final file = File(item.filePath!);
        if (!await file.exists()) {
          staged.add(item.copyWith(
            status: ImportItemStatus.failed,
            errorMessage: 'Inaccessible or missing file.',
          ));
          continue;
        }

        // 2. Compute file hash
        final hash = await _storageService.calculateFileHash(file);

        // 3. Check duplicate
        final duplicate = await _vaultRepository.findDuplicateMaterial(
          userId: userId,
          contentHash: hash,
          originalFileName: item.originalFileName,
          fileSize: item.fileSize,
        );

        if (duplicate != null) {
          staged.add(item.copyWith(
            contentHash: hash,
            status: ImportItemStatus.duplicateDetected,
            duplicateMatch: duplicate,
          ));
        } else {
          staged.add(item.copyWith(
            contentHash: hash,
            status: ImportItemStatus.pending,
          ));
        }
      } else if (item.type == VaultMaterialType.link || item.type == VaultMaterialType.note) {
        // Compute hash of content
        final contentStr = item.content ?? item.title;
        final hash = _storageService.calculateStringHash(contentStr);

        final duplicate = await _vaultRepository.findDuplicateMaterial(
          userId: userId,
          contentHash: hash,
        );

        if (duplicate != null) {
          staged.add(item.copyWith(
            contentHash: hash,
            status: ImportItemStatus.duplicateDetected,
            duplicateMatch: duplicate,
          ));
        } else {
          staged.add(item.copyWith(
            contentHash: hash,
            status: ImportItemStatus.pending,
          ));
        }
      } else {
        staged.add(item.copyWith(status: ImportItemStatus.pending));
      }
    }

    return staged;
  }

  /// Imports a single staging item into the database and storage.
  Future<MaterialItem> importItem(
    ImportItem item, {
    required String userId,
    String? workspaceId,
    String? academicPeriodId,
    String? subjectId,
    String? folderId,
    List<String>? labelIds,
    bool isInbox = true,
  }) async {
    String? finalFilePath;
    String? finalStoragePath;
    int finalFileSize = item.fileSize;

    // Handle physical file persistence
    if (item.filePath != null && item.filePath!.isNotEmpty) {
      final source = File(item.filePath!);
      if (await source.exists()) {
        try {
          final targetName = item.originalFileName ?? '${item.title}.pdf';
          final savedFile = await _storageService.copyToMaterialsStorage(
            sourceFile: source,
            targetFileName: targetName,
          );
          finalFilePath = savedFile.path;
          finalStoragePath = savedFile.path;
          finalFileSize = await savedFile.length();
        } catch (e) {
          debugPrint('Failed to copy file to materials storage: $e');
          // Fallback to original path if copy fails
          finalFilePath = item.filePath;
          finalStoragePath = item.filePath;
        }
      }
    }

    // Persist MaterialItem
    return await _vaultRepository.createMaterial(
      userId: userId,
      workspaceId: workspaceId,
      academicPeriodId: academicPeriodId,
      subjectId: subjectId,
      folderId: folderId,
      title: item.title,
      type: item.type,
      originalFileName: item.originalFileName ?? item.title,
      filePath: finalFilePath,
      storagePath: finalStoragePath,
      fileSize: finalFileSize,
      mimeType: item.mimeType,
      content: item.content,
      remoteUrl: item.type == VaultMaterialType.link ? item.content : null,
      labelIds: labelIds ?? const [],
      isInbox: isInbox,
      source: item.source ?? 'Imported',
      importStatus: 'imported',
      contentHash: item.contentHash,
    );
  }

  /// Batch imports multiple staged items with progress callbacks and fault tolerance.
  Future<({List<MaterialItem> succeeded, List<ImportItem> failed})> importBatch(
    List<ImportItem> items, {
    required String userId,
    String? workspaceId,
    String? academicPeriodId,
    String? subjectId,
    String? folderId,
    List<String>? labelIds,
    bool isInbox = true,
    void Function(int current, int total)? onProgress,
  }) async {
    final succeeded = <MaterialItem>[];
    final failed = <ImportItem>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      onProgress?.call(i + 1, items.length);

      // Skip already failed items from validation
      if (item.status == ImportItemStatus.failed) {
        failed.add(item);
        continue;
      }

      try {
        final saved = await importItem(
          item,
          userId: userId,
          workspaceId: workspaceId,
          academicPeriodId: academicPeriodId,
          subjectId: subjectId,
          folderId: folderId,
          labelIds: labelIds,
          isInbox: isInbox,
        );
        succeeded.add(saved);
      } catch (e) {
        debugPrint('Error importing item ${item.title}: $e');
        failed.add(item.copyWith(
          status: ImportItemStatus.failed,
          errorMessage: e.toString(),
        ));
      }
    }

    return (succeeded: succeeded, failed: failed);
  }
}
