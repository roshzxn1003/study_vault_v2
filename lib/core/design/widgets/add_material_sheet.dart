import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/services/material_upload_service.dart';
import 'package:study_vault/core/utils/permission_utils.dart';

/// Modal bottom sheet allowing students to add study materials from anywhere in the app.
/// Provides direct avenues for uploading files, scanning documents, creating notes, or importing photos.
class AddMaterialSheet extends ConsumerWidget {
  final String? subjectId;
  final String? folderId;
  final String? workspaceId;
  final String? academicPeriodId;
  final String? destinationLabel;

  const AddMaterialSheet({
    super.key,
    this.subjectId,
    this.folderId,
    this.workspaceId,
    this.academicPeriodId,
    this.destinationLabel,
  });

  /// Displays the modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    String? subjectId,
    String? folderId,
    String? workspaceId,
    String? academicPeriodId,
    String? destinationLabel,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AddMaterialSheet(
        subjectId: subjectId,
        folderId: folderId,
        workspaceId: workspaceId,
        academicPeriodId: academicPeriodId,
        destinationLabel: destinationLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadService = ref.read(materialUploadServiceProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Material',
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destinationLabel != null
                          ? 'Saving to: $destinationLabel'
                          : 'Index, store, and organize study resources',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Action 1: Upload Documents / Files
          _buildActionTile(
            context: context,
            icon: Icons.upload_file_rounded,
            iconColor: AppColors.primaryLight,
            iconBg: AppColors.primary.withValues(alpha: 0.15),
            title: 'Upload Documents',
            subtitle: 'PDFs, slides, Word documents, text notes, spreadsheets',
            badge: 'PDF, DOC, TXT',
            onTap: () async {
              Navigator.of(context).pop();
              await uploadService.pickAndUploadFiles(
                context: context,
                subjectId: subjectId,
                folderId: folderId,
                workspaceId: workspaceId,
                academicPeriodId: academicPeriodId,
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Action 2: Scan Document / Camera OCR
          _buildActionTile(
            context: context,
            icon: Icons.document_scanner_rounded,
            iconColor: AppColors.emerald,
            iconBg: AppColors.emerald.withValues(alpha: 0.15),
            title: 'Scan Document (OCR)',
            subtitle: 'Capture textbook pages or handwritten notes with camera',
            badge: 'Camera',
            onTap: () async {
              Navigator.of(context).pop();
              final hasCam = await PermissionUtils.requestCameraPermission(context: context);
              if (hasCam && context.mounted) {
                context.push('/scan');
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Action 3: Create Study Note
          _buildActionTile(
            context: context,
            icon: Icons.edit_note_rounded,
            iconColor: AppColors.amber,
            iconBg: AppColors.amber.withValues(alpha: 0.15),
            title: 'Create Study Note',
            subtitle: 'Rich markdown, lecture summaries, or quick formulas',
            badge: 'Markdown',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/notes/create');
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Action 4: Import Images / Gallery
          _buildActionTile(
            context: context,
            icon: Icons.photo_library_rounded,
            iconColor: AppColors.cyan,
            iconBg: AppColors.cyan.withValues(alpha: 0.15),
            title: 'Import Photos / Gallery',
            subtitle: 'Diagrams, whiteboard photos, or assignment pictures',
            badge: 'Gallery',
            onTap: () async {
              Navigator.of(context).pop();
              await uploadService.pickFromGallery(
                context: context,
                subjectId: subjectId,
                folderId: folderId,
                workspaceId: workspaceId,
                academicPeriodId: academicPeriodId,
              );
            },
          ),

          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: AppSpacing.sm),

          // Storage Permission shortcut if needed
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.security_rounded, size: 16, color: AppColors.textMuted),
              label: Text(
                'Verify Storage & File Permissions',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              onPressed: () async {
                final granted = await PermissionUtils.requestFileStoragePermission(context: context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        granted
                            ? 'All file management permissions are active!'
                            : 'Permissions are restricted in Android settings.',
                      ),
                      backgroundColor: granted ? AppColors.emerald : AppColors.amber,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            badge,
                            style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
