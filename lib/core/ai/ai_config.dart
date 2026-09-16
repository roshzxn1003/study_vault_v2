class AIConfig {
  static const String currentModel = 'gemini-1.5-pro';
  static const int maxTokens = 2048;
  static const double temperature = 0.7;
  static const int topK = 40;
  static const int contextWindow = 10;

  // Feature Flags
  static bool isVoiceEnabled = true;
  static bool isImageAIEnabled = true;
  static bool isExamModeEnabled = true;
  static bool isOfflineModeEnabled = true;
}
