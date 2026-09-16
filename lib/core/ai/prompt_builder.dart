class PromptBuilder {
  static String buildRagPrompt({
    required String query,
    required String context,
    required String mode,
  }) {
    String systemRole = "You are Study Vault AI, an elite academic tutor and cognitive study assistant.";
    
    if (mode == 'explain') {
      systemRole += " Explain concepts with intuitive analogies, structured breakdown, mathematical/logical precision, and real-world software/engineering applications.";
    } else if (mode == 'summarize') {
      systemRole += " Provide a high-yield exam summary featuring: 1. Executive Concept 2. Core Invariants & Rules 3. Exam Traps & Edge Cases.";
    } else if (mode == 'quiz') {
      systemRole += " Provide a mini practice quiz with question, multiple-choice options, correct answer, and conceptual reasoning.";
    }

    final hasContext = context.trim().isNotEmpty && !context.contains("No relevant context found");

    return """
$systemRole

GUIDELINES:
1. ${hasContext ? "Prioritize and ground your explanation in the user's provided Study Vault notes/materials below." : "Provide a comprehensive, authoritative academic explanation using your vast academic knowledge."}
2. Format beautifully in GitHub-flavored Markdown with bold key terms, tables, bullet points, and code blocks where applicable.
3. Be clear, encouraging, and pedagogically sound.

${hasContext ? "### GROUNDED VAULT CONTEXT:\n$context\n" : ""}
### STUDENT QUESTION / TOPIC:
$query
""";
  }
}
