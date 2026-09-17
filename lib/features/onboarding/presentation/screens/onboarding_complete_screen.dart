import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:study_vault/features/onboarding/presentation/widgets/onboarding_scaffold.dart';

/// Final Completion Screen: Displays confirmation that the learning workspace
/// has been provisioned, with zero AI or promotional distractions.
class OnboardingCompleteScreen extends ConsumerWidget {
  final VoidCallback onFinish;

  const OnboardingCompleteScreen({
    super.key,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingProvider);
    final college = onboarding.collegeData;
    final school = onboarding.schoolData;
    final personal = onboarding.personalLearningData;

    return OnboardingScaffold(
      currentStep: OnboardingStep.complete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSpacing.v32,

          // Icon Hero
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.brXl,
                border: AppBorders.allStandard,
              ),
              child: const Center(
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: AppIcons.xl,
                  color: AppColors.success,
                ),
              ),
            ),
          ),

          AppSpacing.v24,

          // Headline
          Text(
            'Your Study Vault is ready',
            textAlign: TextAlign.center,
            style: AppTypography.display.copyWith(
              fontSize: 28,
              letterSpacing: -0.8,
            ),
          ),
          AppSpacing.v8,
          Text(
            'Your learning workspace has been created.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          AppSpacing.v32,

          // Configured Workspace Summary
          Text(
            'Created Workspaces',
            style: AppTypography.label.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          AppSpacing.v8,

          // College Summary
          if (onboarding.isCollegeSelected && college != null) ...[
            _buildSummaryCard(
              title: 'College Workspace',
              icon: Icons.school_outlined,
              details: [
                '${college.degree} • ${college.branch}',
                '${college.academicYear} • ${college.semester}',
                '${college.subjects.length} ${college.subjects.length == 1 ? 'subject' : 'subjects'} configured',
              ],
            ),
            AppSpacing.v12,
          ],

          // School Summary
          if (onboarding.isSchoolSelected && school != null) ...[
            _buildSummaryCard(
              title: 'School Workspace',
              icon: Icons.auto_stories_outlined,
              details: [
                '${school.grade}${school.stream != null ? ' (${school.stream})' : ''}',
                school.academicYear,
                '${school.subjects.length} ${school.subjects.length == 1 ? 'subject' : 'subjects'} configured',
              ],
            ),
            AppSpacing.v12,
          ],

          // Personal Learning Summary
          if (onboarding.isPersonalLearningSelected && personal != null) ...[
            _buildSummaryCard(
              title: 'Personal Learning Workspace',
              icon: Icons.lightbulb_outline_rounded,
              details: [
                '${personal.topics.length} independent ${personal.topics.length == 1 ? 'topic' : 'topics'} created',
                personal.topics.take(4).join(', '),
              ],
            ),
            AppSpacing.v12,
          ],

          AppSpacing.v32,

          // Primary Action
          AppButton.primary(
            text: 'Continue to Study Vault',
            isLoading: onboarding.isLoading,
            onPressed: () async {
              await ref.read(onboardingProvider.notifier).completeOnboarding();
              onFinish();
            },
          ),
          AppSpacing.v24,
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required IconData icon,
    required List<String> details,
  }) {
    return AppCard.standard(
      padding: AppSpacing.p16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: AppRadius.brMd,
              border: AppBorders.allStandard,
            ),
            child: Icon(
              icon,
              size: AppIcons.md,
              color: AppColors.primaryLight,
            ),
          ),
          AppSpacing.h16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.title.copyWith(fontSize: 15),
                ),
                AppSpacing.v4,
                ...details.where((d) => d.trim().isNotEmpty).map(
                      (d) => Text(
                        d,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
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
