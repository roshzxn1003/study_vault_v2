import 'package:flutter/material.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/features/onboarding/domain/models/onboarding_models.dart';

/// Keyboard-safe, responsive container for onboarding screens with
/// consistent progress tracking, title bar, and back navigation.
class OnboardingScaffold extends StatelessWidget {
  final Widget child;
  final OnboardingStep currentStep;
  final VoidCallback? onBack;
  final String? errorMessage;
  final VoidCallback? onDismissError;
  final double maxWidth;

  const OnboardingScaffold({
    super.key,
    required this.child,
    required this.currentStep,
    this.onBack,
    this.errorMessage,
    this.onDismissError,
    this.maxWidth = 480,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Step Indicator
            _buildTopBar(context),

            // Error Banner if present
            if (errorMessage != null && errorMessage!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _buildErrorBanner(),
              ),

            // Scrollable Content
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: AppBorders.standard),
      ),
      child: Row(
        children: [
          // Back action
          if (onBack != null)
            AppIconButton(
              icon: AppIcons.back,
              tooltip: 'Go back',
              onPressed: onBack,
            )
          else
            const SizedBox(width: AppDimensions.minTouchTarget),

          const Spacer(),

          // Step indicators: 01 Purpose • 02 Setup • 03 Subjects • 04 Done
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStepPill(OnboardingStep.purpose, '01 Purpose'),
              _buildStepDivider(),
              _buildStepPill(OnboardingStep.setup, '02 Setup'),
              _buildStepDivider(),
              _buildStepPill(OnboardingStep.subjects, '03 Subjects'),
              _buildStepDivider(),
              _buildStepPill(OnboardingStep.complete, '04 Done'),
            ],
          ),

          const Spacer(),
          const SizedBox(width: AppDimensions.minTouchTarget),
        ],
      ),
    );
  }

  Widget _buildStepPill(OnboardingStep step, String label) {
    final isActive = currentStep == step;
    final isPassed = currentStep.stepNumber > step.stepNumber;

    Color color;
    FontWeight weight;
    if (isActive) {
      color = AppColors.primaryLight;
      weight = FontWeight.w600;
    } else if (isPassed) {
      color = AppColors.textSecondary;
      weight = FontWeight.w500;
    } else {
      color = AppColors.textMuted;
      weight = FontWeight.w400;
    }

    return Text(
      label,
      style: AppTypography.caption.copyWith(
        color: color,
        fontWeight: weight,
        fontSize: 11,
      ),
    );
  }

  Widget _buildStepDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '/',
        style: AppTypography.caption.copyWith(
          color: AppColors.border,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.destructiveSubtle,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: AppColors.destructive.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: AppIcons.sm,
            color: AppColors.destructiveLight,
          ),
          AppSpacing.h12,
          Expanded(
            child: Text(
              errorMessage!,
              style: AppTypography.caption.copyWith(
                color: const Color(0xFFFCA5A5),
              ),
            ),
          ),
          if (onDismissError != null)
            GestureDetector(
              onTap: onDismissError,
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(0xFFFCA5A5),
              ),
            ),
        ],
      ),
    );
  }
}
