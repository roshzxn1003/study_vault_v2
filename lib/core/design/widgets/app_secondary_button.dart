import 'package:flutter/material.dart';
import 'app_button.dart';

/// Convenient secondary button component for cancellations and alternative actions.
class AppSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;
  final AppButtonSize size;
  final double? width;

  const AppSecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.size = AppButtonSize.lg,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton.secondary(
      text: text,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      size: size,
      width: width,
    );
  }
}
