import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/features/academic/domain/models/models.dart';

/// Modal bottom sheet for browsing and selecting an academic period to view on the dashboard.
class PeriodSelectorSheet extends StatelessWidget {
  final List<AcademicYearWithPeriods> history;
  final String selectedPeriodId;
  final ValueChanged<String> onPeriodSelected;

  const PeriodSelectorSheet({
    super.key,
    required this.history,
    required this.selectedPeriodId,
    required this.onPeriodSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required List<AcademicYearWithPeriods> history,
    required String selectedPeriodId,
    required ValueChanged<String> onPeriodSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.bottomSheet,
      ),
      builder: (ctx) => PeriodSelectorSheet(
        history: history,
        selectedPeriodId: selectedPeriodId,
        onPeriodSelected: onPeriodSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Academic Period',
                  style: AppTypography.title,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/academic/history');
                  },
                  child: Text(
                    'Full History',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Switch between current and previous academic terms to browse materials.',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),

            // List of Periods grouped by Year
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: history.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, yearIndex) {
                  final group = history[yearIndex];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          group.year.yearName,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      ...group.periods.map((item) {
                        final period = item.period;
                        final isSelected = period.id == selectedPeriodId;
                        final isCurrent = period.isCurrent;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.surfaceSecondary
                                : AppColors.surface,
                            borderRadius: AppRadius.button,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.cardBorder,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            onTap: () {
                              Navigator.pop(context);
                              onPeriodSelected(period.id);
                            },
                            title: Row(
                              children: [
                                Text(
                                  period.name,
                                  style: AppTypography.body.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? AppColors.emerald.withValues(alpha: 0.15)
                                        : AppColors.surfaceSecondary,
                                    borderRadius: AppRadius.chip,
                                  ),
                                  child: Text(
                                    isCurrent ? 'CURRENT' : 'PREVIOUS',
                                    style: AppTypography.caption.copyWith(
                                      color: isCurrent
                                          ? AppColors.emerald
                                          : AppColors.textMuted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primaryLight,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
