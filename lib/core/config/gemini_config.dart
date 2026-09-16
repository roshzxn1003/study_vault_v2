import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

class GeminiConfig {
  static const String _prefApiKey = 'gemini_api_key';
  static const String _prefModel = 'gemini_selected_model';
  static const String defaultModel = 'gemini-1.5-flash';

  static const String defaultApiKey = '';

  // Environment fallback if compiled with --dart-define=GEMINI_API_KEY=your_key
  static const String envApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: defaultApiKey);

  static Future<String> getApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString(_prefApiKey);
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        return savedKey.trim();
      }
    } catch (_) {}
    return envApiKey.isNotEmpty ? envApiKey : defaultApiKey;
  }

  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKey, key.trim());
  }

  static Future<String> getSelectedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefModel) ?? defaultModel;
    } catch (_) {
      return defaultModel;
    }
  }

  static Future<void> setSelectedModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefModel, model);
  }

  static Future<bool> validateApiKey(String key) async {
    if (key.trim().isEmpty) return false;
    final candidateModels = [defaultModel, 'gemini-2.0-flash', 'gemini-1.5-pro'];
    for (final modelName in candidateModels) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: key.trim(),
        );
        final response = await model.generateContent([Content.text('Hello')]).timeout(const Duration(seconds: 10));
        if (response.text != null && response.text!.isNotEmpty) {
          return true;
        }
      } catch (e) {
        debugPrint('Gemini key validation attempt for $modelName failed: $e');
      }
    }
    return false;
  }

  static const String academicSystemInstruction = '''
You are Study Vault AI, an elite, world-class academic tutor and cognitive study assistant collaborating with Google Gemini.
Your mission is to help students learn deeply, prepare for examinations, and master technical and theoretical subjects.

Guidelines for your thinking and output:
1. Always format responses in clear, structured, readable Markdown with headings, tables, bullet points, and code blocks.
2. When explaining concepts, use real-world analogies followed by formal definitions and practical trade-offs.
3. When answering questions based on user notes or uploaded materials, prioritize the user's provided context and highlight grounded insights.
4. When generating quizzes, provide standard multiple-choice questions with 4 options (A, B, C, D), clearly marked correct answers, and thorough explanations.
5. Provide step-by-step mathematical and logical reasoning without skipping steps.
''';
}
