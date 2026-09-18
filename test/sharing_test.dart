import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/services/connectivity_service.dart';
import 'package:study_vault/features/sharing/data/repositories/sharing_repository.dart';
import 'package:study_vault/features/sharing/data/sources/local_sharing_datasource.dart';
import 'package:study_vault/features/sharing/domain/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/features/sharing/presentation/providers/sharing_providers.dart';
import 'package:study_vault/features/sharing/presentation/widgets/qr_discovery_modal.dart';
import 'package:study_vault/features/sharing/presentation/widgets/student_profile_preview_modal.dart';
import 'package:study_vault/features/vault/data/repositories/vault_repository.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';
import 'package:study_vault/features/vault/presentation/widgets/material_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 9: Domain Model Unit Tests', () {
    test('StudentProfile formats initials, clean usernames, QR payloads and serializes correctly', () {
      final profile = StudentProfile(
        id: 'student_123',
        username: 'arunroshan',
        fullName: 'Arun Roshan',
        institution: 'Anna University',
        degree: 'B.Tech CSE',
        isSearchable: true,
      );

      expect(profile.displayUsername, '@arunroshan');
      expect(profile.initial, 'A');
      expect(profile.publicAcademicSummary, 'B.Tech CSE');
      expect(profile.toQrPayload(), contains('studyvault://user/arunroshan'));

      final parsed = StudentProfile.parseQrPayload(profile.toQrPayload());
      expect(parsed, isNotNull);
      expect(parsed!['username'], 'arunroshan');
      expect(parsed['fullName'], 'Arun Roshan');

      final map = profile.toMap();
      expect(map['id'], 'student_123');
      expect(map['username'], 'arunroshan');
      expect(map['is_searchable'], 1);

      final fromMap = StudentProfile.fromMap(map);
      expect(fromMap.id, profile.id);
      expect(fromMap.username, profile.username);
      expect(fromMap.fullName, profile.fullName);
      expect(fromMap.isSearchable, true);
    });

    test('ShareItem permissions and expiry status calculations work accurately', () {
      final activeShare = ShareItem(
        id: 'share_1',
        ownerId: 'student_1',
        ownerUsername: 'student1',
        recipientId: 'student_2',
        recipientUsername: 'student2',
        resourceType: 'material',
        resourceId: 'mat_100',
        resourceTitle: 'Lecture 1 Operating Systems Notes',
        permissions: const {SharePermission.view, SharePermission.saveCopy},
        status: ShareStatus.active,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        expiresAt: DateTime.now().add(const Duration(days: 5)),
      );

      expect(activeShare.isActive, true);
      expect(activeShare.isRevoked, false);
      expect(activeShare.isExpired, false);
      expect(activeShare.hasPermission(SharePermission.view), true);
      expect(activeShare.hasPermission(SharePermission.saveCopy), true);
      expect(activeShare.hasPermission(SharePermission.download), false);

      final expiredShare = activeShare.copyWith(
        expiresAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      expect(expiredShare.isExpired, true);
      expect(expiredShare.isActive, false);

      final revokedShare = activeShare.copyWith(
        status: ShareStatus.revoked,
        revokedAt: DateTime.now(),
      );
      expect(revokedShare.isRevoked, true);
      expect(revokedShare.isActive, false);
    });

    test('StudyGroup and GroupMember permissions match collaboration roles', () {
      final now = DateTime.now();
      final group = StudyGroup(
        id: 'grp_algo',
        name: 'Algorithms Masters',
        description: 'Semester 4 Algorithms & Complexity discussion',
        ownerId: 'student_1',
        memberCount: 3,
        createdAt: now,
        updatedAt: now,
      );

      expect(group.name, 'Algorithms Masters');
      expect(group.memberCount, 3);
      expect(group.isOwner('student_1'), true);
      expect(group.isOwner('student_2'), false);

      final ownerMember = GroupMember(
        id: 'gm_1',
        groupId: group.id,
        userId: 'student_1',
        role: GroupRole.owner,
        status: GroupMemberStatus.active,
        createdAt: now,
        joinedAt: now,
      );

      expect(ownerMember.role, GroupRole.owner);
      expect(ownerMember.status, GroupMemberStatus.active);

      final peerMember = GroupMember(
        id: 'gm_2',
        groupId: group.id,
        userId: 'student_2',
        role: GroupRole.member,
        status: GroupMemberStatus.invited,
        createdAt: now,
      );

      expect(peerMember.role, GroupRole.member);
      expect(peerMember.status, GroupMemberStatus.invited);
    });

    test('StudyPack and StudyPackItem retain curated item order and metadata', () {
      final now = DateTime.now();
      final items = [
        const StudyPackItem(
          id: 'item_1',
          studyPackId: 'pack_finals',
          materialId: 'mat_1',
          materialTitle: 'Unit 1 Summary',
          materialType: 'DOCUMENT',
          orderIndex: 0,
        ),
        const StudyPackItem(
          id: 'item_2',
          studyPackId: 'pack_finals',
          materialId: 'mat_2',
          materialTitle: 'Unit 2 Cheatsheet',
          materialType: 'DOCUMENT',
          orderIndex: 1,
        ),
      ];

      final pack = StudyPack(
        id: 'pack_finals',
        name: 'OS Final Exam Revision Pack',
        description: 'Complete high-yield materials for end semester finals',
        ownerId: 'student_1',
        itemCount: 2,
        items: items,
        createdAt: now,
        updatedAt: now,
      );

      expect(pack.items.length, 2);
      expect(pack.items.first.materialTitle, 'Unit 1 Summary');
      expect(pack.items.last.orderIndex, 1);
    });

    test('ShareNotification tracks types, unread state and relative timestamps', () {
      final notif = ShareNotification(
        id: 'notif_1',
        userId: 'student_2',
        type: ShareNotificationType.materialShared,
        title: 'New Material Shared',
        message: '@arunroshan shared "Distributed Systems Chapter 4" with you.',
        referenceId: 'mat_dist_4',
        referenceType: 'material',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      expect(notif.isRead, false);
      expect(notif.type, ShareNotificationType.materialShared);

      final readNotif = notif.copyWith(isRead: true);
      expect(readNotif.isRead, true);
    });
  });

  group('Phase 9: SQLite Local Sharing DataSource Tests', () {
    late Directory tempDir;
    late LocalDbService localDb;
    late LocalSharingDataSource localSharing;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('study_vault_sharing_db_');
      localDb = LocalDbService.instance;
      localDb.setCustomPathForTesting('${tempDir.path}/test_sharing.db');
      localSharing = LocalSharingDataSource(localDb: localDb);

      final db = await localDb.database;
      await db.delete('student_profiles');
      await db.delete('shares');
      await db.delete('study_groups');
      await db.delete('group_members');
      await db.delete('group_resources');
      await db.delete('study_packs');
      await db.delete('study_pack_items');
      await db.delete('share_notifications');
    });

    tearDown(() async {
      await localDb.closeForTesting();
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('Store and retrieve student profiles and perform search query', () async {
      final p1 = StudentProfile(
        id: 's_1',
        username: 'alice_vault',
        fullName: 'Alice Walker',
        degree: 'Physics B.Sc',
        isSearchable: true,
      );
      final p2 = StudentProfile(
        id: 's_2',
        username: 'bob_secret',
        fullName: 'Bob Hidden',
        degree: 'Chemistry',
        isSearchable: false, // Private / not searchable
      );

      await localSharing.cacheProfile(p1);
      await localSharing.cacheProfile(p2);

      final fetched1 = await localSharing.getProfileById('s_1');
      expect(fetched1?.fullName, 'Alice Walker');

      final searchAlice = await localSharing.searchProfiles('alice');
      expect(searchAlice.length, 1);
      expect(searchAlice.first.username, 'alice_vault');

      // Hidden student should NOT appear in search results
      final searchBob = await localSharing.searchProfiles('bob');
      expect(searchBob.isEmpty, true);
    });

    test('Store shares, query shared with me / shared by me, and revoke share', () async {
      final share = ShareItem(
        id: 'sh_10',
        ownerId: 's_1',
        ownerUsername: 'alice_vault',
        recipientId: 's_2',
        recipientUsername: 'bob_secret',
        resourceType: 'material',
        resourceId: 'm_100',
        resourceTitle: 'Quantum Mechanics Notes',
        permissions: const {SharePermission.view, SharePermission.download},
        status: ShareStatus.active,
        createdAt: DateTime.now(),
      );

      await localSharing.saveShare(share);

      final withBob = await localSharing.getSharedWithMe('s_2');
      expect(withBob.length, 1);
      expect(withBob.first.resourceTitle, 'Quantum Mechanics Notes');

      final byAlice = await localSharing.getSharedByMe('s_1');
      expect(byAlice.length, 1);
      expect(byAlice.first.recipientUsername, 'bob_secret');

      // Revoke share
      await localSharing.revokeShare('sh_10');
      final updated = await localSharing.getShareById('sh_10');
      expect(updated?.status, ShareStatus.revoked);
      expect(updated?.revokedAt, isNotNull);
    });

    test('Store study groups, members, and group feed references', () async {
      final now = DateTime.now();
      final group = StudyGroup(
        id: 'grp_1',
        name: 'Theoretical Physics Cohort',
        ownerId: 's_1',
        createdAt: now,
        updatedAt: now,
      );
      await localSharing.saveGroup(group);

      final member = GroupMember(
        id: 'gm_1',
        groupId: 'grp_1',
        userId: 's_2',
        role: GroupRole.member,
        status: GroupMemberStatus.active,
        createdAt: now,
        joinedAt: now,
      );
      await localSharing.saveGroupMember(member);

      final res = GroupResource(
        id: 'gr_1',
        groupId: 'grp_1',
        resourceId: 'mat_relativity',
        resourceType: 'material',
        resourceTitle: 'Special Relativity Derivations',
        sharedBy: 's_1',
        createdAt: now,
      );
      await localSharing.saveGroupResource(res);

      final groupResources = await localSharing.getGroupResources('grp_1');
      expect(groupResources.length, 1);
      expect(groupResources.first.resourceTitle, 'Special Relativity Derivations');

      final members = await localSharing.getGroupMembers('grp_1');
      expect(members.length, 1);
      expect(members.first.userId, 's_2');

      // Member leaves group
      await localSharing.removeGroupMember('grp_1', 's_2');
      final remainingMembers = await localSharing.getGroupMembers('grp_1');
      expect(remainingMembers.isEmpty, true);
    });

    test('Store notifications, query unread count, and mark read', () async {
      final notif1 = ShareNotification(
        id: 'n_1',
        userId: 's_2',
        type: ShareNotificationType.materialShared,
        title: 'New Share',
        message: 'Material shared with you',
        isRead: false,
        createdAt: DateTime.now(),
      );
      final notif2 = ShareNotification(
        id: 'n_2',
        userId: 's_2',
        type: ShareNotificationType.groupInvitation,
        title: 'Group Invite',
        message: 'You were invited to a study group',
        isRead: false,
        createdAt: DateTime.now(),
      );

      await localSharing.saveNotification(notif1);
      await localSharing.saveNotification(notif2);

      var unread = await localSharing.getUnreadNotificationCount('s_2');
      expect(unread, 2);

      await localSharing.markNotificationAsRead('n_1');
      unread = await localSharing.getUnreadNotificationCount('s_2');
      expect(unread, 1);

      await localSharing.markAllNotificationsAsRead('s_2');
      unread = await localSharing.getUnreadNotificationCount('s_2');
      expect(unread, 0);
    });
  });

  group('Phase 9: Sharing Repository & Collaboration Workflow Tests', () {
    late Directory tempDir;
    late LocalDbService localDb;
    late VaultRepository vaultRepo;
    late ConnectivityService connectivity;
    late SharingRepository sharingRepo;
    const ownerId = 'user_owner';
    const recipientId = 'user_recipient';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('study_vault_repo_tests_');
      localDb = LocalDbService.instance;
      localDb.setCustomPathForTesting('${tempDir.path}/test_repo_sharing.db');

      vaultRepo = VaultRepository(localDb: localDb);
      connectivity = ConnectivityService();
      connectivity.setOverrideStatusForTesting(NetworkStatus.online);

      final localSource = LocalSharingDataSource(localDb: localDb);
      sharingRepo = SharingRepository(
        localSource: localSource,
        vaultRepo: vaultRepo,
        connectivity: connectivity,
      );

      final db = await localDb.database;
      await db.delete('student_profiles');
      await db.delete('shares');
      await db.delete('study_groups');
      await db.delete('group_members');
      await db.delete('group_resources');
      await db.delete('study_packs');
      await db.delete('study_pack_items');
      await db.delete('share_notifications');
      await db.delete('materials');
      await db.delete('folders');

      // Seed student profiles
      await sharingRepo.updatePublicProfile(
        userId: ownerId,
        username: 'alice_prof',
        fullName: 'Alice Professor',
        isSearchable: true,
      );
      await sharingRepo.updatePublicProfile(
        userId: recipientId,
        username: 'bob_student',
        fullName: 'Bob Student',
        isSearchable: true,
      );
    });

    tearDown(() async {
      await localDb.closeForTesting();
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('Offline sharing safeguard throws SharingOfflineException when disconnected', () async {
      connectivity.setOverrideStatusForTesting(NetworkStatus.offline);

      expect(
        () async => await sharingRepo.shareMaterial(
          ownerId: ownerId,
          recipientId: recipientId,
          resourceId: 'mat_1',
          resourceTitle: 'Notes',
        ),
        throwsA(isA<SharingOfflineException>()),
      );

      expect(
        () async => await sharingRepo.createGroup(
          ownerId: ownerId,
          name: 'Offline Group',
        ),
        throwsA(isA<SharingOfflineException>()),
      );
    });

    test('Material sharing creates active share and duplicate share is prevented', () async {
      final share = await sharingRepo.shareMaterial(
        ownerId: ownerId,
        recipientId: recipientId,
        resourceId: 'mat_os_1',
        resourceTitle: 'Operating Systems Scheduling Cheatsheet',
        permissions: const {SharePermission.view, SharePermission.saveCopy},
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        message: 'Here is the scheduling summary for review!',
      );

      expect(share.id, isNotEmpty);
      expect(share.resourceTitle, 'Operating Systems Scheduling Cheatsheet');
      expect(share.message, 'Here is the scheduling summary for review!');
      expect(share.status, ShareStatus.active);
      expect(share.expiresAt, isNotNull);

      // Attempting duplicate active share should throw DuplicateShareException
      expect(
        () async => await sharingRepo.shareMaterial(
          ownerId: ownerId,
          recipientId: recipientId,
          resourceId: 'mat_os_1',
          resourceTitle: 'Operating Systems Scheduling Cheatsheet',
        ),
        throwsA(isA<DuplicateShareException>()),
      );
    });

    test('Save Copy to Vault creates independent copy in recipient vault without mutating original', () async {
      // 1. Create original material in owner's vault
      final original = await vaultRepo.createMaterial(
        userId: ownerId,
        title: 'Compiler Design Dragon Book Summary',
        type: VaultMaterialType.document,
        content: 'Lexical analysis & syntax-directed translation.',
      );

      // 2. Share with recipient
      final share = await sharingRepo.shareMaterial(
        ownerId: ownerId,
        recipientId: recipientId,
        resourceId: original.id,
        resourceTitle: original.title,
        permissions: const {SharePermission.view, SharePermission.saveCopy},
      );

      // 3. Recipient saves copy to their personal vault
      final savedCopy = await sharingRepo.saveCopyToVault(
        share: share,
        currentUserId: recipientId,
        workspaceId: 'ws_recipient_college',
      );

      expect(savedCopy.id, isNot(original.id));
      expect(savedCopy.userId, recipientId);
      expect(savedCopy.title, original.title);
      expect(savedCopy.content, original.content);
      expect(savedCopy.source, contains('Shared by @alice_prof'));

      // 4. Revoke the share
      await sharingRepo.revokeShare(share.id);
      final revokedShare = await sharingRepo.getShareById(share.id);
      expect(revokedShare?.isRevoked, true);

      // 5. Verify recipient's copy is still completely intact in their vault
      final recipientVaultMaterials = await vaultRepo.getMaterials(userId: recipientId);
      expect(recipientVaultMaterials.any((m) => m.id == savedCopy.id), true);
    });

    test('Study Pack creation and batch save to vault copies all items', () async {
      // Create materials in owner's vault
      final m1 = await vaultRepo.createMaterial(
        userId: ownerId,
        title: 'Algorithms Part 1: Graph Traversal',
        type: VaultMaterialType.document,
      );
      final m2 = await vaultRepo.createMaterial(
        userId: ownerId,
        title: 'Algorithms Part 2: Dynamic Programming',
        type: VaultMaterialType.document,
      );

      final pack = await sharingRepo.createStudyPack(
        ownerId: ownerId,
        name: 'Algorithms Mastery Pack',
        description: 'Complete revision pack for algorithms lab exam',
        materialIds: [m1.id, m2.id],
        materialTitles: {
          m1.id: m1.title,
          m2.id: m2.title,
        },
        materialTypes: {
          m1.id: 'DOCUMENT',
          m2.id: 'DOCUMENT',
        },
      );

      expect(pack.items.length, 2);
      expect(pack.items[0].materialTitle, 'Algorithms Part 1: Graph Traversal');
      expect(pack.items[1].materialTitle, 'Algorithms Part 2: Dynamic Programming');

      // Batch save pack to recipient vault
      await sharingRepo.saveStudyPackToVault(
        pack: pack,
        currentUserId: recipientId,
        workspaceId: 'ws_recip',
      );

      final recipientMaterials = await vaultRepo.getMaterials(userId: recipientId);
      expect(recipientMaterials.length, 2);
      expect(recipientMaterials.any((m) => m.title == m1.title), true);
      expect(recipientMaterials.any((m) => m.title == m2.title), true);
    });
  });

  group('Phase 9: Collaboration UI & Widget Tests', () {
    testWidgets('StudentProfilePreviewModal displays public profile card safely', (tester) async {
      final profile = StudentProfile(
        id: 's_ui',
        username: 'samuel_scholar',
        fullName: 'Samuel Scholar',
        institution: 'Stanford University',
        degree: 'Master of Science in CS',
        isSearchable: true,
      );

      bool shareTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => StudentProfilePreviewModal.show(
                    context: ctx,
                    profile: profile,
                    onShare: () => shareTriggered = true,
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Samuel Scholar'), findsOneWidget);
      expect(find.text('@samuel_scholar'), findsOneWidget);
      expect(find.text('Master of Science in CS'), findsOneWidget);
      expect(find.text('Share Material'), findsOneWidget);

      await tester.tap(find.text('Share Material'));
      await tester.pumpAndSettle();
      expect(shareTriggered, true);
    });

    testWidgets('MaterialCard shows subtle privacy badge (Private vs Shared)', (tester) async {
      final privateMaterial = MaterialItem(
        id: 'mat_priv',
        userId: 'u_1',
        title: 'Personal Study Diary',
        type: VaultMaterialType.note,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final sharedMaterial = MaterialItem(
        id: 'mat_sh',
        userId: 'u_1',
        title: 'Distributed Systems Slides',
        type: VaultMaterialType.document,
        source: 'Shared by @arunroshan',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(height: 160, child: MaterialCard(material: privateMaterial)),
                SizedBox(height: 160, child: MaterialCard(material: sharedMaterial)),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Shared'), findsOneWidget);
    });

    testWidgets('QrDiscoveryModal renders QR payload and student preview notice', (tester) async {
      final profile = StudentProfile(
        id: 's_qr',
        username: 'test_student',
        fullName: 'Test Student',
        institution: 'MIT',
        degree: 'Computer Science',
        isSearchable: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentStudentProfileProvider.overrideWith((ref) => profile),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => QrDiscoveryModal.show(ctx),
                    child: const Text('Open QR'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open QR'));
      await tester.pumpAndSettle();

      expect(find.text('My Study Vault QR'), findsOneWidget);
      expect(find.text('Lookup Student'), findsOneWidget);
      expect(find.text('Test Student'), findsOneWidget);
      expect(find.textContaining('Zero credential exposure'), findsOneWidget);
      expect(find.text('Copy My @username'), findsOneWidget);
    });
  });
}
