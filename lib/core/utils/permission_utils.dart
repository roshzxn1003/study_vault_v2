import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:study_vault/core/theme/app_colors.dart';

/// Centralized utility for managing storage, media, and camera permissions
/// across all Android versions (Android 9 through Android 15+).
class PermissionUtils {
  /// Requests necessary file storage and media permissions.
  /// Handles Scoped Storage and Manage External Storage on modern Android versions.
  static Future<bool> requestFileStoragePermission({BuildContext? context}) async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      // On Android 13+ (API 33+), use granular media permissions.
      // On Android 10-12, use scoped storage (READ_EXTERNAL_STORAGE with maxSdkVersion).
      // The file_picker plugin uses SAF (Storage Access Framework) and does NOT
      // require MANAGE_EXTERNAL_STORAGE for most operations.
      final statuses = await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();

      final isAnyGranted = statuses.values.any(
        (status) => status.isGranted || status.isLimited,
      );

      if (isAnyGranted) {
        return true;
      }

      // If permissions are permanently denied, guide the user via dialog if context is available
      final isPermanentlyDenied = statuses[Permission.storage]?.isPermanentlyDenied == true;

      if (isPermanentlyDenied && context != null && context.mounted) {
        await showPermissionRationaleDialog(
          context: context,
          title: 'Storage Permission Required',
          message:
              'Study Vault requires file management permission to upload, organize, and sync your study materials (PDFs, slides, notes, images) from your device storage.',
          onOpenSettings: () => openAppSettings(),
        );
      }

      // System SAF file picker might still work even if broad permission was denied
      return isAnyGranted;
    } catch (e) {
      debugPrint('[PermissionUtils] Storage permission request error: $e');
      return true;
    }
  }

  /// Requests camera permission for document scanning and OCR.
  static Future<bool> requestCameraPermission({BuildContext? context}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    try {
      final status = await Permission.camera.request();
      if (status.isGranted) {
        return true;
      }

      if (status.isPermanentlyDenied && context != null && context.mounted) {
        await showPermissionRationaleDialog(
          context: context,
          title: 'Camera Permission Required',
          message:
              'Camera access is required to capture and extract text from physical study materials, book pages, and whiteboard diagrams.',
          onOpenSettings: () => openAppSettings(),
        );
      }

      return status.isGranted;
    } catch (e) {
      debugPrint('[PermissionUtils] Camera permission request error: $e');
      return false;
    }
  }

  /// Shows a clean, user-friendly rationale modal explaining why permission is required.
  static Future<void> showPermissionRationaleDialog({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onOpenSettings,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder_special_rounded, color: AppColors.primaryLight, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onOpenSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
