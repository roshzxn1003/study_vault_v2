import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/providers/ai_providers.dart';
import 'package:study_vault/core/ai/llm_service.dart';
import 'package:study_vault/features/ai/presentation/providers/chat_provider.dart';
import 'package:study_vault/features/ai/presentation/widgets/streaming_message.dart';
import 'package:study_vault/features/progress/presentation/providers/progress_provider.dart';
import 'package:study_vault/features/quiz/presentation/screens/quiz_player_screen.dart';
import 'package:study_vault/features/study/presentation/screens/study_topic_screen.dart';

class _FakeLlmService implements LlmService {
  @override
  Future<List<Map<String, dynamic>>> generateQuizQuestions({
    required String topic,
    String? context,
    int count = 5,
  }) async {
    return [
      {
        'question': 'What is a Semaphore?',
        'options': ['A synchronization variable', 'A sorting algorithm', 'A network socket'],
        'correct': 0,
        'explanation': 'A semaphore is an integer variable used for process synchronization.',
      },
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDbService localDb;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('study_vault_quiz_test_');
    localDb = LocalDbService.instance;
    localDb.setCustomPathForTesting('${tempDir.path}/test_quiz.db');

    final db = await localDb.database;
    await db.delete('ai_quizzes');
    await db.delete('flashcards');
    await db.delete('study_stats');
  });

  tearDown(() async {
    await localDb.closeForTesting();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('Adaptive AI Quiz & Topic Mastery Tests', () {
    test('LocalDbService persists and retrieves AI quizzes', () async {
      final questions = [
        {
          'question': 'What does ACID stand for in databases?',
          'options': [
            'Atomicity, Consistency, Isolation, Durability',
            'Accuracy, Control, Integration, Delivery',
          ],
          'correct': 0,
          'explanation': 'ACID properties guarantee valid database transactions.',
        },
      ];

      await localDb.saveAiQuiz(
        id: 'quiz_db_1',
        userId: 'student_42',
        title: 'Database Management Systems',
        questionsJson: jsonEncode(questions),
      );

      final results = await localDb.getAiQuizzes(topic: 'Database Management Systems');
      expect(results.length, equals(1));
      expect(results.first['id'], equals('quiz_db_1'));
      expect(results.first['title'], equals('Database Management Systems'));

      final decoded = jsonDecode(results.first['questions_data'] as String) as List;
      expect(decoded.length, equals(1));
      expect(decoded.first['question'], contains('ACID'));
    });

    testWidgets('QuizPlayerScreen renders questions, handles selection, and shows results', (tester) async {
      final sampleQuestions = [
        {
          'question': 'What is Virtual Memory?',
          'options': [
            'Memory management technique using secondary storage',
            'Physical RAM sticks only',
            'CPU internal registers',
          ],
          'correct': 0,
          'explanation': 'Virtual memory creates an illusion of a larger contiguous address space.',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            llmServiceProvider.overrideWithValue(_FakeLlmService()),
          ],
          child: MaterialApp(
            home: QuizPlayerScreen(
              topic: 'Operating Systems',
              initialQuestions: sampleQuestions,
              persistProgress: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify question and options
      expect(find.text('What is Virtual Memory?'), findsOneWidget);
      expect(find.text('Question 1 of 1'), findsOneWidget);
      expect(find.text('Memory management technique using secondary storage'), findsOneWidget);

      // Select correct option A
      await tester.tap(find.text('Memory management technique using secondary storage'));
      await tester.pumpAndSettle();

      // Check explanation & check icon visible
      expect(find.byIcon(Icons.check_circle), findsWidgets);
      expect(find.textContaining('creates an illusion'), findsOneWidget);

      // Tap See Final Results button
      expect(find.text('See Final Results'), findsOneWidget);
      await tester.tap(find.text('See Final Results'));
      await tester.pumpAndSettle();

      // Verify Results View
      expect(find.text('Quiz Results'), findsOneWidget);
      expect(find.text('Excellent Mastery!'), findsOneWidget);
      expect(find.textContaining('100%'), findsWidgets);
      expect(find.text('Retry Quiz'), findsOneWidget);
      expect(find.text('Finish'), findsOneWidget);
    });

    testWidgets('StreamingMessageWidget includes Practice Quiz and Quiz Me on Document actions', (tester) async {
      final source = AiSource(
        fileId: 'mat_os_1',
        fileName: 'OS_Textbook.pdf',
        pageNumber: 22,
        chunkId: 'chunk_22',
        similarity: 0.92,
        snippet: 'A page fault is an exception raised by the MMU when a process accesses a page not resident in RAM.',
      );

      final message = ChatMessage(
        id: 'msg_tutor_1',
        role: 'assistant',
        content: '### Virtual Memory Management\nPage faults occur when virtual pages are not mapped to physical memory.',
        sources: [source],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StreamingMessageWidget(message: message),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Practice Quiz icon in message action bar
      expect(find.byTooltip('Practice Quiz'), findsOneWidget);

      // Tap citation chip to open preview sheet
      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();

      // Verify both PDF deep-link and Quiz Me buttons exist in preview sheet
      expect(find.text('Open Page 22 in PDF Reader'), findsOneWidget);
      expect(find.text('Quiz Me on this Document'), findsOneWidget);
      expect(find.byIcon(Icons.quiz_outlined), findsWidgets);
    });

    testWidgets('StudyTopicScreen displays live real mastery stats from topicProgressProvider', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            topicProgressProvider.overrideWith(
              (ref) async => [
                TopicStat(
                  topic: 'Computer Networks',
                  attempts: 10,
                  correct: 8,
                  incorrect: 2,
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: StudyTopicScreen(topic: 'Computer Networks'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Real live score 80% should be displayed instead of hardcoded 65%
      expect(find.text('80% Mastery Score'), findsOneWidget);
      expect(find.text('Mastered'), findsOneWidget);
      expect(find.text('8/10 cards mastered'), findsOneWidget);
    });
  });
}
