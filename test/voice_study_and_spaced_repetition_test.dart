import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/services/spaced_repetition_service.dart';
import 'package:study_vault/core/services/flashcard_export_service.dart';
import 'package:study_vault/features/ai/presentation/widgets/voice_study_orb.dart';
import 'package:study_vault/features/flashcards/presentation/screens/flashcard_screen.dart';
import 'package:study_vault/features/ai/ai_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SpacedRepetitionService (SM-2 Algorithm) Unit Tests', () {
    final baseDate = DateTime(2026, 10, 23, 12, 0);

    test('Hard rating resets streak to 0 and schedules next review in 1 day', () {
      final result = SpacedRepetitionService.calculateNextReview(
        rating: FlashcardRating.hard,
        currentRepetitions: 4,
        currentEaseFactor: 2.5,
        currentIntervalDays: 14,
        fromDate: baseDate,
      );

      expect(result.intervalDays, equals(1));
      expect(result.repetitions, equals(0));
      expect(result.masteryLevel, equals(0));
      expect(result.easeFactor, lessThan(2.5));
      expect(result.nextReviewDate, equals(baseDate.add(const Duration(days: 1))));
      expect(result.intervalLabel, equals('1d'));
    });

    test('Good rating progresses repetitions and applies ease factor scaling', () {
      // First review
      final rep1 = SpacedRepetitionService.calculateNextReview(
        rating: FlashcardRating.good,
        currentRepetitions: 0,
        fromDate: baseDate,
      );
      expect(rep1.repetitions, equals(1));
      expect(rep1.intervalDays, equals(1));
      expect(rep1.masteryLevel, equals(1));

      // Second review
      final rep2 = SpacedRepetitionService.calculateNextReview(
        rating: FlashcardRating.good,
        currentRepetitions: 1,
        fromDate: baseDate,
      );
      expect(rep2.repetitions, equals(2));
      expect(rep2.intervalDays, equals(3));

      // Third review with scaling
      final rep3 = SpacedRepetitionService.calculateNextReview(
        rating: FlashcardRating.good,
        currentRepetitions: 2,
        currentEaseFactor: 2.5,
        currentIntervalDays: 3,
        fromDate: baseDate,
      );
      expect(rep3.repetitions, equals(3));
      expect(rep3.intervalDays, equals((3 * 2.5).round())); // 8 days
    });

    test('Easy rating provides accelerated intervals and boosts ease factor', () {
      final rep1 = SpacedRepetitionService.calculateNextReview(
        rating: FlashcardRating.easy,
        currentRepetitions: 0,
        fromDate: baseDate,
      );
      expect(rep1.repetitions, equals(1));
      expect(rep1.intervalDays, equals(3));
      expect(rep1.masteryLevel, equals(2));
      expect(rep1.easeFactor, greaterThan(2.5));

      final rep2 = SpacedRepetitionService.calculateNextReview(
        rating: FlashcardRating.easy,
        currentRepetitions: 1,
        fromDate: baseDate,
      );
      expect(rep2.repetitions, equals(2));
      expect(rep2.intervalDays, equals(7));
      expect(rep2.intervalLabel, equals('7d'));
    });

    test('formatInterval handles day, week, and month scales correctly', () {
      expect(SpacedRepetitionService.formatInterval(0), equals('Today'));
      expect(SpacedRepetitionService.formatInterval(1), equals('1d'));
      expect(SpacedRepetitionService.formatInterval(5), equals('5d'));
      expect(SpacedRepetitionService.formatInterval(7), equals('7d'));
      expect(SpacedRepetitionService.formatInterval(14), equals('2w'));
      expect(SpacedRepetitionService.formatInterval(60), equals('2mo'));
    });
  });

  group('FlashcardExportService Unit Tests', () {
    final sampleCards = [
      {'front': 'What is CPU Cache?', 'back': 'High speed SRAM buffer near the processor core.'},
      {'front': 'Define Virtual Memory\nLine 2', 'back': 'Memory management capability that maps virtual addresses\nto physical addresses.'},
    ];

    test('toAnkiTsv exports tab-separated rows with HTML break tags and deck tag', () {
      final tsv = FlashcardExportService.toAnkiTsv(sampleCards, deckName: 'Computer Architecture');

      expect(tsv, contains('What is CPU Cache?\tHigh speed SRAM buffer near the processor core.\tComputer_Architecture'));
      // Newlines converted to <br> for Anki
      expect(tsv, contains('Define Virtual Memory<br>Line 2'));
      expect(tsv, contains('addresses<br>to physical'));
    });

    test('toQuizlet exports clean tab-separated terms and definitions', () {
      final quizlet = FlashcardExportService.toQuizlet(sampleCards);

      expect(quizlet, contains('What is CPU Cache?\tHigh speed SRAM buffer near the processor core.'));
      expect(quizlet.split('\n').where((l) => l.trim().isNotEmpty).length, equals(2));
    });

    test('toStudyGuideMarkdown formats clean markdown table and study listing', () {
      final md = FlashcardExportService.toStudyGuideMarkdown(sampleCards, topic: 'Operating Systems');

      expect(md, contains('# 📚 Study Guide & Flashcard Deck: Operating Systems'));
      expect(md, contains('| # | Question / Concept | Answer / Definition |'));
      expect(md, contains('| 1 | What is CPU Cache? | High speed SRAM buffer near the processor core. |'));
      expect(md, contains('#### Card 1'));
      expect(md, contains('**Q:** What is CPU Cache?'));
      expect(md, contains('**A:** High speed SRAM buffer near the processor core.'));
    });
  });

  group('VoiceStudyOrb Visualizer Widget Tests', () {
    testWidgets('Renders all four states with their respective labels and icons', (tester) async {
      // 1. Idle state
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VoiceStudyOrb(state: VoiceOrbState.idle),
          ),
        ),
      );
      expect(find.text('Ready to listen'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

      // 2. Listening state
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VoiceStudyOrb(state: VoiceOrbState.listening, soundLevel: 0.6),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Listening...'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // 3. Thinking state
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VoiceStudyOrb(state: VoiceOrbState.thinking),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Thinking...'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);

      // 4. Speaking state
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VoiceStudyOrb(state: VoiceOrbState.speaking),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Tutor Speaking'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('Triggers onTap callback when orb is pressed', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceStudyOrb(
              state: VoiceOrbState.speaking,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(VoiceStudyOrb));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tapped, isTrue);
    });
  });

  group('FlashcardScreen Spaced Repetition UI & Export Integration', () {
    testWidgets('Renders 3-tier spaced repetition buttons and triggers ratings', (tester) async {
      final testDeck = [
        {'front': 'What is Amdahl\'s Law?', 'back': 'Formula for theoretical speedup of latency with fixed workload.'},
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: FlashcardScreen(
              topic: 'Parallel Computing',
              initialCards: testDeck,
              persistProgress: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify card front & export button in AppBar
      expect(find.text('What is Amdahl\'s Law?'), findsOneWidget);
      expect(find.byKey(const ValueKey('export_flashcards_button')), findsOneWidget);

      // Verify 3 spaced repetition buttons
      expect(find.byKey(const ValueKey('flashcard_hard_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('flashcard_good_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('flashcard_easy_button')), findsOneWidget);

      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('1d'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('3d'), findsOneWidget);
      expect(find.text('I Knew It!'), findsOneWidget);
      expect(find.text('Easy (7d)'), findsOneWidget);

      // Tap card to flip
      await tester.tap(find.text('What is Amdahl\'s Law?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Formula for theoretical speedup'), findsOneWidget);

      // Tap Easy / I Knew It!
      await tester.tap(find.byKey(const ValueKey('flashcard_easy_button')));
      await tester.pumpAndSettle();

      // Completion screen shown
      expect(find.text('100% Mastered'), findsOneWidget);
    });

    testWidgets('Tapping Export Deck opens multi-format export sheet with Anki, Quizlet and Markdown tabs', (tester) async {
      final testDeck = [
        {'front': 'HTTP 200', 'back': 'OK'},
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: FlashcardScreen(
              topic: 'Web Protocols',
              initialCards: testDeck,
              persistProgress: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap export button
      await tester.tap(find.byKey(const ValueKey('export_flashcards_button')));
      await tester.pumpAndSettle();

      // Verify modal contents
      expect(find.text('Export Flashcard Deck'), findsOneWidget);
      expect(find.text('Anki (TSV)'), findsOneWidget);
      expect(find.text('Quizlet'), findsOneWidget);
      expect(find.text('Markdown / PDF'), findsOneWidget);
      expect(find.text('Copy to Clipboard'), findsOneWidget);
    });
  });

  group('AIScreen Voice Study Trigger Button Integration', () {
    testWidgets('AIScreen has prominent Headset button in AppBar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AIScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('voice_study_mode_button')), findsOneWidget);
    });
  });
}
