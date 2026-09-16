class StudyPlanPromptBuilder {
  static String buildPlanPrompt({
    required String examName,
    required List<String> topics,
    required int daysUntilExam,
    required String studyTimePerDay,
  }) {
    return """
You are a Study Strategist. Create a realistic, high-efficiency study plan.

EXAM: $examName
TOPICS TO COVER: ${topics.join(', ')}
TIME UNTIL EXAM: $daysUntilExam days
AVAILABLE TIME: $studyTimePerDay per day

PLANNING RULES:
1. Prioritize topics by typical importance in academic exams.
2. Distribute topics logically over the available days.
3. Include a "Revision" slot on the final day.
4. Ensure the daily load does not exceed the available study time.
5. Include a "Quick Quiz" session for each topic.

OUTPUT FORMAT (JSON ONLY):
{
  "plan": [
    {
      "day": 1,
      "date": "YYYY-MM-DD",
      "sessions": [
        {
          "topic": "Topic Name",
          "duration": 45,
          "activity": "learn",
          "priority": "high"
        },
        {
          "topic": "Topic Name",
          "duration": 15,
          "activity": "quiz",
          "priority": "high"
        }
      ]
    }
  ]
}
""";
  }
}
