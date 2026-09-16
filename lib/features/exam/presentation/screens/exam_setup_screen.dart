import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/providers/exam_providers.dart';
import 'package:study_vault/features/exam/domain/entities/exam.dart';
import 'package:study_vault/core/theme/app_colors.dart';
import 'package:uuid/uuid.dart';

class ExamSetupScreen extends ConsumerStatefulWidget {
  const ExamSetupScreen({super.key});

  @override
  ConsumerState<ExamSetupScreen> createState() => _ExamSetupScreenState();
}

class _ExamSetupScreenState extends ConsumerState<ExamSetupScreen> {
  final _nameController = TextEditingController(text: 'DBMS Midterm Exam');
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  String _selectedDifficulty = 'Medium';
  String _selectedStudyTime = '1.5 hours';
  final List<String> _topics = ['ACID Properties', 'Transactions', 'Serializability', 'Concurrency Control', 'Recovery Systems'];
  final _topicInputCtrl = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _topicInputCtrl.dispose();
    super.dispose();
  }

  void _addTopic() {
    final t = _topicInputCtrl.text.trim();
    if (t.isNotEmpty && !_topics.contains(t)) {
      setState(() {
        _topics.add(t);
        _topicInputCtrl.clear();
      });
    }
  }

  Future<void> _createExam() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter an exam name")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id ?? 'guest';

      final exam = Exam(
        id: const Uuid().v4(),
        userId: userId,
        name: _nameController.text.trim(),
        examDate: _selectedDate,
        createdAt: DateTime.now(),
      );

      await ref.read(examRepositoryProvider).createExam(exam);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Exam schedule created! AI is generating your daily plan...")),
        );
        context.go('/exam/plan');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysUntil = _selectedDate.difference(DateTime.now()).inDays + 1;

    return Scaffold(
      appBar: AppBar(title: const Text("Exam Prep Setup")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.primaryLight, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'AI will craft a personalized daily milestone study plan based on your syllabus & target date.',
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text("Exam Subject", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: "e.g., Database Management Systems, OS",
                prefixIcon: Icon(Icons.edit_document),
              ),
            ),
            const SizedBox(height: 20),

            // Date Picker Card
            const Text("Exam Target Date", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1AF59E0B),
                  child: Icon(Icons.calendar_month, color: AppColors.amber),
                ),
                title: Text(
                  _selectedDate.toString().split(' ')[0],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Text('$daysUntil days remaining to prepare'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
              ),
            ),
            const SizedBox(height: 20),

            // Study Preferences
            const Text("Daily Study Time", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['45 min', '1 hour', '1.5 hours', '2+ hours'].map((t) {
                final isSel = _selectedStudyTime == t;
                return ChoiceChip(
                  selected: isSel,
                  label: Text(t),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceElevated,
                  onSelected: (_) => setState(() => _selectedStudyTime = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            const Text("Target Difficulty", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Easy', 'Medium', 'Hard', 'Mastery Level'].map((d) {
                final isSel = _selectedDifficulty == d;
                return ChoiceChip(
                  selected: isSel,
                  label: Text(d),
                  selectedColor: AppColors.secondary,
                  backgroundColor: AppColors.surfaceElevated,
                  onSelected: (_) => setState(() => _selectedDifficulty = d),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),


            // Syllabus Topics Tag Cloud
            const Text("Syllabus & Units to Cover", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _topicInputCtrl,
                    decoration: const InputDecoration(
                      hintText: "Add topic (e.g. Normalization)",
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (_) => _addTopic(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: _addTopic,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _topics.map((t) => Chip(
                label: Text(t, style: const TextStyle(fontSize: 12)),
                backgroundColor: AppColors.surfaceElevated,
                side: const BorderSide(color: AppColors.cardBorder),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => setState(() => _topics.remove(t)),
              )).toList(),
            ),
            const SizedBox(height: 36),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createExam,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                ),
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Generate AI Study Plan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

