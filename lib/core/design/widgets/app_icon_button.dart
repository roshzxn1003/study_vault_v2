import 'package:flutter/material.dart';
import '../tokens/tokens.dart';

/// Accessible icon button with guaranteed minimum 44x44 touch target
/// and subtle academic hover/press styling.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final BorderSide? border;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = AppIcons.md,
    this.color,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onPressed == null
        ? AppColors.textMuted
        : (color ?? AppColors.textSecondary);

    Widget button = Material(
      color: backgroundColor ?? Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.button,
        side: border ?? BorderSide.none,
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.button,
        child: SizedBox(
          width: AppDimensions.minTouchTarget,
          height: AppDimensions.minTouchTarget,
          child: Center(
            child: Icon(
              icon,
              size: size,
              color: effectiveColor,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
