import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';

/// Service responsible for local filesystem storage, hashing, and type detection.
class ImportStorageService {
  final Uuid _uuid = const Uuid();

  /// Gets the directory where study materials are permanently preserved.
  Future<Directory> getMaterialsDirectory() async {
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = Directory(p.join(Directory.systemTemp.path, 'study_vault_test_docs'));
    }
    final materialsDir = Directory(p.join(baseDir.path, 'study_materials'));
    if (!await materialsDir.exists()) {
      await materialsDir.create(recursive: true);
    }
    return materialsDir;
  }

  /// Sanitizes an incoming filename against path traversal and forbidden characters.
  String sanitizeFileName(String? rawName) {
    if (rawName == null || rawName.trim().isEmpty) {
      return 'material_${_uuid.v4().substring(0, 8)}';
    }
    // Strip path components
    var clean = p.basename(rawName.trim());
    // Strip invalid filesystem characters: / \ : * ? " < > |
    clean = clean.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    // Limit length
    if (clean.length > 120) {
      final ext = p.extension(clean);
      final stem = p.basenameWithoutExtension(clean).substring(0, 100);
      clean = '$stem$ext';
    }
    return clean.isEmpty ? 'material_${_uuid.v4().substring(0, 8)}' : clean;
  }

  /// Calculates SHA-256 content hash of a local file.
  Future<String> calculateFileHash(File file) async {
    try {
      if (!await file.exists()) return '';
      final bytes = await file.readAsBytes();
      return sha256.convert(bytes).toString();
    } catch (e) {
      debugPrint('Error calculating file hash: $e');
      return '';
    }
  }

  /// Calculates SHA-256 hash of a string (text note or URL).
  String calculateStringHash(String content) {
    return sha256.convert(content.codeUnits).toString();
  }

  /// Safely copies a source file to permanent materials storage.
  /// Returns the permanent File in local storage.
  Future<File> copyToMaterialsStorage({
    required File sourceFile,
    required String targetFileName,
  }) async {
    final dir = await getMaterialsDirectory();
    final sanitized = sanitizeFileName(targetFileName);
    final ext = p.extension(sanitized);
    final stem = p.basenameWithoutExtension(sanitized);

    // Ensure unique persistent storage name
    var uniqueName = '${stem}_${_uuid.v4().substring(0, 8)}$ext';
    var targetFile = File(p.join(dir.path, uniqueName));

    return await sourceFile.copy(targetFile.path);
  }

  /// Detects VaultMaterialType from filename and mime type.
  VaultMaterialType detectMaterialType({
    required String fileName,
    String? mimeType,
  }) {
    final ext = p.extension(fileName).toLowerCase();
    final mime = (mimeType ?? '').toLowerCase();

    if (ext == '.pdf' || mime.contains('pdf')) {
      return VaultMaterialType.pdf;
    }
    if (['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'].contains(ext) ||
        mime.startsWith('image/')) {
      return VaultMaterialType.image;
    }
    if (['.txt', '.md', '.markdown'].contains(ext) ||
        mime.contains('text/plain') ||
        mime.contains('markdown')) {
      return VaultMaterialType.note;
    }
    if (['.doc', '.docx', '.odt', '.rtf', '.ppt', '.pptx', '.xls', '.xlsx', '.csv'].contains(ext) ||
        mime.contains('word') ||
        mime.contains('officedocument') ||
        mime.contains('presentation') ||
        mime.contains('spreadsheet')) {
      return VaultMaterialType.document;
    }

    return VaultMaterialType.document;
  }

  /// Validates if an extension or MIME is supported for safe import.
  bool isSupportedFile({
    required String fileName,
    String? mimeType,
  }) {
    final ext = p.extension(fileName).toLowerCase();
    final mime = (mimeType ?? '').toLowerCase();

    // Executables, binaries, and system archives that are unsupported
    const unsupportedExts = {
      '.exe', '.apk', '.bat', '.cmd', '.sh', '.bin', '.dll', '.so', '.dmg', '.iso', '.zip', '.tar', '.gz', '.rar', '.7z'
    };
    if (unsupportedExts.contains(ext)) {
      return false;
    }

    // Supported extensions
    const supportedExts = {
      '.pdf', '.jpg', '.jpeg', '.png', '.webp', '.gif',
      '.txt', '.md', '.doc', '.docx', '.odt', '.rtf',
      '.ppt', '.pptx', '.xls', '.xlsx', '.csv'
    };

    if (supportedExts.contains(ext)) return true;
    if (mime.contains('pdf') || mime.startsWith('image/') || mime.startsWith('text/')) {
      return true;
    }
    if (mime.contains('officedocument') || mime.contains('msword') || mime.contains('spreadsheet')) {
      return true;
    }

    // Fallback: allow unknown non-executable files as Document
    return ext.isNotEmpty;
  }
}
