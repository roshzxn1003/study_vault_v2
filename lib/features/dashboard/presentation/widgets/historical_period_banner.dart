import 'package:flutter/material.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';

/// Prominent archive view indicator when user is browsing a historical academic period.
class HistoricalPeriodBanner extends StatelessWidget {
  final String periodName;
  final String currentPeriodName;
  final VoidCallback onSwitchToCurrent;

  const HistoricalPeriodBanner({
    super.key,
    required this.periodName,
    required this.currentPeriodName,
    required this.onSwitchToCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: AppRadius.card,
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                color: AppColors.warning,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'ARCHIVE VIEW • PREVIOUS TERM',
                style: AppTypography.caption.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Viewing $periodName. Preserved for reference.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onSwitchToCurrent,
                child: Text(
                  'Back to Current',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
