import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/theme/app_colors.dart';

class ExamPlanScreen extends ConsumerStatefulWidget {
  const ExamPlanScreen({super.key});

  @override
  ConsumerState<ExamPlanScreen> createState() => _ExamPlanScreenState();
}

class _ExamPlanScreenState extends ConsumerState<ExamPlanScreen> {
  final List<Map<String, dynamic>> _days = [
    {"day": 1, "topic": "ACID Properties", "duration": "45m", "priority": "High", "completed": true, "subtopics": "Atomicity, Consistency, Isolation, Durability"},
    {"day": 2, "topic": "Transactions", "duration": "45m", "priority": "High", "completed": true, "subtopics": "Transaction states, Commit & Rollback"},
    {"day": 3, "topic": "Serializability", "duration": "60m", "priority": "High", "completed": false, "subtopics": "Conflict vs View Serializability, Precedence Graph"},
    {"day": 4, "topic": "Concurrency Control", "duration": "45m", "priority": "Medium", "completed": false, "subtopics": "Two-Phase Locking (2PL), Timestamp Ordering"},
    {"day": 5, "topic": "Recovery Systems", "duration": "60m", "priority": "Medium", "completed": false, "subtopics": "Log-Based Recovery, Checkpointing, WAL"},
    {"day": 6, "topic": "Mock Test & Quizzes", "duration": "90m", "priority": "High", "completed": false, "subtopics": "Timed 20-question practice test with explanations"},
    {"day": 7, "topic": "Final Revision & Flashcards", "duration": "60m", "priority": "High", "completed": false, "subtopics": "High-priority formulas and key definitions"},
  ];

  void _toggleDay(int index) {
    setState(() {
      _days[index]['completed'] = !(_days[index]['completed'] as bool);
    });
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _days.where((d) => d['completed'] == true).length;
    final progress = completedCount / _days.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Study Plan"),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Adjust Schedule',
            onPressed: () => context.push('/exam/setup'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "DBMS Midterm Prep",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${(progress * 100).toInt()}% Done",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryLight),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "$completedCount of ${_days.length} daily milestones completed • 5.5 hours remaining",
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.cardBorder,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              "Daily Milestones",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),

            // Days Milestone List
            Expanded(
              child: ListView.separated(
                itemCount: _days.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final day = _days[index];
                  final isCompleted = day['completed'] as bool;
                  final isHigh = day['priority'] == 'High';

                  return Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.surfaceElevated.withValues(alpha: 0.5)
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCompleted
                              ? AppColors.emerald.withValues(alpha: 0.3)
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              InkWell(
                                onTap: () => _toggleDay(index),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isCompleted
                                        ? AppColors.emerald
                                        : AppColors.primary.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isCompleted ? AppColors.emerald : AppColors.primaryLight,
                                    ),
                                  ),
                                  child: isCompleted
                                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                                      : Center(
                                          child: Text(
                                            "${day['day']}",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryLight),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      day['topic'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      day['subtopics'] as String,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isHigh ? AppColors.rose.withValues(alpha: 0.15) : AppColors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "${day['duration']} • ${day['priority']}",
                                  style: TextStyle(
                                    color: isHigh ? AppColors.rose : AppColors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => context.push('/study/learn/${day['topic']}'),
                                icon: const Icon(Icons.school_outlined, size: 14),
                                label: const Text('AI Tutor', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => context.push('/study/quiz/${day['topic']}'),
                                icon: const Icon(Icons.quiz_outlined, size: 14),
                                label: const Text('Quiz', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => context.go('/home'),
                child: const Text("Done / Return to Dashboard"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

