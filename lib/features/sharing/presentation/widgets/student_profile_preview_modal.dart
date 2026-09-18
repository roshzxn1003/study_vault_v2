import 'package:flutter/material.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/widgets.dart';
import '../../domain/models/models.dart';

/// Clean academic modal previewing a student's public identity.
/// Strictly presents only safe public information, never exposing private academic history or auth credentials.
class StudentProfilePreviewModal extends StatelessWidget {
  final StudentProfile profile;
  final VoidCallback? onShare;

  const StudentProfilePreviewModal({
    super.key,
    required this.profile,
    this.onShare,
  });

  static Future<void> show({
    required BuildContext context,
    required StudentProfile profile,
    VoidCallback? onShare,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StudentProfilePreviewModal(
        profile: profile,
        onShare: onShare,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Avatar & Name
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
              child: Text(
                profile.initial,
                style: AppTypography.title.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              profile.fullName,
              style: AppTypography.title.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              profile.displayUsername,
              style: AppTypography.body.copyWith(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Public Academic Badges
            if (profile.publicAcademicSummary.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.chip,
                  border: AppBorders.allStandard,
                ),
                child: Text(
                  profile.publicAcademicSummary,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Institution notice if present
            if (profile.institution != null && profile.institution!.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school_outlined, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    profile.institution!,
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            const AppDivider(),
            const SizedBox(height: AppSpacing.md),

            // Actions
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    text: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    text: 'Share Material',
                    icon: const Icon(Icons.share_rounded),
                    onPressed: () {
                      Navigator.pop(context);
                      onShare?.call();
                    },
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
