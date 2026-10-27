import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/theme/app_colors.dart';
import 'package:study_vault/core/providers/ai_providers.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/services/spaced_repetition_service.dart';
import 'package:study_vault/core/services/flashcard_export_service.dart';

class FlashcardScreen extends ConsumerStatefulWidget {
  final String topic;
  final List<Map<String, String>>? initialCards;
  final bool persistProgress;

  const FlashcardScreen({
    super.key,
    required this.topic,
    this.initialCards,
    this.persistProgress = true,
  });

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
    if (widget.initialCards != null && widget.initialCards!.isNotEmpty) {
      _cards = List.from(widget.initialCards!);
      _isLoading = false;
    } else {
      _fetchDynamicFlashcards();
    }
  }

  Future<void> _fetchDynamicFlashcards() async {
    try {
      final localCards = await LocalDbService.instance.getFlashcards(topic: widget.topic);
      if (localCards.isNotEmpty) {
        if (mounted) {
          setState(() {
            _cards = localCards.map((c) => {
              'id': c['id']?.toString() ?? '',
              'front': c['front']?.toString() ?? '',
              'back': c['back']?.toString() ?? '',
              'topic': c['topic']?.toString() ?? widget.topic,
            }).toList();
            _isLoading = false;
          });
        }
        return;
      }

      final llm = ref.read(llmServiceProvider);
      final cards = await llm.generateFlashcardDeck(topic: widget.topic);
      if (cards.isNotEmpty) {
        final now = DateTime.now().toIso8601String();
        final user = Supabase.instance.client.auth.currentUser;
        final userId = user?.id ?? 'guest';
        final dbCards = cards.asMap().entries.map((entry) {
          final idx = entry.key;
          final c = entry.value;
          final cardId = 'card_${DateTime.now().millisecondsSinceEpoch}_$idx';
          return {
            'id': cardId,
            'user_id': userId,
            'topic': widget.topic,
            'front': c['front'] ?? '',
            'back': c['back'] ?? '',
            'mastery_level': 0,
            'created_at': now,
            'last_reviewed': null,
          };
        }).toList();
        await LocalDbService.instance.saveFlashcards(dbCards);
        if (mounted) {
          setState(() {
            _cards = dbCards.map((c) => {
              'id': c['id']?.toString() ?? '',
              'front': c['front']?.toString() ?? '',
              'back': c['back']?.toString() ?? '',
              'topic': c['topic']?.toString() ?? widget.topic,
            }).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _rateCard(FlashcardRating rating) {
    final result = SpacedRepetitionService.calculateNextReview(
      rating: rating,
      currentRepetitions: rating == FlashcardRating.hard ? 0 : 1,
    );

    if (widget.persistProgress) {
      if (_cards.isNotEmpty && _currentIndex < _cards.length) {
        final card = _cards[_currentIndex];
        final cardId = card['id'];
        if (cardId != null && cardId.isNotEmpty) {
          LocalDbService.instance.updateFlashcardMastery(cardId, result.masteryLevel);
        }
      }
      LocalDbService.instance.recordStudyAction('flashcard_review');
    }

    if (rating == FlashcardRating.hard) {
      _reviewCount++;
    } else {
      _masteredCount++;
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
                        onPressed: () => context.push('/study/quiz/${Uri.encodeComponent(topicName)}'),
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
            key: const ValueKey('export_flashcards_button'),
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export Deck (Anki / Quizlet / Markdown)',
            onPressed: () {
              FlashcardExportService.showExportDialog(
                context,
                topic: topicName,
                cards: _cards,
              );
            },
          ),
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
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
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

            // Spaced Repetition 3-Tier Action Buttons
            Row(
              children: [
                // Hard (1d)
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('flashcard_hard_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rose,
                      side: const BorderSide(color: AppColors.rose),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _rateCard(FlashcardRating.hard),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Hard", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(height: 2),
                        Text("1d", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Good (3d)
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('flashcard_good_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.amber,
                      side: const BorderSide(color: AppColors.amber),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _rateCard(FlashcardRating.good),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Good", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(height: 2),
                        Text("3d", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Easy / I Knew It! (7d)
                Expanded(
                  child: ElevatedButton(
                    key: const ValueKey('flashcard_easy_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _rateCard(FlashcardRating.easy),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("I Knew It!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(height: 2),
                        Text("Easy (7d)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
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
