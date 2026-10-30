import 'package:flutter/material.dart';

/// Centralized color system for Study Vault.
/// Defines a calm, academic, obsidian/zinc palette with restrained accents.
class AppColors {
  // Prevent instantiation
  AppColors._();

  // Dark Theme Base Surfaces (Obsidian / Zinc)
  static const Color background = Color(0xFF09090B);
  static const Color surface = Color(0xFF18181B);
  static const Color surfaceSecondary = Color(0xFF202023);
  static const Color surfaceElevated = Color(0xFF27272A);
  static const Color surfaceVariant = Color(0xFF2E2E33);

  // Dark Theme Borders (Crisp & High-Contrast)
  static const Color border = Color(0xFF27272A);
  static const Color borderSubtle = Color(0xFF1E1E22);
  static const Color borderHover = Color(0xFF3F3F46);
  static const Color borderFocus = Color(0xFF6366F1);
  static const Color cardOutline = Color(0xFF32323A);

  // Dark Theme Typography Colors
  static const Color textPrimary = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF8E8EA0);

  // Restrained Primary Accent (Indigo)
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primarySubtle = Color(0x1F6366F1); // 12% opacity

  // Semantic Status Colors
  static const Color destructive = Color(0xFFEF4444);
  static const Color destructiveLight = Color(0xFFF87171);
  static const Color destructiveSubtle = Color(0x1FEF4444);

  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color successSubtle = Color(0x1F10B981);
  static const Color emerald = success;

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningSubtle = Color(0x1FF59E0B);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoSubtle = Color(0x1F3B82F6);

  // Vibrant Academic File Type Indicators (High-Vibrancy for Instant Recognition)
  static const Color filePdf = Color(0xFFF87171);
  static const Color fileNote = Color(0xFF818CF8);
  static const Color fileFolder = Color(0xFFFBBF24);
  static const Color fileImage = Color(0xFF22D3EE);
  static const Color fileAudio = Color(0xFFA78BFA);
  static const Color fileGeneric = Color(0xFFA1A1AA);

  // Light Theme Preparation
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSecondary = Color(0xFFF1F5F9);
  static const Color lightSurfaceElevated = Color(0xFFE2E8F0);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Aliases for legacy backwards compatibility
  static const Color accent = primary;
  static const Color cardBorder = border;
  static const Color error = destructive;
  static const Color textTertiary = textMuted;
  static const Color divider = border;
  static const Color rose = destructive;
  static const Color amber = warning;
  static const Color cyan = fileImage;
}
