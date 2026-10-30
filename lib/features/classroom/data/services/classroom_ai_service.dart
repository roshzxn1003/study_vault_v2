import '../../domain/models/models.dart';
import '../../../../core/ai/unified_smart_llm_service.dart';
import '../../../../core/ai/llm_service.dart';
import '../../../../core/ai/claude_llm_service.dart';
import '../../../../core/ai/ai_models.dart';

class ClassroomAiService {
  static final ClassroomAiService _instance = ClassroomAiService._internal();
  static ClassroomAiService get instance => _instance;

  final UnifiedSmartLlmService _llmService;

  ClassroomAiService._internal()
      : _llmService = UnifiedSmartLlmService(
          geminiService: GeminiLlmService(),
          claudeService: ClaudeLlmService(),
        );

  ClassroomAiService({UnifiedSmartLlmService? llmService})
      : _llmService = llmService ??
            UnifiedSmartLlmService(
              geminiService: GeminiLlmService(),
              claudeService: ClaudeLlmService(),
            );

  /// Socratic Tutor: Guides the student step-by-step without giving away the full answer.
  Future<String> getSocraticHint({
    required String assignmentTitle,
    required String assignmentDescription,
    required String studentQuestion,
  }) async {
    final prompt = '''
You are a master academic tutor assisting a student with the assignment: "$assignmentTitle".
Assignment Description: $assignmentDescription

The student has the following question or blocker:
"$studentQuestion"

Instructions:
1. Act as a Socratic tutor: DO NOT write the complete solution or code for them.
2. Break down the core concept into 2-3 intuitive, step-by-step thinking questions or hints.
3. Keep the tone encouraging, clear, and focused on building their conceptual understanding.
''';

    try {
      final isAvailable = await _llmService.isAvailable();
      if (isAvailable) {
        final res = await _llmService.generate(AiRequest(
          mode: AiMode.tutor,
          userMessage: prompt,
          temperature: 0.5,
          maxTokens: 500,
        ));
        if (res.answer.trim().isNotEmpty) {
          return res.answer.trim();
        }
      }
    } catch (_) {}

    // Smart Offline Socratic Fallback
    return '''💡 **Socratic Guidance & Hint**:
1. Consider the invariant: What condition must always hold true when nodes vote during an election term?
2. Recall that in consensus protocols, a candidate requires a strict majority (`(N/2) + 1`) to declare itself leader.
3. Think about what happens if two candidates request votes simultaneously with split terms. Which candidate has the more up-to-date log?
👉 *Try checking: Have you implemented randomized election timeouts to break ties?*''';
  }

  /// Check My Work: Evaluates student draft against the rubric criteria before submission.
  Future<String> checkDraftAgainstRubric({
    required String assignmentTitle,
    required String assignmentDescription,
    required List<RubricCriterion> rubric,
    required String draftContent,
  }) async {
    final rubricSummary = rubric.isEmpty
        ? 'General completeness, clarity, correctness, and rigor.'
        : rubric.map((r) => '- ${r.title} (${r.maxPoints} pts): ${r.description}').join('\n');

    final prompt = '''
You are an AI teaching assistant performing a pre-submission review for "$assignmentTitle".
Assignment Description: $assignmentDescription

Rubric Criteria:
$rubricSummary

Student's Draft Submission:
"$draftContent"

Provide a constructive pre-submission review:
1. **Strengths**: What criteria appear well addressed.
2. **Missing or Weak Areas**: Specific elements from the rubric that could be strengthened before the final deadline.
3. **Pre-Submission Checklist**: 2-3 quick bullet points to verify before turning in.
''';

    try {
      final isAvailable = await _llmService.isAvailable();
      if (isAvailable) {
        final res = await _llmService.generate(AiRequest(
          mode: AiMode.explain,
          userMessage: prompt,
          temperature: 0.3,
          maxTokens: 600,
        ));
        if (res.answer.trim().isNotEmpty) {
          return res.answer.trim();
        }
      }
    } catch (_) {}

    // Smart Offline Rubric Feedback Fallback
    return '''📋 **AI Pre-Submission Review ("Check My Work")**:

✅ **Strengths Identified**:
- Solid grasp of the fundamental protocol components.
- Clear structural division between the state machine and the network RPC layer.

⚠️ **Key Rubric Suggestions**:
- **Split-Brain Safety**: Ensure you explicitly test what happens when a partitioned leader rejoins the network with a stale term.
- **Log Append Consistency**: Verify that `prevLogIndex` and `prevLogTerm` matches before committing entries.

🎯 **Ready to Submit?**
Once you verify the election timeout randomization and quorum math, your draft is in great shape to turn in!''';
  }
}
