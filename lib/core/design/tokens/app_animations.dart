import 'package:flutter/material.dart';

/// Centralized subtle animation tokens and conventions for Study Vault.
class AppAnimations {
  AppAnimations._();

  // Fast, subtle durations
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);

  // Smooth, calm curves
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve decelerate = Curves.easeOut;
  static const Curve emphasized = Curves.fastOutSlowIn;
}
