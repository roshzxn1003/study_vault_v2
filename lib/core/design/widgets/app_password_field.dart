import 'package:flutter/material.dart';
import '../tokens/tokens.dart';
import 'app_text_field.dart';

/// Specialized password text field with accessible show/hide toggle.
class AppPasswordField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;
  final bool enabled;

  const AppPasswordField({
    super.key,
    this.label = 'Password',
    this.hint = '••••••••',
    this.controller,
    this.textInputAction = TextInputAction.done,
    this.autofillHints = const [AutofillHints.password],
    this.validator,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      hint: widget.hint,
      controller: widget.controller,
      isPassword: _obscureText,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      suffixIcon: Semantics(
        label: _obscureText ? 'Show password' : 'Hide password',
        button: true,
        child: IconButton(
          icon: Icon(
            _obscureText ? AppIcons.eye : AppIcons.eyeOff,
            size: AppIcons.md,
            color: AppColors.textMuted,
          ),
          tooltip: _obscureText ? 'Show password' : 'Hide password',
          onPressed: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
        ),
      ),
    );
  }
}
