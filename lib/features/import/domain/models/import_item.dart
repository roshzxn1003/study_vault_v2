import 'package:study_vault/features/vault/domain/models/models.dart';

/// Status of an item during the import process.
enum ImportItemStatus {
  pending,
  importing,
  success,
  duplicateDetected,
  failed,
}

/// Represents an item staged for universal import into Study Vault.
class ImportItem {
  final String id;
  final String title;
  final VaultMaterialType type;
  final String? originalFileName;
  final String? filePath;
  final String? content;
  final int fileSize;
  final String? mimeType;
  final String? source;
  final ImportItemStatus status;
  final String? errorMessage;
  final MaterialItem? duplicateMatch;
  final String? contentHash;

  const ImportItem({
    required this.id,
    required this.title,
    required this.type,
    this.originalFileName,
    this.filePath,
    this.content,
    this.fileSize = 0,
    this.mimeType,
    this.source,
    this.status = ImportItemStatus.pending,
    this.errorMessage,
    this.duplicateMatch,
    this.contentHash,
  });

  /// Formatted file size representation.
  String get formattedFileSize {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  ImportItem copyWith({
    String? id,
    String? title,
    VaultMaterialType? type,
    String? originalFileName,
    String? filePath,
    String? content,
    int? fileSize,
    String? mimeType,
    String? source,
    ImportItemStatus? status,
    String? errorMessage,
    MaterialItem? duplicateMatch,
    bool clearDuplicate = false,
    String? contentHash,
  }) {
    return ImportItem(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      originalFileName: originalFileName ?? this.originalFileName,
      filePath: filePath ?? this.filePath,
      content: content ?? this.content,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      source: source ?? this.source,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      duplicateMatch: clearDuplicate ? null : (duplicateMatch ?? this.duplicateMatch),
      contentHash: contentHash ?? this.contentHash,
    );
  }
}
