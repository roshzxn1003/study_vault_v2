import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/theme/app_colors.dart';

/// Service handling external Android system actions for study materials:
/// - "Open With" intent to compatible third-party viewers/editors
/// - System file sharing via Android share sheet
/// - Exporting / downloading files to device storage
class FileActionService {
  FileActionService._();
  static final FileActionService instance = FileActionService._();

  /// Resolves the local file path, downloading from remote URL or Supabase storage if necessary.
  Future<File?> resolveLocalFile({
    required BuildContext context,
    required String filePath,
    required String fileName,
  }) async {
    if (filePath.isEmpty) return null;

    final localFile = File(filePath);
    if (localFile.existsSync()) return localFile;
    if (filePath.startsWith('/')) return null;

    try {
      final tempDir = await getTemporaryDirectory();
      final sanitized = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final cacheFile = File('${tempDir.path}/$sanitized');
      if (cacheFile.existsSync() && cacheFile.lengthSync() > 0) {
        return cacheFile;
      }

      Uint8List? bytes;
      if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
        final res = await http.get(Uri.parse(filePath));
        if (res.statusCode == 200) bytes = res.bodyBytes;
      } else if (!filePath.startsWith('/')) {
        // Supabase storage path
        try {
          bytes = await Supabase.instance.client.storage.from('study_materials').download(filePath);
        } catch (_) {
          try {
            final signed = await Supabase.instance.client.storage.from('study_materials').createSignedUrl(filePath, 3600);
            final res = await http.get(Uri.parse(signed));
            if (res.statusCode == 200) bytes = res.bodyBytes;
          } catch (_) {}
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        await cacheFile.writeAsBytes(bytes);
        return cacheFile;
      }
    } catch (e) {
      debugPrint('[FileActionService] Failed to resolve remote file: $e');
    }
    return null;
  }

  /// Opens the file using an Android-compatible app chooser.
  /// Handles "No compatible app found" and missing file conditions gracefully without crashing.
  Future<void> openWith({
    required BuildContext context,
    required String filePath,
    String? mimeType,
    required String title,
  }) async {
    final file = await resolveLocalFile(
      context: context,
      filePath: filePath,
      fileName: title,
    );

    if (file == null || !file.existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File not found on device storage.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final result = await OpenFilex.open(
        filePath,
        type: mimeType,
      );

      if (!context.mounted) return;

      switch (result.type) {
        case ResultType.done:
          // Successfully opened in external application
          break;
        case ResultType.noAppToOpen:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No compatible app found to open this file.'),
              backgroundColor: AppColors.amber,
              behavior: SnackBarBehavior.floating,
            ),
          );
          break;
        case ResultType.fileNotFound:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File not found.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          break;
        case ResultType.permissionDenied:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission denied to open file.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          break;
        case ResultType.error:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error opening file: ${result.message}'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          break;
      }
    } catch (e) {
      debugPrint('[FileActionService] openWith error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open with external app: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Shares the actual physical file via the Android system share sheet.
  Future<void> shareSystemFile({
    required BuildContext context,
    required String filePath,
    required String title,
  }) async {
    final file = await resolveLocalFile(
      context: context,
      filePath: filePath,
      fileName: title,
    );

    if (file == null || !file.existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File not found on device storage.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final xFile = XFile(file.path, name: title);
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: 'Study Material: $title',
        ),
      );
    } catch (e) {
      debugPrint('[FileActionService] shareSystemFile error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share file: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Copies/downloads the file to the user's accessible downloads/documents directory.
  Future<void> downloadFile({
    required BuildContext context,
    required String sourceFilePath,
    required String fileName,
  }) async {
    final source = await resolveLocalFile(
      context: context,
      filePath: sourceFilePath,
      fileName: fileName,
    );

    if (source == null || !source.existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Source file not found.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      Directory? targetDir;
      if (Platform.isAndroid) {
        // Try Download directory
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          targetDir = downloadDir;
        } else {
          targetDir = await getExternalStorageDirectory();
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      targetDir ??= await getApplicationDocumentsDirectory();

      final sanitizedName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final targetPath = '${targetDir.path}/$sanitizedName';
      final targetFile = File(targetPath);

      // Copy file
      await source.copy(targetFile.path);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved copy to ${targetDir.path.split('/').last}/$sanitizedName'),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () {
                openWith(
                  context: context,
                  filePath: targetFile.path,
                  title: fileName,
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[FileActionService] downloadFile error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
