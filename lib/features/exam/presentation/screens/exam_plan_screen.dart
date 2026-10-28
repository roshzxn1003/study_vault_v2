import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/theme/app_colors.dart';

class ExamPlanScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>>? initialDays;
  final String? initialExamTitle;
  final String? initialSubject;

  const ExamPlanScreen({
    super.key,
    this.initialDays,
    this.initialExamTitle,
    this.initialSubject,
  });

  @override
  ConsumerState<ExamPlanScreen> createState() => _ExamPlanScreenState();
}

class _ExamPlanScreenState extends ConsumerState<ExamPlanScreen> {
  final List<Map<String, dynamic>> _days = [];
  String _examTitle = 'Exam Prep Plan';
  String _subject = 'General';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialDays != null) {
      _days.addAll(widget.initialDays!);
      _examTitle = widget.initialExamTitle ?? 'Exam Prep Plan';
      _subject = widget.initialSubject ?? 'General';
      _isLoading = false;
    } else {
      _loadPlanFromDb();
    }
  }

  Future<void> _loadPlanFromDb() async {
    try {
      final goals = await LocalDbService.instance.getExamGoals();
      if (!mounted) return;
      if (goals.isNotEmpty) {
        final goal = goals.first;
        _examTitle = (goal['title'] as String?)?.trim().isNotEmpty == true
            ? goal['title'] as String
            : 'Upcoming Exam';
        _subject = (goal['subject'] as String?)?.trim().isNotEmpty == true
            ? goal['subject'] as String
            : 'Study Plan';

        DateTime? targetDate;
        if (goal['target_date'] != null) {
          targetDate = DateTime.tryParse(goal['target_date'] as String);
        }
        final now = DateTime.now();
        final daysUntil = targetDate != null
            ? (targetDate.difference(now).inDays + 1).clamp(2, 14)
            : 5;

        final generatedDays = _generateMilestones(_subject, _examTitle, daysUntil);
        setState(() {
          _days.addAll(generatedDays);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading exam goals: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _generateMilestones(String subject, String title, int count) {
    final templates = [
      {'phase': 'Core Foundations & Concepts', 'duration': '1.5 hrs', 'priority': 'High', 'subtopics': 'Definitions, axioms, foundational overview'},
      {'phase': 'Deep Dive & Key Methodologies', 'duration': '2.0 hrs', 'priority': 'High', 'subtopics': 'Mechanisms, equations, step-by-step algorithms'},
      {'phase': 'Applied Problem Solving & Workflows', 'duration': '1.5 hrs', 'priority': 'Medium', 'subtopics': 'Practical scenarios, exercises & worked examples'},
      {'phase': 'Edge Cases & Advanced Applications', 'duration': '2.0 hrs', 'priority': 'Medium', 'subtopics': 'Complex topics, common pitfalls & counterexamples'},
      {'phase': 'High-Yield Review & Active Recall', 'duration': '1.5 hrs', 'priority': 'High', 'subtopics': 'Key formulas, flashcard retention & definitions'},
      {'phase': 'Mock Exam Simulation & Timed Drills', 'duration': '2.5 hrs', 'priority': 'High', 'subtopics': 'Simulated test questions, self-evaluation & grading'},
      {'phase': 'Targeted Weak Spot Remediation', 'duration': '1.5 hrs', 'priority': 'Medium', 'subtopics': 'Review missed quiz questions & tricky concepts'},
      {'phase': 'Comprehensive Final Revision & Polish', 'duration': '1.0 hr', 'priority': 'High', 'subtopics': 'Cheat sheet review, summary diagrams & confidence boost'},
    ];

    final days = <Map<String, dynamic>>[];
    for (int i = 0; i < count; i++) {
      final t = templates[i % templates.length];
      days.add({
        'day': i + 1,
        'topic': '$subject: ${t['phase']}',
        'subtopics': t['subtopics'] as String,
        'duration': t['duration'] as String,
        'priority': t['priority'] as String,
        'completed': false,
      });
    }
    return days;
  }

  void _toggleDay(int index) {
    if (index >= 0 && index < _days.length) {
      setState(() {
        final willComplete = !(_days[index]['completed'] as bool);
        _days[index]['completed'] = willComplete;
        if (willComplete) {
          LocalDbService.instance.recordStudyAction('milestone_complete');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          title: const Text("AI Study Plan"),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_days.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          title: const Text("AI Study Plan"),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_note_rounded, size: 48, color: AppColors.primaryLight),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No Study Plan Yet',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Configure your upcoming exam to generate a customized, daily milestone study plan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.push('/exam/setup'),
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: const Text('Create Study Plan', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final completedCount = _days.where((d) => d['completed'] == true).length;
    final progress = _days.isNotEmpty ? completedCount / _days.length : 0.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
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
                      Text(
                        _examTitle,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => context.push('/study/learn/${Uri.encodeComponent(day['topic'] as String)}'),
                                icon: const Icon(Icons.school_outlined, size: 14),
                                label: const Text('AI Tutor', style: TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => context.push('/study/flashcards/${Uri.encodeComponent(day['topic'] as String)}'),
                                icon: const Icon(Icons.style_outlined, size: 14),
                                label: const Text('Flashcards', style: TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => context.push('/study/quiz/${Uri.encodeComponent(day['topic'] as String)}'),
                                icon: const Icon(Icons.quiz_outlined, size: 14),
                                label: const Text('Quiz', style: TextStyle(fontSize: 11)),
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

