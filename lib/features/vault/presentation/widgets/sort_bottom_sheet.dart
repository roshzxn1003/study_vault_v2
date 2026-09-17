import 'package:flutter/material.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import '../../domain/models/models.dart';

/// Modal bottom sheet allowing selection of material sorting strategy.
class SortBottomSheet extends StatelessWidget {
  final MaterialSortOption currentSort;
  final ValueChanged<MaterialSortOption> onSelectSort;

  const SortBottomSheet({
    super.key,
    required this.currentSort,
    required this.onSelectSort,
  });

  static Future<void> show({
    required BuildContext context,
    required MaterialSortOption currentSort,
    required ValueChanged<MaterialSortOption> onSelectSort,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.bottomSheet,
      ),
      builder: (ctx) => SortBottomSheet(
        currentSort: currentSort,
        onSelectSort: onSelectSort,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'Sort Materials',
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...MaterialSortOption.values.map((option) {
              final isSelected = currentSort == option;
              return ListTile(
                title: Text(
                  option.label,
                  style: AppTypography.body.copyWith(
                    color: isSelected ? AppColors.primaryLight : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_rounded, color: AppColors.primaryLight, size: 20)
                    : null,
                onTap: () {
                  onSelectSort(option);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
