import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/progress_provider.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(topicProgressProvider);
    final generalStats = ref.watch(studyStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Study Progress")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(generalStats),
            const SizedBox(height: 32),
            const Text("Topic Mastery", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text("Error: $err")),
              data: (stats) => Column(
                children: stats.map((stat) => _buildTopicRow(stat)).toList(),
              ),
            ),
            const SizedBox(height: 32),
            const Text("Weak Areas", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
            const SizedBox(height: 16),
            ...((generalStats['weakTopics'] as List<String>?)?.isEmpty ?? true)
              ? [const Text("No weak areas! Keep it up!")] 
              : (generalStats['weakTopics'] as List<String>).map((topic) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.warning, color: Colors.orange),
                    title: Text(topic),
                    trailing: IconButton(
                      icon: const Icon(Icons.book),
                      onPressed: () => context.push('/study/$topic'),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> stats) {
    return Card(
      color: Colors.blueAccent,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text("Overall Accuracy", style: TextStyle(color: Colors.white70, fontSize: 16)),
            Text(
              "${(stats['avgAccuracy'] * 100).toStringAsFixed(1)}%",
              style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
            ),
            Text("Out of ${stats['totalQuestions']} questions answered", style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicRow(TopicStat stat) {
    return Card(
      child: ListTile(
        title: Text(stat.topic),
        subtitle: LinearProgressIndicator(value: stat.accuracy, minHeight: 6),
        trailing: Text("${(stat.accuracy * 100).toStringAsFixed(0)}%"),
      ),
    );
  }
}
