/// Prompt builder for generating strictly-typed, structured multiple choice quizzes.
class QuizPromptBuilder {
  static String buildQuizPrompt({
    required String topic,
    required String context,
    int count = 5,
    String difficulty = 'medium',
    String? subject,
  }) {
    return """
You are Study Vault's Chief Examination Assessor.
Generate exactly $count high-quality multiple choice questions testing deep conceptual comprehension of "$topic".

${subject != null ? "SUBJECT: $subject" : ""}
DIFFICULTY: $difficulty

REFERENCE VAULT MATERIAL:
${context.trim().isNotEmpty ? context : "Use official university curriculum standards for $topic."}

STRICT QUIZ RULES:
1. Every question must have EXACTLY 4 distinct options (A, B, C, D).
2. "correctIndex" MUST be an integer between 0 and 3 indicating the zero-based index of the single correct option.
3. Provide a clear, pedagogical "explanation" detailing why the selected option is correct and why other distractors are incorrect.
4. If referencing specific pages or sections from the context, include them in "sources".

OUTPUT SCHEMA:
Return ONLY a valid JSON array of objects conforming to this schema without code fences:
[
  {
    "question": "Question text here?",
    "options": ["Option 0", "Option 1", "Option 2", "Option 3"],
    "correctIndex": 0,
    "explanation": "Detailed explanation of the correct choice.",
    "difficulty": "$difficulty",
    "sources": ["Page 12"]
  }
]
""";
  }
}
