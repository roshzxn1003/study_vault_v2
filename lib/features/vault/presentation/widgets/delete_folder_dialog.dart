import 'package:flutter/material.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import '../../domain/models/models.dart';

/// Result options for folder deletion.
enum DeleteFolderAction {
  cancel,
  moveContentsAndDelete,
  deleteAll,
}

/// Confirmation dialog for folder deletion preventing accidental material loss.
class DeleteFolderDialog extends StatelessWidget {
  final VaultFolder folder;
  final List<VaultFolder> availableTargetFolders;

  const DeleteFolderDialog({
    super.key,
    required this.folder,
    this.availableTargetFolders = const [],
  });

  static Future<DeleteFolderAction?> show({
    required BuildContext context,
    required VaultFolder folder,
    List<VaultFolder> availableTargetFolders = const [],
  }) {
    return showDialog<DeleteFolderAction>(
      context: context,
      builder: (ctx) => DeleteFolderDialog(
        folder: folder,
        availableTargetFolders: availableTargetFolders,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasContents = folder.hasContents;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: AppRadius.button,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Delete "${folder.name}"?',
              style: AppTypography.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasContents) ...[
            Text(
              'This folder currently contains:',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: AppRadius.button,
                border: AppBorders.allSubtle,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (folder.materialCount > 0)
                    Text(
                      '• ${folder.materialCount} ${folder.materialCount == 1 ? 'material' : 'materials'}',
                      style: AppTypography.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                  if (folder.subfolderCount > 0)
                    Text(
                      '• ${folder.subfolderCount} ${folder.subfolderCount == 1 ? 'subfolder' : 'subfolders'}',
                      style: AppTypography.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Choose whether to move its contents to the parent level or delete everything.',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ] else
            Text(
              'Are you sure you want to delete this empty folder? This action cannot be undone.',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, DeleteFolderAction.cancel),
          child: Text('Cancel', style: AppTypography.button.copyWith(color: AppColors.textSecondary)),
        ),
        if (hasContents)
          TextButton(
            onPressed: () => Navigator.pop(context, DeleteFolderAction.moveContentsAndDelete),
            child: Text(
              'Move contents & delete',
              style: AppTypography.button.copyWith(color: AppColors.primaryLight),
            ),
          ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, DeleteFolderAction.deleteAll),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
          child: Text(hasContents ? 'Delete all' : 'Delete', style: AppTypography.button),
        ),
      ],
    );
  }
}
