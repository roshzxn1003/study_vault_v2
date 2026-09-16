import 'package:study_vault/core/ai/ai_orchestrator.dart';
import 'package:study_vault/core/ai/llm_service.dart';

class MultimodalOrchestrator {
  final AiOrchestrator _aiOrchestrator;
  final LlmService _llmService;
  LlmService get llmService => _llmService;

  MultimodalOrchestrator(this._aiOrchestrator, this._llmService);

  Future<String> handleImageQuery({
    required String imagePath,
    required String query,
    String? preferredLanguage,
    String? explanationLevel,
  }) async {
    final response = await _aiOrchestrator.askQuestion(
      query: "Analyze this study material: $query (Language: ${preferredLanguage ?? 'English'}, Level: ${explanationLevel ?? 'Intermediate'})",
      mode: 'explain',
      imagePath: imagePath,
    );
    return response.answer;
  }
}
