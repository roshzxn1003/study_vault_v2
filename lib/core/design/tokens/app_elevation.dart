import 'package:flutter/material.dart';

/// Centralized elevation and shadow tokens for Study Vault.
/// Prioritizes surface contrast, borders, and subtle diffuse shadows.
class AppElevation {
  AppElevation._();

  // No shadow (default for most flat cards relying on borders)
  static const List<BoxShadow> none = [];

  // Subtle elevation for hover cards and interactive elements
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x2E000000),
      blurRadius: 6,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  // Medium elevation for menus, popovers, and floating toolbars
  static const List<BoxShadow> flyout = [
    BoxShadow(
      color: Color(0x52000000),
      blurRadius: 14,
      offset: Offset(0, 6),
      spreadRadius: -2,
    ),
  ];

  // Elevated modal/dialog shadow
  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x73000000),
      blurRadius: 28,
      offset: Offset(0, 12),
      spreadRadius: -4,
    ),
  ];

  // Bottom sheet upward shadow
  static const List<BoxShadow> bottomSheet = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 20,
      offset: Offset(0, -4),
      spreadRadius: 0,
    ),
  ];
}
