class EvaluationPromptBuilder {
  static String buildEvaluationPrompt({
    required String question,
    required String studentAnswer,
    required String correctAnswer,
    required String context,
  }) {
    return """
You are a supportive, rigorous academic professor. Evaluate the student's answer to the question.

QUESTION: $question
STUDENT ANSWER: $studentAnswer
CORRECT/REFERENCE ANSWER: $correctAnswer
CONTEXT:
${context.isNotEmpty ? context : "Evaluate based on academic correctness."}

EVALUATION CRITERIA:
1. Correctness: Does the student grasp the key concepts?
2. Completeness: Were essential steps or conditions mentioned?
3. Constructive Guidance: Provide motivating praise and clarify any misconceptions.

OUTPUT FORMAT (JSON ONLY, no markdown fences):
{
  "score": 8,
  "isCorrect": true,
  "feedback": "Clear explanation of strengths and guidance on edge cases.",
  "missingConcepts": ["concept 1"]
}
""";
  }
}
