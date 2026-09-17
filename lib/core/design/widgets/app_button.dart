import 'package:flutter/material.dart';
import '../tokens/tokens.dart';

enum AppButtonVariant { primary, secondary, tertiary, destructive }
enum AppButtonSize { sm, md, lg }

/// Unified academic button component for Study Vault.
/// Implements consistent heights, typography, loading states, and variants.
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final Widget? icon;
  final double? width;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.lg,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  // Convenience factories
  const AppButton.primary({
    super.key,
    required this.text,
    required this.onPressed,
    this.size = AppButtonSize.lg,
    this.isLoading = false,
    this.icon,
    this.width,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.text,
    required this.onPressed,
    this.size = AppButtonSize.lg,
    this.isLoading = false,
    this.icon,
    this.width,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.tertiary({
    super.key,
    required this.text,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.icon,
    this.width,
  }) : variant = AppButtonVariant.tertiary;

  const AppButton.destructive({
    super.key,
    required this.text,
    required this.onPressed,
    this.size = AppButtonSize.lg,
    this.isLoading = false,
    this.icon,
    this.width,
  }) : variant = AppButtonVariant.destructive;

  double get _height {
    switch (size) {
      case AppButtonSize.sm:
        return AppDimensions.buttonSm;
      case AppButtonSize.md:
        return AppDimensions.buttonMd;
      case AppButtonSize.lg:
        return AppDimensions.buttonLg;
    }
  }

  TextStyle get _textStyle {
    switch (size) {
      case AppButtonSize.sm:
        return AppTypography.caption.copyWith(fontWeight: FontWeight.w600);
      case AppButtonSize.md:
        return AppTypography.button.copyWith(fontSize: 13);
      case AppButtonSize.lg:
        return AppTypography.button;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;
    final effectiveOnPressed = isDisabled ? null : onPressed;

    Widget childContent;
    if (isLoading) {
      childContent = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == AppButtonVariant.secondary || variant == AppButtonVariant.tertiary
                ? AppColors.textSecondary
                : Colors.white,
          ),
        ),
      );
    } else {
      childContent = Row(
        mainAxisSize: width != null ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            text,
            style: _textStyle.copyWith(
              color: _getTextColor(isDisabled),
            ),
          ),
        ],
      );
    }

    Widget buttonWidget;
    switch (variant) {
      case AppButtonVariant.primary:
        buttonWidget = ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          child: childContent,
        );
        break;

      case AppButtonVariant.secondary:
        buttonWidget = OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            side: AppBorders.standard,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          child: childContent,
        );
        break;

      case AppButtonVariant.tertiary:
        buttonWidget = TextButton(
          onPressed: effectiveOnPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
          child: childContent,
        );
        break;

      case AppButtonVariant.destructive:
        buttonWidget = ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.destructive,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.destructive.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          child: childContent,
        );
        break;
    }

    return SizedBox(
      width: width,
      height: _height,
      child: buttonWidget,
    );
  }

  Color _getTextColor(bool isDisabled) {
    if (isDisabled) {
      return AppColors.textMuted;
    }
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.destructive:
        return Colors.white;
      case AppButtonVariant.secondary:
        return AppColors.textPrimary;
      case AppButtonVariant.tertiary:
        return AppColors.textSecondary;
    }
  }
}
