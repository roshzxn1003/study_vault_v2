import 'package:flutter/material.dart';
import '../tokens/tokens.dart';

/// Professional academic text input field adhering to Study Vault design tokens.
class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final FocusNode? focusNode;
  final bool autofocus;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.label,
          ),
          AppSpacing.v8,
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          obscureText: isPassword,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          enabled: enabled,
          readOnly: readOnly,
          maxLines: isPassword ? 1 : maxLines,
          style: AppTypography.body.copyWith(
            color: enabled ? AppColors.textPrimary : AppColors.textMuted,
          ),
          cursorColor: AppColors.primaryLight,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            errorText: errorText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
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
            disabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.field,
              borderSide: AppBorders.subtle,
            ),
            hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
            errorStyle: AppTypography.error,
            helperStyle: AppTypography.caption,
          ),
        ),
      ],
    );
  }
}
