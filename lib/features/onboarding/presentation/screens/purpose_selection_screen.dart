import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:study_vault/features/onboarding/presentation/widgets/onboarding_scaffold.dart';

/// Screen 1: Purpose selection with multi-select support for College, School, and Personal Learning.
class PurposeSelectionScreen extends ConsumerWidget {
  final VoidCallback onContinue;

  const PurposeSelectionScreen({
    super.key,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final hasSelection = onboarding.hasSelectedPurposes;

    return OnboardingScaffold(
      currentStep: OnboardingStep.purpose,
      errorMessage: onboarding.errorMessage,
      onDismissError: () => notifier.clearError(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSpacing.v16,

          // Header
          Text(
            'What are you organizing?',
            textAlign: TextAlign.center,
            style: AppTypography.display.copyWith(
              fontSize: 28,
              letterSpacing: -0.8,
            ),
          ),
          AppSpacing.v8,
          Text(
            'Choose the learning space that fits you.\nYou can add another space later.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),

          AppSpacing.v32,

          // Purpose Cards
          _buildPurposeCard(
            purpose: OnboardingPurpose.college,
            title: 'College',
            description:
                'University subjects, notes, assignments, lab work and study materials.',
            icon: Icons.school_outlined,
            isSelected: onboarding.isCollegeSelected,
            onTap: () => notifier.togglePurpose(OnboardingPurpose.college),
          ),
          AppSpacing.v16,

          _buildPurposeCard(
            purpose: OnboardingPurpose.school,
            title: 'School',
            description:
                'Classes, subjects, homework, notes and study materials.',
            icon: Icons.auto_stories_outlined,
            isSelected: onboarding.isSchoolSelected,
            onTap: () => notifier.togglePurpose(OnboardingPurpose.school),
          ),
          AppSpacing.v16,

          _buildPurposeCard(
            purpose: OnboardingPurpose.personalLearning,
            title: 'Personal Learning',
            description:
                'Courses, programming, skills, projects and independent learning.',
            icon: Icons.lightbulb_outline_rounded,
            isSelected: onboarding.isPersonalLearningSelected,
            onTap: () => notifier.togglePurpose(OnboardingPurpose.personalLearning),
          ),

          AppSpacing.v32,

          // Primary Continue Action
          AppButton.primary(
            text: 'Continue',
            onPressed: hasSelection ? onContinue : null,
          ),
          AppSpacing.v24,
        ],
      ),
    );
  }

  Widget _buildPurposeCard({
    required OnboardingPurpose purpose,
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AppCard(
      variant: isSelected ? AppCardVariant.selected : AppCardVariant.interactive,
      onTap: onTap,
      padding: AppSpacing.p20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge with subtle background
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : AppColors.surfaceSecondary,
              borderRadius: AppRadius.brMd,
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryLight.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Icon(
              icon,
              size: AppIcons.lg,
              color: isSelected ? AppColors.primaryLight : AppColors.textSecondary,
            ),
          ),
          AppSpacing.h16,

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: AppTypography.title.copyWith(
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
                AppSpacing.v4,
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(
                    color: isSelected
                        ? AppColors.textSecondary
                        : AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
