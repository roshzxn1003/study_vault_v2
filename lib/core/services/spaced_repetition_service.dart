/// Rating tiers given by the student when reviewing a flashcard.
enum FlashcardRating {
  hard, // Grade: 1. Difficult or failed recall. Resets streak, 1-day interval.
  good, // Grade: 3. Successful recall with moderate thought. ~3-day interval.
  easy, // Grade: 5. Immediate, effortless recall. ~7-day interval + ease boost.
}

/// Computed interval and scheduling metadata from the SuperMemo SM-2 algorithm.
class SpacedRepetitionResult {
  final int intervalDays;
  final int repetitions;
  final double easeFactor;
  final DateTime nextReviewDate;
  final int masteryLevel; // 0: Learning / Hard, 1: Progressing / Good, 2: Mastered / Easy
  final String intervalLabel;

  const SpacedRepetitionResult({
    required this.intervalDays,
    required this.repetitions,
    required this.easeFactor,
    required this.nextReviewDate,
    required this.masteryLevel,
    required this.intervalLabel,
  });
}

/// SuperMemo SM-2 Spaced Repetition Scheduling Engine
///
/// Implements active recall intervals:
/// - Hard: interval resets to 1 day, repetitions reset, EF reduced.
/// - Good: interval scales by EF (1 -> 3 -> 6 -> interval * EF).
/// - Easy: interval scales faster (1 -> 7 -> interval * EF * 1.3), EF boosted.
class SpacedRepetitionService {
  static const double initialEaseFactor = 2.5;
  static const double minEaseFactor = 1.3;

  /// Calculates the next review date and updated SM-2 parameters.
  static SpacedRepetitionResult calculateNextReview({
    required FlashcardRating rating,
    int currentRepetitions = 0,
    double currentEaseFactor = initialEaseFactor,
    int currentIntervalDays = 0,
    DateTime? fromDate,
  }) {
    final baseDate = fromDate ?? DateTime.now();

    int newReps = currentRepetitions;
    double newEf = currentEaseFactor;
    int intervalDays = 1;
    int masteryLevel = 0;

    switch (rating) {
      case FlashcardRating.hard:
        // Reset repetition streak on failure / high difficulty
        newReps = 0;
        intervalDays = 1;
        newEf = (currentEaseFactor - 0.20).clamp(minEaseFactor, 3.0);
        masteryLevel = 0;
        break;

      case FlashcardRating.good:
        newReps = currentRepetitions + 1;
        if (newReps <= 1) {
          intervalDays = 1;
        } else if (newReps == 2) {
          intervalDays = 3;
        } else {
          final prev = currentIntervalDays > 0 ? currentIntervalDays : 3;
          intervalDays = (prev * currentEaseFactor).round();
        }
        // Quality grade 3 slightly adjusts EF
        newEf = (currentEaseFactor + (0.1 - (5 - 3) * (0.08 + (5 - 3) * 0.02))).clamp(minEaseFactor, 3.0);
        masteryLevel = 1;
        break;

      case FlashcardRating.easy:
        newReps = currentRepetitions + 1;
        if (newReps <= 1) {
          intervalDays = 3;
        } else if (newReps == 2) {
          intervalDays = 7;
        } else {
          final prev = currentIntervalDays > 0 ? currentIntervalDays : 7;
          intervalDays = (prev * currentEaseFactor * 1.25).round();
        }
        // Quality grade 5 boosts EF
        newEf = (currentEaseFactor + 0.15).clamp(minEaseFactor, 3.2);
        masteryLevel = 2;
        break;
    }

    final nextReviewDate = baseDate.add(Duration(days: intervalDays));
    final label = formatInterval(intervalDays);

    return SpacedRepetitionResult(
      intervalDays: intervalDays,
      repetitions: newReps,
      easeFactor: newEf,
      nextReviewDate: nextReviewDate,
      masteryLevel: masteryLevel,
      intervalLabel: label,
    );
  }

  /// Formats days into human-friendly interval badges (e.g., '1d', '3d', '7d', '2w', '1mo').
  static String formatInterval(int days) {
    if (days <= 0) return 'Today';
    if (days == 1) return '1d';
    if (days <= 7) return '${days}d';
    if (days < 30) return '${(days / 7).round()}w';
    return '${(days / 30).round()}mo';
  }
}
