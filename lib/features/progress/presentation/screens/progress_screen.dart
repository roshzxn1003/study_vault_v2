import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/design_system.dart';
import '../providers/progress_provider.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(topicProgressProvider);
    final generalStats = ref.watch(studyStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        title: 'Study Analytics & Mastery',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(generalStats),
            const SizedBox(height: AppSpacing.xl),

            Text(
              'Topic Mastery',
              style: AppTypography.headline.copyWith(fontSize: 18),
            ),
            const SizedBox(height: AppSpacing.sm),

            statsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading progress: $err', style: const TextStyle(color: AppColors.error)),
                ),
              ),
              data: (stats) => stats.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.card,
                        border: AppBorders.allStandard,
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.psychology_outlined, size: 40, color: AppColors.textMuted),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'No topic progress recorded yet.',
                            style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Practice flashcards or take quizzes to track topic mastery and accuracy!',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: stats.map((stat) => _buildTopicRow(context, stat)).toList(),
                    ),
            ),

            const SizedBox(height: AppSpacing.xl),

            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.amber),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Weak Areas & Focus Topics',
                  style: AppTypography.headline.copyWith(fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            ...((generalStats['weakTopics'] as List<String>?)?.isEmpty ?? true)
                ? [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.card,
                        border: AppBorders.allStandard,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, color: AppColors.emerald, size: 22),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'No weak areas identified! Outstanding mastery across topics.',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                : (generalStats['weakTopics'] as List<String>).map(
                    (topic) => Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.card,
                        border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Material(
                        color: AppColors.surface,
                        borderRadius: AppRadius.card,
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: const Icon(Icons.priority_high_rounded, color: AppColors.amber),
                          title: Text(topic, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            'Recommended for practice review',
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                          ),
                          trailing: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.amber.withValues(alpha: 0.15),
                              foregroundColor: AppColors.amber,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            icon: const Icon(Icons.auto_stories_rounded, size: 14),
                            label: const Text('Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () => context.push('/study/${Uri.encodeComponent(topic)}'),
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> stats) {
    final double accuracy = (stats['avgAccuracy'] as num?)?.toDouble() ?? 0.0;
    final int totalQuestions = stats['totalQuestions'] as int? ?? 0;
    final int streak = stats['streak'] as int? ?? 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Accuracy',
                style: AppTypography.caption.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded, size: 14, color: AppColors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '$streak day streak',
                      style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${(accuracy * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Across $totalQuestions practice questions answered',
            style: AppTypography.caption.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicRow(BuildContext context, TopicStat stat) {
    final percent = (stat.accuracy * 100).toInt();
    final Color barColor = percent >= 80
        ? AppColors.emerald
        : (percent >= 50 ? AppColors.primaryLight : AppColors.amber);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        border: AppBorders.allStandard,
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => context.push('/study/${Uri.encodeComponent(stat.topic)}'),
          title: Text(
            stat.topic,
            style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: stat.accuracy.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.surfaceSecondary,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$percent%',
              style: TextStyle(
                color: barColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
