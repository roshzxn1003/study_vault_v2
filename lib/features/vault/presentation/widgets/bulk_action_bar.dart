import 'package:flutter/material.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';

/// Floating bulk selection toolbar for batch operations.
class BulkActionBar extends StatelessWidget {
  final int selectedCount;
  final bool isAllSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onMove;
  final VoidCallback onLabel;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const BulkActionBar({
    super.key,
    required this.selectedCount,
    this.isAllSelected = false,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onMove,
    required this.onLabel,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: AppBorders.allStandard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
            onPressed: onClearSelection,
            tooltip: 'Clear selection',
          ),
          Text(
            '$selectedCount selected',
            style: AppTypography.subtitle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: onSelectAll,
            child: Text(
              isAllSelected ? 'Deselect All' : 'Select All',
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.drive_file_move_outlined, color: AppColors.textPrimary, size: 20),
            onPressed: onMove,
            tooltip: 'Move selected',
          ),
          IconButton(
            icon: const Icon(Icons.label_outline_rounded, color: AppColors.textPrimary, size: 20),
            onPressed: onLabel,
            tooltip: 'Add labels',
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined, color: AppColors.textPrimary, size: 20),
            onPressed: onArchive,
            tooltip: 'Archive selected',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
            onPressed: onDelete,
            tooltip: 'Delete selected',
          ),
        ],
      ),
    );
  }
}
