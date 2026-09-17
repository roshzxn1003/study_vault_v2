import 'package:flutter/material.dart';
import 'package:study_vault/core/design/design_system.dart';

/// Minimal academic text input field with accessible label, inline validation,
/// and password visibility toggle, built with design tokens.
class AuthTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final bool enabled;

  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: AppTypography.label.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        AppSpacing.v8,
        TextFormField(
          controller: widget.controller,
          obscureText: _obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          validator: widget.validator,
          onFieldSubmitted: widget.onFieldSubmitted,
          enabled: widget.enabled,
          style: AppTypography.body,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: AppTypography.bodySmall.copyWith(
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: AppRadius.field,
              borderSide: AppBorders.standard,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.field,
              borderSide: AppBorders.standard,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.field,
              borderSide: AppBorders.focus,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.field,
              borderSide: AppBorders.error,
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppRadius.field,
              borderSide: AppBorders.errorFocus,
            ),
            errorStyle: AppTypography.error,
            suffixIcon: widget.isPassword
                ? Semantics(
                    label: _obscureText ? 'Show password' : 'Hide password',
                    button: true,
                    child: IconButton(
                      icon: Icon(
                        _obscureText ? AppIcons.eye : AppIcons.eyeOff,
                        size: AppIcons.sm,
                        color: AppColors.textMuted,
                      ),
                      tooltip: _obscureText ? 'Show password' : 'Hide password',
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

