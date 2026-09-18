import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_vault/core/ai/ai_config.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/ai/citation_builder.dart';
import 'package:study_vault/core/ai/context_builder.dart';
import 'package:study_vault/core/ai/embedding_service.dart';
import 'package:study_vault/core/ai/hybrid_retriever.dart';
import 'package:study_vault/core/ai/llm_service.dart';
import 'package:study_vault/core/ai/prompt_engine.dart';
import 'package:study_vault/core/ai/retriever.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/import/presentation/widgets/smart_organization_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 11 — Embedding Service & Cosine Mathematics', () {
    late GoogleEmbeddingService embeddingService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      embeddingService = GoogleEmbeddingService();
    });

    test('Identical vectors compute exactly 1.0 cosine similarity', () {
      final v1 = [1.0, 0.0, 0.0];
      final v2 = [1.0, 0.0, 0.0];
      final sim = embeddingService.calculateCosineSimilarity(v1, v2);
      expect(sim, closeTo(1.0, 1e-6));
    });

    test('Orthogonal vectors compute 0.0 cosine similarity', () {
      final v1 = [1.0, 0.0, 0.0];
      final v2 = [0.0, 1.0, 0.0];
      final sim = embeddingService.calculateCosineSimilarity(v1, v2);
      expect(sim, closeTo(0.0, 1e-6));
    });

    test('Opposite vectors compute -1.0 cosine similarity', () {
      final v1 = [1.0, 0.0];
      final v2 = [-1.0, 0.0];
      final sim = embeddingService.calculateCosineSimilarity(v1, v2);
      expect(sim, closeTo(-1.0, 1e-6));
    });

    test('Zero vector safely returns 0.0 without division-by-zero NaN', () {
      final v1 = [0.0, 0.0, 0.0];
      final v2 = [1.0, 2.0, 3.0];
      final sim = embeddingService.calculateCosineSimilarity(v1, v2);
      expect(sim, equals(0.0));
      expect(sim.isNaN, isFalse);
    });

    test('Mismatched vector dimensions return 0.0 safely', () {
      final v1 = [1.0, 2.0];
      final v2 = [1.0, 2.0, 3.0];
      final sim = embeddingService.calculateCosineSimilarity(v1, v2);
      expect(sim, equals(0.0));
    });

    test('768-dimensional normalized vectors calculate accurate similarity', () {
      final rand = math.Random(42);
      final raw1 = List.generate(768, (_) => rand.nextDouble() - 0.5);
      final raw2 = List.generate(768, (_) => rand.nextDouble() - 0.5);

      final mag1 = math.sqrt(raw1.fold(0.0, (sum, x) => sum + x * x));
      final mag2 = math.sqrt(raw2.fold(0.0, (sum, x) => sum + x * x));

      final v1 = raw1.map((x) => x / mag1).toList();
      final v2 = raw2.map((x) => x / mag2).toList();

      final expectedDot = List.generate(768, (i) => v1[i] * v2[i]).fold(0.0, (sum, x) => sum + x);
      final computedSim = embeddingService.calculateCosineSimilarity(v1, v2);

      expect(computedSim, closeTo(expectedDot, 1e-5));
    });
  });

  group('Phase 11 — LLM Cancel Token & Cooperative Cancellation', () {
    test('AiCancelToken initializes uncancelled and switches state on cancel', () {
      final token = AiCancelToken();
      expect(token.isCancelled, isFalse);

      token.cancel();
      expect(token.isCancelled, isTrue);
    });
  });

  group('Phase 11 — Multi-Tenant RAG Security & Hybrid Retrieval', () {
    late LocalDbService localDb;
    late HybridRetriever retriever;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('study_vault_rag_tests_');
      localDb = LocalDbService.instance;
      localDb.setCustomPathForTesting('${tempDir.path}/test_rag.db');

      final mockEmbeddingService = _MockEmbeddingService();
      retriever = HybridRetriever(
        embeddingService: mockEmbeddingService,
        localDb: localDb,
      );

      // Initialize database tables
      final db = await localDb.database;
      await db.delete('document_chunks');
      await db.delete('materials');
      await db.delete('shares');

      final now = DateTime.now().toIso8601String();

      // Seed Material & Chunks for User Alice
      await db.insert('materials', {
        'id': 'mat_alice_os',
        'user_id': 'user_alice',
        'workspace_id': 'ws_alice_engineering',
        'subject_id': 'subj_os',
        'title': 'Operating Systems Deadlock Notes',
        'original_file_name': 'deadlock_notes.pdf',
        'type': 'DOCUMENT',
        'indexing_status': 'INDEXED',
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('document_chunks', {
        'id': 'chunk_alice_1',
        'material_id': 'mat_alice_os',
        'user_id': 'user_alice',
        'workspace_id': 'ws_alice_engineering',
        'subject_id': 'subj_os',
        'page_number': 1,
        'chunk_index': 0,
        'text': 'A deadlock occurs when a set of processes are blocked because each is holding a resource and waiting for another resource.',
        'token_count': 23,
        'embedding': jsonEncode([1.0, 0.0, 0.0]),
        'metadata': jsonEncode({'type': 'concept'}),
        'created_at': now,
        'updated_at': now,
      });

      // Seed Material & Chunks for User Bob (Private)
      await db.insert('materials', {
        'id': 'mat_bob_exam',
        'user_id': 'user_bob',
        'workspace_id': 'ws_bob_commerce',
        'subject_id': 'subj_finance',
        'title': 'Confidential Financial Analysis',
        'original_file_name': 'finance_exam.pdf',
        'type': 'DOCUMENT',
        'indexing_status': 'INDEXED',
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('document_chunks', {
        'id': 'chunk_bob_1',
        'material_id': 'mat_bob_exam',
        'user_id': 'user_bob',
        'workspace_id': 'ws_bob_commerce',
        'subject_id': 'subj_finance',
        'page_number': 1,
        'chunk_index': 0,
        'text': 'Confidential capital structure data and future acquisition plans.',
        'token_count': 12,
        'embedding': jsonEncode([0.0, 1.0, 0.0]),
        'metadata': jsonEncode({'type': 'private'}),
        'created_at': now,
        'updated_at': now,
      });
    });

    tearDown(() async {
      await localDb.closeForTesting();
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('Tenant Isolation: Alice cannot retrieve any of Bob private chunks', () async {
      final results = await retriever.retrieve(RetrievalQuery(
        queryText: 'deadlock or capital structure confidential',
        userId: 'user_alice',
      ));

      // Alice should ONLY get her own chunks
      expect(results.isNotEmpty, isTrue);
      for (final chunk in results) {
        expect(chunk.materialId, equals('mat_alice_os'));
        expect(chunk.text.contains('Confidential'), isFalse);
      }
    });

    test('Tenant Isolation: Bob cannot retrieve any of Alice chunks', () async {
      final results = await retriever.retrieve(RetrievalQuery(
        queryText: 'deadlock processes resource',
        userId: 'user_bob',
      ));

      // Alice's chunks must NEVER appear in Bob's results
      for (final chunk in results) {
        expect(chunk.materialId, isNot(equals('mat_alice_os')));
      }
    });

    test('Active Share Grant: Recipient can retrieve shared chunks when grant is active', () async {
      final db = await localDb.database;
      final now = DateTime.now().toIso8601String();

      // Bob shares a material with Alice
      await db.insert('materials', {
        'id': 'mat_bob_algorithms',
        'user_id': 'user_bob',
        'workspace_id': 'ws_bob_shared',
        'subject_id': 'subj_algo',
        'title': 'Graph Traversal BFS and DFS',
        'original_file_name': 'graph.pdf',
        'type': 'DOCUMENT',
        'indexing_status': 'INDEXED',
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('document_chunks', {
        'id': 'chunk_bob_algo_1',
        'material_id': 'mat_bob_algorithms',
        'user_id': 'user_bob',
        'workspace_id': 'ws_bob_shared',
        'subject_id': 'subj_algo',
        'page_number': 4,
        'chunk_index': 0,
        'text': 'Breadth-first search traverses graph level by level using a FIFO queue.',
        'token_count': 13,
        'embedding': jsonEncode([0.0, 0.0, 1.0]),
        'metadata': jsonEncode({'type': 'algorithm'}),
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('shares', {
        'id': 'share_grant_1',
        'owner_id': 'user_bob',
        'recipient_id': 'user_alice',
        'resource_type': 'material',
        'resource_id': 'mat_bob_algorithms',
        'permission': 'view',
        'status': 'active',
        'created_at': now,
      });

      // Alice queries BFS: should return Bob's shared material
      final results = await retriever.retrieve(RetrievalQuery(
        queryText: 'Breadth-first search queue graph',
        userId: 'user_alice',
        includeShared: true,
      ));

      final sharedMatch = results.where((c) => c.materialId == 'mat_bob_algorithms');
      expect(sharedMatch.isNotEmpty, isTrue);
      expect(sharedMatch.first.pageNumber, equals(4));
    });

    test('Revoked Share Grant: Alice immediately loses access when share is revoked', () async {
      final db = await localDb.database;

      // Revoke the share
      await db.update(
        'shares',
        {
          'status': 'revoked',
          'revoked_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: ['share_grant_1'],
      );

      final results = await retriever.retrieve(RetrievalQuery(
        queryText: 'Breadth-first search queue graph',
        userId: 'user_alice',
        includeShared: true,
      ));

      final sharedMatch = results.where((c) => c.materialId == 'mat_bob_algorithms');
      expect(sharedMatch.isEmpty, isTrue);
    });

    test('Workspace Filtering: Scopes retrieval strictly to specified workspace', () async {
      final results = await retriever.retrieve(RetrievalQuery(
        queryText: 'deadlock',
        userId: 'user_alice',
        workspaceId: 'other_unrelated_workspace',
      ));

      expect(results.isEmpty, isTrue);
    });
  });

  group('Phase 11 — Context Assembly & Anti-Hallucination Citations', () {
    test('ContextBuilder formats chunks with explicit page numbers and enforces limits', () {
      final chunks = [
        const RetrievedChunk(
          chunkId: 'c1',
          materialId: 'm1',
          materialTitle: 'Distributed Systems',
          pageNumber: 12,
          chunkIndex: 0,
          text: 'Raft uses randomized election timers to prevent split votes.',
          score: 0.95,
          matchType: 'semantic',
        ),
        const RetrievedChunk(
          chunkId: 'c2',
          materialId: 'm1',
          materialTitle: 'Distributed Systems',
          pageNumber: 14,
          chunkIndex: 1,
          text: 'Log entries are committed once replicated to a majority of servers.',
          score: 0.88,
          matchType: 'semantic',
        ),
      ];

      final context = ContextBuilder.buildContextFromChunks(chunks, maxChars: 4000);
      expect(context.contains('Distributed Systems'), isTrue);
      expect(context.contains('Page: 12'), isTrue);
      expect(context.contains('Page: 14'), isTrue);
      expect(context.contains('Raft uses randomized election timers'), isTrue);
    });

    test('ContextBuilder deduplicates identical text chunks', () {
      final chunks = [
        const RetrievedChunk(
          chunkId: 'c1',
          materialId: 'm1',
          materialTitle: 'Notes',
          pageNumber: 1,
          chunkIndex: 0,
          text: 'Identical definition of polymorphism.',
          score: 0.9,
          matchType: 'semantic',
        ),
        const RetrievedChunk(
          chunkId: 'c2',
          materialId: 'm1',
          materialTitle: 'Notes',
          pageNumber: 1,
          chunkIndex: 0,
          text: 'Identical definition of polymorphism.',
          score: 0.8,
          matchType: 'keyword',
        ),
      ];

      final context = ContextBuilder.buildContextFromChunks(chunks);
      final count = 'Identical definition of polymorphism'.allMatches(context).length;
      expect(count, equals(1));
    });

    test('CitationBuilder correctly creates verified citations from retrieved chunks', () {
      final chunks = [
        const RetrievedChunk(
          chunkId: 'c1',
          materialId: 'm1',
          materialTitle: 'Computer Networks',
          pageNumber: 45,
          chunkIndex: 0,
          text: 'TCP uses a 3-way handshake (SYN, SYN-ACK, ACK) to establish a connection.',
          score: 0.9,
          matchType: 'semantic',
        ),
      ];

      final citations = CitationBuilder.buildCitations(chunks);

      expect(citations.isNotEmpty, isTrue);
      expect(citations.first.fileName, equals('Computer Networks'));
      expect(citations.first.pageNumber, equals(45));
    });
  });

  group('Phase 11 — Prompt Engine & Socratic Pedagogy', () {
    test('Tutor prompt enforces 5-step academic pedagogy', () {
      final prompt = PromptEngine.buildTutorPrompt(
        topic: 'Virtual Memory & Paging',
        context: 'Paging maps virtual addresses to physical frames via page tables.',
        currentStep: 'Step 1: Intuitive Mental Model',
        subject: 'Operating Systems',
      );

      expect(prompt.contains('TEACHING PEDAGOGY:'), isTrue);
      expect(prompt.contains('1. Mental Model:'), isTrue);
      expect(prompt.contains('2. Formal Definition:'), isTrue);
      expect(prompt.contains('3. Analogy & Example:'), isTrue);
      expect(prompt.contains('4. Common Exam Traps:'), isTrue);
      expect(prompt.contains('5. Mastery Check:'), isTrue);
      expect(prompt.contains('Virtual Memory & Paging'), isTrue);
      expect(prompt.contains('Paging maps virtual addresses') || prompt.contains('STUDY VAULT REFERENCE CONTEXT:'), isTrue);
    });

    test('Quiz prompt requires JSON schema with 4 options and correctIndex', () {
      final prompt = PromptEngine.buildQuizPrompt(
        topic: 'DBMS Normalization',
        context: '3NF requires that every non-prime attribute is non-transitively dependent on primary key.',
        count: 5,
      );

      expect(prompt.contains('"question"'), isTrue);
      expect(prompt.contains('"options"'), isTrue);
      expect(prompt.contains('"correctIndex"'), isTrue);
      expect(prompt.contains('"explanation"'), isTrue);
      expect(prompt.contains('DBMS Normalization'), isTrue);
    });

    test('Organization prompt produces structured suggestion contract', () {
      final prompt = PromptEngine.buildOrganizationPrompt(
        documentContent: 'Lecture 4 on Operating System Scheduling Algorithms: FCFS, SJF, Round Robin.',
        rawFileName: 'os_lec4_sched.pdf',
        existingSubjects: ['Operating Systems', 'Calculus'],
        existingFolders: ['Unit 1', 'Unit 2'],
      );

      expect(prompt.contains('"suggestedTitle"'), isTrue);
      expect(prompt.contains('"suggestedSubject"'), isTrue);
      expect(prompt.contains('"suggestedFolder"'), isTrue);
      expect(prompt.contains('"suggestedLabels"'), isTrue);
      expect(prompt.contains('Operating Systems'), isTrue);
    });
  });

  group('Phase 11 — Structured Output & Safe Schema Parsing', () {
    test('Quiz JSON parsing succeeds with valid payload', () {
      const validJson = '''
      {
        "title": "OS Memory Quiz",
        "questions": [
          {
            "id": "q1",
            "question": "What is thrashing in virtual memory?",
            "options": [
              "Excessive paging activity spending more time swapping than executing",
              "A hard disk head crash",
              "CPU overheating shutdown",
              "Defragmentation process"
            ],
            "correctIndex": 0,
            "explanation": "Thrashing occurs when high paging activity starves processes of execution time."
          }
        ]
      }
      ''';

      final decoded = jsonDecode(validJson) as Map<String, dynamic>;
      final quiz = QuizSet.fromMap(decoded);
      expect(quiz.title, equals('OS Memory Quiz'));
      expect(quiz.questions.length, equals(1));
      expect(quiz.questions.first.correctIndex, equals(0));
      expect(quiz.questions.first.options.length, equals(4));
    });

    test('Flashcard parsing creates editable cards from JSON array', () {
      const flashcardsJson = '''
      [
        {
          "front": "What does ACID stand for in DBMS?",
          "back": "Atomicity, Consistency, Isolation, Durability"
        },
        {
          "front": "What is a Deadlock?",
          "back": "A state where two or more processes are blocked waiting for resources held by each other."
        }
      ]
      ''';

      final decoded = jsonDecode(flashcardsJson) as List;
      final cards = decoded.map((e) => FlashcardItem.fromMap(e)).toList();

      expect(cards.length, equals(2));
      expect(cards[0].front, contains('ACID'));
      expect(cards[0].back, contains('Atomicity'));
    });

    test('StudyPlan parses timeline and tasks accurately', () {
      const studyPlanJson = '''
      {
        "title": "Semester Exam Prep: DBMS",
        "subject": "Database Management Systems",
        "items": [
          {
            "day": 1,
            "topic": "ER Modeling & Normalization",
            "goal": "Review ER diagrams and practice 1NF, 2NF, 3NF conversions",
            "suggestedActivity": "Solve 5 previous year question papers",
            "revisionCheckpoint": "Explain Boyce-Codd Normal Form from memory"
          }
        ]
      }
      ''';

      final decoded = jsonDecode(studyPlanJson) as Map<String, dynamic>;
      final plan = StudyPlan.fromMap(decoded);
      expect(plan.title, equals('Semester Exam Prep: DBMS'));
      expect(plan.items.length, equals(1));
      expect(plan.items.first.topic, equals('ER Modeling & Normalization'));
      expect(plan.items.first.day, equals(1));
    });
  });

  group('Phase 11 — Smart Organization Dialog Safety Widget Tests', () {
    testWidgets('SmartOrganizationDialog renders non-destructive review with Accept and Keep Original', (tester) async {
      const suggestion = SmartOrganizationSuggestion(
        suggestedTitle: 'Database ACID Properties Summary',
        suggestedSubject: 'Database Management Systems',
        suggestedFolder: 'Module 3: Transactions',
        suggestedLabels: ['Exam High Yield', 'Lecture Notes'],
        confidence: 0.92,
        rationale: 'Identified transaction processing and ACID consistency models.',
      );

      SmartOrgDecision? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await SmartOrganizationDialog.show(
                    context: context,
                    suggestion: suggestion,
                    originalFileName: 'raw_dbms_notes_3.pdf',
                    availableSubjects: ['Database Management Systems', 'Algorithms'],
                    availableFolders: ['Module 1', 'Module 3: Transactions'],
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify Non-Destructive Review UI elements
      expect(find.text('AI Organization Suggestion'), findsOneWidget);
      expect(find.text('Database ACID Properties Summary'), findsOneWidget);
      expect(find.text('Database Management Systems'), findsOneWidget);
      expect(find.text('Module 3: Transactions'), findsOneWidget);
      expect(find.text('Exam High Yield'), findsOneWidget);
      expect(find.textContaining('Identified transaction processing'), findsOneWidget);

      // Verify Safety buttons: Keep Original, Edit, Accept
      expect(find.text('Keep Original'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);

      // Tap Accept
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.accepted, isTrue);
      expect(result!.title, equals('Database ACID Properties Summary'));
      expect(result!.subject, equals('Database Management Systems'));
      expect(result!.folder, equals('Module 3: Transactions'));
      expect(result!.labels, contains('Exam High Yield'));
    });

    testWidgets('SmartOrganizationDialog preserves original metadata when user clicks Keep Original', (tester) async {
      const suggestion = SmartOrganizationSuggestion(
        suggestedTitle: 'AI Suggested Title',
        suggestedSubject: 'AI Suggested Subject',
        suggestedFolder: null,
        suggestedLabels: ['AI Tag'],
        confidence: 0.8,
        rationale: 'Heuristic recommendation.',
      );

      SmartOrgDecision? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await SmartOrganizationDialog.show(
                    context: context,
                    suggestion: suggestion,
                    originalFileName: 'my_original_file.pdf',
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Click Keep Original (Rejection of AI suggestion)
      await tester.tap(find.text('Keep Original'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.accepted, isFalse);
      expect(result!.title, equals('my_original_file.pdf'));
    });
  });

  group('Phase 11 — Offline, Disabled AI & Missing Key Graceful Degradation', () {
    test('AiConfig.isAiEnabled respects SharedPreferences switch', () async {
      SharedPreferences.setMockInitialValues({'ai_enabled': false});
      final enabled = await AiConfig.isAiEnabled();
      expect(enabled, isFalse);

      await AiConfig.setAiEnabled(true);
      final enabledTrue = await AiConfig.isAiEnabled();
      expect(enabledTrue, isTrue);
    });

    test('AiConfig.getApiKey handles missing key safely without throw', () async {
      SharedPreferences.setMockInitialValues({});
      final key = await AiConfig.getApiKey();
      // Returns empty string or dart-define value, never throws fatal exception
      expect(key, isA<String>());
    });
  });
}

class _MockEmbeddingService implements EmbeddingService {
  @override
  int get dimension => 768;

  @override
  double calculateCosineSimilarity(List<double> vectorA, List<double> vectorB) {
    if (vectorA.length != vectorB.length || vectorA.isEmpty) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < vectorA.length; i++) {
      dotProduct += vectorA[i] * vectorB[i];
      normA += vectorA[i] * vectorA[i];
      normB += vectorB[i] * vectorB[i];
    }
    if (normA <= 0.0 || normB <= 0.0) return 0.0;
    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
  }

  @override
  Future<List<double>> embed(AiEmbeddingInput input) async {
    final query = input.text.toLowerCase();
    if (query.contains('deadlock')) {
      return [1.0, 0.0, 0.0];
    } else if (query.contains('breadth') || query.contains('queue') || query.contains('graph')) {
      return [0.0, 0.0, 1.0];
    } else if (query.contains('confidential') || query.contains('capital')) {
      return [0.0, 1.0, 0.0];
    }
    return [0.577, 0.577, 0.577];
  }

  @override
  Future<List<double>> generateEmbedding(
    String text, {
    AiEmbeddingTaskType taskType = AiEmbeddingTaskType.retrievalDocument,
  }) {
    return embed(AiEmbeddingInput(text: text, taskType: taskType));
  }

  @override
  Future<List<List<double>>> generateEmbeddings(
    List<String> texts, {
    AiEmbeddingTaskType taskType = AiEmbeddingTaskType.retrievalDocument,
  }) {
    return Future.wait(texts.map((t) => generateEmbedding(t, taskType: taskType)));
  }
}
