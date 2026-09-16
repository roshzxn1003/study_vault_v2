import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../ai/presentation/providers/chat_provider.dart';

class AiTopicLauncherSheet extends ConsumerStatefulWidget {
  final String? initialTopic;
  const AiTopicLauncherSheet({super.key, this.initialTopic});

  static void show(BuildContext context, {String? initialTopic}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => AiTopicLauncherSheet(initialTopic: initialTopic),
    );
  }

  @override
  ConsumerState<AiTopicLauncherSheet> createState() => _AiTopicLauncherSheetState();
}

class _AiTopicLauncherSheetState extends ConsumerState<AiTopicLauncherSheet> {
  late TextEditingController _topicController;

  final List<String> _popularTopics = [
    'Binary Search Trees',
    'Normalization & 3NF',
    'Process Scheduling & Deadlocks',
    'TCP/IP 4-Layer Model',
    'Neural Networks & Backprop',
    'Calculus Chain Rule',
  ];

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.initialTopic ?? '');
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  void _launchAction(String type) {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic name')),
      );
      return;
    }

    Navigator.pop(context);

    switch (type) {
      case 'tutor':
        context.push('/study/learn/$topic');
        break;
      case 'quiz':
        context.push('/study/quiz/$topic');
        break;
      case 'flashcards':
        context.push('/study/flashcards/$topic');
        break;
      case 'summary':
        ref.read(chatProvider.notifier).setMode('summarize');
        ref.read(chatProvider.notifier).sendMessage('Provide a structured, high-yield exam cheat sheet for $topic.');
        context.push('/ai');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI Study Command Hub',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Topic Input Field
          TextField(
            controller: _topicController,
            autofocus: widget.initialTopic == null,
            decoration: InputDecoration(
              hintText: 'What topic are you studying today?',
              prefixIcon: const Icon(Icons.search, color: AppColors.primaryLight, size: 20),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onSubmitted: (_) => _launchAction('tutor'),
          ),
          const SizedBox(height: 12),

          // Quick Topic Chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _popularTopics.length,
              separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final t = _popularTopics[i];
                return ActionChip(
                  label: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  backgroundColor: AppColors.surfaceVariant,
                  side: const BorderSide(color: AppColors.cardBorder),
                  onPressed: () {
                    setState(() => _topicController.text = t);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Choose AI Study Action',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          // 2x2 Grid of Actions
          Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  icon: Icons.school_rounded,
                  color: AppColors.primary,
                  title: 'AI Tutor',
                  subtitle: 'Socratic step-by-step',
                  onTap: () => _launchAction('tutor'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.quiz_rounded,
                  color: AppColors.emerald,
                  title: 'Practice Quiz',
                  subtitle: '5-min MCQ test',
                  onTap: () => _launchAction('quiz'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  icon: Icons.style_rounded,
                  color: AppColors.amber,
                  title: 'Flashcards',
                  subtitle: 'Active recall deck',
                  onTap: () => _launchAction('flashcards'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.summarize_rounded,
                  color: AppColors.cyan,
                  title: 'Cheat Sheet',
                  subtitle: 'Exam review summary',
                  onTap: () => _launchAction('summary'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
