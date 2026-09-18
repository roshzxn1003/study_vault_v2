import 'package:flutter/foundation.dart';
import 'gemini_config.dart';
import 'supabase_config.dart';

enum AppEnvironment {
  development,
  staging,
  production,
}

class EnvironmentConfig {
  static const String _rawEnv = String.fromEnvironment('APP_ENV', defaultValue: '');

  static AppEnvironment get current {
    final lower = _rawEnv.toLowerCase();
    if (lower == 'prod' || lower == 'production') {
      return AppEnvironment.production;
    } else if (lower == 'staging' || lower == 'stage') {
      return AppEnvironment.staging;
    } else if (lower == 'dev' || lower == 'development') {
      return AppEnvironment.development;
    }
    // Fallback: If in release mode, default to production, otherwise development
    return kReleaseMode ? AppEnvironment.production : AppEnvironment.development;
  }

  static bool get isProduction => current == AppEnvironment.production;
  static bool get isStaging => current == AppEnvironment.staging;
  static bool get isDevelopment => current == AppEnvironment.development;

  /// Logging configuration: verbose debug logging enabled only outside production
  static bool get enableVerboseLogging => !isProduction;

  /// Guard for developer tools, debug banners, design system preview screens
  static bool get allowDevTools => isDevelopment && !kReleaseMode;

  /// Supabase Configuration
  static String get supabaseUrl => SupabaseConfig.url;
  static String get supabaseAnonKey => SupabaseConfig.anonKey;
  static bool get isSupabaseConfigured => SupabaseConfig.isConfigured;

  /// Gemini Configuration
  static String get geminiApiKey => GeminiConfig.envApiKey;
  static String get defaultGeminiModel => GeminiConfig.defaultModel;

  /// Masks sensitive strings (e.g. "AIzaSy...XYZ" -> "AIza...XYZ")
  static String maskSecret(String? secret) {
    if (secret == null || secret.isEmpty) return '(not set)';
    if (secret.length <= 8) return '****';
    final prefix = secret.substring(0, 4);
    final suffix = secret.substring(secret.length - 4);
    return '$prefix...$suffix';
  }

  /// Safe diagnostic summary without leaking sensitive API keys or credentials
  static Map<String, dynamic> getDiagnosticSummary() {
    return {
      'environment': current.name,
      'isReleaseMode': kReleaseMode,
      'supabaseConfigured': isSupabaseConfigured,
      'supabaseUrl': supabaseUrl.isNotEmpty ? supabaseUrl : '(empty)',
      'supabaseKeyMasked': maskSecret(supabaseAnonKey),
      'geminiKeyConfigured': geminiApiKey.isNotEmpty,
      'geminiKeyMasked': maskSecret(geminiApiKey),
      'verboseLogging': enableVerboseLogging,
    };
  }
}
