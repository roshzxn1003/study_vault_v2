import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/vault/data/repositories/vault_repository.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 6 Vault Repository Unit Tests (Scenarios A through O)', () {
    late Directory tempDir;
    late LocalDbService localDb;
    late VaultRepository repo;
    const userId = 'student_1';
    const wsCollege = 'ws_college_1';
    const wsPersonal = 'ws_personal_2';
    const sem1 = 'period_sem_1';
    const sem2 = 'period_sem_2';
    const subOs = 'sub_operating_systems';
    const subCn = 'sub_computer_networks';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('study_vault_vault_tests_');
      localDb = LocalDbService.instance;
      localDb.setCustomPathForTesting('${tempDir.path}/test_vault.db');
      repo = VaultRepository(localDb: localDb);

      // Clean tables before each test to guarantee fresh isolation
      final db = await localDb.database;
      await db.delete('material_labels');
      await db.delete('materials');
      await db.delete('folders');
      await db.delete('labels');

      // Seed academic labels
      await repo.ensureInitialized(userId: userId, workspaceId: wsCollege);
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
    // SCENARIO A: Nested folder hierarchy creation
    // =========================================================================
    test('Scenario A: Create nested folder hierarchy and verify breadcrumbs', () async {
      final f1 = await repo.createFolder(
        userId: userId,
        workspaceId: wsCollege,
        academicPeriodId: sem2,
        subjectId: subOs,
        name: 'Operating Systems',
      );
      expect(f1.name, 'Operating Systems');
      expect(f1.parentId, isNull);

      final f2 = await repo.createFolder(
        userId: userId,
        workspaceId: wsCollege,
        academicPeriodId: sem2,
        subjectId: subOs,
        parentId: f1.id,
        name: 'Unit 3',
      );
      expect(f2.name, 'Unit 3');
      expect(f2.parentId, f1.id);

      final f3 = await repo.createFolder(
        userId: userId,
        workspaceId: wsCollege,
        academicPeriodId: sem2,
        subjectId: subOs,
        parentId: f2.id,
        name: 'Revision',
      );
      expect(f3.name, 'Revision');
      expect(f3.parentId, f2.id);

      // Verify breadcrumb path from deepest child up to root
      final breadcrumbs = await repo.getBreadcrumbs(f3.id);
      expect(breadcrumbs.length, 3);
      expect(breadcrumbs[0].name, 'Operating Systems');
      expect(breadcrumbs[1].name, 'Unit 3');
      expect(breadcrumbs[2].name, 'Revision');
    });

    // =========================================================================
    // SCENARIO B: Rename folder & validation
    // =========================================================================
    test('Scenario B: Rename folder and enforce non-empty name validation', () async {
      final folder = await repo.createFolder(
        userId: userId,
        workspaceId: wsCollege,
        name: 'Initial Name',
      );

      await repo.renameFolder(folder.id, 'Final Exam Revision');
      final updated = await repo.getFolderById(folder.id);
      expect(updated?.name, 'Final Exam Revision');

      // Enforce validation: empty name throws ArgumentError
      expect(
        () => repo.renameFolder(folder.id, '   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    // =========================================================================
    // SCENARIO C: Move material between folders & to root
    // =========================================================================
    test('Scenario C: Move material between folders and to root level', () async {
      final fSource = await repo.createFolder(userId: userId, name: 'Folder A');
      final fTarget = await repo.createFolder(userId: userId, name: 'Folder B');

      final mat = await repo.createMaterial(
        userId: userId,
        workspaceId: wsCollege,
        folderId: fSource.id,
        title: 'CPU Scheduling Notes.pdf',
        type: VaultMaterialType.pdf,
        fileSize: 1048576,
      );
      expect(mat.folderId, fSource.id);

      // Move to Folder B
      await repo.moveMaterial(mat.id, folderId: fTarget.id);
      var moved = await repo.getMaterialById(mat.id);
      expect(moved?.folderId, fTarget.id);

      // Move to root level (null folderId)
      await repo.moveMaterial(mat.id, folderId: null);
      moved = await repo.getMaterialById(mat.id);
      expect(moved?.folderId, isNull);
    });

    // =========================================================================
    // SCENARIO D: Label management & multi-label application
    // =========================================================================
    test('Scenario D: Default labels, custom label creation, and multi-label tagging', () async {
      final labels = await repo.getLabels(userId: userId);
      expect(labels.length, greaterThanOrEqualTo(9));
      expect(labels.any((l) => l.name == 'Notes'), isTrue);
      expect(labels.any((l) => l.name == 'Revision'), isTrue);
      expect(labels.any((l) => l.name == 'Exam'), isTrue);

      final customLabel = await repo.createLabel(
        userId: userId,
        workspaceId: wsCollege,
        name: 'Formulas',
        colorHex: '#EF4444',
      );
      expect(customLabel.name, 'Formulas');

      final notesLabel = labels.firstWhere((l) => l.name == 'Notes');
      final examLabel = labels.firstWhere((l) => l.name == 'Exam');

      final mat = await repo.createMaterial(
        userId: userId,
        title: 'Midterm Review Sheet',
        type: VaultMaterialType.document,
        labelIds: [notesLabel.id, examLabel.id, customLabel.id],
      );

      final fetched = await repo.getMaterialById(mat.id);
      expect(fetched?.labels.length, 3);
      expect(fetched?.labels.any((l) => l.name == 'Formulas'), isTrue);

      // Remove one label
      await repo.removeLabelFromMaterial(mat.id, customLabel.id);
      final afterRemove = await repo.getMaterialById(mat.id);
      expect(afterRemove?.labels.length, 2);

      // Delete label and verify junction table cascaded
      await repo.deleteLabel(customLabel.id);
      final remainingLabels = await repo.getLabels(userId: userId);
      expect(remainingLabels.any((l) => l.name == 'Formulas'), isFalse);
    });

    // =========================================================================
    // SCENARIO E: Favorite toggle & Favorites view
    // =========================================================================
    test('Scenario E: Toggle favorites and query favorites view', () async {
      final m1 = await repo.createMaterial(
        userId: userId,
        title: 'Lecture 1 Slides',
        type: VaultMaterialType.pdf,
        isFavorite: false,
      );
      final m2 = await repo.createMaterial(
        userId: userId,
        title: 'Quick Reference Sheet',
        type: VaultMaterialType.note,
        isFavorite: true,
      );

      var favs = await repo.getMaterials(
        userId: userId,
        filter: const MaterialFilter(isFavoriteOnly: true),
      );
      expect(favs.length, 1);
      expect(favs.first.id, m2.id);

      // Toggle m1 to favorite
      await repo.toggleFavorite(m1.id, true);
      favs = await repo.getMaterials(
        userId: userId,
        filter: const MaterialFilter(isFavoriteOnly: true),
      );
      expect(favs.length, 2);

      // Untoggle m2
      await repo.toggleFavorite(m2.id, false);
      favs = await repo.getMaterials(
        userId: userId,
        filter: const MaterialFilter(isFavoriteOnly: true),
      );
      expect(favs.length, 1);
      expect(favs.first.id, m1.id);
    });

    // =========================================================================
    // SCENARIO F: Archive toggle, Archive view & Restore
    // =========================================================================
    test('Scenario F: Archive material, view archive, and restore material', () async {
      final m = await repo.createMaterial(
        userId: userId,
        title: 'Old Assignment Draft',
        type: VaultMaterialType.document,
      );

      // Normal view includes it
      var active = await repo.getMaterials(userId: userId);
      expect(active.any((x) => x.id == m.id), isTrue);

      // Archive it
      await repo.archiveMaterial(m.id);

      // Normal view excludes it
      active = await repo.getMaterials(userId: userId);
      expect(active.any((x) => x.id == m.id), isFalse);

      // Archive view includes it
      var archived = await repo.getMaterials(
        userId: userId,
        filter: const MaterialFilter(isArchivedOnly: true),
      );
      expect(archived.any((x) => x.id == m.id), isTrue);

      // Restore it
      await repo.restoreMaterial(m.id);
      active = await repo.getMaterials(userId: userId);
      expect(active.any((x) => x.id == m.id), isTrue);
    });

    // =========================================================================
    // SCENARIO G: Global search (title, description, file name)
    // =========================================================================
    test('Scenario G: Search by title, description, and original file name', () async {
      await repo.createMaterial(
        userId: userId,
        title: 'Virtual Memory Architectures',
        description: 'Paging algorithms and segmentation mechanisms',
        originalFileName: 'vm_arch_v2.pdf',
        type: VaultMaterialType.pdf,
      );
      await repo.createMaterial(
        userId: userId,
        title: 'TCP/IP Protocol Suite',
        description: 'Socket programming walkthrough',
        originalFileName: 'network_sockets.c',
        type: VaultMaterialType.note,
      );

      // Search by title keyword
      var results = await repo.getMaterials(
        userId: userId,
        filter: const MaterialFilter(searchQuery: 'Virtual Memory'),
      );
      expect(results.length, 1);
      expect(results.first.title, 'Virtual Memory Architectures');

      // Search by description keyword
      results = await repo.getMaterials(
        userId: userId,
        filter: const MaterialFilter(searchQuery: 'segmentation'),
      );
      expect(results.length, 1);
      expect(results.first.title, 'Virtual Memory Architectures');

      // Search by original file name
      results = await repo.getMaterials(
        userId: userId,
        filter: const MaterialFilter(searchQuery: 'network_sockets'),
      );
      expect(results.length, 1);
      expect(results.first.title, 'TCP/IP Protocol Suite');

      // Non-matching search returns empty
      results = await repo.getMaterials(
        userId: userId,
        filter: const MaterialFilter(searchQuery: 'quantum computing'),
      );
      expect(results, isEmpty);
    });

    // =========================================================================
    // SCENARIO H: Multi-facet filtering (type, subject, labels)
    // =========================================================================
    test('Scenario H: Multi-facet filtering across type, subject, and labels', () async {
      final labels = await repo.getLabels(userId: userId);
      final examLabel = labels.firstWhere((l) => l.name == 'Exam');
      final labLabel = labels.firstWhere((l) => l.name == 'Lab');

      final m1 = await repo.createMaterial(
        userId: userId,
        subjectId: subOs,
        title: 'OS Exam Prep.pdf',
        type: VaultMaterialType.pdf,
        labelIds: [examLabel.id],
      );
      await repo.createMaterial(
        userId: userId,
        subjectId: subOs,
        title: 'OS Lab Manual.pdf',
        type: VaultMaterialType.pdf,
        labelIds: [labLabel.id],
      );
      await repo.createMaterial(
        userId: userId,
        subjectId: subCn,
        title: 'CN Exam Question Bank.pdf',
        type: VaultMaterialType.pdf,
        labelIds: [examLabel.id],
      );

      // Filter: Subject = subOs AND Label = Exam
      final filtered = await repo.getMaterials(
        userId: userId,
        filter: MaterialFilter(
          subjectId: subOs,
          labelIds: {examLabel.id},
        ),
      );
      expect(filtered.length, 1);
      expect(filtered.first.id, m1.id);
    });

    // =========================================================================
    // SCENARIO I: Sorting options
    // =========================================================================
    test('Scenario I: Sorting by name Ascending and Descending', () async {
      await repo.createMaterial(
        userId: userId,
        title: 'Algorithms',
        type: VaultMaterialType.note,
      );
      await repo.createMaterial(
        userId: userId,
        title: 'Compilers',
        type: VaultMaterialType.note,
      );
      await repo.createMaterial(
        userId: userId,
        title: 'Databases',
        type: VaultMaterialType.note,
      );

      // Name Ascending
      final asc = await repo.getMaterials(
        userId: userId,
        sort: MaterialSortOption.nameAsc,
      );
      expect(asc.map((m) => m.title).toList(), ['Algorithms', 'Compilers', 'Databases']);

      // Name Descending
      final desc = await repo.getMaterials(
        userId: userId,
        sort: MaterialSortOption.nameDesc,
      );
      expect(desc.map((m) => m.title).toList(), ['Databases', 'Compilers', 'Algorithms']);
    });

    // =========================================================================
    // SCENARIO J: Bulk actions (Move, Label, Archive, Delete)
    // =========================================================================
    test('Scenario J: Bulk move, bulk label, bulk archive, and bulk delete', () async {
      final targetFolder = await repo.createFolder(userId: userId, name: 'Archive Batch');
      final labels = await repo.getLabels(userId: userId);
      final impLabel = labels.firstWhere((l) => l.name == 'Important');

      final m1 = await repo.createMaterial(userId: userId, title: 'Doc 1', type: VaultMaterialType.note);
      final m2 = await repo.createMaterial(userId: userId, title: 'Doc 2', type: VaultMaterialType.note);
      final ids = [m1.id, m2.id];

      // 1. Bulk Move
      await repo.bulkMove(ids, folderId: targetFolder.id);
      var fetched = await repo.getMaterials(userId: userId, folderId: targetFolder.id);
      expect(fetched.length, 2);

      // 2. Bulk Add Labels
      await repo.bulkAddLabels(ids, [impLabel.id]);
      var m1Updated = await repo.getMaterialById(m1.id);
      expect(m1Updated?.labels.any((l) => l.name == 'Important'), isTrue);

      // 3. Bulk Archive
      await repo.bulkArchive(ids);
      fetched = await repo.getMaterials(userId: userId);
      expect(fetched.where((m) => ids.contains(m.id)), isEmpty);

      // 4. Bulk Delete
      await repo.bulkDelete(ids);
      final m1Check = await repo.getMaterialById(m1.id);
      final m2Check = await repo.getMaterialById(m2.id);
      expect(m1Check, isNull);
      expect(m2Check, isNull);
    });

    // =========================================================================
    // SCENARIO K: Safe folder deletion choices & cycle prevention
    // =========================================================================
    test('Scenario K: Safe folder deletion choices and cycle prevention', () async {
      final parentFolder = await repo.createFolder(userId: userId, name: 'Parent');
      final childFolder = await repo.createFolder(userId: userId, parentId: parentFolder.id, name: 'Child');

      final mat = await repo.createMaterial(
        userId: userId,
        folderId: childFolder.id,
        title: 'Child Note',
        type: VaultMaterialType.note,
      );

      // Choice 1: Move contents to parent and delete child folder
      await repo.deleteFolder(
        childFolder.id,
        deleteContents: false,
        moveContentsToParentId: parentFolder.id,
      );

      final matAfter = await repo.getMaterialById(mat.id);
      expect(matAfter?.folderId, parentFolder.id);
      final childCheck = await repo.getFolderById(childFolder.id);
      expect(childCheck, isNull);

      // Choice 2: Delete folder and all contents
      await repo.deleteFolder(parentFolder.id, deleteContents: true);
      final matFinal = await repo.getMaterialById(mat.id);
      expect(matFinal, isNull);
      final parentCheck = await repo.getFolderById(parentFolder.id);
      expect(parentCheck, isNull);

      // Cycle prevention: Cannot move folder into itself
      final folderX = await repo.createFolder(userId: userId, name: 'Folder X');
      expect(
        () => repo.moveFolder(folderX.id, folderX.id),
        throwsA(isA<ArgumentError>()),
      );
    });

    // =========================================================================
    // SCENARIO L: Subject context isolation
    // =========================================================================
    test('Scenario L: Subject context isolation preserves strict boundaries', () async {
      await repo.createMaterial(
        userId: userId,
        subjectId: subOs,
        title: 'OS Process Management',
        type: VaultMaterialType.document,
      );
      await repo.createMaterial(
        userId: userId,
        subjectId: subCn,
        title: 'CN Congestion Control',
        type: VaultMaterialType.document,
      );

      final osMaterials = await repo.getMaterials(userId: userId, subjectId: subOs);
      expect(osMaterials.length, 1);
      expect(osMaterials.first.title, 'OS Process Management');

      final cnMaterials = await repo.getMaterials(userId: userId, subjectId: subCn);
      expect(cnMaterials.length, 1);
      expect(cnMaterials.first.title, 'CN Congestion Control');
    });

    // =========================================================================
    // SCENARIO M: Historical academic semester association
    // =========================================================================
    test('Scenario M: Materials preserve historical academic period associations', () async {
      await repo.createMaterial(
        userId: userId,
        academicPeriodId: sem1,
        title: 'Semester 1 Final Project',
        type: VaultMaterialType.document,
      );
      await repo.createMaterial(
        userId: userId,
        academicPeriodId: sem2,
        title: 'Semester 2 Lab Assignment',
        type: VaultMaterialType.document,
      );

      final sem1Materials = await repo.getMaterials(
        userId: userId,
        filter: const MaterialFilter(academicPeriodId: sem1),
      );
      expect(sem1Materials.length, 1);
      expect(sem1Materials.first.title, 'Semester 1 Final Project');

      final sem2Materials = await repo.getMaterials(
        userId: userId,
        filter: const MaterialFilter(academicPeriodId: sem2),
      );
      expect(sem2Materials.length, 1);
      expect(sem2Materials.first.title, 'Semester 2 Lab Assignment');
    });

    // =========================================================================
    // SCENARIO N: Multiple workspace isolation
    // =========================================================================
    test('Scenario N: Workspace isolation prevents leakage between College and Personal Learning', () async {
      await repo.createMaterial(
        userId: userId,
        workspaceId: wsCollege,
        title: 'College Data Structures Syllabus',
        type: VaultMaterialType.pdf,
      );
      await repo.createMaterial(
        userId: userId,
        workspaceId: wsPersonal,
        title: 'Rust Programming Practice',
        type: VaultMaterialType.note,
      );

      final collegeMaterials = await repo.getMaterials(
        userId: userId,
        workspaceId: wsCollege,
      );
      expect(collegeMaterials.length, 1);
      expect(collegeMaterials.first.title, 'College Data Structures Syllabus');

      final personalMaterials = await repo.getMaterials(
        userId: userId,
        workspaceId: wsPersonal,
      );
      expect(personalMaterials.length, 1);
      expect(personalMaterials.first.title, 'Rust Programming Practice');
    });

    // =========================================================================
    // SCENARIO O: Data persistence across app restarts
    // =========================================================================
    test('Scenario O: Data persists across repository re-instantiation', () async {
      final f = await repo.createFolder(userId: userId, name: 'Persistent Folder');
      final m = await repo.createMaterial(
        userId: userId,
        folderId: f.id,
        title: 'Persistent Material Record',
        type: VaultMaterialType.note,
      );

      // Simulate app restart by constructing fresh repository instance
      final restartedRepo = VaultRepository(localDb: localDb);

      final persistedFolder = await restartedRepo.getFolderById(f.id);
      expect(persistedFolder?.name, 'Persistent Folder');

      final persistedMaterial = await restartedRepo.getMaterialById(m.id);
      expect(persistedMaterial?.title, 'Persistent Material Record');
      expect(persistedMaterial?.folderId, f.id);
    });
  });
}
