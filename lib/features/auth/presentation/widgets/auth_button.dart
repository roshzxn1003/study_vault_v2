import 'package:flutter/material.dart';
import 'package:study_vault/core/design/design_system.dart';

/// Primary/secondary action button for authentication screens,
/// backed by the unified AppButton component.
class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final Widget? icon;

  const AuthButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      size: AppButtonSize.lg,
      width: double.infinity,
      variant: isSecondary ? AppButtonVariant.secondary : AppButtonVariant.primary,
    );
  }
}

