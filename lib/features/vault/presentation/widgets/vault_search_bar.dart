import 'dart:async';
import 'package:flutter/material.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';

/// Debounced search bar with integrated filter and sort triggers.
class VaultSearchBar extends StatefulWidget {
  final String initialQuery;
  final String hintText;
  final int activeFilterCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onOpenFilters;
  final VoidCallback? onOpenSort;
  final bool showActionButtons;

  const VaultSearchBar({
    super.key,
    this.initialQuery = '',
    this.hintText = 'Search materials, subjects, folders...',
    this.activeFilterCount = 0,
    required this.onSearchChanged,
    this.onOpenFilters,
    this.onOpenSort,
    this.showActionButtons = false,
  });

  @override
  State<VaultSearchBar> createState() => _VaultSearchBarState();
}

class _VaultSearchBarState extends State<VaultSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant VaultSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery &&
        _controller.text != widget.initialQuery) {
      _controller.text = widget.initialQuery;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      widget.onSearchChanged(value);
    });
  }

  void _clear() {
    _controller.clear();
    widget.onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final searchInput = Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.button,
        border: AppBorders.allStandard,
      ),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        style: AppTypography.body.copyWith(
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppTypography.body.copyWith(
            color: AppColors.textMuted,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textMuted,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                  onPressed: _clear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );

    if (!widget.showActionButtons || widget.onOpenFilters == null || widget.onOpenSort == null) {
      return searchInput;
    }

    return Row(
      children: [
        // Search Input
        Expanded(child: searchInput),

        const SizedBox(width: AppSpacing.sm),

        // Filter Button with count badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: widget.activeFilterCount > 0
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surface,
                borderRadius: AppRadius.button,
                border: widget.activeFilterCount > 0
                    ? Border.all(color: AppColors.primaryLight, width: 1.5)
                    : AppBorders.allStandard,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.filter_list_rounded,
                  size: 20,
                  color: widget.activeFilterCount > 0
                      ? AppColors.primaryLight
                      : AppColors.textSecondary,
                ),
                onPressed: widget.onOpenFilters,
                tooltip: 'Filter materials',
              ),
            ),
            if (widget.activeFilterCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Center(
                    child: Text(
                      '${widget.activeFilterCount}',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(width: AppSpacing.xs),

        // Sort Button
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.button,
            border: AppBorders.allStandard,
          ),
          child: IconButton(
            icon: const Icon(
              Icons.swap_vert_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            onPressed: widget.onOpenSort,
            tooltip: 'Sort materials',
          ),
        ),
      ],
    );
  }
}
