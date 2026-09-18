import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/vault/data/repositories/vault_repository.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';
import 'package:study_vault/features/academic/data/repositories/academic_workspace_repository.dart';
import 'package:study_vault/features/academic/domain/models/models.dart';
import 'package:study_vault/features/onboarding/domain/models/onboarding_models.dart';
import 'package:study_vault/features/sync/data/repositories/outbox_repository.dart';
import 'package:study_vault/features/sync/domain/models/outbox_operation.dart';
import 'package:study_vault/features/sharing/domain/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;
  late LocalDbService localDb;
  late VaultRepository vaultRepo;
  late AcademicWorkspaceRepository academicRepo;
  late OutboxRepository outboxRepo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('study_vault_qa_test_');
    dbPath = '${tempDir.path}/qa_test.db';
    localDb = LocalDbService.instance;
    localDb.setCustomPathForTesting(dbPath);

    outboxRepo = OutboxRepository(localDb: localDb);
    vaultRepo = VaultRepository(localDb: localDb, outboxRepo: outboxRepo);
    academicRepo = AcademicWorkspaceRepository(localDb: localDb, outboxRepo: outboxRepo);
  });

  tearDown(() async {
    await localDb.closeForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase 10: Multi-User Data Isolation QA Tests', () {
    test('User A data is completely purged on logout; User B never sees User A records', () async {
      const userA = 'user_student_a';
      const userB = 'user_student_b';

      // Seed User A data
      final wsA = await academicRepo.createWorkspace(
        userId: userA,
        name: 'User A College',
        purpose: OnboardingPurpose.college,
      );
      final yearA = await academicRepo.createAcademicYear(
        userId: userA,
        workspaceId: wsA.id,
        yearName: '2026-27',
      );
      final periodA = await academicRepo.startNewPeriod(
        userId: userA,
        workspaceId: wsA.id,
        academicYearId: yearA.id,
        newPeriodName: 'Semester 3',
      );
      final subjA = await academicRepo.addSubject(
        userId: userA,
        periodId: periodA.id,
        name: 'Operating Systems',
        code: 'CS301',
      );
      await vaultRepo.createMaterial(
        userId: userA,
        workspaceId: wsA.id,
        academicPeriodId: periodA.id,
        subjectId: subjA.id,
        title: 'User A Private Notes',
        type: VaultMaterialType.note,
        content: 'Super confidential exam tips',
      );

      // Verify User A data exists
      final userAMaterials = await vaultRepo.getMaterials(userId: userA);
      expect(userAMaterials.length, 1);
      expect(userAMaterials.first.title, 'User A Private Notes');

      // User A logs out -> clearUserData is invoked
      await localDb.clearUserData(userA);

      // Verify User A data is completely wiped
      final purgedMaterials = await vaultRepo.getMaterials(userId: userA);
      expect(purgedMaterials, isEmpty);

      final db = await localDb.database;
      final outboxRowsA = await db.query('outbox_operations', where: 'user_id = ?', whereArgs: [userA]);
      expect(outboxRowsA, isEmpty);

      // User B logs in and queries their vault -> returns 0 items, User A's confidential notes are inaccessible
      final userBMaterials = await vaultRepo.getMaterials(userId: userB);
      expect(userBMaterials, isEmpty);
    });
  });

  group('Phase 10: Academic Workspaces, Semesters & Transitions QA Tests', () {
    test('College Workspace setup (B.E CSE 2026-27 Sem 3) creates correct hierarchy', () async {
      const userId = 'qa_college_user';

      final ws = await academicRepo.createWorkspace(
        userId: userId,
        name: 'College',
        purpose: OnboardingPurpose.college,
      );
      expect(ws.name, 'College');
      expect(ws.purpose, OnboardingPurpose.college);

      final year = await academicRepo.createAcademicYear(
        userId: userId,
        workspaceId: ws.id,
        yearName: '2026-27',
      );
      expect(year.yearName, '2026-27');

      final sem3 = await academicRepo.startNewPeriod(
        userId: userId,
        workspaceId: ws.id,
        academicYearId: year.id,
        newPeriodName: 'Semester 3',
      );
      expect(sem3.name, 'Semester 3');
      expect(sem3.isCurrent, true);

      // Add 4 core subjects
      await academicRepo.addSubject(
        userId: userId,
        periodId: sem3.id,
        name: 'Operating Systems',
        code: 'CS301',
      );
      await academicRepo.addSubject(
        userId: userId,
        periodId: sem3.id,
        name: 'DBMS',
        code: 'CS302',
      );
      await academicRepo.addSubject(
        userId: userId,
        periodId: sem3.id,
        name: 'Computer Networks',
        code: 'CS303',
      );
      await academicRepo.addSubject(
        userId: userId,
        periodId: sem3.id,
        name: 'Mathematics',
        code: 'MA301',
      );

      final subjects = await academicRepo.getSubjectsForPeriod(sem3.id);
      expect(subjects.length, 4);
      final subjectNames = subjects.map((s) => s.name).toList();
      expect(subjectNames, containsAll(['Operating Systems', 'DBMS', 'Computer Networks', 'Mathematics']));
    });

    test('School Workspace setup does not leak college fields', () async {
      const userId = 'qa_school_user';

      final ws = await academicRepo.createWorkspace(
        userId: userId,
        name: 'School',
        purpose: OnboardingPurpose.school,
      );
      expect(ws.purpose, OnboardingPurpose.school);

      final year = await academicRepo.createAcademicYear(
        userId: userId,
        workspaceId: ws.id,
        yearName: '2026-27',
      );

      final class12 = await academicRepo.startNewPeriod(
        userId: userId,
        workspaceId: ws.id,
        academicYearId: year.id,
        newPeriodName: 'Class 12',
        periodType: AcademicPeriodType.classGrade,
      );

      await academicRepo.addSubject(
        userId: userId,
        periodId: class12.id,
        name: 'Computer Science',
      );

      final subjects = await academicRepo.getSubjectsForPeriod(class12.id);
      expect(subjects.length, 1);
      expect(subjects.first.name, 'Computer Science');
    });

    test('Personal Learning topics remain strictly isolated from College subjects', () async {
      const userId = 'qa_multi_ws_user';

      // 1. College Workspace
      final collegeWs = await academicRepo.createWorkspace(
        userId: userId,
        name: 'College',
        purpose: OnboardingPurpose.college,
      );
      final year = await academicRepo.createAcademicYear(
        userId: userId,
        workspaceId: collegeWs.id,
        yearName: '2026-27',
      );
      final sem = await academicRepo.startNewPeriod(
        userId: userId,
        workspaceId: collegeWs.id,
        academicYearId: year.id,
        newPeriodName: 'Semester 3',
      );
      await academicRepo.addSubject(
        userId: userId,
        periodId: sem.id,
        name: 'Operating Systems',
      );

      // 2. Personal Learning Workspace
      final personalWs = await academicRepo.createWorkspace(
        userId: userId,
        name: 'Personal Learning',
        purpose: OnboardingPurpose.personalLearning,
      );
      await academicRepo.addPersonalTopic(
        userId: userId,
        workspaceId: personalWs.id,
        name: 'Python',
      );
      await academicRepo.addPersonalTopic(
        userId: userId,
        workspaceId: personalWs.id,
        name: 'Flutter',
      );
      await academicRepo.addPersonalTopic(
        userId: userId,
        workspaceId: personalWs.id,
        name: 'Web Development',
      );

      // Verify college subjects stay inside College
      final collegeSubjects = await academicRepo.getSubjectsForPeriod(sem.id);
      expect(collegeSubjects.length, 1);
      expect(collegeSubjects.first.name, 'Operating Systems');

      // Verify personal topics stay inside Personal Learning
      final personalTopics = await academicRepo.getPersonalTopics(personalWs.id);
      expect(personalTopics.length, 3);
      final topicNames = personalTopics.map((t) => t.name).toList();
      expect(topicNames, containsAll(['Python', 'Flutter', 'Web Development']));
      expect(topicNames, isNot(contains('Operating Systems')));
    });

    test('Semester Transition & Historical Immutability (Sem 3 -> Sem 4)', () async {
      const userId = 'qa_sem_transition_user';

      final ws = await academicRepo.createWorkspace(
        userId: userId,
        name: 'College',
        purpose: OnboardingPurpose.college,
      );
      final year = await academicRepo.createAcademicYear(
        userId: userId,
        workspaceId: ws.id,
        yearName: '2026-27',
      );
      final sem3 = await academicRepo.startNewPeriod(
        userId: userId,
        workspaceId: ws.id,
        academicYearId: year.id,
        newPeriodName: 'Semester 3',
      );
      final osSubj = await academicRepo.addSubject(
        userId: userId,
        periodId: sem3.id,
        name: 'Operating Systems',
      );

      // Create materials in Sem 3
      final matSem3 = await vaultRepo.createMaterial(
        userId: userId,
        workspaceId: ws.id,
        academicPeriodId: sem3.id,
        subjectId: osSubj.id,
        title: 'OS Process Scheduling',
        type: VaultMaterialType.pdf,
        originalFileName: 'os_sched.pdf',
      );

      // Transition to Semester 4
      final sem4 = await academicRepo.startNewPeriod(
        userId: userId,
        workspaceId: ws.id,
        academicYearId: year.id,
        newPeriodName: 'Semester 4',
      );

      // Verify Sem 4 is current and Sem 3 is historical
      final activePeriod = await academicRepo.getCurrentPeriod(ws.id);
      expect(activePeriod?.id, sem4.id);
      expect(activePeriod?.name, 'Semester 4');

      // Verify Sem 3 materials remain intact and uncorrupted
      final sem3Materials = await vaultRepo.getMaterials(
        userId: userId,
        filter: MaterialFilter(academicPeriodId: sem3.id),
      );
      expect(sem3Materials.length, 1);
      expect(sem3Materials.first.id, matSem3.id);
      expect(sem3Materials.first.title, 'OS Process Scheduling');
    });
  });

  group('Phase 10: Vault, Folders, Labels & Title Decoupling QA Tests', () {
    test('Display title renaming decouples from physical original_file_name and storage_path', () async {
      const userId = 'qa_rename_user';

      final mat = await vaultRepo.createMaterial(
        userId: userId,
        title: 'Operating Systems — Unit 3 Notes',
        originalFileName: 'OS_Unit3_final.pdf',
        storagePath: 'materials/user123/OS_Unit3_final.pdf',
        type: VaultMaterialType.pdf,
      );

      expect(mat.title, 'Operating Systems — Unit 3 Notes');
      expect(mat.originalFileName, 'OS_Unit3_final.pdf');
      expect(mat.storagePath, 'materials/user123/OS_Unit3_final.pdf');

      // Rename display title
      await vaultRepo.renameMaterial(mat.id, 'OS Unit 3 Complete Revised');

      final updated = await vaultRepo.getMaterialById(mat.id);
      expect(updated, isNotNull);
      expect(updated!.title, 'OS Unit 3 Complete Revised');
      expect(updated.originalFileName, 'OS_Unit3_final.pdf');
      expect(updated.storagePath, 'materials/user123/OS_Unit3_final.pdf');
    });

    test('Folder Cycle and Self-Move Prevention throws ArgumentError', () async {
      const userId = 'qa_folder_user';

      final parentFolder = await vaultRepo.createFolder(
        userId: userId,
        name: 'Root Folder',
      );
      final subFolder = await vaultRepo.createFolder(
        userId: userId,
        name: 'Sub Folder',
        parentId: parentFolder.id,
      );

      // Attempting to move folder into itself must fail
      expect(
        () async => await vaultRepo.moveFolder(parentFolder.id, parentFolder.id),
        throwsA(isA<ArgumentError>()),
      );

      // Attempting to move parent folder into its child subfolder must fail
      expect(
        () async => await vaultRepo.moveFolder(parentFolder.id, subFolder.id),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Deleting a Label removes label association without deleting the underlying material', () async {
      const userId = 'qa_label_user';

      final mat = await vaultRepo.createMaterial(
        userId: userId,
        title: 'Exam Notes',
        type: VaultMaterialType.note,
      );

      final label1 = await vaultRepo.createLabel(userId: userId, name: 'Exam Prep');
      final label2 = await vaultRepo.createLabel(userId: userId, name: 'High Yield');

      await vaultRepo.setMaterialLabels(mat.id, [label1.id, label2.id]);

      var matLabels = await vaultRepo.getMaterialLabels(mat.id);
      expect(matLabels.length, 2);

      // Delete label1
      await vaultRepo.deleteLabel(label1.id);

      // Verify underlying material still exists!
      final existingMat = await vaultRepo.getMaterialById(mat.id);
      expect(existingMat, isNotNull);
      expect(existingMat!.title, 'Exam Notes');

      // Verify label2 is still attached, label1 is removed
      matLabels = await vaultRepo.getMaterialLabels(mat.id);
      expect(matLabels.length, 1);
      expect(matLabels.first.name, 'High Yield');
    });
  });

  group('Phase 10: Deduplication, Offline Outbox & Security QA Tests', () {
    test('Universal Import deduplication detects existing identical content hash', () async {
      const userId = 'qa_dedup_user';
      const fileHash = 'sha256_mock_hash_abc12345';

      await vaultRepo.createMaterial(
        userId: userId,
        title: 'Existing Unit 1 PDF',
        originalFileName: 'unit1.pdf',
        contentHash: fileHash,
        type: VaultMaterialType.pdf,
      );

      // Query if hash exists
      final duplicate = await vaultRepo.findDuplicateMaterial(userId: userId, contentHash: fileHash);
      expect(duplicate, isNotNull);
      expect(duplicate!.title, 'Existing Unit 1 PDF');

      // Non-existent hash returns null
      final nonExistent = await vaultRepo.findDuplicateMaterial(userId: userId, contentHash: 'non_existent_hash');
      expect(nonExistent, isNull);
    });

    test('Offline Outbox queues operations and applies exponential backoff on retry failure', () async {
      const userId = 'qa_outbox_user';

      await outboxRepo.enqueue(
        userId: userId,
        entityType: 'material',
        entityId: 'mat_test_001',
        operation: OutboxOperationType.create,
        payload: {'id': 'mat_test_001', 'title': 'Offline Study Guide'},
      );

      final pending = await outboxRepo.getPendingOperations(userId: userId);
      expect(pending.length, 1);
      expect(pending.first.status, OutboxStatus.pending);
      expect(pending.first.attemptCount, 0);

      // Record failure with custom error
      await outboxRepo.markFailed(
        pending.first.id,
        error: 'Network unreachable (503)',
      );

      final db = await localDb.database;
      final rows = await db.query('outbox_operations', where: 'id = ?', whereArgs: [pending.first.id]);
      expect(rows, isNotEmpty);
      final opRow = rows.first;
      expect(opRow['attempt_count'], 1);
      expect(opRow['status'], 'failed');
      expect(opRow['last_error'], contains('Network unreachable'));
      expect(opRow['next_retry_at'], isNotNull);
    });

    test('Negative Security Tests: Revoked and Expired shares are strictly rejected', () {
      final revokedShare = ShareItem(
        id: 'share_revoked',
        resourceId: 'res_001',
        resourceType: 'material',
        resourceTitle: 'OS Notes',
        ownerId: 'owner_user',
        recipientId: 'recipient_user',
        permissions: const {SharePermission.view},
        status: ShareStatus.revoked,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(revokedShare.isActive, false);
      expect(revokedShare.displayStatusText, 'Access Revoked');

      final expiredShare = ShareItem(
        id: 'share_expired',
        resourceId: 'res_002',
        resourceType: 'material',
        resourceTitle: 'OS Notes',
        ownerId: 'owner_user',
        recipientId: 'recipient_user',
        permissions: const {SharePermission.view},
        status: ShareStatus.active,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(expiredShare.isExpired, true);
      expect(expiredShare.isActive, false);
      expect(expiredShare.displayStatusText, 'Access Expired');
    });
  });
}
