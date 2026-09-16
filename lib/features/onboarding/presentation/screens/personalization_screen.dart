import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/features/onboarding/presentation/providers/onboarding_provider.dart';

class PersonalizationScreen extends ConsumerStatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  ConsumerState<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends ConsumerState<PersonalizationScreen> {
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _subjectsController = TextEditingController();
  String _selectedGoal = 'College exams';

  final List<String> _goals = const [
    'College exams',
    'Assignments & Projects',
    'Competitive exams',
    'Self-paced Learning',
  ];

  @override
  void dispose() {
    _courseController.dispose();
    _subjectsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personalize Your Vault')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What are you studying?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('This helps AI tailor explanations and generate accurate exam questions.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            TextField(
              controller: _courseController,
              decoration: const InputDecoration(
                labelText: 'Course / Degree',
                hintText: 'e.g., Computer Science, Engineering, Law',
                prefixIcon: Icon(Icons.school_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _subjectsController,
              decoration: const InputDecoration(
                labelText: 'Key Subjects',
                hintText: 'e.g., DBMS, Algorithms, OS',
                prefixIcon: Icon(Icons.book_outlined),
              ),
            ),
            const SizedBox(height: 32),
            const Text('Primary Study Goal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._goals.map((goal) {
              final isSelected = _selectedGoal == goal;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Card(
                  color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected 
                        ? Theme.of(context).colorScheme.primary 
                        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: ListTile(
                    title: Text(goal, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                    onTap: () => setState(() => _selectedGoal = goal),
                  ),
                ),
              );
            }),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(onboardingProvider.notifier).completeOnboarding(
                    course: _courseController.text.trim(),
                    subjects: _subjectsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                    studyGoal: _selectedGoal,
                  );
                  context.go('/home');
                },
                child: const Text('Finish Setup & Enter Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
