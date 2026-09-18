/// Prompt builder for generating high-yield active-recall flashcard decks.
class FlashcardPromptBuilder {
  static String buildPrompt({
    required String topic,
    required String context,
    int count = 5,
    String difficulty = 'medium',
  }) {
    return """
You are Study Vault's Spaced Repetition Specialist.
Generate exactly $count high-yield flashcards designed for maximum active recall on "$topic".

DIFFICULTY: $difficulty
MATERIAL CONTEXT:
${context.trim().isNotEmpty ? context : "Use standard academic syllabus definitions for $topic."}

CARD DESIGN GUIDELINES:
- Front: A definitive question, prompt, or technical term. Avoid trivial yes/no questions.
- Back: A concise, authoritative answer with the essential formula, mechanism, or proof.
- Distinctness: Ensure each card covers a completely different facet of the topic (no duplicate concepts).

OUTPUT SCHEMA:
Return ONLY a valid JSON array of objects conforming to this schema without markdown code blocks:
[
  {
    "front": "Front question / prompt?",
    "back": "Definitive explanation or answer.",
    "topic": "$topic",
    "difficulty": "$difficulty",
    "source_reference": "Unit 3 p. 14"
  }
]
""";
  }
}
