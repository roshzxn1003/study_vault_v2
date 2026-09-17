import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized typography tokens for Study Vault using Inter.
/// Establishes strong typographic hierarchy across all application screens.
class AppTypography {
  AppTypography._();

  // Font family reference
  static String get fontFamily => GoogleFonts.inter().fontFamily ?? 'Inter';

  // Base TextStyle builder with Inter font
  static TextStyle _style({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    double letterSpacing = 0,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  // Core Typography Tokens
  static TextStyle get display => _style(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -1.0,
      );

  static TextStyle get headline => _style(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.6,
      );

  static TextStyle get title => _style(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.3,
      );

  static TextStyle get subtitle => _style(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: -0.1,
        color: AppColors.textSecondary,
      );

  static TextStyle get body => _style(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodySmall => _style(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => _style(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        letterSpacing: 0.1,
        color: AppColors.textMuted,
      );

  static TextStyle get label => _style(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.1,
        color: AppColors.textSecondary,
      );

  static TextStyle get button => _style(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.1,
        color: Colors.white,
      );

  static TextStyle get error => _style(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: AppColors.destructive,
      );

  // Helper extension for quickly coloring tokens
  static TextStyle withColor(TextStyle style, Color color) =>
      style.copyWith(color: color);
}
