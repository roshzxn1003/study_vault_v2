import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Detailed breakdown of application storage usage.
class StorageBreakdown {
  final int documentsBytes;
  final int cacheBytes;
  final int scansBytes;
  final int databaseBytes;

  const StorageBreakdown({
    this.documentsBytes = 0,
    this.cacheBytes = 0,
    this.scansBytes = 0,
    this.databaseBytes = 0,
  });

  int get totalBytes => documentsBytes + cacheBytes + scansBytes + databaseBytes;

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedDocuments => formatBytes(documentsBytes);
  String get formattedCache => formatBytes(cacheBytes);
  String get formattedScans => formatBytes(scansBytes);
  String get formattedDatabase => formatBytes(databaseBytes);
  String get formattedTotal => formatBytes(totalBytes);
}

/// Centralized service handling sandboxed local storage, directory isolation,
/// storage usage metrics, and safe cache pruning.
class StorageManagerService {
  StorageManagerService._();
  static final StorageManagerService instance = StorageManagerService._();

  Directory? _customBaseDirForTesting;

  @visibleForTesting
  void setCustomBaseDirForTesting(Directory dir) {
    _customBaseDirForTesting = dir;
  }

  Future<Directory> _getBaseDir() async {
    if (_customBaseDirForTesting != null) {
      return _customBaseDirForTesting!;
    }
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  Future<Directory> _getTempDir() async {
    if (_customBaseDirForTesting != null) {
      return Directory(p.join(_customBaseDirForTesting!.path, 'temp'));
    }
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  /// Permanent directory for user's imported study notes, PDFs, and materials.
  /// This directory is NEVER purged by cache clearing operations.
  Future<Directory> getDocumentsDirectory() async {
    final base = await _getBaseDir();
    final dir = Directory(p.join(base.path, 'vault_documents'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Transient cache directory for remote file previews and downloaded cloud attachments.
  /// Can be safely deleted at any time to recover space.
  Future<Directory> getCacheDirectory() async {
    final temp = await _getTempDir();
    final dir = Directory(p.join(temp.path, 'vault_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Ephemeral directory for camera snapshots and OCR image processing.
  Future<Directory> getTempScansDirectory() async {
    final temp = await _getTempDir();
    final dir = Directory(p.join(temp.path, 'vault_scans'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Recursively sums file sizes in a directory.
  Future<int> _calculateDirectorySize(Directory dir) async {
    if (!await dir.exists()) return 0;
    int total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    } catch (e) {
      debugPrint('[StorageManager] Error calculating size of ${dir.path}: $e');
    }
    return total;
  }

  /// Computes a comprehensive breakdown of storage usage across documents, caches, and DB.
  Future<StorageBreakdown> calculateStorageBreakdown() async {
    final docsDir = await getDocumentsDirectory();
    final cacheDir = await getCacheDirectory();
    final scansDir = await getTempScansDirectory();

    final docsSize = await _calculateDirectorySize(docsDir);
    final cacheSize = await _calculateDirectorySize(cacheDir);
    final scansSize = await _calculateDirectorySize(scansDir);

    // Approximate database size
    int dbSize = 0;
    try {
      final base = await _getBaseDir();
      final dbFile = File(p.join(base.path, 'study_vault.db'));
      if (await dbFile.exists()) {
        dbSize = await dbFile.length();
      }
    } catch (_) {}

    return StorageBreakdown(
      documentsBytes: docsSize,
      cacheBytes: cacheSize,
      scansBytes: scansSize,
      databaseBytes: dbSize,
    );
  }

  /// Safely clears ONLY temporary caches and scans.
  /// User's permanent study documents and notes are 100% preserved.
  Future<int> clearSafeCache() async {
    int bytesFreed = 0;

    // 1. Clear remote cache
    final cacheDir = await getCacheDirectory();
    if (await cacheDir.exists()) {
      await for (final entity in cacheDir.list(recursive: false)) {
        if (entity is File) {
          bytesFreed += await entity.length();
          await entity.delete();
        } else if (entity is Directory) {
          bytesFreed += await _calculateDirectorySize(entity);
          await entity.delete(recursive: true);
        }
      }
    }

    // 2. Clear temp scans
    final scansDir = await getTempScansDirectory();
    if (await scansDir.exists()) {
      await for (final entity in scansDir.list(recursive: false)) {
        if (entity is File) {
          bytesFreed += await entity.length();
          await entity.delete();
        } else if (entity is Directory) {
          bytesFreed += await _calculateDirectorySize(entity);
          await entity.delete(recursive: true);
        }
      }
    }

    return bytesFreed;
  }

  /// Saves a permanent study material file into the sandboxed documents directory.
  Future<File> savePermanentMaterialFile({
    required File sourceFile,
    required String fileName,
  }) async {
    final docsDir = await getDocumentsDirectory();
    final cleanName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final targetFile = File(p.join(docsDir.path, cleanName));

    if (await targetFile.exists()) {
      // If exact same name exists with matching size, reuse
      if (await targetFile.length() == await sourceFile.length()) {
        return targetFile;
      }
      // Otherwise suffix with timestamp
      final ext = p.extension(cleanName);
      final stem = p.basenameWithoutExtension(cleanName);
      final uniqueFile = File(p.join(docsDir.path, '${stem}_${DateTime.now().millisecondsSinceEpoch}$ext'));
      return sourceFile.copy(uniqueFile.path);
    }

    return sourceFile.copy(targetFile.path);
  }
}
