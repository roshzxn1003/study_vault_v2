import 'package:flutter/material.dart';

/// Centralized spacing system for Study Vault.
/// Defines a strict mathematical spacing scale to maintain consistent rhythm.
class AppSpacing {
  AppSpacing._();

  // Spacing Scale Tokens
  static const double none = 0;
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double massive = 64;

  // Vertical Spacer Widgets
  static const SizedBox v4 = SizedBox(height: xxs);
  static const SizedBox v8 = SizedBox(height: xs);
  static const SizedBox v12 = SizedBox(height: sm);
  static const SizedBox v16 = SizedBox(height: md);
  static const SizedBox v20 = SizedBox(height: lg);
  static const SizedBox v24 = SizedBox(height: xl);
  static const SizedBox v32 = SizedBox(height: xxl);
  static const SizedBox v40 = SizedBox(height: xxxl);
  static const SizedBox v48 = SizedBox(height: huge);
  static const SizedBox v64 = SizedBox(height: massive);

  // Horizontal Spacer Widgets
  static const SizedBox h4 = SizedBox(width: xxs);
  static const SizedBox h8 = SizedBox(width: xs);
  static const SizedBox h12 = SizedBox(width: sm);
  static const SizedBox h16 = SizedBox(width: md);
  static const SizedBox h20 = SizedBox(width: lg);
  static const SizedBox h24 = SizedBox(width: xl);
  static const SizedBox h32 = SizedBox(width: xxl);
  static const SizedBox h40 = SizedBox(width: xxxl);
  static const SizedBox h48 = SizedBox(width: huge);

  // EdgeInsets Uniform Padding Helpers
  static const EdgeInsets p4 = EdgeInsets.all(xxs);
  static const EdgeInsets p8 = EdgeInsets.all(xs);
  static const EdgeInsets p12 = EdgeInsets.all(sm);
  static const EdgeInsets p16 = EdgeInsets.all(md);
  static const EdgeInsets p20 = EdgeInsets.all(lg);
  static const EdgeInsets p24 = EdgeInsets.all(xl);
  static const EdgeInsets p32 = EdgeInsets.all(xxl);

  // EdgeInsets Horizontal Padding Helpers
  static const EdgeInsets ph8 = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets ph12 = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets ph16 = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets ph20 = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets ph24 = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets ph32 = EdgeInsets.symmetric(horizontal: xxl);

  // EdgeInsets Vertical Padding Helpers
  static const EdgeInsets pv8 = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets pv12 = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets pv16 = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets pv20 = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets pv24 = EdgeInsets.symmetric(vertical: xl);
}
