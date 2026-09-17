import 'package:flutter/material.dart';
import '../tokens/tokens.dart';

/// Subtle 1px structural divider with optional centered label.
class AppDivider extends StatelessWidget {
  final String? label;
  final double verticalPadding;
  final Color color;

  const AppDivider({
    super.key,
    this.label,
    this.verticalPadding = AppSpacing.lg,
    this.color = AppColors.border,
  });

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: Divider(
          color: color,
          thickness: AppBorders.subtleWidth,
          height: 1,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: color,
              thickness: AppBorders.subtleWidth,
              height: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              label!,
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: color,
              thickness: AppBorders.subtleWidth,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
