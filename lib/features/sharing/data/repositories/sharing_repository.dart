import 'package:uuid/uuid.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/services/connectivity_service.dart';
import 'package:study_vault/features/vault/data/repositories/vault_repository.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';
import '../../domain/models/models.dart';
import '../sources/local_sharing_datasource.dart';
import '../sources/supabase_sharing_datasource.dart';

/// Exception thrown when an online network connection is required for permission granting.
class SharingOfflineException implements Exception {
  final String message;
  const SharingOfflineException([
    this.message = "You're offline. We'll keep your local changes safe, but sharing requires an internet connection.",
  ]);

  @override
  String toString() => message;
}

/// Exception thrown when attempting to share a resource that is already actively shared with the recipient.
class DuplicateShareException implements Exception {
  final ShareItem existingShare;
  final String message;

  DuplicateShareException(this.existingShare, [String? customMessage])
      : message = customMessage ??
            'Already shared with @${existingShare.recipientUsername ?? "student"}.';

  @override
  String toString() => message;
}

/// Central repository managing student-to-student sharing, group collaboration, and curated study packs.
class SharingRepository {
  final LocalSharingDataSource _localSource;
  final SupabaseSharingDataSource _remoteSource;
  final VaultRepository _vaultRepo;
  final ConnectivityService _connectivity;
  static const _uuid = Uuid();

  SharingRepository({
    LocalSharingDataSource? localSource,
    SupabaseSharingDataSource? remoteSource,
    VaultRepository? vaultRepo,
    ConnectivityService? connectivity,
  })  : _localSource = localSource ?? LocalSharingDataSource(),
        _remoteSource = remoteSource ?? SupabaseSharingDataSource(),
        _vaultRepo = vaultRepo ?? VaultRepository(),
        _connectivity = connectivity ?? ConnectivityService();

  Future<bool> _isOnline() async {
    final status = await _connectivity.checkStatus();
    return status == NetworkStatus.online;
  }

  // ===========================================================================
  // 1. STUDENT IDENTITY & SEARCH
  // ===========================================================================

  Future<StudentProfile?> getStudentProfile(String userId) async {
    final cached = await _localSource.getProfileById(userId);
    if (cached != null) return cached;

    if (await _isOnline()) {
      try {
        final remote = await _remoteSource.getProfile(userId);
        if (remote != null) {
          await _localSource.cacheProfile(remote);
          return remote;
        }
      } catch (_) {}
    }
    return cached;
  }

  Future<StudentProfile?> getStudentByUsername(String username) async {
    final clean = username.replaceAll('@', '').trim().toLowerCase();
    final cached = await _localSource.getProfileByUsername(clean);
    if (cached != null) return cached;

    if (await _isOnline()) {
      try {
        final remote = await _remoteSource.getProfileByUsername(clean);
        if (remote != null) {
          await _localSource.cacheProfile(remote);
          return remote;
        }
      } catch (_) {}
    }
    return cached;
  }

  Future<List<StudentProfile>> searchStudents({
    required String query,
    required String currentUserId,
  }) async {
    final clean = query.replaceAll('@', '').trim();
    if (clean.isEmpty) return [];

    if (await _isOnline()) {
      try {
        final remote = await _remoteSource.searchStudents(query: clean, currentUserId: currentUserId);
        if (remote.isNotEmpty) {
          await _localSource.cacheProfiles(remote);
          return remote;
        }
      } catch (_) {}
    }

    // Fallback to local cache
    return await _localSource.searchProfiles(clean);
  }

  Future<void> updatePublicProfile({
    required String userId,
    String? username,
    String? fullName,
    String? institution,
    String? degree,
    String? branch,
    String? semester,
    bool? isSearchable,
    String? allowGroupInvites,
  }) async {
    final cleanUsername = username?.replaceAll('@', '').trim().toLowerCase();

    // Update local cache immediately
    final existing = await _localSource.getProfileById(userId);
    final updated = (existing ?? StudentProfile(id: userId, username: cleanUsername ?? 'student', fullName: fullName ?? 'Scholar')).copyWith(
      username: cleanUsername,
      fullName: fullName,
      institution: institution,
      degree: degree,
      branch: branch,
      semester: semester,
      isSearchable: isSearchable,
      allowGroupInvites: allowGroupInvites,
      updatedAt: DateTime.now(),
    );
    await _localSource.cacheProfile(updated);

    if (await _isOnline()) {
      try {
        await _remoteSource.updateProfile(
          userId: userId,
          username: cleanUsername,
          fullName: fullName,
          institution: institution,
          degree: degree,
          branch: branch,
          semester: semester,
          isSearchable: isSearchable,
          allowGroupInvites: allowGroupInvites,
        );
      } catch (_) {}
    }
  }

  Future<SharingPrivacySettings> getPrivacySettings(String userId) async {
    final profile = await getStudentProfile(userId);
    if (profile == null) return const SharingPrivacySettings();
    return SharingPrivacySettings(
      isSearchable: profile.isSearchable,
      allowGroupInvites: profile.allowGroupInvites,
    );
  }

  Future<void> updatePrivacySettings(String userId, SharingPrivacySettings settings) async {
    await updatePublicProfile(
      userId: userId,
      isSearchable: settings.isSearchable,
      allowGroupInvites: settings.allowGroupInvites,
    );
  }

  // ===========================================================================
  // 2. MATERIAL SHARING & PERMISSIONS
  // ===========================================================================

  Future<ShareItem> shareMaterial({
    required String ownerId,
    required String recipientId,
    required String resourceId,
    String resourceType = 'material',
    Set<SharePermission> permissions = const {SharePermission.view},
    DateTime? expiresAt,
    String? message,
    String? ownerUsername,
    String? ownerName,
    String? recipientUsername,
    String? resourceTitle,
  }) async {
    if (!await _isOnline()) {
      throw const SharingOfflineException();
    }

    // Duplicate share prevention: check if an active unexpired share already exists
    final existing = await _remoteSource.findActiveShare(
          ownerId: ownerId,
          recipientId: recipientId,
          resourceId: resourceId,
        ) ??
        await _localSource.findActiveShare(
          ownerId: ownerId,
          recipientId: recipientId,
          resourceId: resourceId,
        );

    if (existing != null && existing.isActive) {
      throw DuplicateShareException(existing);
    }

    var finalOwnerUsername = ownerUsername;
    var finalOwnerName = ownerName;
    if (finalOwnerUsername == null) {
      final ownerProfile = await getStudentProfile(ownerId);
      finalOwnerUsername = ownerProfile?.username;
      finalOwnerName = ownerProfile?.fullName;
    }
    var finalRecipientUsername = recipientUsername;
    if (finalRecipientUsername == null) {
      final recipientProfile = await getStudentProfile(recipientId);
      finalRecipientUsername = recipientProfile?.username;
    }

    final shareId = _uuid.v4();
    final newShare = ShareItem(
      id: shareId,
      ownerId: ownerId,
      recipientId: recipientId,
      resourceType: resourceType,
      resourceId: resourceId,
      permissions: permissions,
      status: ShareStatus.active,
      message: message,
      ownerUsername: finalOwnerUsername,
      ownerName: finalOwnerName,
      recipientUsername: finalRecipientUsername,
      resourceTitle: resourceTitle ?? 'Academic Material',
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
    );

    // Persist remotely first (critical for security and recipient access)
    final savedShare = await _remoteSource.createShare(newShare);
    await _localSource.saveShare(savedShare);

    // Send in-app notification to recipient
    try {
      final notif = ShareNotification(
        id: _uuid.v4(),
        userId: recipientId,
        type: ShareNotificationType.materialShared,
        title: 'New material shared',
        message: '@${ownerUsername?.replaceAll('@', '') ?? "A student"} shared "$resourceTitle"',
        referenceId: savedShare.id,
        referenceType: resourceType,
        createdAt: DateTime.now(),
      );
      await _remoteSource.sendNotification(notif);
    } catch (_) {}

    return savedShare;
  }

  Future<List<ShareItem>> shareMultipleMaterials({
    required String ownerId,
    required String recipientId,
    required List<String> resourceIds,
    required Map<String, String> resourceTitles,
    Set<SharePermission> permissions = const {SharePermission.view},
    DateTime? expiresAt,
    String? message,
    String? ownerUsername,
    String? recipientUsername,
  }) async {
    if (!await _isOnline()) {
      throw const SharingOfflineException();
    }

    final results = <ShareItem>[];
    for (final resourceId in resourceIds) {
      try {
        final share = await shareMaterial(
          ownerId: ownerId,
          recipientId: recipientId,
          resourceId: resourceId,
          resourceTitle: resourceTitles[resourceId] ?? 'Material',
          permissions: permissions,
          expiresAt: expiresAt,
          message: message,
          ownerUsername: ownerUsername,
          recipientUsername: recipientUsername,
        );
        results.add(share);
      } catch (e) {
        // If duplicate or error on single item, continue sharing the rest
        if (e is! DuplicateShareException) rethrow;
      }
    }
    return results;
  }

  Future<List<ShareItem>> getSharedWithMe(String userId) async {
    if (await _isOnline()) {
      try {
        final remote = await _remoteSource.getSharedWithMe(userId);
        await _localSource.saveShares(remote);
        return remote;
      } catch (_) {}
    }
    return await _localSource.getSharedWithMe(userId);
  }

  Future<List<ShareItem>> getSharedByMe(String userId) async {
    if (await _isOnline()) {
      try {
        final remote = await _remoteSource.getSharedByMe(userId);
        await _localSource.saveShares(remote);
        return remote;
      } catch (_) {}
    }
    return await _localSource.getSharedByMe(userId);
  }

  Future<void> revokeShare(String shareId) async {
    if (!await _isOnline()) {
      throw const SharingOfflineException(
        "You're offline. Revoking access requires an internet connection to guarantee server security.",
      );
    }

    await _remoteSource.revokeShare(shareId);
    await _localSource.revokeShare(shareId);
  }

  Future<ShareItem?> getShareById(String shareId) async {
    return await _localSource.getShareById(shareId);
  }

  Future<void> updateSharePermission({
    required String shareId,
    required Set<SharePermission> permissions,
  }) async {
    if (!await _isOnline()) {
      throw const SharingOfflineException();
    }

    await _remoteSource.updateSharePermission(shareId: shareId, permissions: permissions);
    final existing = await _localSource.getShareById(shareId);
    if (existing != null) {
      await _localSource.saveShare(existing.copyWith(permissions: permissions));
    }
  }

  Future<void> removeSharedWithMe(String shareId) async {
    await _localSource.deleteShare(shareId);
  }

  // ===========================================================================
  // 3. SAVE COPY TO VAULT (SEPARATE OWNERSHIP & RELATIONAL INTEGRITY)
  // ===========================================================================

  /// Saves an independent copy of a shared material into recipient's Vault.
  /// Strictly preserves source metadata ('Shared by @username') while granting 100% independent ownership.
  Future<MaterialItem> saveCopyToVault({
    required ShareItem share,
    required String currentUserId,
    required String workspaceId,
    String? academicPeriodId,
    String? subjectId,
    String? folderId,
    List<String> labelIds = const [],
  }) async {
    if (!share.canSaveCopy) {
      throw Exception('Permission denied: The owner has not allowed saving a copy of this material.');
    }

    // Fetch original material metadata
    final db = await LocalDbService.instance.database;
    final origRows = await db.query('materials', where: 'id = ?', whereArgs: [share.resourceId]);
    MaterialItem original;
    if (origRows.isNotEmpty) {
      original = MaterialItem.fromMap(origRows.first);
    } else {
      // Create representative material from share information
      original = MaterialItem(
        id: share.resourceId,
        userId: share.ownerId,
        title: share.resourceTitle,
        type: VaultMaterialType.document,
        createdAt: share.createdAt,
        updatedAt: share.createdAt,
      );
    }

    final sourceString = 'Shared by @${share.ownerUsername?.replaceAll('@', '') ?? "scholar"}';
    final descriptionString = 'Copied from @${share.ownerUsername?.replaceAll('@', '') ?? "scholar"} • Original: ${share.resourceTitle}';

    final copyMaterial = await _vaultRepo.createMaterial(
      userId: currentUserId,
      workspaceId: workspaceId,
      academicPeriodId: academicPeriodId,
      subjectId: subjectId,
      folderId: folderId,
      title: original.title,
      description: descriptionString,
      originalFileName: original.originalFileName,
      type: original.type,
      content: original.content,
      filePath: original.filePath,
      storagePath: original.storagePath,
      mimeType: original.mimeType,
      fileSize: original.fileSize,
      remoteUrl: original.remoteUrl,
      source: sourceString,
      labelIds: labelIds,
    );

    return copyMaterial;
  }

  // ===========================================================================
  // 4. STUDY GROUPS
  // ===========================================================================

  Future<StudyGroup> createGroup({
    required String ownerId,
    required String name,
    String? description,
    String? ownerUsername,
  }) async {
    if (!await _isOnline()) {
      throw const SharingOfflineException(
        "You're offline. Creating a study group requires an internet connection.",
      );
    }

    final groupId = _uuid.v4();
    final group = await _remoteSource.createGroup(
      groupId: groupId,
      ownerId: ownerId,
      name: name,
      description: description,
    );

    final fullGroup = group.copyWith(ownerUsername: ownerUsername);
    await _localSource.saveGroup(fullGroup);
    await _localSource.saveGroupMember(
      GroupMember(
        id: _uuid.v4(),
        groupId: groupId,
        userId: ownerId,
        username: ownerUsername,
        role: GroupRole.owner,
        status: GroupMemberStatus.active,
        createdAt: DateTime.now(),
        joinedAt: DateTime.now(),
      ),
    );

    return fullGroup;
  }

  Future<List<StudyGroup>> getGroups(String userId) async {
    if (await _isOnline()) {
      try {
        final remote = await _remoteSource.getGroups(userId);
        await _localSource.saveGroups(remote);
        return remote;
      } catch (_) {}
    }
    return await _localSource.getGroupsForUser(userId);
  }

  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    if (await _isOnline()) {
      try {
        final remote = await _remoteSource.getGroupMembers(groupId);
        await _localSource.saveGroupMembers(remote);
        return remote;
      } catch (_) {}
    }
    return await _localSource.getGroupMembers(groupId);
  }

  Future<void> inviteMember({
    required String groupId,
    required String userId,
    required String invitedByUsername,
    required String groupName,
  }) async {
    if (!await _isOnline()) {
      throw const SharingOfflineException();
    }

    final memberId = _uuid.v4();
    await _remoteSource.inviteGroupMember(memberId: memberId, groupId: groupId, userId: userId);

    // Notify recipient
    try {
      final notif = ShareNotification(
        id: _uuid.v4(),
        userId: userId,
        type: ShareNotificationType.groupInvitation,
        title: 'Group Invitation',
        message: '@${invitedByUsername.replaceAll('@', '')} invited you to join "$groupName"',
        referenceId: groupId,
        referenceType: 'study_group',
        createdAt: DateTime.now(),
      );
      await _remoteSource.sendNotification(notif);
    } catch (_) {}
  }

  Future<void> respondToInvitation({
    required String groupId,
    required String userId,
    required bool accept,
  }) async {
    if (!await _isOnline()) {
      throw const SharingOfflineException();
    }

    await _remoteSource.respondToGroupInvitation(groupId: groupId, userId: userId, accept: accept);
  }

  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    if (!await _isOnline()) {
      throw const SharingOfflineException();
    }

    await _remoteSource.leaveGroup(groupId: groupId, userId: userId);
    await _localSource.removeGroupMember(groupId, userId);
  }

  Future<void> deleteGroup(String groupId) async {
    if (!await _isOnline()) {
      throw const SharingOfflineException();
    }

    await _remoteSource.deleteGroup(groupId);
    await _localSource.deleteGroup(groupId);
  }

  Future<GroupResource> shareMaterialToGroup({
    required String groupId,
    required String resourceId,
    required String resourceTitle,
    required String sharedBy,
    String? sharedByUsername,
    Set<SharePermission> permissions = const {SharePermission.view, SharePermission.saveCopy},
    DateTime? expiresAt,
  }) async {
    if (!await _isOnline()) {
      throw const SharingOfflineException();
    }

    final resource = GroupResource(
      id: _uuid.v4(),
      groupId: groupId,
      resourceId: resourceId,
      resourceType: 'material',
      sharedBy: sharedBy,
      sharedByUsername: sharedByUsername,
      resourceTitle: resourceTitle,
      permissions: permissions,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
    );

    await _remoteSource.shareToGroup(resource);
    await _localSource.saveGroupResource(resource);
    return resource;
  }

  Future<List<GroupResource>> getGroupResources(String groupId) async {
    if (await _isOnline()) {
      try {
        final remote = await _remoteSource.getGroupResources(groupId);
        await _localSource.saveGroupResources(remote);
        return remote;
      } catch (_) {}
    }
    return await _localSource.getGroupResources(groupId);
  }

  // ===========================================================================
  // 5. STUDY PACKS
  // ===========================================================================

  Future<StudyPack> createStudyPack({
    required String ownerId,
    required String name,
    String? description,
    required List<String> materialIds,
    required Map<String, String> materialTitles,
    required Map<String, String> materialTypes,
    String? ownerUsername,
  }) async {
    final packId = _uuid.v4();
    final items = <StudyPackItem>[];
    for (int i = 0; i < materialIds.length; i++) {
      final mId = materialIds[i];
      items.add(
        StudyPackItem(
          id: _uuid.v4(),
          studyPackId: packId,
          materialId: mId,
          materialTitle: materialTitles[mId] ?? 'Material',
          materialType: materialTypes[mId] ?? 'PDF',
          orderIndex: i,
        ),
      );
    }

    final pack = StudyPack(
      id: packId,
      ownerId: ownerId,
      ownerUsername: ownerUsername,
      name: name,
      description: description,
      itemCount: items.length,
      items: items,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _localSource.saveStudyPack(pack);

    if (await _isOnline()) {
      try {
        await _remoteSource.createStudyPack(pack);
      } catch (_) {}
    }

    return pack;
  }

  Future<List<StudyPack>> getStudyPacks(String userId) async {
    if (await _isOnline()) {
      try {
        final remote = await _remoteSource.getStudyPacks(userId);
        await _localSource.saveStudyPacks(remote);
        return remote;
      } catch (_) {}
    }
    return await _localSource.getStudyPacksForUser(userId);
  }

  /// Alias for retrieving packs belonging to or created by a user.
  Future<List<StudyPack>> getMyStudyPacks(String userId) => getStudyPacks(userId);

  Future<StudyPack?> getStudyPackDetails(String packId) async {
    return await _localSource.getStudyPackById(packId);
  }

  Future<void> saveStudyPackToVault({
    required StudyPack pack,
    required String currentUserId,
    required String workspaceId,
    String? academicPeriodId,
    String? subjectId,
    String? folderId,
  }) async {
    for (final item in pack.items) {
      final dummyShare = ShareItem(
        id: _uuid.v4(),
        ownerId: pack.ownerId,
        ownerUsername: pack.ownerUsername,
        resourceId: item.materialId,
        resourceTitle: item.materialTitle,
        permissions: const {SharePermission.view, SharePermission.saveCopy},
        createdAt: DateTime.now(),
      );

      try {
        await saveCopyToVault(
          share: dummyShare,
          currentUserId: currentUserId,
          workspaceId: workspaceId,
          academicPeriodId: academicPeriodId,
          subjectId: subjectId,
          folderId: folderId,
        );
      } catch (_) {}
    }
  }

  // ===========================================================================
  // 6. COLLABORATION NOTIFICATIONS
  // ===========================================================================

  Future<List<ShareNotification>> getNotifications(String userId) async {
    if (await _isOnline()) {
      try {
        final remote = await _remoteSource.getNotifications(userId);
        await _localSource.saveNotifications(remote);
        return remote;
      } catch (_) {}
    }
    return await _localSource.getNotificationsForUser(userId);
  }

  Future<void> markNotificationAsRead(String id) async {
    await _localSource.markNotificationAsRead(id);
    if (await _isOnline()) {
      try {
        await _remoteSource.markNotificationAsRead(id);
      } catch (_) {}
    }
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    await _localSource.markAllNotificationsAsRead(userId);
    if (await _isOnline()) {
      try {
        await _remoteSource.markAllNotificationsAsRead(userId);
      } catch (_) {}
    }
  }

  Future<int> getUnreadNotificationCount(String userId) async {
    return await _localSource.getUnreadNotificationCount(userId);
  }
}
