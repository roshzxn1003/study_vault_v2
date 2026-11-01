import 'package:flutter/widgets.dart';

/// Centralized control heights and dimensions for Study Vault.
class AppDimensions {
  AppDimensions._();

  // Button Heights
  static const double buttonSm = 36.0;
  static const double buttonMd = 44.0;
  static const double buttonLg = 50.0;

  // Form Field Dimensions
  static const double inputHeight = 48.0;
  static const double minTouchTarget = 44.0;

  // Component Heights
  static const double topBarHeight = 56.0;
  static const double bottomNavHeight = 68.0;
  static const double sidebarWidth = 240.0;
  static const double navRailWidth = 72.0;

  // Dynamic Clearance Helper for floating navigation bar
  static double bottomNavClearance(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final floatingMargin = bottomPadding > 0 ? bottomPadding + 8.0 : 20.0;
    return bottomNavHeight + floatingMargin + 16.0;
  }

  // Max Readable Widths
  static const double authContainerMaxWidth = 440.0;
  static const double dialogMaxWidth = 460.0;
  static const double sheetMaxWidth = 600.0;
  static const double contentMaxWidth = 1120.0;
}
