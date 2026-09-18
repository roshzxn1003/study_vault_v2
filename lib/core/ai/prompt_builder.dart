import 'package:study_vault/core/ai/prompt_engine.dart';

/// Legacy prompt builder bridging to [PromptEngine].
class PromptBuilder {
  static String buildRagPrompt({
    required String query,
    required String context,
    required String mode,
  }) {
    if (mode == 'summarize') {
      return PromptEngine.buildSummaryPrompt(context: context);
    } else if (mode == 'quiz') {
      return PromptEngine.buildQuizPrompt(topic: query, context: context);
    } else if (mode == 'tutor') {
      return PromptEngine.buildTutorPrompt(
        topic: query,
        context: context,
        currentStep: 'Step 1: Intuitive Mental Model',
      );
    }
    return PromptEngine.buildDocumentQaPrompt(query: query, context: context);
  }
}
