import 'package:study_vault/core/ai/ai_models.dart';

/// Prompt builder for document summaries with configurable depth.
class SummaryPromptBuilder {
  static String buildSummaryPrompt({
    required String context,
    SummaryDepth depth = SummaryDepth.detailed,
    String? title,
  }) {
    final instructions = switch (depth) {
      SummaryDepth.quick => """
Provide an Executive Quick Summary (under 250 words):
- 2-3 sentence overview of the core problem or concept
- Top 3 critical takeaways in bullet points
- Key formula or invariant rule if applicable
""",
      SummaryDepth.detailed => """
Provide an Exhaustive Technical Summary:
1. Executive Overview & Problem Context
2. Core Mathematical/System Invariants & Definitions (use clear bullet points or comparison table)
3. Step-by-Step Architectural/Algorithmic Flow
4. Practical Engineering Trade-offs (Time vs Space, Latency vs Throughput, Consistency vs Availability)
5. Summary Table of Key Terms
""",
      SummaryDepth.examRevision => """
Provide an High-Yield Exam Revision Sheet:
1. High-Probability Exam Concepts (definitions most tested in university exams)
2. Crucial Formulas, Proofs & Pseudocode
3. Classic Exam Pitfalls & Misconceptions
4. 3 Quick Model Questions likely to appear on test papers
""",
      SummaryDepth.keyPoints => """
Provide Key Points & Cheat Sheet:
- Extract all critical facts, definitions, rules, and equations in bulleted format.
- Group logically by topic.
""",
    };

    return """
You are Study Vault's Expert Academic Synthesizer.
Summarize the following study material accurately, adhering strictly to the requested summary format.

${title != null ? "DOCUMENT TITLE: $title\n" : ""}
$instructions

STUDY MATERIAL:
$context
""";
  }
}
