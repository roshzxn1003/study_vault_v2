import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:study_vault/core/database/local_db_service.dart';

class TopicStat {
  final String topic;
  final int attempts;
  final int correct;
  final int incorrect;
  double get accuracy => attempts == 0 ? 0.0 : correct / attempts;
  
  TopicStat({required this.topic, required this.attempts, required this.correct, required this.incorrect});
}

final topicProgressProvider = FutureProvider<List<TopicStat>>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  // 1. Check remote Supabase table if authenticated
  if (user != null) {
    try {
      final res = await supabase
          .from('topic_progress')
          .select()
          .eq('user_id', user.id);
      if (res.isNotEmpty) {
        return res.map((r) => TopicStat(
          topic: r['topic'] as String? ?? 'General',
          attempts: (r['attempts'] as num?)?.toInt() ?? 0,
          correct: (r['correct'] as num?)?.toInt() ?? 0,
          incorrect: (r['incorrect'] as num?)?.toInt() ?? 0,
        )).toList();
      }
    } catch (e) {
      debugPrint('Remote topic_progress query note: $e');
    }
  }

  // 2. Query local SQLite flashcards/study data
  try {
    final db = await LocalDbService.instance.database;
    final rows = await db.rawQuery('''
      SELECT topic, 
             COUNT(*) as total_cards, 
             SUM(CASE WHEN mastery_level >= 3 THEN 1 ELSE 0 END) as mastered 
      FROM flashcards 
      WHERE topic IS NOT NULL AND topic != ''
      GROUP BY topic
    ''');
    if (rows.isNotEmpty) {
      return rows.map((r) {
        final total = (r['total_cards'] as num?)?.toInt() ?? 0;
        final correct = (r['mastered'] as num?)?.toInt() ?? 0;
        return TopicStat(
          topic: r['topic'] as String? ?? 'General',
          attempts: total,
          correct: correct,
          incorrect: total - correct,
        );
      }).toList();
    }
  } catch (e) {
    debugPrint('Local flashcards topic query note: $e');
  }

  return [];
});

final studyStatsProvider = Provider((ref) {
  final progress = ref.watch(topicProgressProvider).value ?? [];
  int totalCorrect = 0;
  int totalAttempts = 0;
  
  for (var stat in progress) {
    totalCorrect += stat.correct;
    totalAttempts += stat.attempts;
  }

  return {
    'avgAccuracy': totalAttempts == 0 ? 0.0 : totalCorrect / totalAttempts,
    'totalQuestions': totalAttempts,
    'weakTopics': progress.where((s) => s.accuracy < 0.6).map((s) => s.topic).toList(),
  };
});
