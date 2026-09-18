import 'package:flutter/material.dart';
import 'vault_label.dart';

/// Supported academic material types within the Vault.
enum VaultMaterialType {
  pdf(
    label: 'PDF',
    icon: Icons.picture_as_pdf_rounded,
    color: Color(0xFFEF4444),
  ),
  image(
    label: 'Image',
    icon: Icons.image_rounded,
    color: Color(0xFF10B981),
  ),
  note(
    label: 'Note',
    icon: Icons.edit_note_rounded,
    color: Color(0xFFF59E0B),
  ),
  document(
    label: 'Document',
    icon: Icons.description_rounded,
    color: Color(0xFF3B82F6),
  ),
  link(
    label: 'Link',
    icon: Icons.link_rounded,
    color: Color(0xFF8B5CF6),
  );

  final String label;
  final IconData icon;
  final Color color;

  const VaultMaterialType({
    required this.label,
    required this.icon,
    required this.color,
  });

  static VaultMaterialType fromString(String? value) {
    if (value == null) return VaultMaterialType.document;
    final normalized = value.trim().toUpperCase();
    switch (normalized) {
      case 'PDF':
        return VaultMaterialType.pdf;
      case 'IMAGE':
      case 'IMG':
      case 'JPG':
      case 'JPEG':
      case 'PNG':
      case 'WEBP':
        return VaultMaterialType.image;
      case 'NOTE':
      case 'TEXT':
      case 'MARKDOWN':
        return VaultMaterialType.note;
      case 'LINK':
      case 'URL':
      case 'RESOURCE':
        return VaultMaterialType.link;
      case 'DOCUMENT':
      case 'DOC':
      case 'DOCX':
      case 'TXT':
      default:
        return VaultMaterialType.document;
    }
  }

  String toDbString() {
    switch (this) {
      case VaultMaterialType.pdf:
        return 'PDF';
      case VaultMaterialType.image:
        return 'IMAGE';
      case VaultMaterialType.note:
        return 'NOTE';
      case VaultMaterialType.document:
        return 'DOCUMENT';
      case VaultMaterialType.link:
        return 'LINK';
    }
  }
}

/// Core material representation in Study Vault.
/// Unifies files, notes, documents, and resources under a strict academic hierarchy.
class MaterialItem {
  final String id;
  final String userId;
  final String? workspaceId;
  final String? academicPeriodId;
  final String? subjectId;
  final String? folderId;
  final String title;
  final String? description;
  final String? originalFileName;
  final VaultMaterialType type;
  final String? content;
  final String? filePath;
  final String? storagePath;
  final String? mimeType;
  final int fileSize;
  final String? remoteUrl;
  final bool isFavorite;
  final bool isArchived;
  final bool isInbox;
  final String? source;
  final String? importStatus;
  final String? contentHash;
  final String? indexingStatus;
  final String? indexingError;
  final DateTime? indexedAt;
  final DateTime? lastOpenedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<VaultLabel> labels;
  final String? subjectName;
  final String? folderName;

  const MaterialItem({
    required this.id,
    required this.userId,
    this.workspaceId,
    this.academicPeriodId,
    this.subjectId,
    this.folderId,
    required this.title,
    this.description,
    this.originalFileName,
    required this.type,
    this.content,
    this.filePath,
    this.storagePath,
    this.mimeType,
    this.fileSize = 0,
    this.remoteUrl,
    this.isFavorite = false,
    this.isArchived = false,
    this.isInbox = false,
    this.source,
    this.importStatus,
    this.contentHash,
    this.indexingStatus,
    this.indexingError,
    this.indexedAt,
    this.lastOpenedAt,
    required this.createdAt,
    required this.updatedAt,
    this.labels = const [],
    this.subjectName,
    this.folderName,
  });

  /// Formatted file size string (e.g. 450 KB, 2.4 MB).
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

  /// Humanized relative time string for updates.
  String get relativeUpdatedTime {
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
  }

  /// Relative opened time or fallback.
  String get relativeOpenedTime {
    if (lastOpenedAt == null) return 'Never opened';
    final diff = DateTime.now().difference(lastOpenedAt!);
    if (diff.inSeconds < 60) return 'Opened just now';
    if (diff.inMinutes < 60) return 'Opened ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Opened ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Opened yesterday';
    return 'Opened ${diff.inDays}d ago';
  }

  /// Subtitle combining subject and folder path.
  String get locationSubtitle {
    final parts = <String>[];
    if (subjectName != null && subjectName!.isNotEmpty) {
      parts.add(subjectName!);
    }
    if (folderName != null && folderName!.isNotEmpty) {
      parts.add(folderName!);
    }
    if (parts.isEmpty) {
      return 'Vault Root';
    }
    return parts.join(' • ');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'workspace_id': workspaceId,
      'academic_period_id': academicPeriodId,
      'subject_id': subjectId,
      'folder_id': folderId,
      'title': title,
      'description': description,
      'original_file_name': originalFileName,
      'type': type.toDbString(),
      'content': content,
      'file_path': filePath,
      'storage_path': storagePath,
      'mime_type': mimeType,
      'file_size': fileSize,
      'remote_url': remoteUrl,
      'is_favorite': isFavorite ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'is_inbox': isInbox ? 1 : 0,
      'source': source,
      'import_status': importStatus,
      'content_hash': contentHash,
      'indexing_status': indexingStatus,
      'indexing_error': indexingError,
      'indexed_at': indexedAt?.toIso8601String(),
      'last_opened_at': lastOpenedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MaterialItem.fromMap(
    Map<String, dynamic> map, {
    List<VaultLabel> labels = const [],
    String? subjectName,
    String? folderName,
  }) {
    return MaterialItem(
      id: map['id'] as String,
      userId: map['user_id'] as String? ?? 'guest',
      workspaceId: map['workspace_id'] as String?,
      academicPeriodId: map['academic_period_id'] as String?,
      subjectId: map['subject_id'] as String?,
      folderId: map['folder_id'] as String?,
      title: map['title'] as String? ?? 'Untitled Material',
      description: map['description'] as String?,
      originalFileName: map['original_file_name'] as String?,
      type: VaultMaterialType.fromString(map['type'] as String?),
      content: map['content'] as String?,
      filePath: map['file_path'] as String?,
      storagePath: map['storage_path'] as String?,
      mimeType: map['mime_type'] as String?,
      fileSize: (map['file_size'] as num?)?.toInt() ?? 0,
      remoteUrl: map['remote_url'] as String?,
      isFavorite: (map['is_favorite'] as num?)?.toInt() == 1,
      isArchived: (map['is_archived'] as num?)?.toInt() == 1,
      isInbox: (map['is_inbox'] as num?)?.toInt() == 1,
      source: map['source'] as String?,
      importStatus: map['import_status'] as String? ?? 'imported',
      contentHash: map['content_hash'] as String?,
      indexingStatus: map['indexing_status'] as String? ?? 'NOT_INDEXED',
      indexingError: map['indexing_error'] as String?,
      indexedAt: map['indexed_at'] != null
          ? DateTime.tryParse(map['indexed_at'] as String)
          : null,
      lastOpenedAt: map['last_opened_at'] != null
          ? DateTime.tryParse(map['last_opened_at'] as String)
          : null,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
      labels: labels,
      subjectName: subjectName,
      folderName: folderName,
    );
  }

  MaterialItem copyWith({
    String? id,
    String? userId,
    String? workspaceId,
    String? academicPeriodId,
    String? subjectId,
    String? folderId,
    String? title,
    String? description,
    String? originalFileName,
    VaultMaterialType? type,
    String? content,
    String? filePath,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    String? remoteUrl,
    bool? isFavorite,
    bool? isArchived,
    bool? isInbox,
    String? source,
    String? importStatus,
    String? contentHash,
    String? indexingStatus,
    String? indexingError,
    DateTime? indexedAt,
    DateTime? lastOpenedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<VaultLabel>? labels,
    String? subjectName,
    String? folderName,
  }) {
    return MaterialItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      workspaceId: workspaceId ?? this.workspaceId,
      academicPeriodId: academicPeriodId ?? this.academicPeriodId,
      subjectId: subjectId ?? this.subjectId,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      description: description ?? this.description,
      originalFileName: originalFileName ?? this.originalFileName,
      type: type ?? this.type,
      content: content ?? this.content,
      filePath: filePath ?? this.filePath,
      storagePath: storagePath ?? this.storagePath,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      isInbox: isInbox ?? this.isInbox,
      source: source ?? this.source,
      importStatus: importStatus ?? this.importStatus,
      contentHash: contentHash ?? this.contentHash,
      indexingStatus: indexingStatus ?? this.indexingStatus,
      indexingError: indexingError ?? this.indexingError,
      indexedAt: indexedAt ?? this.indexedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      labels: labels ?? this.labels,
      subjectName: subjectName ?? this.subjectName,
      folderName: folderName ?? this.folderName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
