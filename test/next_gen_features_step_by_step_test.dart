import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/ai/embedding_service.dart';
import 'package:study_vault/core/ai/hybrid_retriever.dart';
import 'package:study_vault/core/ai/retriever.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/dashboard/presentation/widgets/daily_due_cards_section.dart';
import 'package:study_vault/features/files/file_view_screen.dart';
import 'package:study_vault/features/study/presentation/widgets/lecture_audio_recorder_modal.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingEmbeddingService implements EmbeddingService {
  @override
  int get dimension => 768;

  @override
  Future<List<double>> embed(AiEmbeddingInput input) async {
    throw Exception('Simulated Network Outage / Offline Mode');
  }

  @override
  Future<List<double>> generateEmbedding(
    String text, {
    AiEmbeddingTaskType taskType = AiEmbeddingTaskType.retrievalDocument,
  }) async {
    throw Exception('Simulated Network Outage');
  }

  @override
  Future<List<List<double>>> generateEmbeddings(
    List<String> texts, {
    AiEmbeddingTaskType taskType = AiEmbeddingTaskType.retrievalDocument,
  }) async {
    throw Exception('Simulated Network Outage');
  }

  @override
  double calculateCosineSimilarity(List<double> a, List<double> b) => 0.0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late LocalDbService localDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('study_vault_next_gen_');
    localDb = LocalDbService.instance;
    await localDb.closeForTesting();
    localDb.setCustomPathForTesting('${tempDir.path}/test_next_gen.db');

    final db = await localDb.database;
    await db.delete('flashcards');
    await db.delete('materials');
    await db.delete('document_chunks');
  });

  tearDown(() async {
    await localDb.closeForTesting();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Step 3: Offline BM25 Search Fallback Unit Tests', () {
    test('HybridRetriever gracefully falls back to BM25 keyword matching when embeddings fail', () async {
      final db = await localDb.database;
      final now = DateTime.now().toIso8601String();

      // Seed Material & Chunks for User Guest
      await db.insert('materials', {
        'id': 'mat_mesi_os',
        'user_id': 'guest',
        'workspace_id': 'ws_main',
        'subject_id': 'subj_os',
        'title': 'Cache Coherence Protocols',
        'original_file_name': 'cache_mesi.pdf',
        'type': 'DOCUMENT',
        'indexing_status': 'INDEXED',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('document_chunks', {
        'id': 'chunk_mesi_1',
        'material_id': 'mat_mesi_os',
        'user_id': 'guest',
        'page_number': 1,
        'chunk_index': 0,
        'text': 'The MESI protocol defines four states: Modified, Exclusive, Shared, and Invalid.',
        'embedding': '[]', // Offline / failed embedding
        'created_at': now,
        'updated_at': now,
      });

      final retriever = HybridRetriever(
        embeddingService: _FailingEmbeddingService(),
        localDb: localDb,
      );

      final results = await retriever.retrieve(const RetrievalQuery(
        queryText: 'What is the MESI protocol?',
        userId: 'guest',
        topK: 5,
        minSimilarity: 0.1,
      ));

      expect(results.isNotEmpty, isTrue);
      expect(results.first.text, contains('MESI protocol defines four states'));
      expect(results.first.matchType, equals('bm25_offline'));
    });
  });

  group('Step 1: DailyDueCardsSection Widget Tests', () {
    testWidgets('Displays due flashcards count and Start Drill button when cards are due', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyDueCardsSection(
              dueCardsFuture: Future.value([
                {
                  'id': 'card_due_01',
                  'topic': 'Operating Systems',
                  'front': 'What is Thrashing?',
                  'back': 'Excessive paging causing degraded system performance.',
                  'mastery_level': 0,
                }
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('daily_due_cards_section')), findsOneWidget);
      expect(find.text('Daily Spaced Drill'), findsOneWidget);
      expect(find.text('1 Due'), findsOneWidget);
      expect(find.byKey(const ValueKey('start_daily_drill_button')), findsOneWidget);
    });

    testWidgets('Renders up-to-date state when no cards are due', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyDueCardsSection(
              dueCardsFuture: Future.value([]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('daily_due_cards_section_completed')), findsOneWidget);
      expect(find.text('Active Recall Up to Date'), findsOneWidget);
    });
  });

  group('Step 2: FileViewScreen Contextual AI Integration Tests', () {
    testWidgets('FileViewScreen renders header, contextual AI fab, and document details', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileDetailsProvider('test_link_doc').overrideWith((ref) => Future.value({
              'id': 'test_link_doc',
              'name': 'Deep Learning Notes',
              'file_type': 'LINK',
              'remote_url': 'https://example.com/deep-learning',
            })),
          ],
          child: const MaterialApp(
            home: FileViewScreen(id: 'test_link_doc'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Deep Learning Notes'), findsWidgets);
      expect(find.byTooltip('Ask AI about this page'), findsOneWidget);
    });
  });

  group('Step 4: LectureAudioRecorderModal Widget Tests', () {
    testWidgets('Renders recorder modal with timer, record button, and transcript box', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LectureAudioRecorderModal(
                subjectName: 'Computer Architecture',
                autoInitSpeech: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lecture Audio Recorder'), findsOneWidget);
      expect(find.text('Subject: Computer Architecture'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.byKey(const ValueKey('toggle_lecture_record_fab')), findsOneWidget);
      expect(find.text('Live Speech Transcript'), findsOneWidget);
    });
  });
}
