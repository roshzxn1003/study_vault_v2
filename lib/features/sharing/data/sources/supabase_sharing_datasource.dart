import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/models.dart';

/// Remote Supabase data source for collaborative sharing and permissions enforcement.
class SupabaseSharingDataSource {
  SupabaseClient? _client;

  // ignore: prefer_initializing_formals
  SupabaseSharingDataSource({SupabaseClient? client}) : _client = client;

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    try {
      if (Supabase.instance.isInitialized) {
        _client = Supabase.instance.client;
        return _client;
      }
    } catch (e) {
      debugPrint('SupabaseSharingDataSource: Supabase not initialized or error: $e');
    }
    return null;
  }

  // ===========================================================================
  // 1. PROFILES & DISCOVERY
  // ===========================================================================

  Future<StudentProfile?> getProfile(String userId) async {
    final client = _supabase;
    if (client == null) return null;
    final res = await client.from('profiles').select().eq('id', userId).maybeSingle();
    if (res == null) return null;
    return StudentProfile.fromMap(res);
  }

  Future<StudentProfile?> getProfileByUsername(String username) async {
    final client = _supabase;
    if (client == null) return null;
    final clean = username.replaceAll('@', '').trim().toLowerCase();
    final res = await client.from('profiles').select().ilike('username', clean).maybeSingle();
    if (res == null) return null;
    return StudentProfile.fromMap(res);
  }

  Future<List<StudentProfile>> searchStudents({
    required String query,
    required String currentUserId,
  }) async {
    final client = _supabase;
    if (client == null) return [];
    final clean = query.replaceAll('@', '').trim();
    if (clean.isEmpty) return [];

    // Search public profiles where is_searchable = true and not current user
    final res = await client
        .from('profiles')
        .select()
        .neq('id', currentUserId)
        .eq('is_searchable', true)
        .or('username.ilike.%$clean%,full_name.ilike.%$clean%')
        .limit(15);

    return (res as List).map((r) => StudentProfile.fromMap(r)).toList();
  }

  Future<void> updateProfile({
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
    final client = _supabase;
    if (client == null) return;

    final updates = <String, dynamic>{
      'id': userId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (username != null) updates['username'] = username.replaceAll('@', '').toLowerCase();
    if (fullName != null) updates['full_name'] = fullName;
    if (institution != null) updates['institution'] = institution;
    if (degree != null) updates['degree'] = degree;
    if (branch != null) updates['branch'] = branch;
    if (semester != null) updates['semester'] = semester;
    if (isSearchable != null) updates['is_searchable'] = isSearchable;
    if (allowGroupInvites != null) updates['allow_group_invites'] = allowGroupInvites;

    await client.from('profiles').upsert(updates);
  }

  // ===========================================================================
  // 2. SHARES
  // ===========================================================================

  Future<ShareItem?> findActiveShare({
    required String ownerId,
    required String recipientId,
    required String resourceId,
  }) async {
    final client = _supabase;
    if (client == null) return null;

    final res = await client
        .from('shares')
        .select()
        .eq('owner_id', ownerId)
        .eq('recipient_id', recipientId)
        .eq('resource_id', resourceId)
        .eq('status', 'active')
        .isFilter('revoked_at', null)
        .maybeSingle();

    if (res == null) return null;
    return ShareItem.fromMap(res);
  }

  Future<ShareItem> createShare(ShareItem share) async {
    final client = _supabase;
    if (client == null) return share;

    final data = {
      'id': share.id,
      'owner_id': share.ownerId,
      'recipient_id': share.recipientId,
      'resource_type': share.resourceType,
      'resource_id': share.resourceId,
      'permission': SharePermission.serializeSet(share.permissions),
      'status': share.status.key,
      'message': share.message,
      'created_at': share.createdAt.toIso8601String(),
      'expires_at': share.expiresAt?.toIso8601String(),
    };

    final res = await client.from('shares').insert(data).select().single();
    return ShareItem.fromMap(res).copyWith(
      ownerUsername: share.ownerUsername,
      ownerName: share.ownerName,
      recipientUsername: share.recipientUsername,
      resourceTitle: share.resourceTitle,
    );
  }

  Future<List<ShareItem>> getSharedWithMe(String userId) async {
    final client = _supabase;
    if (client == null) return [];

    final res = await client
        .from('shares')
        .select('''
          *,
          owner:owner_id (username, full_name),
          material:resource_id (title)
        ''')
        .eq('recipient_id', userId)
        .neq('status', 'revoked')
        .order('created_at', ascending: false);

    return (res as List).map((r) {
      final ownerMap = r['owner'] as Map<String, dynamic>?;
      final materialMap = r['material'] as Map<String, dynamic>?;

      return ShareItem.fromMap(r).copyWith(
        ownerUsername: ownerMap?['username'] as String?,
        ownerName: ownerMap?['full_name'] as String?,
        resourceTitle: materialMap?['title'] as String?,
      );
    }).toList();
  }

  Future<List<ShareItem>> getSharedByMe(String userId) async {
    final client = _supabase;
    if (client == null) return [];

    final res = await client
        .from('shares')
        .select('''
          *,
          recipient:recipient_id (username, full_name),
          material:resource_id (title)
        ''')
        .eq('owner_id', userId)
        .order('created_at', ascending: false);

    return (res as List).map((r) {
      final recipientMap = r['recipient'] as Map<String, dynamic>?;
      final materialMap = r['material'] as Map<String, dynamic>?;

      return ShareItem.fromMap(r).copyWith(
        recipientUsername: recipientMap?['username'] as String?,
        recipientName: recipientMap?['full_name'] as String?,
        resourceTitle: materialMap?['title'] as String?,
      );
    }).toList();
  }

  Future<void> revokeShare(String shareId) async {
    final client = _supabase;
    if (client == null) return;

    await client.from('shares').update({
      'status': 'revoked',
      'revoked_at': DateTime.now().toIso8601String(),
    }).eq('id', shareId);
  }

  Future<void> updateSharePermission({
    required String shareId,
    required Set<SharePermission> permissions,
  }) async {
    final client = _supabase;
    if (client == null) return;

    await client.from('shares').update({
      'permission': SharePermission.serializeSet(permissions),
    }).eq('id', shareId);
  }

  // ===========================================================================
  // 3. STUDY GROUPS
  // ===========================================================================

  Future<StudyGroup> createGroup({
    required String groupId,
    required String ownerId,
    required String name,
    String? description,
  }) async {
    final client = _supabase;
    final now = DateTime.now().toIso8601String();

    if (client != null) {
      await client.from('study_groups').insert({
        'id': groupId,
        'owner_id': ownerId,
        'name': name,
        'description': description,
        'created_at': now,
        'updated_at': now,
      });

      // Add owner as active owner member
      await client.from('group_members').insert({
        'group_id': groupId,
        'user_id': ownerId,
        'role': 'owner',
        'status': 'active',
        'created_at': now,
        'joined_at': now,
      });
    }

    return StudyGroup(
      id: groupId,
      ownerId: ownerId,
      name: name,
      description: description,
      memberCount: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<List<StudyGroup>> getGroups(String userId) async {
    final client = _supabase;
    if (client == null) return [];

    final res = await client
        .from('study_groups')
        .select('*, owner:owner_id (username)')
        .order('updated_at', ascending: false);

    return (res as List).map((r) {
      final ownerMap = r['owner'] as Map<String, dynamic>?;
      return StudyGroup.fromMap(r).copyWith(
        ownerUsername: ownerMap?['username'] as String?,
      );
    }).toList();
  }

  Future<void> inviteGroupMember({
    required String memberId,
    required String groupId,
    required String userId,
  }) async {
    final client = _supabase;
    if (client == null) return;

    await client.from('group_members').insert({
      'id': memberId,
      'group_id': groupId,
      'user_id': userId,
      'role': 'member',
      'status': 'invited',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> respondToGroupInvitation({
    required String groupId,
    required String userId,
    required bool accept,
  }) async {
    final client = _supabase;
    if (client == null) return;

    if (accept) {
      await client.from('group_members').update({
        'status': 'active',
        'joined_at': DateTime.now().toIso8601String(),
      }).eq('group_id', groupId).eq('user_id', userId);
    } else {
      await client.from('group_members').update({
        'status': 'declined',
      }).eq('group_id', groupId).eq('user_id', userId);
    }
  }

  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    final client = _supabase;
    if (client == null) return;

    await client.from('group_members').delete().eq('group_id', groupId).eq('user_id', userId);
  }

  Future<void> deleteGroup(String groupId) async {
    final client = _supabase;
    if (client == null) return;

    await client.from('study_groups').delete().eq('id', groupId);
  }

  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    final client = _supabase;
    if (client == null) return [];

    final res = await client
        .from('group_members')
        .select('*, profile:user_id (username, full_name)')
        .eq('group_id', groupId);

    return (res as List).map((r) {
      final profile = r['profile'] as Map<String, dynamic>?;
      return GroupMember.fromMap(r).copyWith(
        username: profile?['username'] as String?,
        fullName: profile?['full_name'] as String?,
      );
    }).toList();
  }

  Future<void> shareToGroup(GroupResource resource) async {
    final client = _supabase;
    if (client == null) return;

    await client.from('group_resources').insert({
      'id': resource.id,
      'group_id': resource.groupId,
      'resource_id': resource.resourceId,
      'resource_type': resource.resourceType,
      'shared_by': resource.sharedBy,
      'permission': SharePermission.serializeSet(resource.permissions),
      'created_at': resource.createdAt.toIso8601String(),
      'expires_at': resource.expiresAt?.toIso8601String(),
    });
  }

  Future<List<GroupResource>> getGroupResources(String groupId) async {
    final client = _supabase;
    if (client == null) return [];

    final res = await client
        .from('group_resources')
        .select('''
          *,
          sharer:shared_by (username),
          material:resource_id (title)
        ''')
        .eq('group_id', groupId)
        .order('created_at', ascending: false);

    return (res as List).map((r) {
      final sharer = r['sharer'] as Map<String, dynamic>?;
      final material = r['material'] as Map<String, dynamic>?;

      return GroupResource.fromMap(r).copyWith(
        sharedByUsername: sharer?['username'] as String?,
        resourceTitle: material?['title'] as String?,
      );
    }).toList();
  }

  // ===========================================================================
  // 4. STUDY PACKS
  // ===========================================================================

  Future<StudyPack> createStudyPack(StudyPack pack) async {
    final client = _supabase;
    if (client != null) {
      await client.from('study_packs').insert({
        'id': pack.id,
        'owner_id': pack.ownerId,
        'name': pack.name,
        'description': pack.description,
        'created_at': pack.createdAt.toIso8601String(),
        'updated_at': pack.updatedAt.toIso8601String(),
      });

      if (pack.items.isNotEmpty) {
        final itemsData = pack.items.map((it) => {
          'id': it.id,
          'study_pack_id': pack.id,
          'material_id': it.materialId,
          'order_index': it.orderIndex,
        }).toList();
        await client.from('study_pack_items').insert(itemsData);
      }
    }
    return pack;
  }

  Future<List<StudyPack>> getStudyPacks(String userId) async {
    final client = _supabase;
    if (client == null) return [];

    final res = await client
        .from('study_packs')
        .select('''
          *,
          owner:owner_id (username),
          items:study_pack_items (
            id, material_id, order_index,
            material:material_id (title, type)
          )
        ''')
        .eq('owner_id', userId)
        .order('updated_at', ascending: false);

    return (res as List).map((r) {
      final ownerMap = r['owner'] as Map<String, dynamic>?;
      final rawItems = (r['items'] as List?) ?? [];

      final items = rawItems.map((it) {
        final mat = it['material'] as Map<String, dynamic>?;
        return StudyPackItem(
          id: it['id']?.toString() ?? '',
          studyPackId: r['id']?.toString() ?? '',
          materialId: it['material_id']?.toString() ?? '',
          materialTitle: mat?['title']?.toString() ?? 'Material',
          materialType: mat?['type']?.toString() ?? 'PDF',
          orderIndex: (it['order_index'] as num?)?.toInt() ?? 0,
        );
      }).toList();

      return StudyPack.fromMap(r, items: items).copyWith(
        ownerUsername: ownerMap?['username'] as String?,
      );
    }).toList();
  }

  // ===========================================================================
  // 5. NOTIFICATIONS
  // ===========================================================================

  Future<void> sendNotification(ShareNotification notification) async {
    final client = _supabase;
    if (client == null) return;

    await client.from('share_notifications').insert({
      'id': notification.id,
      'user_id': notification.userId,
      'type': notification.type.key,
      'title': notification.title,
      'message': notification.message,
      'reference_id': notification.referenceId,
      'reference_type': notification.referenceType,
      'is_read': notification.isRead,
      'created_at': notification.createdAt.toIso8601String(),
    });
  }

  Future<List<ShareNotification>> getNotifications(String userId) async {
    final client = _supabase;
    if (client == null) return [];

    final res = await client
        .from('share_notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return (res as List).map((r) => ShareNotification.fromMap(r)).toList();
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final client = _supabase;
    if (client == null) return;
    await client.from('share_notifications').update({'is_read': true}).eq('id', notificationId);
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    final client = _supabase;
    if (client == null) return;
    await client.from('share_notifications').update({'is_read': true}).eq('user_id', userId);
  }
}

extension on GroupMember {
  GroupMember copyWith({String? username, String? fullName}) {
    return GroupMember(
      id: id,
      groupId: groupId,
      userId: userId,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      role: role,
      status: status,
      createdAt: createdAt,
      joinedAt: joinedAt,
    );
  }
}

extension on GroupResource {
  GroupResource copyWith({String? sharedByUsername, String? resourceTitle}) {
    return GroupResource(
      id: id,
      groupId: groupId,
      resourceId: resourceId,
      resourceType: resourceType,
      sharedBy: sharedBy,
      sharedByUsername: sharedByUsername ?? this.sharedByUsername,
      resourceTitle: resourceTitle ?? this.resourceTitle,
      permissions: permissions,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }
}
