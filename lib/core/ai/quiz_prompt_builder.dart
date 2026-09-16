class QuizPromptBuilder {
  static String buildQuizPrompt({
    required String topic,
    required String context,
    required int count,
    required String difficulty,
  }) {
    return """
You are an expert academic examiner and professor. Generate a high-yield examination quiz.

TOPIC: $topic
CONTEXT:
${context.isNotEmpty ? context : "Use general subject syllabus standards for $topic."}

REQUIREMENTS:
- Number of Questions: $count
- Difficulty: $difficulty
- Question Types: High-quality multiple-choice questions with 4 distinct options (A, B, C, D).
- Grounding: Focus on conceptual depth, edge cases, definitions, and problem-solving.

OUTPUT FORMAT (JSON ONLY, no markdown code block backticks):
[
  {
    "question": "Clear and conceptual question text?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctIndex": 0,
    "explanation": "Thorough explanation of why the correct option is right and others are incorrect."
  }
]
""";
  }
}
