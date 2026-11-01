import 'package:flutter/material.dart';

/// Centralized subtle animation tokens and conventions for Study Vault.
class AppAnimations {
  AppAnimations._();

  // Fast, subtle durations
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration press = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration spring = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 350);

  // Smooth, calm curves (including Apple HIG standard spring-ease)
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve appleEaseOut = Cubic(0.23, 1.0, 0.32, 1.0);
  static const Curve decelerate = Curves.easeOut;
  static const Curve emphasized = Curves.fastOutSlowIn;

  // Physical touch-down scales
  static const double cardPressScale = 0.97;
  static const double buttonPressScale = 0.96;
}
