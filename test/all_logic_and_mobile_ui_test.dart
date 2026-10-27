import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/notes/data/repositories/note_repository.dart';
import 'package:study_vault/features/search/presentation/providers/search_provider.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';
import 'package:study_vault/features/vault/presentation/widgets/bulk_action_bar.dart';
import 'package:study_vault/features/vault/presentation/widgets/material_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDbService localDb;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('study_vault_logic_ui_test_');
    localDb = LocalDbService.instance;
    localDb.setCustomPathForTesting('${tempDir.path}/test_app.db');

    final db = await localDb.database;
    await db.delete('topic_progress');
    await db.delete('study_stats');
    await db.delete('document_chunks');
    await db.delete('materials');
    await db.delete('notes');
  });

  tearDown(() async {
    try {
      final db = await localDb.database;
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Logic Enhancements Verification', () {
    test('1. recordQuizResult updates topic_progress and study_stats correctly', () async {
      await localDb.recordQuizResult(
        topic: 'Operating Systems',
        totalQuestions: 5,
        correctAnswers: 4,
        userId: 'test_user_1',
      );

      final db = await localDb.database;
      final progressRows = await db.query(
        'topic_progress',
        where: 'user_id = ? AND topic = ?',
        whereArgs: ['test_user_1', 'Operating Systems'],
      );

      expect(progressRows, isNotEmpty);
      expect(progressRows.first['attempts'], equals(5));
      expect(progressRows.first['correct'], equals(4));
      expect(progressRows.first['incorrect'], equals(1));

      // Second attempt on the same topic aggregates progress
      await localDb.recordQuizResult(
        topic: 'Operating Systems',
        totalQuestions: 5,
        correctAnswers: 5,
        userId: 'test_user_1',
      );

      final updatedRows = await db.query(
        'topic_progress',
        where: 'user_id = ? AND topic = ?',
        whereArgs: ['test_user_1', 'Operating Systems'],
      );
      expect(updatedRows.first['attempts'], equals(10));
      expect(updatedRows.first['correct'], equals(9));
      expect(updatedRows.first['incorrect'], equals(1));
    });

    test('2. NoteRepository.getNoteById falls back to materials table for note materials', () async {
      final db = await localDb.database;
      final now = DateTime.now().toIso8601String();

      // Insert into materials table as a Phase 6 note material
      await db.insert('materials', {
        'id': 'mat_note_123',
        'user_id': 'guest',
        'title': 'Distributed Consensus Notes',
        'type': 'note',
        'content': 'Paxos and Raft consensus algorithms comparison.',
        'created_at': now,
        'updated_at': now,
      });

      final noteRepo = NoteRepository();
      final resolved = await noteRepo.getNoteById('mat_note_123');

      expect(resolved, isNotNull);
      expect(resolved!['id'], equals('mat_note_123'));
      expect(resolved['title'], equals('Distributed Consensus Notes'));
      expect(resolved['content'], contains('Paxos and Raft'));
    });

    test('3. searchProvider queries document_chunks and returns in-document citations', () async {
      final db = await localDb.database;
      final now = DateTime.now().toIso8601String();

      // Insert parent material
      await db.insert('materials', {
        'id': 'mat_pdf_777',
        'user_id': 'guest',
        'title': 'Biochemistry Textbook',
        'original_file_name': 'biochem.pdf',
        'type': 'pdf',
        'created_at': now,
        'updated_at': now,
      });

      // Insert document chunk with page number and text
      await db.insert('document_chunks', {
        'id': 'chunk_1',
        'material_id': 'mat_pdf_777',
        'user_id': 'guest',
        'page_number': 42,
        'chunk_index': 0,
        'text': 'The Krebs cycle, also known as the citric acid cycle, produces ATP in the mitochondrial matrix.',
        'created_at': now,
        'updated_at': now,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final searchResults = await container.read(searchProvider('mitochondrial').future);

      expect(searchResults, isNotEmpty);
      final chunkHit = searchResults.firstWhere((r) => r['type'] == 'document_chunk');
      expect(chunkHit['material_id'], equals('mat_pdf_777'));
      expect(chunkHit['page_number'], equals(42));
      expect(chunkHit['title'], equals('Biochemistry Textbook'));
      expect(chunkHit['snippet'], contains('mitochondrial'));
    });
  });

  group('Mobile UI Layout & Viewport Robustness', () {
    testWidgets('4. BulkActionBar renders cleanly on 360px width without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: BulkActionBar(
                selectedCount: 3,
                isAllSelected: false,
                onSelectAll: () {},
                onClearSelection: () {},
                onShare: () {},
                onCreatePack: () {},
                onMove: () {},
                onLabel: () {},
                onArchive: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify no RenderFlex exception occurred
      expect(tester.takeException(), isNull);
      expect(find.text('3 selected'), findsOneWidget);
      expect(find.text('Select All'), findsOneWidget);
    });

    testWidgets('5. MaterialCard renders cleanly in narrow 140px mobile grid column without overflow', (tester) async {
      final testMaterial = MaterialItem(
        id: 'test_card_1',
        userId: 'guest',
        title: 'Very Long Comprehensive Advanced Study Guide On Discrete Mathematics And Computer Architecture',
        type: VaultMaterialType.pdf,
        fileSize: 1048576, // 1 MB
        source: 'Private',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 140, // Strict narrow column constraint
              child: MaterialCard(
                material: testMaterial,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify zero RenderFlex errors thrown
      expect(tester.takeException(), isNull);
      expect(find.text('PDF'), findsWidgets);
    });
  });
}
