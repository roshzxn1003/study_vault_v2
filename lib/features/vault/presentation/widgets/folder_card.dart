import 'package:flutter/material.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import '../../domain/models/models.dart';

/// Academic folder card displaying name, material and subfolder counts, and context actions.
class FolderCard extends StatelessWidget {
  final VaultFolder folder;
  final VoidCallback? onTap;
  final VoidCallback? onRename;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;

  const FolderCard({
    super.key,
    required this.folder,
    this.onTap,
    this.onRename,
    this.onMove,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final contentsParts = <String>[];
    if (folder.materialCount > 0) {
      contentsParts.add('${folder.materialCount} ${folder.materialCount == 1 ? 'material' : 'materials'}');
    }
    if (folder.subfolderCount > 0) {
      contentsParts.add('${folder.subfolderCount} ${folder.subfolderCount == 1 ? 'subfolder' : 'subfolders'}');
    }
    final subtitle = contentsParts.isEmpty ? 'Empty folder' : contentsParts.join(' • ');

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          border: AppBorders.allStandard,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: AppRadius.button,
              ),
              child: const Icon(
                Icons.folder_rounded,
                color: AppColors.primaryLight,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    folder.name,
                    style: AppTypography.subtitle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textMuted),
              color: AppColors.surface,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
              onSelected: (val) {
                switch (val) {
                  case 'rename':
                    onRename?.call();
                    break;
                  case 'move':
                    onMove?.call();
                    break;
                  case 'delete':
                    onDelete?.call();
                    break;
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                      SizedBox(width: 8),
                      Text('Rename Folder'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'move',
                  child: Row(
                    children: [
                      Icon(Icons.drive_file_move_outlined, size: 18, color: AppColors.textPrimary),
                      SizedBox(width: 8),
                      Text('Move Folder'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text('Delete Folder', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
