import 'package:flutter/material.dart';
import '../tokens/tokens.dart';

enum AppCardVariant { standard, interactive, selected, subtle }

/// Semantic card component for Study Vault with 4 distinct visual variants.
class AppCard extends StatelessWidget {
  final Widget child;
  final AppCardVariant variant;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.standard,
    this.padding = AppSpacing.p16,
    this.margin,
    this.onTap,
    this.borderRadius,
    this.width,
    this.height,
  });

  const AppCard.standard({
    super.key,
    required this.child,
    this.padding = AppSpacing.p16,
    this.margin,
    this.borderRadius,
    this.width,
    this.height,
  })  : variant = AppCardVariant.standard,
        onTap = null;

  const AppCard.interactive({
    super.key,
    required this.child,
    required this.onTap,
    this.padding = AppSpacing.p16,
    this.margin,
    this.borderRadius,
    this.width,
    this.height,
  }) : variant = AppCardVariant.interactive;

  const AppCard.selected({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppSpacing.p16,
    this.margin,
    this.borderRadius,
    this.width,
    this.height,
  }) : variant = AppCardVariant.selected;

  const AppCard.subtle({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppSpacing.p16,
    this.margin,
    this.borderRadius,
    this.width,
    this.height,
  }) : variant = AppCardVariant.subtle;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? AppRadius.card;

    Color backgroundColor;
    Border border;
    List<BoxShadow> shadows = AppElevation.none;

    switch (variant) {
      case AppCardVariant.standard:
        backgroundColor = AppColors.surface;
        border = AppBorders.allStandard;
        break;

      case AppCardVariant.interactive:
        backgroundColor = AppColors.surface;
        border = AppBorders.allStandard;
        shadows = AppElevation.subtle;
        break;

      case AppCardVariant.selected:
        backgroundColor = AppColors.surfaceSecondary;
        border = AppBorders.allSelected;
        break;

      case AppCardVariant.subtle:
        backgroundColor = AppColors.surfaceSecondary;
        border = AppBorders.allSubtle;
        break;
    }

    Widget cardBody = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: border,
        borderRadius: effectiveRadius,
        boxShadow: shadows,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          child: cardBody,
        ),
      );
    }

    return cardBody;
  }
}
