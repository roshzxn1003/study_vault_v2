import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/ai/presentation/providers/chat_provider.dart';
import 'package:study_vault/features/ai/presentation/widgets/streaming_message.dart';
import 'package:study_vault/core/ai/llm_service.dart';
import 'package:study_vault/core/providers/ai_providers.dart';
import 'package:study_vault/features/files/file_view_screen.dart';
import 'package:study_vault/features/flashcards/presentation/screens/flashcard_screen.dart';

class _FakeLlmService implements LlmService {
  @override
  Future<List<Map<String, String>>> generateFlashcardDeck({
    required String topic,
    String? context,
    int count = 5,
  }) async {
    return [
      {'front': 'Q1', 'back': 'A1', 'topic': topic},
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
    tempDir = await Directory.systemTemp.createTemp('study_vault_loop_test_');
    localDb = LocalDbService.instance;
    localDb.setCustomPathForTesting('${tempDir.path}/test_loop.db');

    final db = await localDb.database;
    await db.delete('flashcards');
    await db.delete('study_stats');
  });

  tearDown(() async {
    await localDb.closeForTesting();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('Deep-Linked AI Citations & Study Loop Tests', () {
    test('Flashcard Database Persistence & Spaced Repetition Mastery', () async {
      final now = DateTime.now().toIso8601String();
      final cards = [
        {
          'id': 'card_1',
          'user_id': 'guest',
          'topic': 'Operating Systems',
          'front': 'What is Deadlock?',
          'back': 'A condition where processes are blocked waiting for resources held by each other.',
          'mastery_level': 0,
          'created_at': now,
          'last_reviewed': null,
        },
        {
          'id': 'card_2',
          'user_id': 'guest',
          'topic': 'Operating Systems',
          'front': 'What are the 4 Coffman conditions?',
          'back': 'Mutual exclusion, Hold and wait, No preemption, Circular wait.',
          'mastery_level': 0,
          'created_at': now,
          'last_reviewed': null,
        },
        {
          'id': 'card_3',
          'user_id': 'guest',
          'topic': 'Database Systems',
          'front': 'What is ACID?',
          'back': 'Atomicity, Consistency, Isolation, Durability.',
          'mastery_level': 0,
          'created_at': now,
          'last_reviewed': null,
        },
      ];

      await localDb.saveFlashcards(cards);

      // Verify all cards saved
      final allCards = await localDb.getFlashcards();
      expect(allCards.length, equals(3));

      // Verify topic filter
      final osCards = await localDb.getFlashcards(topic: 'Operating Systems');
      expect(osCards.length, equals(2));
      expect(osCards.first['topic'], equals('Operating Systems'));

      // Verify mastery update
      await localDb.updateFlashcardMastery('card_1', 1);
      final updatedCards = await localDb.getFlashcards(topic: 'Operating Systems');
      final card1 = updatedCards.firstWhere((c) => c['id'] == 'card_1');
      expect(card1['mastery_level'], equals(1));
      expect(card1['last_reviewed'], isNotNull);

      // Verify study activity recording
      await localDb.recordStudyAction('flashcard_review');
      final stats = await localDb.getVaultStats();
      expect(stats['dailyActions'], equals(1));
    });

    testWidgets('FileViewScreen renders AI citation banner and Ask AI action', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileDetailsProvider('file_os_2').overrideWith(
              (ref) async => {
                'id': 'file_os_2',
                'name': 'OS_Unit_2.txt',
                'file_type': 'TXT',
                'content': 'Operating Systems deadlock avoidance notes and Coffman conditions.',
              },
            ),
          ],
          child: const MaterialApp(
            home: FileViewScreen(
              id: 'file_os_2',
              initialPage: 14,
              highlightQuery: 'deadlock',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check document title
      expect(find.text('OS_Unit_2.txt'), findsOneWidget);

      // Check citation banner with page 14
      expect(find.text('Navigated to Page 14 from AI Citation'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsWidgets);

      // Check Ask AI action in AppBar
      expect(find.byTooltip('Ask AI about this page'), findsOneWidget);

      // Tap banner close icon and verify dismissal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Navigated to Page 14 from AI Citation'), findsNothing);
    });

    testWidgets('Citation modal sheet displays Open Page N in PDF Reader button', (tester) async {
      final source = AiSource(
        fileId: 'mat_os_14',
        fileName: 'Operating_Systems.pdf',
        pageNumber: 14,
        chunkId: 'chunk_os_14',
        similarity: 0.95,
        snippet: 'A set of processes is in deadlock if each process is waiting for an event that only another process can cause.',
      );

      final message = ChatMessage(
        id: 'msg_assistant_1',
        role: 'assistant',
        content: 'Deadlock occurs when processes wait mutually for held resources.',
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

      // Check citation chip is rendered
      expect(find.text('Grounded Sources (1)'), findsOneWidget);
      expect(find.byType(ActionChip), findsOneWidget);

      // Check action bar buttons
      expect(find.byTooltip('Create Flashcards'), findsOneWidget);
      expect(find.byTooltip('Save as Note'), findsOneWidget);

      // Tap citation chip to open detail bottom sheet
      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();

      // Verify bottom sheet title and confidence
      expect(find.text('Operating_Systems.pdf'), findsOneWidget);
      expect(find.textContaining('Page 14'), findsWidgets);
      expect(find.textContaining('Grounding Confidence: 95%'), findsOneWidget);
      expect(find.text(source.snippet!), findsOneWidget);

      // Verify prominent Open Page 14 in PDF Reader button
      expect(find.text('Open Page 14 in PDF Reader'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_rounded), findsWidgets);
    });

    testWidgets('Routing parameters: GoRouter /files/:id parses page and query', (tester) async {
      int? capturedPage;
      String? capturedQuery;
      String? capturedId;

      final testRouter = GoRouter(
        initialLocation: '/test',
        routes: [
          GoRoute(path: '/test', builder: (_, _) => const SizedBox()),
          GoRoute(
            path: '/files/:id',
            builder: (context, state) {
              capturedId = state.pathParameters['id'];
              final pageStr = state.uri.queryParameters['page'];
              capturedPage = pageStr != null ? int.tryParse(pageStr) : null;
              capturedQuery = state.uri.queryParameters['query'];
              return const SizedBox();
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: testRouter,
        ),
      );
      await tester.pumpAndSettle();

      testRouter.go('/files/doc_42?page=14&query=deadlock');
      await tester.pumpAndSettle();

      expect(capturedId, equals('doc_42'));
      expect(capturedPage, equals(14));
      expect(capturedQuery, equals('deadlock'));
    });

    testWidgets('FlashcardScreen displays card, flips on tap, and shows completion on mark', (tester) async {
      final initialCards = [
        {
          'id': 'card_os_1',
          'front': 'What is Thrashing?',
          'back': 'High paging activity where the system spends more time paging than executing.',
          'topic': 'Operating Systems',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            llmServiceProvider.overrideWithValue(_FakeLlmService()),
          ],
          child: MaterialApp(
            home: FlashcardScreen(
              topic: 'Operating Systems',
              initialCards: initialCards,
              persistProgress: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card front visible
      expect(find.text('What is Thrashing?'), findsOneWidget);
      expect(find.text('Card 1 of 1'), findsOneWidget);

      // Tap card to flip
      await tester.tap(find.text('What is Thrashing?'));
      await tester.pumpAndSettle();

      // Card back visible
      expect(find.textContaining('High paging activity'), findsOneWidget);

      // Tap I Knew It button
      await tester.tap(find.text('I Knew It!'));
      await tester.pumpAndSettle();

      // Completion screen shown
      expect(find.text('100% Mastered'), findsOneWidget);
    });
  });
}
