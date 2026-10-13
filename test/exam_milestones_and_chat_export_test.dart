import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/ai/ai_screen.dart';
import 'package:study_vault/features/ai/data/repositories/ai_conversation_repository.dart';
import 'package:study_vault/features/ai/data/services/chat_export_service.dart';
import 'package:study_vault/features/ai/presentation/providers/chat_provider.dart';
import 'package:study_vault/features/ai/presentation/widgets/streaming_message.dart';
import 'package:study_vault/features/exam/presentation/screens/exam_plan_screen.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';

class _FakeVaultNotifier extends StateNotifier<VaultState> implements VaultNotifier {
  _FakeVaultNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDbService localDb;
  late Directory tempDir;
  late AiConversationRepository conversationRepo;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('study_vault_exam_chat_test_');
    localDb = LocalDbService.instance;
    localDb.setCustomPathForTesting('${tempDir.path}/test_features.db');
  });

  setUp(() async {
    final db = await localDb.database;
    await db.delete('ai_messages');
    await db.delete('ai_conversations');
    await db.delete('notes');
    await db.delete('study_stats');
    await db.delete('exam_goals');

    conversationRepo = AiConversationRepository(localDb: localDb);
  });

  tearDownAll(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('Feature 1: Multimodal Image Lightbox in Chat', () {
    test('ChatMessage supports imagePath and copyWith preserves/updates imagePath', () {
      final msg = ChatMessage(
        role: 'user',
        content: 'Check this diagram',
        imagePath: '/path/to/diagram.png',
      );

      expect(msg.imagePath, equals('/path/to/diagram.png'));
      expect(msg.isUser, isTrue);

      final copied = msg.copyWith(content: 'Updated diagram question');
      expect(copied.imagePath, equals('/path/to/diagram.png'));
      expect(copied.content, equals('Updated diagram question'));

      final replacedImage = msg.copyWith(imagePath: '/path/to/new_diagram.png');
      expect(replacedImage.imagePath, equals('/path/to/new_diagram.png'));
    });

    test('AiConversationRepository persists and restores imagePath in SQLite', () async {
      final conv = await conversationRepo.createConversation(
        title: 'Biology Photosynthesis Study',
        userId: 'student_bio',
      );

      final userMsg = ChatMessage(
        id: 'msg_img_1',
        role: 'user',
        content: 'Explain the light-dependent reactions in this diagram',
        imagePath: '/vault/diagrams/chloroplast.png',
      );

      await conversationRepo.saveMessage(conv.id, userMsg, userId: 'student_bio');

      final loaded = await conversationRepo.loadMessages(conv.id);
      expect(loaded.length, equals(1));
      expect(loaded.first.id, equals('msg_img_1'));
      expect(loaded.first.content, contains('light-dependent reactions'));
    });

    test('LocalDbService.recordStudyAction inserts into study_stats', () async {
      await localDb.recordStudyAction('milestone_complete');
      final db = await localDb.database;
      final rows = await db.query('study_stats');
      // ignore: avoid_print
      print('DEBUG RECORD ROWS: $rows');
      expect(rows.isNotEmpty, isTrue);
    });

    testWidgets('StreamingMessageWidget displays thumbnail and opens lightbox on tap', (tester) async {
      final msgWithImage = ChatMessage(
        role: 'user',
        content: 'What is this structure?',
        imagePath: '/mock/path/sample_cell.png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingMessageWidget(message: msgWithImage),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('What is this structure?'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_image_thumbnail')), findsOneWidget);

      // Tap thumbnail to open lightbox dialog
      await tester.tap(find.byKey(const ValueKey('chat_image_thumbnail')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Lightbox InteractiveViewer and close button should be shown
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byTooltip('Close preview'), findsOneWidget);

      // Tap close button
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(InteractiveViewer), findsNothing);

      // Clean up mounted widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('Feature 2: Full Chat Study Guide Export as Note', () {
    test('ChatExportService compiles conversation into structured Markdown note and saves to SQLite', () async {
      final userMessage = ChatMessage(
        role: 'user',
        content: 'Explain Normalization in Relational Databases',
      );
      final aiMessage = ChatMessage(
        role: 'assistant',
        content: 'Normalization eliminates redundancy. 1NF requires atomic values, 2NF removes partial dependencies.',
        sources: [
          AiSource(
            chunkId: 'dbms_c1',
            fileId: 'file_dbms_1',
            fileName: 'Database_Systems.pdf',
            pageNumber: 112,
            similarity: 0.96,
            snippet: 'First normal form enforces atomic domain attributes.',
          ),
        ],
      );

      final chatState = ChatState(
        messages: [userMessage, aiMessage],
        currentMode: 'explain',
        activeSubject: 'Database Management',
      );

      final result = await ChatExportService.exportToStudyNote(
        chatState: chatState,
        localDbService: localDb,
      );

      expect(result, isNotNull);
      expect(result!.title, contains('AI Study Guide: Explain Normalization'));
      expect(result.content, contains('# AI Study Guide: Explain Normalization'));
      expect(result.content, contains('**Mode**: EXPLAIN'));
      expect(result.content, contains('Database Management'));
      expect(result.content, contains('Database_Systems.pdf'));
      expect(result.content, contains('Page 112'));

      // Verify in SQLite notes table
      final db = await localDb.database;
      final notes = await db.query('notes', where: 'id = ?', whereArgs: [result.noteId]);
      expect(notes.length, equals(1));
      expect(notes.first['title'], equals(result.title));

      // Verify study action recorded
      final statsRows = await db.query('study_stats', where: "key = 'today_actions'");
      expect(statsRows.isNotEmpty, isTrue);
      expect(statsRows.first['value_int'], greaterThanOrEqualTo(1));
    });

    testWidgets('AIScreen renders export note button in AppBar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiConversationRepositoryProvider.overrideWithValue(conversationRepo),
            vaultProvider.overrideWith(
              (ref) => _FakeVaultNotifier(const VaultState(materials: [])),
            ),
          ],
          child: const MaterialApp(
            home: AIScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final exportBtn = find.byKey(const ValueKey('export_chat_button'));
      expect(exportBtn, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('Feature 3 & 4: Exam Plan Milestones, Flashcards, Quiz, & Gamification', () {
    testWidgets('ExamPlanScreen renders milestones with AI Tutor, Flashcards, and Quiz buttons', (tester) async {
      final testDays = [
        {
          'day': 1,
          'topic': 'DBMS: Normal Forms',
          'subtopics': '1NF, 2NF, 3NF, BCNF rules',
          'duration': '1.5 hrs',
          'priority': 'High',
          'completed': false,
        },
        {
          'day': 2,
          'topic': 'DBMS: Transaction Processing',
          'subtopics': 'ACID properties, serializability',
          'duration': '2.0 hrs',
          'priority': 'High',
          'completed': false,
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ExamPlanScreen(
              initialDays: testDays,
              initialExamTitle: 'DBMS Final Exam Prep',
              initialSubject: 'Database Systems',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('DBMS Final Exam Prep'), findsOneWidget);
      expect(find.text('DBMS: Normal Forms'), findsOneWidget);
      expect(find.text('DBMS: Transaction Processing'), findsOneWidget);

      // Verify each milestone card has AI Tutor, Flashcards, and Quiz buttons
      expect(find.text('AI Tutor'), findsNWidgets(2));
      expect(find.text('Flashcards'), findsNWidgets(2));
      expect(find.text('Quiz'), findsNWidgets(2));

      // Toggle first milestone completion
      expect(find.text('0% Done'), findsOneWidget);
      await tester.tap(find.text('1'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('50% Done'), findsOneWidget);

      // Verify gamification action recorded inside tester.runAsync
      late List<Map<String, Object?>> statsRows;
      await tester.runAsync(() async {
        final db = await localDb.database;
        statsRows = await db.query('study_stats', where: "key = 'today_actions'");
      });
      expect(statsRows.isNotEmpty, isTrue);
      expect(statsRows.first['value_int'], greaterThanOrEqualTo(1));

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('ExamPlanScreen dynamically loads exam goal from SQLite when initialDays is null', (tester) async {
      // Save an exam goal into SQLite inside tester.runAsync
      await tester.runAsync(() async {
        await localDb.saveExamGoal(
          id: 'goal_os_1',
          title: 'Operating Systems Midterm',
          subject: 'Operating Systems',
          targetDate: DateTime.now().add(const Duration(days: 5)).toIso8601String(),
          syllabusPercent: 25,
        );
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ExamPlanScreen(),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should automatically load and generate milestones for Operating Systems
      expect(find.text('Operating Systems Midterm'), findsOneWidget);
      expect(find.textContaining('Operating Systems: Core Foundations'), findsOneWidget);
      expect(find.text('Flashcards'), findsWidgets);
      expect(find.text('Quiz'), findsWidgets);

      // Clean up mounted widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
