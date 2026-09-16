import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/theme/app_colors.dart';
import 'package:study_vault/core/providers/ai_providers.dart';

class QuizPlayerScreen extends ConsumerStatefulWidget {
  final String topic;
  const QuizPlayerScreen({super.key, required this.topic});

  @override
  ConsumerState<QuizPlayerScreen> createState() => _QuizPlayerScreenState();
}

class _QuizPlayerScreenState extends ConsumerState<QuizPlayerScreen> {
  int _currentQuestionIndex = 0;
  int? _selectedOption;
  bool _isAnswerSubmitted = false;
  final List<int> _userAnswers = [];
  bool _isFinished = false;
  bool _isLoading = true;

  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _fetchDynamicQuestions();
  }

  Future<void> _fetchDynamicQuestions() async {
    setState(() => _isLoading = true);
    try {
      final llm = ref.read(llmServiceProvider);
      final questions = await llm.generateQuizQuestions(topic: widget.topic);
      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  void _submitAnswer(int optionIndex) {
    if (_isAnswerSubmitted) return;
    setState(() {
      _selectedOption = optionIndex;
      _isAnswerSubmitted = true;
      _userAnswers.add(optionIndex);
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedOption = null;
        _isAnswerSubmitted = false;
      });
    } else {
      setState(() => _isFinished = true);
    }
  }

  void _restartQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _selectedOption = null;
      _isAnswerSubmitted = false;
      _userAnswers.clear();
      _isFinished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("Quiz • ${widget.topic}")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text("Generating Adaptive Quiz...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text("Google Gemini is crafting practice questions for ${widget.topic}", style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
      );
    }

    if (_isFinished) {
      return _buildResultsScreen();
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("Quiz • ${widget.topic}")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.quiz_outlined, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text("No questions generated", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchDynamicQuestions, child: const Text("Retry")),
            ],
          ),
        ),
      );
    }

    final q = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;
    final topicName = widget.topic.isEmpty ? 'General Knowledge' : widget.topic;
    final int correctIdx = (q['correct'] ?? q['correctIndex'] ?? 0) as int;

    return Scaffold(
      appBar: AppBar(
        title: Text("Quiz • $topicName"),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Bar & Question Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Question ${_currentQuestionIndex + 1} of ${_questions.length}",
                  style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  "${(progress * 100).toInt()}%",
                  style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.cardBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),

            // Question Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Text(
                q['question'] as String,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.4, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 20),

            // Options List
            Expanded(
              child: ListView.separated(
                itemCount: (q['options'] as List).length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final optionText = q['options'][index] as String;
                  final isSelected = _selectedOption == index;
                  final isCorrect = index == correctIdx;


                  Color borderColor = AppColors.cardBorder;
                  Color bgColor = AppColors.surfaceElevated;

                  if (_isAnswerSubmitted) {
                    if (isCorrect) {
                      borderColor = AppColors.emerald;
                      bgColor = AppColors.emerald.withValues(alpha: 0.15);
                    } else if (isSelected && !isCorrect) {
                      borderColor = AppColors.rose;
                      bgColor = AppColors.rose.withValues(alpha: 0.15);
                    }
                  } else if (isSelected) {
                    borderColor = AppColors.primary;
                    bgColor = AppColors.primary.withValues(alpha: 0.1);
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _isAnswerSubmitted ? null : () => _submitAnswer(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: borderColor.withValues(alpha: 0.2),
                            child: Text(
                              String.fromCharCode(65 + index),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: borderColor == AppColors.cardBorder ? AppColors.textPrimary : borderColor),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              optionText,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ),
                          if (_isAnswerSubmitted && isCorrect)
                            const Icon(Icons.check_circle, color: AppColors.emerald, size: 20),
                          if (_isAnswerSubmitted && isSelected && !isCorrect)
                            const Icon(Icons.cancel, color: AppColors.rose, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Explanation & Next Button
            if (_isAnswerSubmitted) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        q['explanation'] ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _nextQuestion,
                  child: Text(
                    _currentQuestionIndex == _questions.length - 1 ? "See Final Results" : "Next Question",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsScreen() {
    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      final corr = (_questions[i]['correct'] ?? _questions[i]['correctIndex'] ?? 0) as int;
      if (i < _userAnswers.length && _userAnswers[i] == corr) {
        score++;
      }
    }
    final percentage = _questions.isNotEmpty ? ((score / _questions.length) * 100).toInt() : 0;
    final topicName = widget.topic.isEmpty ? 'Knowledge' : widget.topic;

    return Scaffold(
      appBar: AppBar(title: const Text("Quiz Results")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: percentage >= 70
                        ? AppColors.emerald.withValues(alpha: 0.15)
                        : AppColors.amber.withValues(alpha: 0.15),
                    child: Icon(
                      percentage >= 70 ? Icons.emoji_events_rounded : Icons.psychology_rounded,
                      size: 44,
                      color: percentage >= 70 ? AppColors.emerald : AppColors.amber,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    percentage >= 70 ? "Excellent Mastery!" : "Good Practice Attempt!",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "You scored $score out of ${_questions.length} ($percentage%) on $topicName",
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Answer Review", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 12),

            ...List.generate(_questions.length, (i) {
              final q = _questions[i];
              final corr = (q['correct'] ?? q['correctIndex'] ?? 0) as int;
              final isCorrect = i < _userAnswers.length && _userAnswers[i] == corr;
              final opts = q['options'] as List;
              final correctOptText = corr < opts.length ? opts[corr] : '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isCorrect ? Icons.check_circle : Icons.cancel,
                            color: isCorrect ? AppColors.emerald : AppColors.rose,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              q['question'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Correct: $correctOptText",
                        style: const TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        q['explanation'] ?? '',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }),


            const SizedBox(height: 20),


            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _restartQuiz,
                    icon: const Icon(Icons.replay),
                    label: const Text("Retry Quiz"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () => context.go('/home'),
                    icon: const Icon(Icons.check),
                    label: const Text("Finish"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

