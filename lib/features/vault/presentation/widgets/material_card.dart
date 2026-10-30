import 'package:flutter/material.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import '../../domain/models/models.dart';
import 'material_action_sheet.dart';
import 'material_preview_widget.dart';

/// Clean academic material card for both list and grid view contexts.
/// Features integrated material preview thumbnail for every material type.
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
  final VoidCallback? onShareStudent;
  final VoidCallback? onShareGroup;
  final VoidCallback? onCreatePack;

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
    this.onShareStudent,
    this.onShareGroup,
    this.onCreatePack,
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
            // Top Row: Type badge + File size + Privacy badge + Actions
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Type Icon Badge (high contrast)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: type.color.withValues(alpha: 0.15),
                            borderRadius: AppRadius.chip,
                            border: Border.all(color: type.color.withValues(alpha: 0.3)),
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
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (material.formattedFileSize.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            material.formattedFileSize,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        // Subtle Privacy Indicator (always present: Private vs Shared)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                material.source?.startsWith('Shared') == true
                                    ? Icons.group_outlined
                                    : Icons.lock_outline_rounded,
                                size: 10,
                                color: material.source?.startsWith('Shared') == true
                                    ? AppColors.emerald
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                material.source?.startsWith('Shared') == true ? 'Shared' : 'Private',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: material.source?.startsWith('Shared') == true
                                      ? AppColors.emerald
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

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
                      color: material.isFavorite ? const Color(0xFFFBBF24) : AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: onToggleFavorite,
                    visualDensity: VisualDensity.compact,
                    splashRadius: 18,
                    tooltip: material.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                  ),

                  // Context Menu replaced with responsive Action Sheet
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textSecondary),
                    tooltip: 'Material actions',
                    visualDensity: VisualDensity.compact,
                    splashRadius: 18,
                    onPressed: () {
                      MaterialActionSheet.show(
                        context: context,
                        material: material,
                        onRename: onRename,
                        onMove: onMove,
                        onEditLabels: onEditLabels,
                        onToggleFavorite: onToggleFavorite,
                        onArchive: onArchive,
                        onRestore: onRestore,
                        onDelete: onDelete,
                      );
                    },
                  ),
                ],
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // Material Content Row: Preview Thumbnail + Title & Metadata
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: MaterialPreviewWidget(
                      material: material,
                      isCompact: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Material Title (bold, wrapped safely)
                      Text(
                        material.title,
                        style: AppTypography.subtitle.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      // Secondary metadata line: Type · Size · Location
                      Text(
                        '${material.type.label}${material.formattedFileSize.isNotEmpty ? ' · ${material.formattedFileSize}' : ''}${material.locationSubtitle.isNotEmpty ? ' · ${material.locationSubtitle}' : ''}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
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
