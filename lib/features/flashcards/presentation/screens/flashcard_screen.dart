import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/theme/app_colors.dart';
import 'package:study_vault/core/providers/ai_providers.dart';

class FlashcardScreen extends ConsumerStatefulWidget {
  final String topic;
  const FlashcardScreen({super.key, required this.topic});

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  bool _isFlipped = false;
  int _currentIndex = 0;
  int _masteredCount = 0;
  int _reviewCount = 0;
  bool _isCompleted = false;
  bool _isLoading = true;

  List<Map<String, String>> _cards = [];

  @override
  void initState() {
    super.initState();
    _fetchDynamicFlashcards();
  }

  Future<void> _fetchDynamicFlashcards() async {
    setState(() => _isLoading = true);
    try {
      final llm = ref.read(llmServiceProvider);
      final cards = await llm.generateFlashcardDeck(topic: widget.topic);
      if (mounted) {
        setState(() {
          _cards = cards;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _markCard(bool mastered) {
    if (mastered) {
      _masteredCount++;
    } else {
      _reviewCount++;
    }

    if (_currentIndex < _cards.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    } else {
      setState(() => _isCompleted = true);
    }
  }

  void _restartDeck() {
    setState(() {
      _currentIndex = 0;
      _masteredCount = 0;
      _reviewCount = 0;
      _isFlipped = false;
      _isCompleted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topicName = widget.topic.isEmpty || widget.topic == 'general' ? 'Core Concepts' : widget.topic;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("Flashcards • $topicName")),
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
                child: const Icon(Icons.style_outlined, size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text("Generating Flashcard Deck...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text("Google Gemini is distilling high-yield flashcards for '$topicName'", style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
      );
    }

    if (_isCompleted) {
      final scorePercent = _cards.isNotEmpty ? ((_masteredCount / _cards.length) * 100).toInt() : 0;

      return Scaffold(
        appBar: AppBar(title: const Text("Flashcard Results")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events_rounded, size: 64, color: AppColors.emerald),
                ),
                const SizedBox(height: 24),
                Text(
                  "$scorePercent% Mastered",
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  "You mastered $_masteredCount of ${_cards.length} flashcards for '$topicName'.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: _restartDeck,
                        icon: const Icon(Icons.replay),
                        label: const Text("Study Again"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () => context.push('/study/quiz/$topicName'),
                        icon: const Icon(Icons.quiz),
                        label: const Text("Take Quiz"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text("Return to Dashboard"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("Flashcards • $topicName")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.style_outlined, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text("No flashcards found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchDynamicFlashcards, child: const Text("Retry")),
            ],
          ),
        ),
      );
    }

    final card = _cards[_currentIndex];
    final progress = (_currentIndex + 1) / _cards.length;

    return Scaffold(
      appBar: AppBar(
        title: Text("Flashcards • $topicName"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Restart Deck',
            onPressed: _restartDeck,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        child: Column(
          children: [
            // Progress Bar & Counts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Card ${_currentIndex + 1} of ${_cards.length}",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: AppColors.emerald),
                    const SizedBox(width: 4),
                    Text("$_masteredCount", style: const TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    const Icon(Icons.cancel, size: 16, color: AppColors.rose),
                    const SizedBox(width: 4),
                    Text("$_reviewCount", style: const TextStyle(color: AppColors.rose, fontWeight: FontWeight.bold)),
                  ],
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

            // Flashcard Interactive Box
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isFlipped = !_isFlipped),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isFlipped
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _isFlipped ? AppColors.cyan.withValues(alpha: 0.4) : Colors.white24,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isFlipped ? Colors.black45 : const Color(0xFF6366F1).withValues(alpha: 0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _isFlipped ? 'ANSWER / DEFINITION' : 'QUESTION / TERM',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ),
                          const Icon(Icons.touch_app, color: Colors.white60, size: 20),
                        ],
                      ),
                      Center(
                        child: Text(
                          _isFlipped ? (card['back'] ?? '') : (card['front'] ?? ''),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: _isFlipped ? 17 : 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                      ),
                      Text(
                        _isFlipped ? 'Tap to see question' : 'Tap to reveal answer',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rose,
                      side: const BorderSide(color: AppColors.rose),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _markCard(false),
                    icon: const Icon(Icons.close),
                    label: const Text("Need Review", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _markCard(true),
                    icon: const Icon(Icons.check),
                    label: const Text("I Knew It!", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
