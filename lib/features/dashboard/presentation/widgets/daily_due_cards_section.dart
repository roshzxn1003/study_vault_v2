import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: AppBorders.allStandard,
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySubtle,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryLight.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: AppColors.primaryLight,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Daily Spaced Drill',
                      style: AppTypography.title.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.destructiveSubtle,
                        borderRadius: AppRadius.chip,
                        border: Border.all(
                          color: AppColors.destructiveLight.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '$_dueCount Due',
                        style: AppTypography.caption.tabular.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.destructiveLight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Reinforce active recall for $_dominantTopic before memory decays.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton.icon(
            key: const ValueKey('start_daily_drill_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
              elevation: 0,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/study/flashcards/${Uri.encodeComponent(_dominantTopic)}');
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(
              'Drill',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
