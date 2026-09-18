import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Centralized AI Configuration for Study Vault.
///
/// SECURITY & SECRET ARCHITECTURE NOTE:
/// In development/testing and BYOK (Bring Your Own Key) workflows, the Gemini API key
/// is stored securely in SharedPreferences or passed at compile-time via --dart-define=GEMINI_API_KEY.
/// For production multi-tenant mobile deployments, direct client-side API keys are susceptible
/// to extraction. The recommended architecture is routing requests through a secure server-side
/// proxy (e.g. Supabase Edge Functions / Firebase Genkit) that validates the user's JWT and
/// attaches the API key server-side before invoking the Gemini API.
class AiConfig {
  // Current supported official Google Gemini model IDs (Verified for 2025/2026)
  static const String primaryModel = 'gemini-1.5-flash';
  static const String fastModel = 'gemini-1.5-flash';
  static const String reasoningModel = 'gemini-1.5-pro';
  static const String embeddingModel = 'text-embedding-004';

  // Configurable fallback chain for recoverable provider outages
  static const List<String> fallbackModels = [
    'gemini-1.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-pro',
  ];

  // Generation Defaults
  static const Duration timeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens = 2048;
  static const int defaultTopK = 40;
  static const int contextWindowTokens = 3000;

  // Preference Keys
  static const String _prefApiKey = 'gemini_api_key';
  static const String _prefSelectedModel = 'gemini_selected_model';
  static const String _prefAiEnabled = 'ai_enabled';
  static const String _prefVaultContext = 'ai_vault_context_enabled';
  static const String _prefResponseStyle = 'ai_response_style';
  static const String _prefAiConsent = 'ai_consent_granted';

  // Environment fallback via --dart-define=GEMINI_API_KEY=...
  static const String envApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Retrieves the active API key (from local storage or environment define).
  static Future<String> getApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString(_prefApiKey);
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        return savedKey.trim();
      }
    } catch (_) {}
    return envApiKey.trim();
  }

  /// Sets or clears the active API key.
  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKey, key.trim());
  }

  /// Gets the currently selected LLM generation model.
  static Future<String> getSelectedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefSelectedModel) ?? primaryModel;
    } catch (_) {
      return primaryModel;
    }
  }

  /// Sets the selected LLM generation model.
  static Future<void> setSelectedModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSelectedModel, model);
  }

  /// Checks if AI intelligence features are globally enabled.
  static Future<bool> isAiEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefAiEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Toggles AI intelligence features globally.
  static Future<void> setAiEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAiEnabled, enabled);
  }

  /// Checks if AI is allowed to index and retrieve private vault materials.
  static Future<bool> isVaultContextEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefVaultContext) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Toggles whether AI can search personal vault materials.
  static Future<void> setVaultContextEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefVaultContext, enabled);
  }

  /// Gets student's preferred response style ('socratic', 'concise', 'detailed').
  static Future<String> getPreferredResponseStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefResponseStyle) ?? 'socratic';
    } catch (_) {
      return 'socratic';
    }
  }

  /// Sets student's preferred response style.
  static Future<void> setPreferredResponseStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefResponseStyle, style);
  }

  /// Checks if student has acknowledged the AI privacy notice.
  static Future<bool> hasUserConsented() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefAiConsent) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Records student's consent to the AI privacy policy.
  static Future<void> setUserConsented(bool consented) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAiConsent, consented);
  }

  /// Validates a candidate Gemini API key by making a lightweight test call.
  static Future<bool> validateApiKey(String key) async {
    if (key.trim().isEmpty) return false;
    final candidates = [primaryModel, 'gemini-2.0-flash', 'gemini-1.5-pro'];
    for (final modelName in candidates) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: key.trim(),
        );
        final response = await model
            .generateContent([Content.text('Ping')])
            .timeout(const Duration(seconds: 8));
        if (response.text != null && response.text!.isNotEmpty) {
          return true;
        }
      } catch (e) {
        debugPrint('Gemini key test failed on $modelName: $e');
      }
    }
    return false;
  }

  // System Instructions
  static const String academicSystemInstruction = '''
You are Study Vault AI, an elite academic tutor and cognitive study companion collaborating with Google Gemini.
Your mission is to help students learn deeply, prepare for examinations, and master technical and theoretical subjects.

Guidelines for your thinking and output:
1. Always format responses in clear, structured, readable Markdown with headings, tables, bullet points, and code blocks.
2. When explaining concepts, start with an intuitive mental model, followed by formal definitions and practical trade-offs.
3. When answering questions based on user notes or uploaded materials, prioritize the user's provided context and highlight grounded insights.
4. When generating quizzes, provide standard multiple-choice questions with 4 options (A, B, C, D), clearly marked correct answers, and thorough explanations.
5. If the user's question cannot be answered from their provided notes, explicitly state: "I couldn't find this in your Study Vault materials" before offering general knowledge.
6. Never fabricate page numbers or citations.
''';

  static const String socraticTutorInstruction = '''
You are an expert, engaging Socratic AI Tutor. Teach with high pedagogical clarity:
1. Mental Model: Build intuition with everyday analogies.
2. Formal Definition: State technical principles and invariants clearly.
3. Concrete Example: Provide real-world systems, code, or numerical walk-throughs.
4. Common Exam Traps: Highlight misconceptions, tricky edge cases, and pitfalls.
5. Mastery Check: Ask 1 thought-provoking multiple-choice question to test active recall.
Encourage reasoning rather than immediately revealing every answer.
''';
}

/// Backwards-compatible alias for existing imports of AIConfig
typedef AIConfig = AiConfig;
