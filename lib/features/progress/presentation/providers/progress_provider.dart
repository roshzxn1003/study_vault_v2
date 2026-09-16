import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  if (user == null) return [];

  // In real implementation, this queries the 'topic_progress' table
  // Mocking data to demonstrate the UI functionality
  return [
    TopicStat(topic: "ACID Properties", attempts: 12, correct: 11, incorrect: 1),
    TopicStat(topic: "Transactions", attempts: 8, correct: 7, incorrect: 1),
    TopicStat(topic: "Serializability", attempts: 10, correct: 4, incorrect: 6),
    TopicStat(topic: "Concurrency Control", attempts: 5, correct: 2, incorrect: 3),
  ];
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
