import 'package:flutter/material.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/features/dashboard/domain/models/dashboard_models.dart';

/// Clean, minimal, academic subject card for the Study Vault Dashboard.
/// Adheres strictly to Phase 5: "SUBJECTS FIRST", no generic file statistics.
class SubjectCard extends StatelessWidget {
  final SubjectWithCount subjectWithCount;
  final VoidCallback onTap;

  const SubjectCard({
    super.key,
    required this.subjectWithCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subject = subjectWithCount.subject;
    final hasCode = subject.code != null && subject.code!.trim().isNotEmpty;
    final countLabel = subjectWithCount.materialCountLabel;

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        splashColor: AppColors.primary.withValues(alpha: 0.1),
        highlightColor: AppColors.primary.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: AppBorders.allStandard,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Code Badge (if present) & Chevron
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (hasCode)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: AppRadius.chip,
                        border: AppBorders.allStandard,
                      ),
                      child: Text(
                        subject.code!.trim().toUpperCase(),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // Subject Name
              Text(
                subject.name,
                style: AppTypography.subtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: AppSpacing.xs),

              // Material count (real data only, e.g. "12 materials" or "No materials yet")
              Text(
                countLabel,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
