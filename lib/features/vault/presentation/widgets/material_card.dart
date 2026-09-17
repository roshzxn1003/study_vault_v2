import 'package:flutter/material.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import '../../domain/models/models.dart';

/// Clean academic material card for both list and grid view contexts.
class MaterialCard extends StatelessWidget {
  final MaterialItem material;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool?>? onSelectChanged;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onRename;
  final VoidCallback? onMove;
  final VoidCallback? onEditLabels;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;

  const MaterialCard({
    super.key,
    required this.material,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onTap,
    this.onLongPress,
    this.onSelectChanged,
    this.onToggleFavorite,
    this.onRename,
    this.onMove,
    this.onEditLabels,
    this.onArchive,
    this.onRestore,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final type = material.type;

    return InkWell(
      onTap: isSelectionMode ? () => onSelectChanged?.call(!isSelected) : onTap,
      onLongPress: onLongPress,
      borderRadius: AppRadius.card,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: AppRadius.card,
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : AppBorders.allStandard,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Type badge + Selection Checkbox / Favorite + Context menu
            Row(
              children: [
                // Type Icon Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: type.color.withValues(alpha: 0.12),
                    borderRadius: AppRadius.chip,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(type.icon, size: 14, color: type.color),
                      const SizedBox(width: 4),
                      Text(
                        type.label,
                        style: AppTypography.caption.copyWith(
                          color: type.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (material.formattedFileSize.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    material.formattedFileSize,
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
                const Spacer(),

                // Bulk Selection Checkbox
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: onSelectChanged,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  )
                else ...[
                  // Favorite Star Button
                  IconButton(
                    icon: Icon(
                      material.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: material.isFavorite ? const Color(0xFFF59E0B) : AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: onToggleFavorite,
                    visualDensity: VisualDensity.compact,
                    splashRadius: 18,
                    tooltip: material.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                  ),

                  // Context Menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textMuted),
                    color: AppColors.surface,
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
                    onSelected: (val) {
                      switch (val) {
                        case 'open':
                          onTap?.call();
                          break;
                        case 'rename':
                          onRename?.call();
                          break;
                        case 'move':
                          onMove?.call();
                          break;
                        case 'labels':
                          onEditLabels?.call();
                          break;
                        case 'archive':
                          onArchive?.call();
                          break;
                        case 'restore':
                          onRestore?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'open',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 18, color: AppColors.textPrimary),
                            SizedBox(width: 8),
                            Text('Open / Details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                            SizedBox(width: 8),
                            Text('Rename'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'move',
                        child: Row(
                          children: [
                            Icon(Icons.drive_file_move_outlined, size: 18, color: AppColors.textPrimary),
                            SizedBox(width: 8),
                            Text('Move to...'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'labels',
                        child: Row(
                          children: [
                            Icon(Icons.label_outline_rounded, size: 18, color: AppColors.textPrimary),
                            SizedBox(width: 8),
                            Text('Labels'),
                          ],
                        ),
                      ),
                      if (material.isArchived)
                        const PopupMenuItem(
                          value: 'restore',
                          child: Row(
                            children: [
                              Icon(Icons.unarchive_outlined, size: 18, color: AppColors.textPrimary),
                              SizedBox(width: 8),
                              Text('Restore from Archive'),
                            ],
                          ),
                        )
                      else
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive_outlined, size: 18, color: AppColors.textPrimary),
                              SizedBox(width: 8),
                              Text('Archive'),
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
                            Text('Delete', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // Material Title
            Text(
              material.title,
              style: AppTypography.subtitle.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 4),

            // Location Subtitle (Subject & Folder)
            Text(
              material.locationSubtitle,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Labels Row
            if (material.labels.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: material.labels.take(3).map((l) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: l.color.withValues(alpha: 0.1),
                      borderRadius: AppRadius.chip,
                    ),
                    child: Text(
                      l.name,
                      style: AppTypography.caption.copyWith(
                        color: l.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const Spacer(),

            // Footer: Relative updated timestamp
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Updated ${material.relativeUpdatedTime}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
