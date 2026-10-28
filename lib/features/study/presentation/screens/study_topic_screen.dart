import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/theme/app_colors.dart';
import 'package:study_vault/features/progress/presentation/providers/progress_provider.dart';

class StudyTopicScreen extends ConsumerWidget {
  final String topic;
  const StudyTopicScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(topicProgressProvider);
    final statsList = statsAsync.value ?? [];
    final matchingStat = statsList.cast<TopicStat?>().firstWhere(
      (s) => s != null && s.topic.toLowerCase() == topic.toLowerCase(),
      orElse: () => null,
    );

    final double progressValue = matchingStat != null ? matchingStat.accuracy : 0.0;
    final int scorePercent = (progressValue * 100).toInt();
    final bool hasStarted = matchingStat != null && matchingStat.attempts > 0;

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
        title: Text(topic),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mastery Progress Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Topic Mastery", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (hasStarted && scorePercent >= 70 ? AppColors.emerald : AppColors.primary).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          hasStarted ? (scorePercent >= 70 ? 'Mastered' : 'In Progress') : 'Not Started',
                          style: TextStyle(
                            color: hasStarted && scorePercent >= 70 ? AppColors.emerald : (hasStarted ? AppColors.primaryLight : AppColors.textSecondary),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        scorePercent >= 70 ? AppColors.emerald : AppColors.primaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        hasStarted ? "$scorePercent% Mastery Score" : "0% Mastery Score",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: hasStarted && scorePercent >= 70 ? AppColors.emerald : (hasStarted ? AppColors.primaryLight : AppColors.textSecondary),
                        ),
                      ),
                      Text(
                        hasStarted ? "${matchingStat.correct}/${matchingStat.attempts} cards mastered" : "Target: 100% for Exam",
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text("Interactive Study Tools", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),

            _buildActionCard(
              context,
              "AI Step-by-Step Tutor",
              "Socratic lesson progression with analogies & code examples",
              Icons.psychology_outlined,
              AppColors.primary,
              () => context.push('/study/learn/${Uri.encodeComponent(topic)}'),
            ),
            _buildActionCard(
              context,
              "Active Recall Flashcards",
              "Flip study cards with topic-specific test questions",
              Icons.style_outlined,
              AppColors.amber,
              () => context.push('/study/flashcards/${Uri.encodeComponent(topic)}'),
            ),
            _buildActionCard(
              context,
              "Adaptive Practice Quiz",
              "Instant grading, answer feedback, and detailed explanations",
              Icons.quiz_outlined,
              AppColors.emerald,
              () => context.push('/study/quiz/${Uri.encodeComponent(topic)}'),
            ),
            _buildActionCard(
              context,
              "Ask AI Assistant",
              "Deep conversational Q&A grounded in your vault notes",
              Icons.auto_awesome_outlined,
              AppColors.cyan,
              () => context.push('/ai?subject=${Uri.encodeComponent(topic)}'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
          onTap: onTap,
        ),
      ),
    );
  }
}

