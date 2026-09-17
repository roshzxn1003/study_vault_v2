import 'package:flutter/material.dart';
import '../tokens/tokens.dart';

/// Minimal academic search input with clear button and subtle border.
class AppSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final String hint;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;

  const AppSearchField({
    super.key,
    this.controller,
    this.hint = 'Search vault, notes, subjects...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_updateState);
  }

  void _updateState() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_updateState);
    }
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.inputHeight,
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        style: AppTypography.body,
        cursorColor: AppColors.primaryLight,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
          prefixIcon: const Icon(
            AppIcons.search,
            size: AppIcons.md,
            color: AppColors.textMuted,
          ),
          suffixIcon: _hasText
              ? IconButton(
                  icon: const Icon(
                    AppIcons.close,
                    size: AppIcons.sm,
                    color: AppColors.textMuted,
                  ),
                  tooltip: 'Clear search',
                  onPressed: _clear,
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
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
        ),
      ),
    );
  }
}
