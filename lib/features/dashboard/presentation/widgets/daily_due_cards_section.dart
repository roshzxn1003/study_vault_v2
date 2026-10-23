import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';

/// Spaced Repetition Daily Active Recall card displayed prominently on the Dashboard.
///
/// Surfaces flashcards due for review under the SuperMemo SM-2 algorithm.
class DailyDueCardsSection extends StatefulWidget {
  final Future<List<Map<String, dynamic>>>? dueCardsFuture;

  const DailyDueCardsSection({
    super.key,
    this.dueCardsFuture,
  });

  @override
  State<DailyDueCardsSection> createState() => _DailyDueCardsSectionState();
}

class _DailyDueCardsSectionState extends State<DailyDueCardsSection> {
  int _dueCount = 0;
  String _dominantTopic = 'Core Concepts';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDueCards();
  }

  Future<void> _loadDueCards() async {
    try {
      final dueCards = widget.dueCardsFuture != null
          ? await widget.dueCardsFuture!
          : await LocalDbService.instance.getDueFlashcards();
      if (mounted) {
        setState(() {
          _dueCount = dueCards.length;
          if (dueCards.isNotEmpty) {
            _dominantTopic = dueCards.first['topic']?.toString() ?? 'Core Concepts';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_dueCount == 0) {
      return Container(
        key: const ValueKey('daily_due_cards_section_completed'),
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Recall Up to Date',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'You have completed all scheduled flashcards for today.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('daily_due_cards_section'),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1E2E), const Color(0xFF2D1B4E)]
              : [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.35 : 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.20 : 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Color(0xFF8B5CF6),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Daily Spaced Drill',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_dueCount Due',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Reinforce active recall for $_dominantTopic before memory decays.',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            key: const ValueKey('start_daily_drill_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              context.push('/study/flashcards/${Uri.encodeComponent(_dominantTopic)}');
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Drill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
