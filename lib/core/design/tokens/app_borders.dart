import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized border tokens for Study Vault.
/// Defines subtle 1px structural borders that clarify surface hierarchy.
class AppBorders {
  AppBorders._();

  // Border Widths
  static const double subtleWidth = 1.0;
  static const double activeWidth = 1.5;

  // BorderSide Tokens
  static const BorderSide none = BorderSide.none;

  static const BorderSide standard = BorderSide(
    color: AppColors.border,
    width: subtleWidth,
  );

  static const BorderSide subtle = BorderSide(
    color: AppColors.borderSubtle,
    width: subtleWidth,
  );

  static const BorderSide hover = BorderSide(
    color: AppColors.borderHover,
    width: subtleWidth,
  );

  static const BorderSide focus = BorderSide(
    color: AppColors.primaryLight,
    width: activeWidth,
  );

  static const BorderSide error = BorderSide(
    color: AppColors.destructive,
    width: subtleWidth,
  );

  static const BorderSide errorFocus = BorderSide(
    color: AppColors.destructive,
    width: activeWidth,
  );

  static const BorderSide selected = BorderSide(
    color: AppColors.primary,
    width: activeWidth,
  );

  // Full Box Border Helpers
  static final Border allStandard = Border.all(
    color: AppColors.border,
    width: subtleWidth,
  );

  static final Border allSubtle = Border.all(
    color: AppColors.borderSubtle,
    width: subtleWidth,
  );

  static final Border allHover = Border.all(
    color: AppColors.borderHover,
    width: subtleWidth,
  );

  static final Border allSelected = Border.all(
    color: AppColors.primary,
    width: activeWidth,
  );

  static final Border allDestructive = Border.all(
    color: AppColors.destructive,
    width: subtleWidth,
  );

  // Directional Structural Borders
  static const Border top = Border(top: standard);
  static const Border bottom = Border(bottom: standard);
  static const Border left = Border(left: standard);
  static const Border right = Border(right: standard);
}
