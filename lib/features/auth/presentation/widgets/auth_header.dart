import 'package:flutter/material.dart';
import 'package:study_vault/core/design/design_system.dart';

/// Minimal academic brand header for authentication screens.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showLogo;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLogo) ...[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.brLg,
              border: AppBorders.allStandard,
            ),
            child: const Center(
              child: Icon(
                Icons.auto_stories_rounded,
                size: 26,
                color: AppColors.primaryLight,
              ),
            ),
          ),
          AppSpacing.v16,
          Text(
            'Study Vault',
            style: AppTypography.label.copyWith(
              letterSpacing: 0.5,
              color: AppColors.textMuted,
            ),
          ),
          AppSpacing.v12,
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.headline.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        AppSpacing.v8,
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

