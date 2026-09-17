import 'package:flutter/material.dart';
import '../tokens/tokens.dart';
import 'app_button.dart';

/// Clean academic empty state with restrained icon container and optional action.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionText;
  final VoidCallback? onAction;
  final String? secondaryActionText;
  final VoidCallback? onSecondaryAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionText,
    this.onAction,
    this.secondaryActionText,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container with subtle border
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: AppRadius.brLg,
                border: AppBorders.allStandard,
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: AppIcons.lg,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            AppSpacing.v20,

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.title,
            ),
            AppSpacing.v8,

            // Description
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall,
              ),
            ),

            // Actions
            if (actionText != null && onAction != null) ...[
              AppSpacing.v24,
              AppButton.primary(
                text: actionText!,
                onPressed: onAction,
                size: AppButtonSize.md,
              ),
            ],
            if (secondaryActionText != null && onSecondaryAction != null) ...[
              AppSpacing.v8,
              AppButton.tertiary(
                text: secondaryActionText!,
                onPressed: onSecondaryAction,
                size: AppButtonSize.md,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
