import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/features/dashboard/domain/models/dashboard_models.dart';

/// Hero "Continue Learning" card showing the student's most recently accessed material.
class ContinueLearningCard extends StatelessWidget {
  final DashboardRecentMaterial? recentMaterial;

  const ContinueLearningCard({
    super.key,
    this.recentMaterial,
  });

  @override
  Widget build(BuildContext context) {
    if (recentMaterial == null) {
      return const SizedBox.shrink();
    }

    final item = recentMaterial!;
    final isNote = item.type.toUpperCase() == 'NOTE';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: AppRadius.chip,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 13,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'CONTINUE LEARNING',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                item.relativeTime,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.button,
                  border: AppBorders.allStandard,
                ),
                child: Icon(
                  isNote ? Icons.edit_note_rounded : Icons.picture_as_pdf_outlined,
                  color: isNote ? AppColors.amber : AppColors.primaryLight,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subjectName != null && item.subjectName!.isNotEmpty
                          ? item.subjectName!
                          : 'General Material',
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
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Resume', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                onPressed: () => context.push('/material/${item.id}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
