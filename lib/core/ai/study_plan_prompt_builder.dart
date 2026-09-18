/// Prompt builder for generating realistic, milestone-driven exam study plans.
class StudyPlanPromptBuilder {
  static String buildPlanPrompt({
    required String subject,
    required List<String> topics,
    required int days,
    required String dailyStudyTime,
    String? difficulty,
  }) {
    return """
You are Study Vault's Academic Strategist.
Create a structured, highly realistic $days-day study and revision schedule for "$subject".

TOPICS TO MASTER: ${topics.join(', ')}
AVAILABLE DAYS: $days
DAILY STUDY TIME: $dailyStudyTime
${difficulty != null ? "EXAM DIFFICULTY: $difficulty" : ""}

STRATEGY GUIDELINES:
1. Spread the topics logically across Days 1 through $days.
2. Group related conceptual topics together.
3. Reserve the final day ($days) exclusively for comprehensive review and mock practice.
4. Each day must specify:
   - "day": Integer (1 to $days)
   - "topic": Name of primary topic
   - "goal": Clear measurable learning objective
   - "suggestedActivity": Specific task (e.g. "Review lecture notes & solve 5 practice problems")
   - "revisionCheckpoint": Fast self-test question or checkpoint

OUTPUT SCHEMA:
Return ONLY a valid JSON array of day items without markdown fences:
[
  {
    "day": 1,
    "topic": "Process Scheduling",
    "goal": "Understand FCFS, Round Robin, and SJF scheduling algorithms",
    "suggestedActivity": "Read Unit 3 slides and calculate turnaround time for 3 example workloads",
    "revisionCheckpoint": "Can you compute average waiting time for preemptive SJF?",
    "isCompleted": false
  }
]
""";
  }
}
