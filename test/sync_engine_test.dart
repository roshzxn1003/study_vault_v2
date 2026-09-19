import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/services/connectivity_service.dart';
import 'package:study_vault/features/academic/data/repositories/academic_workspace_repository.dart';
import 'package:study_vault/features/onboarding/domain/models/onboarding_models.dart';
import 'package:study_vault/features/auth/domain/entities/auth_user.dart';
import 'package:study_vault/features/auth/domain/repositories/auth_repository.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/sync/data/repositories/outbox_repository.dart';
import 'package:study_vault/features/sync/data/services/remote_sync_service.dart';
import 'package:study_vault/features/sync/data/services/sync_engine.dart';
import 'package:study_vault/features/sync/domain/models/outbox_operation.dart';
import 'package:study_vault/features/sync/domain/models/sync_state.dart';
import 'package:study_vault/features/sync/presentation/providers/sync_provider.dart';
import 'package:study_vault/features/sync/presentation/screens/storage_sync_screen.dart';
import 'package:study_vault/features/sync/presentation/widgets/offline_banner.dart';
import 'package:study_vault/features/vault/data/repositories/vault_repository.dart';
import 'package:study_vault/features/vault/domain/models/material_item.dart';

class FakeAuthRepository implements AuthRepository {
  final AuthUser? _currentUser;
  FakeAuthRepository({AuthUser? user})
      : _currentUser = user ?? AuthUser(id: 'student_sync_user_1', email: 'test@vault.edu', fullName: 'Test User');

  @override
  AuthUser? getCurrentUser() => _currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<void> signUp({required String email, required String password, required String fullName}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resetPassword({required String email}) async {}

  @override
  Future<void> signInWithGoogle({String? redirectTo}) async {}
}

/// Test implementation of RemoteSyncService to verify push, pull, and file operations.
class MockRemoteSyncService implements RemoteSyncService {
  final List<({String entityType, OutboxOperationType operation, String entityId, Map<String, dynamic>? payload})> pushedEntities = [];
  final Map<String, List<Map<String, dynamic>>> pullData = {};
  bool shouldFailPush = false;
  bool shouldFailUpload = false;

  @override
  Future<void> pushEntity({
    required String entityType,
    required OutboxOperationType operation,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    if (shouldFailPush) {
      throw Exception('Simulated push error to remote Supabase server');
    }
    pushedEntities.add((
      entityType: entityType,
      operation: operation,
      entityId: entityId,
      payload: payload,
    ));
  }

  @override
  Future<List<Map<String, dynamic>>> pullEntities({
    required String entityType,
    required String userId,
    DateTime? since,
  }) async {
    return pullData[entityType] ?? [];
  }

  @override
  Future<({String storagePath, String? remoteUrl})> uploadMaterialFile({
    required String userId,
    required String materialId,
    required File file,
    required String fileName,
  }) async {
    if (shouldFailUpload) {
      throw Exception('Simulated upload failure to Supabase Storage');
    }
    return (
      storagePath: '$userId/${materialId}_$fileName',
      remoteUrl: 'https://supabase.example.com/storage/v1/object/public/study_materials/$userId/${materialId}_$fileName',
    );
  }
}

class FakeSyncNotifier extends StateNotifier<SyncState> implements SyncNotifier {
  FakeSyncNotifier(super.state);

  void updateState(SyncState newState) {
    state = newState;
  }

  @override
  Future<void> syncNow() async {}

  @override
  Future<void> retryFailed() async {}

  @override
  Future<int> purgeSynced({Duration olderThan = const Duration(days: 7)}) async => 0;

  @override
  Future<StorageUsage> getStorageUsage() async => const StorageUsage(
        localDbBytes: 1024,
        localMaterialFilesBytes: 2048,
        remoteStorageBytes: 4096,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 8: Offline-First Storage, Cloud Sync & Outbox Unit Tests', () {
    late Directory tempDir;
    late LocalDbService localDb;
    late OutboxRepository outboxRepo;
    late AcademicWorkspaceRepository academicRepo;
    late VaultRepository vaultRepo;
    late MockRemoteSyncService mockRemote;
    late ConnectivityService mockConnectivity;
    late SyncEngine syncEngine;

    const testUserId = 'student_sync_user_1';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('study_vault_sync_tests_');
      localDb = LocalDbService.instance;
      localDb.setCustomPathForTesting('${tempDir.path}/test_sync.db');

      outboxRepo = OutboxRepository(localDb: localDb);
      academicRepo = AcademicWorkspaceRepository(localDb: localDb, outboxRepo: outboxRepo);
      vaultRepo = VaultRepository(localDb: localDb, outboxRepo: outboxRepo);

      mockRemote = MockRemoteSyncService();
      mockConnectivity = ConnectivityService();
      mockConnectivity.setOverrideStatusForTesting(NetworkStatus.online);

      syncEngine = SyncEngine(
        localDb: localDb,
        outboxRepo: outboxRepo,
        remoteService: mockRemote,
        connectivityService: mockConnectivity,
      );

      // Clean tables for fresh test isolation
      final db = await localDb.database;
      await db.delete('outbox_operations');
      await db.delete('sync_metadata');
      await db.delete('material_labels');
      await db.delete('materials');
      await db.delete('folders');
      await db.delete('labels');
      await db.delete('academic_subjects');
      await db.delete('academic_periods');
      await db.delete('academic_years');
      await db.delete('workspaces');
    });

    tearDown(() async {
      syncEngine.dispose();
      mockConnectivity.setOverrideStatusForTesting(null);
      await localDb.closeForTesting();
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    // =========================================================================
    // 1. LOCAL WRITES & AUTOMATIC OUTBOX MUTATION ENQUEUEING
    // =========================================================================
    test('1. Creating academic structures automatically enqueues outbox operations', () async {
      final ws = await academicRepo.createWorkspace(
        userId: testUserId,
        name: 'Computer Science Vault',
        purpose: OnboardingPurpose.college,
      );

      final year = await academicRepo.createAcademicYear(
        workspaceId: ws.id,
        userId: testUserId,
        yearName: '2026–27',
      );

      final period = await academicRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: testUserId,
        academicYearId: year.id,
        newPeriodName: 'Semester 5',
      );

      await academicRepo.addSubject(
        periodId: period.id,
        userId: testUserId,
        name: 'Distributed Systems',
      );

      final pendingOps = await outboxRepo.getPendingOperations(userId: testUserId);
      expect(pendingOps.length, greaterThanOrEqualTo(4));

      final types = pendingOps.map((op) => op.entityType).toList();
      expect(types, contains('workspace'));
      expect(types, contains('academic_year'));
      expect(types, contains('academic_period'));
      expect(types, contains('subject'));
    });

    test('2. Creating folders, materials, and labels in Vault enqueues outbox mutations', () async {
      final folder = await vaultRepo.createFolder(
        userId: testUserId,
        name: 'Lecture Slides',
      );

      await vaultRepo.createLabel(
        userId: testUserId,
        name: 'High Priority',
        colorHex: '#EF4444',
      );

      await vaultRepo.createMaterial(
        userId: testUserId,
        title: 'Paxos Consensus Overview',
        type: VaultMaterialType.note,
        content: 'Notes on Paxos and Raft algorithms.',
        folderId: folder.id,
      );

      final pendingOps = await outboxRepo.getPendingOperations(userId: testUserId);
      final types = pendingOps.map((op) => op.entityType).toList();

      expect(types, contains('folder'));
      expect(types, contains('label'));
      expect(types, contains('material'));
    });

    // =========================================================================
    // 2. OUTBOX MUTATION COALESCING
    // =========================================================================
    test('3. Outbox Coalescing: CREATE + UPDATE on same entity merges into single CREATE with updated payload', () async {
      final folder = await vaultRepo.createFolder(
        userId: testUserId,
        name: 'Old Folder Name',
      );

      // Verify pending outbox count is 1
      var ops = await outboxRepo.getPendingOperations(userId: testUserId);
      expect(ops.where((op) => op.entityId == folder.id).length, 1);
      expect(ops.first.payload?['name'], 'Old Folder Name');

      // Update folder
      await vaultRepo.renameFolder(folder.id, 'Renamed Folder Name');

      // Coalescing should preserve single CREATE operation with updated name
      ops = await outboxRepo.getPendingOperations(userId: testUserId);
      final folderOps = ops.where((op) => op.entityId == folder.id).toList();
      expect(folderOps.length, 1);
      expect(folderOps.first.operation, OutboxOperationType.create);
      expect(folderOps.first.payload?['name'], 'Renamed Folder Name');
    });

    test('4. Outbox Coalescing: CREATE + DELETE on unpublished entity cancels both outbox operations', () async {
      final folder = await vaultRepo.createFolder(
        userId: testUserId,
        name: 'Temporary Folder',
      );

      var ops = await outboxRepo.getPendingOperations(userId: testUserId);
      expect(ops.where((op) => op.entityId == folder.id).length, 1);

      // Now soft-delete before it ever synced
      await vaultRepo.deleteFolder(folder.id);

      // Coalescing: neither CREATE nor DELETE needs to be sent to remote backend!
      ops = await outboxRepo.getPendingOperations(userId: testUserId);
      expect(ops.where((op) => op.entityId == folder.id).isEmpty, isTrue);
    });

    // =========================================================================
    // 3. STRICT TOPOLOGICAL DEPENDENCY ORDERING
    // =========================================================================
    test('5. SyncEngine pushes outbox mutations in strict topological dependency order', () async {
      // Create entities out-of-order in time
      await vaultRepo.createLabel(
        userId: testUserId,
        name: 'Midterms',
        colorHex: '#3B82F6',
      );

      final ws = await academicRepo.createWorkspace(
        userId: testUserId,
        name: 'Engineering Workspace',
        purpose: OnboardingPurpose.college,
      );

      await vaultRepo.createFolder(
        userId: testUserId,
        workspaceId: ws.id,
        name: 'Algorithms',
      );

      final year = await academicRepo.createAcademicYear(
        workspaceId: ws.id,
        userId: testUserId,
        yearName: '2026–27',
      );

      await academicRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: testUserId,
        academicYearId: year.id,
        newPeriodName: 'Semester 6',
      );

      // Execute sync
      await syncEngine.syncAll(userId: testUserId);

      expect(mockRemote.pushedEntities, isNotEmpty);
      final pushedTypes = mockRemote.pushedEntities.map((e) => e.entityType).toList();

      // Verify strict dependency order:
      // workspace < academic_year < academic_period < folder < label
      final wsIdx = pushedTypes.indexOf('workspace');
      final yearIdx = pushedTypes.indexOf('academic_year');
      final periodIdx = pushedTypes.indexOf('academic_period');
      final folderIdx = pushedTypes.indexOf('folder');
      final labelIdx = pushedTypes.indexOf('label');

      expect(wsIdx, lessThan(yearIdx));
      expect(yearIdx, lessThan(periodIdx));
      expect(periodIdx, lessThan(folderIdx));
      expect(folderIdx, lessThan(labelIdx));
    });

    // =========================================================================
    // 4. SOFT DELETE BEHAVIOR
    // =========================================================================
    test('6. Soft delete marks deleted_at timestamp, hides from queries, and queues delete outbox mutation', () async {
      final mat = await vaultRepo.createMaterial(
        userId: testUserId,
        title: 'Draft Notes',
        type: VaultMaterialType.note,
        content: 'Rough draft to be deleted',
      );

      // Verify present in active list
      var materials = await vaultRepo.getMaterials(userId: testUserId);
      expect(materials.any((m) => m.id == mat.id), isTrue);

      // Perform soft delete
      await vaultRepo.deleteMaterial(mat.id);

      // Immediately filtered out from local queries
      materials = await vaultRepo.getMaterials(userId: testUserId);
      expect(materials.any((m) => m.id == mat.id), isFalse);

      // But row still exists in DB with deleted_at IS NOT NULL for syncing
      final db = await localDb.database;
      final rawRow = await db.query('materials', where: 'id = ?', whereArgs: [mat.id]);
      expect(rawRow.isNotEmpty, isTrue);
      expect(rawRow.first['deleted_at'], isNotNull);
    });

    // =========================================================================
    // 5. EXPONENTIAL BACKOFF & RETRY SCHEDULING
    // =========================================================================
    test('7. Push failures trigger exponential backoff retry scheduling', () async {
      await vaultRepo.createFolder(userId: testUserId, name: 'Retry Test Folder');

      // Make remote fail
      mockRemote.shouldFailPush = true;

      // Run sync
      await syncEngine.syncAll(userId: testUserId);

      // Outbox status should be failed with attempt_count = 1 and next_retry_at set in the future
      final counts = await outboxRepo.getCounts(userId: testUserId);
      expect(counts.failed, greaterThanOrEqualTo(1));

      final db = await localDb.database;
      final rows = await db.query('outbox_operations', where: 'user_id = ?', whereArgs: [testUserId]);
      final failedOp = rows.first;

      expect(failedOp['status'], 'failed');
      expect(failedOp['attempt_count'], 1);
      expect(failedOp['next_retry_at'], isNotNull);
    });

    test('8. retryAllFailed resets failed mutations to pending state with zero attempts', () async {
      await vaultRepo.createFolder(userId: testUserId, name: 'Backoff Folder');
      mockRemote.shouldFailPush = true;
      await syncEngine.syncAll(userId: testUserId);

      var counts = await outboxRepo.getCounts(userId: testUserId);
      expect(counts.failed, greaterThanOrEqualTo(1));

      // Reset failed mutations
      final resetCount = await outboxRepo.retryAllFailed(userId: testUserId);
      expect(resetCount, greaterThanOrEqualTo(1));

      counts = await outboxRepo.getCounts(userId: testUserId);
      expect(counts.failed, 0);
      expect(counts.pending, greaterThanOrEqualTo(1));

      // Fix mock and sync successfully
      mockRemote.shouldFailPush = false;
      await syncEngine.syncAll(userId: testUserId);

      counts = await outboxRepo.getCounts(userId: testUserId);
      expect(counts.pending, 0);
      expect(counts.failed, 0);
    });

    // =========================================================================
    // 6. INCREMENTAL PULL & LAST-WRITE-WINS (LWW) CONFLICT RESOLUTION
    // =========================================================================
    test('9. Remote pull updates local SQLite records when remote timestamp is newer (LWW)', () async {
      // 1. Create a folder locally
      final localFolder = await vaultRepo.createFolder(userId: testUserId, name: 'Local Original');
      await syncEngine.syncAll(userId: testUserId);

      // 2. Prepare mock remote record with a newer updated_at timestamp
      final newerTime = DateTime.now().add(const Duration(minutes: 5)).toIso8601String();
      mockRemote.pullData['folder'] = [
        {
          'id': localFolder.id,
          'user_id': testUserId,
          'name': 'Updated From Cloud Client',
          'parent_id': null,
          'created_at': localFolder.createdAt.toIso8601String(),
          'updated_at': newerTime,
          'deleted_at': null,
        }
      ];

      // 3. Sync to pull changes
      await syncEngine.syncAll(userId: testUserId);

      // 4. Verify local DB was updated
      final folders = await vaultRepo.getFolders(userId: testUserId);
      final updated = folders.firstWhere((f) => f.id == localFolder.id);
      expect(updated.name, 'Updated From Cloud Client');
    });

    test('10. Remote pull does NOT overwrite local record if an un-synced outbox mutation is pending locally', () async {
      // 1. Create folder and sync
      final folder = await vaultRepo.createFolder(userId: testUserId, name: 'Base Folder');
      await syncEngine.syncAll(userId: testUserId);

      // 2. Make local edit (enqueues pending outbox update)
      await vaultRepo.renameFolder(folder.id, 'Local High Priority Edit');

      // 3. Suppose remote sends another update with older timestamp (stale edit)
      final remoteTime = DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String();
      mockRemote.pullData['folder'] = [
        {
          'id': folder.id,
          'user_id': testUserId,
          'name': 'Stale Remote Edit',
          'parent_id': null,
          'created_at': folder.createdAt.toIso8601String(),
          'updated_at': remoteTime,
          'deleted_at': null,
        }
      ];

      // 4. Keep local outbox mutation pending by simulating push failure
      mockRemote.shouldFailPush = true;
      await syncEngine.syncAll(userId: testUserId);

      final folders = await vaultRepo.getFolders(userId: testUserId);
      final current = folders.firstWhere((f) => f.id == folder.id);
      expect(current.name, 'Local High Priority Edit');
    });

    // =========================================================================
    // 7. FILE STORAGE SYNC DECOUPLING
    // =========================================================================
    test('11. File upload decoupling: metadata sync proceeds even if physical file upload fails', () async {
      // Create a dummy local file
      final dummyFile = File('${tempDir.path}/test_upload.pdf');
      await dummyFile.writeAsString('Dummy PDF binary content for testing');

      final material = await vaultRepo.createMaterial(
        userId: testUserId,
        title: 'Lecture Slides Chapter 1',
        type: VaultMaterialType.pdf,
        filePath: dummyFile.path,
      );

      // Simulate file upload failure (e.g. flaky WiFi)
      mockRemote.shouldFailUpload = true;

      // Sync should catch file upload error gracefully without crashing metadata push
      await syncEngine.syncAll(userId: testUserId);

      // Material should still exist locally and metadata should be pushed
      final pushedMaterials = mockRemote.pushedEntities.where((e) => e.entityId == material.id);
      expect(pushedMaterials, isNotEmpty);
    });

    // =========================================================================
    // 8. MULTI-USER ISOLATION & CLEAR USER DATA
    // =========================================================================
    test('12. clearUserData purges all user data without affecting other users', () async {
      const userA = 'user_alice';
      const userB = 'user_bob';

      await academicRepo.createWorkspace(userId: userA, name: "Alice's Vault", purpose: OnboardingPurpose.college);
      await academicRepo.createWorkspace(userId: userB, name: "Bob's Vault", purpose: OnboardingPurpose.college);

      var aliceWs = await academicRepo.getWorkspaces(userA);
      var bobWs = await academicRepo.getWorkspaces(userB);
      expect(aliceWs.length, 1);
      expect(bobWs.length, 1);

      // Clear Alice's data on signout
      await localDb.clearUserData(userA);

      aliceWs = await academicRepo.getWorkspaces(userA);
      bobWs = await academicRepo.getWorkspaces(userB);

      expect(aliceWs.isEmpty, isTrue);
      expect(bobWs.length, 1);
      expect(bobWs.first.name, "Bob's Vault");
    });

    // =========================================================================
    // 9. STORAGE METRICS CALCULATOR
    // =========================================================================
    test('13. calculateStorageUsage tallies local SQLite size and remote cloud metrics', () async {
      await vaultRepo.createFolder(userId: testUserId, name: 'Usage Folder');
      final usage = await syncEngine.calculateStorageUsage(userId: testUserId);

      expect(usage.localDbBytes, greaterThan(0));
      expect(usage.totalLocalBytes, greaterThanOrEqualTo(usage.localDbBytes));
    });

    // =========================================================================
    // 10. PURGE SYNCED OPERATIONS
    // =========================================================================
    test('14. purgeSyncedOperations removes old synced mutations from outbox table', () async {
      await vaultRepo.createFolder(userId: testUserId, name: 'Purgeable Folder');

      // Sync successfully
      await syncEngine.syncAll(userId: testUserId);

      var counts = await outboxRepo.getCounts(userId: testUserId);
      expect(counts.pending, 0);

      // Purge all synced mutations
      final purged = await outboxRepo.purgeSyncedOperations(olderThan: const Duration(seconds: 0));
      expect(purged, greaterThanOrEqualTo(1));
    });

    // =========================================================================
    // 11. OFFLINE BANNER WIDGET TEST
    // =========================================================================
    testWidgets('15. OfflineBanner renders offline mode when disconnected and hides when online/idle', (tester) async {
      final fakeAuth = FakeAuthRepository();
      final notifier = FakeSyncNotifier(const SyncState());
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          outboxRepositoryProvider.overrideWithValue(outboxRepo),
          outboxCountsProvider.overrideWith((ref) => (pending: 0, failed: 0, syncing: 0, total: 0)),
          syncProvider.overrideWith((ref) => notifier),
        ],
      );
      addTearDown(container.dispose);

      // Initial state: online, idle -> banner is hidden (SizedBox.shrink)
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: OfflineBanner(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Offline Mode'), findsNothing);

      // Transition state to offline
      notifier.updateState(const SyncState(status: SyncStatus.offline, isOnline: false));
      await tester.pump();

      // Banner should now indicate offline mode
      expect(find.textContaining('Working offline'), findsOneWidget);
    });

    // =========================================================================
    // 12. STORAGE & SYNC SCREEN WIDGET TEST
    // =========================================================================
    testWidgets('16. StorageSyncScreen renders Cloud Synchronization, Outbox Queue, and Storage Breakdown', (tester) async {
      final fakeAuth = FakeAuthRepository();
      final notifier = FakeSyncNotifier(const SyncState(status: SyncStatus.synced, isOnline: true));
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          outboxRepositoryProvider.overrideWithValue(outboxRepo),
          outboxCountsProvider.overrideWith((ref) => (pending: 2, failed: 1, syncing: 0, total: 3)),
          storageUsageProvider.overrideWith((ref) => const StorageUsage(
                localDbBytes: 1024,
                localMaterialFilesBytes: 2048,
                remoteStorageBytes: 4096,
              )),
          syncProvider.overrideWith((ref) => notifier),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: StorageSyncScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Storage & Sync'), findsOneWidget);
      expect(find.text('Cloud Synchronization'), findsOneWidget);
      expect(find.text('Outbox Queue'), findsOneWidget);
      expect(find.text('Storage Breakdown'), findsOneWidget);
      expect(find.text('Sync Now'), findsOneWidget);
      expect(find.text('Purge Synced Outbox Logs'), findsOneWidget);
      expect(find.text('Retry Failed Mutations'), findsOneWidget);
    });
  });
}
