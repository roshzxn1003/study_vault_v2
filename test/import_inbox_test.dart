import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/import/data/repositories/import_repository.dart';
import 'package:study_vault/features/import/data/services/import_storage_service.dart';
import 'package:study_vault/features/import/domain/models/import_item.dart';
import 'package:study_vault/features/vault/data/repositories/vault_repository.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 7 Universal Import & Inbox Unit Tests', () {
    late LocalDbService localDb;
    late VaultRepository vaultRepo;
    late ImportStorageService storageService;
    late ImportRepository importRepo;

    late Directory tempDir;
    const userId = 'student_test_1';
    const wsId = 'workspace_engineering';
    const periodId = 'semester_3';
    const subjectId = 'subject_math_3';

    setUp(() async {
      // Create a dedicated temp directory for physical test files & isolated database
      tempDir = await Directory.systemTemp.createTemp('study_vault_import_tests_');
      localDb = LocalDbService.instance;
      localDb.setCustomPathForTesting('${tempDir.path}/test_import.db');
      vaultRepo = VaultRepository(localDb: localDb);
      storageService = ImportStorageService();
      importRepo = ImportRepository(
        vaultRepository: vaultRepo,
        storageService: storageService,
      );

      // Reset test database tables
      final db = await localDb.database;
      await db.delete('material_labels');
      await db.delete('materials');
      await db.delete('folders');
      await db.delete('labels');

      // Initialize default labels
      await vaultRepo.ensureInitialized(userId: userId, workspaceId: wsId);
    });

    tearDown(() async {
      await localDb.closeForTesting();
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    // =========================================================================
    // 1. File Type Validation & Sanitization Tests
    // =========================================================================
    test('1. File Type Validation: allows supported types, rejects dangerous executables', () {
      // Supported types
      expect(storageService.isSupportedFile(fileName: 'lecture_notes.pdf'), isTrue);
      expect(storageService.isSupportedFile(fileName: 'whiteboard.png'), isTrue);
      expect(storageService.isSupportedFile(fileName: 'diagram.jpg'), isTrue);
      expect(storageService.isSupportedFile(fileName: 'summary.txt'), isTrue);
      expect(storageService.isSupportedFile(fileName: 'assignment.docx'), isTrue);
      expect(storageService.isSupportedFile(fileName: 'presentation.pptx'), isTrue);
      expect(storageService.isSupportedFile(fileName: 'grades.xlsx'), isTrue);

      // Dangerous / unsupported extensions
      expect(storageService.isSupportedFile(fileName: 'malware.exe'), isFalse);
      expect(storageService.isSupportedFile(fileName: 'app.apk'), isFalse);
      expect(storageService.isSupportedFile(fileName: 'script.sh'), isFalse);
      expect(storageService.isSupportedFile(fileName: 'cmd.bat'), isFalse);
      expect(storageService.isSupportedFile(fileName: 'archive.zip'), isFalse);
      expect(storageService.isSupportedFile(fileName: 'archive.tar'), isFalse);
    });

    test('2. Filename Sanitization: removes path traversal and invalid characters', () {
      expect(
        storageService.sanitizeFileName('../../etc/passwd'),
        'passwd',
      );
      expect(
        storageService.sanitizeFileName('notes/folder/sub:test*.pdf'),
        'sub_test_.pdf',
      );
      expect(
        storageService.sanitizeFileName(''),
        startsWith('material_'),
      );
    });

    test('3. Hash Generation: computes accurate SHA-256 for file and text content', () async {
      final sampleFile = File('${tempDir.path}/test_hash.txt');
      await sampleFile.writeAsString('Study Vault Offline First Architecture');

      final fileHash = await storageService.calculateFileHash(sampleFile);
      expect(fileHash, isNotEmpty);
      expect(fileHash.length, 64); // Standard SHA-256 hex length

      final stringHash = storageService.calculateStringHash('Study Vault Offline First Architecture');
      expect(fileHash, equals(stringHash));
    });

    // =========================================================================
    // 2. Single File Import & Quick Save to Inbox
    // =========================================================================
    test('4. Ingest single PDF file and Quick Save to Inbox', () async {
      final testPdf = File('${tempDir.path}/Calculus_Notes.pdf');
      await testPdf.writeAsString('%PDF-1.4 Mock PDF Content For Calculus');

      final hash = await storageService.calculateFileHash(testPdf);
      final importItem = ImportItem(
        id: 'item_calc_1',
        title: 'Calculus Notes',
        type: VaultMaterialType.pdf,
        filePath: testPdf.path,
        fileSize: await testPdf.length(),
        originalFileName: 'Calculus_Notes.pdf',
        mimeType: 'application/pdf',
        contentHash: hash,
        source: 'Google Classroom',
      );

      // Validate staging
      final staged = await importRepo.validateAndStageItems([importItem], userId: userId);
      expect(staged.first.status, ImportItemStatus.pending);

      // Quick Save to Inbox (isInbox = true, no subject/folder)
      final saved = await importRepo.importItem(
        staged.first,
        userId: userId,
        workspaceId: wsId,
        isInbox: true,
      );

      expect(saved.title, 'Calculus Notes');
      expect(saved.isInbox, isTrue);
      expect(saved.subjectId, isNull);
      expect(saved.folderId, isNull);
      expect(saved.source, 'Google Classroom');
      expect(saved.contentHash, hash);
      expect(saved.filePath, isNotNull);
      expect(await File(saved.filePath!).exists(), isTrue);

      // Verify Inbox queries
      final inboxCount = await vaultRepo.getInboxCount(userId: userId);
      expect(inboxCount, 1);

      final inboxItems = await vaultRepo.getInboxMaterials(userId: userId);
      expect(inboxItems.length, 1);
      expect(inboxItems.first.id, saved.id);
    });

    // =========================================================================
    // 3. Shared URL and Text Note Ingestion
    // =========================================================================
    test('5. Ingest shared URL link and shared text note into Inbox', () async {
      final linkItem = ImportItem(
        id: 'item_link_1',
        title: 'https://ocw.mit.edu/courses/mathematics',
        type: VaultMaterialType.link,
        content: 'https://ocw.mit.edu/courses/mathematics',
        source: 'Chrome',
      );

      final noteItem = ImportItem(
        id: 'item_note_1',
        title: 'Exam Formula Reminder',
        type: VaultMaterialType.note,
        content: 'Remember: Integration by parts is integral(u dv) = uv - integral(v du)',
        source: 'WhatsApp',
      );

      final staged = await importRepo.validateAndStageItems([linkItem, noteItem], userId: userId);
      expect(staged.length, 2);
      expect(staged[0].status, ImportItemStatus.pending);
      expect(staged[1].status, ImportItemStatus.pending);

      final batchResult = await importRepo.importBatch(
        staged,
        userId: userId,
        workspaceId: wsId,
        isInbox: true,
      );

      expect(batchResult.succeeded.length, 2);
      expect(batchResult.failed, isEmpty);

      final inboxMaterials = await vaultRepo.getInboxMaterials(userId: userId);
      expect(inboxMaterials.length, 2);

      final linkMat = inboxMaterials.firstWhere((m) => m.type == VaultMaterialType.link);
      expect(linkMat.remoteUrl, 'https://ocw.mit.edu/courses/mathematics');
      expect(linkMat.source, 'Chrome');

      final noteMat = inboxMaterials.firstWhere((m) => m.type == VaultMaterialType.note);
      expect(noteMat.content, contains('Integration by parts'));
      expect(noteMat.source, 'WhatsApp');
    });

    // =========================================================================
    // 4. Multi-file Batch Import with Progress
    // =========================================================================
    test('6. Ingest multiple files in batch with progress notification', () async {
      final files = <File>[];
      final items = <ImportItem>[];

      for (int i = 1; i <= 3; i++) {
        final f = File('${tempDir.path}/lecture_$i.pdf');
        await f.writeAsString('Lecture $i content');
        files.add(f);

        items.add(ImportItem(
          id: 'batch_item_$i',
          title: 'Lecture $i',
          type: VaultMaterialType.pdf,
          filePath: f.path,
          fileSize: await f.length(),
          originalFileName: 'lecture_$i.pdf',
          source: 'Files',
        ));
      }

      final progressReports = <int>[];
      final result = await importRepo.importBatch(
        items,
        userId: userId,
        workspaceId: wsId,
        isInbox: true,
        onProgress: (current, total) {
          progressReports.add(current);
        },
      );

      expect(result.succeeded.length, 3);
      expect(result.failed, isEmpty);
      expect(progressReports, [1, 2, 3]);

      final count = await vaultRepo.getInboxCount(userId: userId);
      expect(count, 3);
    });

    // =========================================================================
    // 5. Duplicate Detection & Duplicate Override Flow
    // =========================================================================
    test('7. Duplicate detection identifies identical content and allows override', () async {
      final origFile = File('${tempDir.path}/Algorithms.pdf');
      await origFile.writeAsString('Binary Search Trees and AVL Trees');

      final hash = await storageService.calculateFileHash(origFile);

      // Save initial material
      await vaultRepo.createMaterial(
        userId: userId,
        workspaceId: wsId,
        title: 'Algorithms Revision',
        type: VaultMaterialType.pdf,
        originalFileName: 'Algorithms.pdf',
        fileSize: await origFile.length(),
        contentHash: hash,
        isInbox: true,
      );

      // Attempt to stage a duplicate file with identical hash
      final incomingDuplicate = ImportItem(
        id: 'dup_item_1',
        title: 'Algorithms Copy',
        type: VaultMaterialType.pdf,
        filePath: origFile.path,
        fileSize: await origFile.length(),
        originalFileName: 'Algorithms.pdf',
      );

      final staged = await importRepo.validateAndStageItems([incomingDuplicate], userId: userId);
      expect(staged.first.status, ImportItemStatus.duplicateDetected);
      expect(staged.first.duplicateMatch, isNotNull);
      expect(staged.first.duplicateMatch!.title, 'Algorithms Revision');

      // User decides to override and import anyway
      final forcedItem = staged.first.copyWith(status: ImportItemStatus.pending);
      final imported = await importRepo.importItem(
        forcedItem,
        userId: userId,
        workspaceId: wsId,
        isInbox: true,
      );

      expect(imported.id, isNotEmpty);
      final count = await vaultRepo.getInboxCount(userId: userId);
      expect(count, 2); // Both the original and forced duplicate now exist safely
    });

    // =========================================================================
    // 6. Partial Batch Failure & Retry Handling
    // =========================================================================
    test('8. Partial batch failure: missing file fails without interrupting valid imports', () async {
      final validFile = File('${tempDir.path}/valid_doc.pdf');
      await validFile.writeAsString('Valid document content');

      final items = [
        ImportItem(
          id: 'valid_1',
          title: 'Valid Doc',
          type: VaultMaterialType.pdf,
          filePath: validFile.path,
          fileSize: await validFile.length(),
          originalFileName: 'valid_doc.pdf',
        ),
        ImportItem(
          id: 'invalid_1',
          title: 'Missing File',
          type: VaultMaterialType.pdf,
          filePath: '${tempDir.path}/non_existent_file.pdf',
          fileSize: 1024,
          originalFileName: 'non_existent_file.pdf',
        ),
      ];

      final staged = await importRepo.validateAndStageItems(items, userId: userId);
      expect(staged[0].status, ImportItemStatus.pending);
      expect(staged[1].status, ImportItemStatus.failed);
      expect(staged[1].errorMessage, contains('Inaccessible or missing file'));

      final result = await importRepo.importBatch(
        staged,
        userId: userId,
        workspaceId: wsId,
        isInbox: true,
      );

      expect(result.succeeded.length, 1);
      expect(result.failed.length, 1);
      expect(result.succeeded.first.title, 'Valid Doc');
      expect(result.failed.first.title, 'Missing File');
    });

    // =========================================================================
    // 7. Save & Organize Directly (Bypasses Inbox)
    // =========================================================================
    test('9. Save & Organize saves directly to academic structure and bypasses Inbox', () async {
      // Create folder and label first
      final folder = await vaultRepo.createFolder(
        userId: userId,
        workspaceId: wsId,
        academicPeriodId: periodId,
        subjectId: subjectId,
        name: 'Calculus Chapter 1',
      );

      final labels = await vaultRepo.getLabels(userId: userId);
      final examLabel = labels.firstWhere((l) => l.name == 'Exam');

      final testFile = File('${tempDir.path}/Chapter1_Summary.pdf');
      await testFile.writeAsString('Summary of limits and derivatives');

      final item = ImportItem(
        id: 'direct_org_1',
        title: 'Limits & Derivatives',
        type: VaultMaterialType.pdf,
        filePath: testFile.path,
        fileSize: await testFile.length(),
        originalFileName: 'Chapter1_Summary.pdf',
      );

      final organizedMaterial = await importRepo.importItem(
        item,
        userId: userId,
        workspaceId: wsId,
        academicPeriodId: periodId,
        subjectId: subjectId,
        folderId: folder.id,
        labelIds: [examLabel.id],
        isInbox: false, // Save & Organize directly!
      );

      expect(organizedMaterial.isInbox, isFalse);
      expect(organizedMaterial.subjectId, subjectId);
      expect(organizedMaterial.folderId, folder.id);
      expect(organizedMaterial.labels.map((l) => l.id), contains(examLabel.id));

      // Must NOT appear in Inbox
      final inboxCount = await vaultRepo.getInboxCount(userId: userId);
      expect(inboxCount, 0);

      // Must appear in Subject materials
      final subjectMaterials = await vaultRepo.getMaterials(
        userId: userId,
        filter: MaterialFilter(subjectId: subjectId, isInbox: false),
      );
      expect(subjectMaterials.length, 1);
      expect(subjectMaterials.first.title, 'Limits & Derivatives');
    });

    // =========================================================================
    // 8. Single & Bulk Organize from Inbox
    // =========================================================================
    test('10. Organize single and bulk items out of Inbox into academic destination', () async {
      // Create 3 inbox items
      final m1 = await vaultRepo.createMaterial(
        userId: userId,
        workspaceId: wsId,
        title: 'Inbox Item 1',
        type: VaultMaterialType.pdf,
        isInbox: true,
      );
      final m2 = await vaultRepo.createMaterial(
        userId: userId,
        workspaceId: wsId,
        title: 'Inbox Item 2',
        type: VaultMaterialType.note,
        isInbox: true,
      );
      final m3 = await vaultRepo.createMaterial(
        userId: userId,
        workspaceId: wsId,
        title: 'Inbox Item 3',
        type: VaultMaterialType.link,
        isInbox: true,
      );

      expect(await vaultRepo.getInboxCount(userId: userId), 3);

      // 1. Single organize m1
      await vaultRepo.organizeMaterial(
        m1.id,
        workspaceId: wsId,
        academicPeriodId: periodId,
        subjectId: subjectId,
      );

      expect(await vaultRepo.getInboxCount(userId: userId), 2);
      final updatedM1 = await vaultRepo.getMaterialById(m1.id);
      expect(updatedM1?.isInbox, isFalse);
      expect(updatedM1?.subjectId, subjectId);

      // 2. Bulk organize m2 and m3
      await vaultRepo.bulkOrganizeMaterials(
        [m2.id, m3.id],
        workspaceId: wsId,
        academicPeriodId: periodId,
        subjectId: subjectId,
      );

      expect(await vaultRepo.getInboxCount(userId: userId), 0);
      final updatedM2 = await vaultRepo.getMaterialById(m2.id);
      final updatedM3 = await vaultRepo.getMaterialById(m3.id);
      expect(updatedM2?.isInbox, isFalse);
      expect(updatedM3?.isInbox, isFalse);
    });

    // =========================================================================
    // 9. Offline Persistence Across Repository Re-instantiation
    // =========================================================================
    test('11. Local Offline Persistence: data is preserved across repository re-instantiation', () async {
      final persistentFile = File('${tempDir.path}/Physics_Lab.pdf');
      await persistentFile.writeAsString('Lab 4: Simple Harmonic Motion Data');

      final saved = await importRepo.importItem(
        ImportItem(
          id: 'phys_lab_1',
          title: 'Physics Lab 4',
          type: VaultMaterialType.pdf,
          filePath: persistentFile.path,
          fileSize: await persistentFile.length(),
          originalFileName: 'Physics_Lab.pdf',
        ),
        userId: userId,
        workspaceId: wsId,
        isInbox: true,
      );

      // Simulate app restart by re-instantiating repositories
      final newVaultRepo = VaultRepository(localDb: localDb);
      final newInboxItems = await newVaultRepo.getInboxMaterials(userId: userId);

      expect(newInboxItems.length, 1);
      expect(newInboxItems.first.id, saved.id);
      expect(newInboxItems.first.title, 'Physics Lab 4');
      expect(await File(newInboxItems.first.filePath!).exists(), isTrue);
    });
  });
}
