import 'package:study_vault/core/ai/ai_config.dart';

/// Legacy bridge for GeminiConfig, delegating to the unified [AiConfig].
class GeminiConfig {
  static const String defaultModel = AiConfig.primaryModel;
  static const String defaultApiKey = '';
  static const String envApiKey = AiConfig.envApiKey;
  static const String academicSystemInstruction = AiConfig.academicSystemInstruction;

  static Future<String> getApiKey() => AiConfig.getApiKey();
  static Future<void> setApiKey(String key) => AiConfig.setApiKey(key);
  static Future<String> getSelectedModel() => AiConfig.getSelectedModel();
  static Future<void> setSelectedModel(String model) => AiConfig.setSelectedModel(model);
  static Future<bool> validateApiKey(String key) => AiConfig.validateApiKey(key);
}
