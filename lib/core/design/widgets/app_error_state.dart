import 'package:flutter/material.dart';
import '../tokens/tokens.dart';
import 'app_button.dart';

/// Reusable human-readable error state component for Study Vault.
class AppErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryText;
  final IconData icon;

  const AppErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
    this.retryText = 'Try again',
    this.icon = AppIcons.error,
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
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.destructiveSubtle,
                borderRadius: AppRadius.brLg,
                border: Border.all(
                  color: AppColors.destructive.withValues(alpha: 0.3),
                  width: AppBorders.subtleWidth,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: AppIcons.lg,
                  color: AppColors.destructiveLight,
                ),
              ),
            ),
            AppSpacing.v20,
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.title,
            ),
            AppSpacing.v8,
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall,
              ),
            ),
            if (onRetry != null) ...[
              AppSpacing.v24,
              AppButton.secondary(
                text: retryText,
                onPressed: onRetry,
                size: AppButtonSize.md,
                icon: const Icon(Icons.refresh_rounded, size: AppIcons.sm),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
