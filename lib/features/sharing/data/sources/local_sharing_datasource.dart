import 'package:sqflite/sqflite.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import '../../domain/models/models.dart';

/// Local SQLite data source for offline caching of student profiles, shares, groups, study packs, and notifications.
class LocalSharingDataSource {
  final LocalDbService _localDb;

  LocalSharingDataSource({LocalDbService? localDb})
      : _localDb = localDb ?? LocalDbService.instance;

  // ===========================================================================
  // 1. STUDENT PROFILES
  // ===========================================================================

  Future<void> cacheProfile(StudentProfile profile) async {
    final db = await _localDb.database;
    await db.insert('student_profiles', profile.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> cacheProfiles(List<StudentProfile> profiles) async {
    final db = await _localDb.database;
    final batch = db.batch();
    for (final p in profiles) {
      batch.insert('student_profiles', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<StudentProfile?> getProfileById(String id) async {
    final db = await _localDb.database;
    final rows = await db.query('student_profiles', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return StudentProfile.fromMap(rows.first);
  }

  Future<StudentProfile?> getProfileByUsername(String username) async {
    final clean = username.replaceAll('@', '').toLowerCase();
    final db = await _localDb.database;
    final rows = await db.query('student_profiles', where: 'LOWER(username) = ?', whereArgs: [clean]);
    if (rows.isEmpty) return null;
    return StudentProfile.fromMap(rows.first);
  }

  Future<List<StudentProfile>> searchProfiles(String query) async {
    final clean = query.replaceAll('@', '').toLowerCase().trim();
    if (clean.isEmpty) return [];
    final db = await _localDb.database;
    final rows = await db.query(
      'student_profiles',
      where: 'is_searchable = 1 AND (LOWER(username) LIKE ? OR LOWER(full_name) LIKE ?)',
      whereArgs: ['%$clean%', '%$clean%'],
      limit: 20,
    );
    return rows.map((r) => StudentProfile.fromMap(r)).toList();
  }

  // ===========================================================================
  // 2. SHARES
  // ===========================================================================

  Future<void> saveShare(ShareItem share) async {
    final db = await _localDb.database;
    await db.insert('shares', share.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveShares(List<ShareItem> shares) async {
    final db = await _localDb.database;
    final batch = db.batch();
    for (final s in shares) {
      batch.insert('shares', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<ShareItem>> getSharedWithMe(String userId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'shares',
      where: 'recipient_id = ? AND status != ?',
      whereArgs: [userId, 'revoked'],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => ShareItem.fromMap(r)).toList();
  }

  Future<List<ShareItem>> getSharedByMe(String userId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'shares',
      where: 'owner_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => ShareItem.fromMap(r)).toList();
  }

  Future<ShareItem?> getShareById(String shareId) async {
    final db = await _localDb.database;
    final rows = await db.query('shares', where: 'id = ?', whereArgs: [shareId]);
    if (rows.isEmpty) return null;
    return ShareItem.fromMap(rows.first);
  }

  Future<ShareItem?> findActiveShare({
    required String ownerId,
    required String recipientId,
    required String resourceId,
  }) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'shares',
      where: 'owner_id = ? AND recipient_id = ? AND resource_id = ? AND status = ? AND revoked_at IS NULL',
      whereArgs: [ownerId, recipientId, resourceId, 'active'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final share = ShareItem.fromMap(rows.first);
    if (share.isExpired) return null;
    return share;
  }

  Future<void> revokeShare(String shareId) async {
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'shares',
      {
        'status': ShareStatus.revoked.key,
        'revoked_at': now,
      },
      where: 'id = ?',
      whereArgs: [shareId],
    );
  }

  Future<void> deleteShare(String shareId) async {
    final db = await _localDb.database;
    await db.delete('shares', where: 'id = ?', whereArgs: [shareId]);
  }

  // ===========================================================================
  // 3. STUDY GROUPS & MEMBERS
  // ===========================================================================

  Future<void> saveGroup(StudyGroup group) async {
    final db = await _localDb.database;
    await db.insert('study_groups', group.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveGroups(List<StudyGroup> groups) async {
    final db = await _localDb.database;
    final batch = db.batch();
    for (final g in groups) {
      batch.insert('study_groups', g.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<StudyGroup>> getGroupsForUser(String userId) async {
    final db = await _localDb.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT g.* FROM study_groups g
      LEFT JOIN group_members m ON g.id = m.group_id
      WHERE g.owner_id = ? OR (m.user_id = ? AND m.status IN ('active', 'invited'))
      ORDER BY g.updated_at DESC
    ''', [userId, userId]);
    return rows.map((r) => StudyGroup.fromMap(r)).toList();
  }

  Future<StudyGroup?> getGroupById(String groupId) async {
    final db = await _localDb.database;
    final rows = await db.query('study_groups', where: 'id = ?', whereArgs: [groupId]);
    if (rows.isEmpty) return null;
    return StudyGroup.fromMap(rows.first);
  }

  Future<void> deleteGroup(String groupId) async {
    final db = await _localDb.database;
    await db.transaction((txn) async {
      await txn.delete('group_resources', where: 'group_id = ?', whereArgs: [groupId]);
      await txn.delete('group_members', where: 'group_id = ?', whereArgs: [groupId]);
      await txn.delete('study_groups', where: 'id = ?', whereArgs: [groupId]);
    });
  }

  Future<void> saveGroupMember(GroupMember member) async {
    final db = await _localDb.database;
    await db.insert('group_members', member.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveGroupMembers(List<GroupMember> members) async {
    final db = await _localDb.database;
    final batch = db.batch();
    for (final m in members) {
      batch.insert('group_members', m.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    final db = await _localDb.database;
    final rows = await db.query('group_members', where: 'group_id = ?', whereArgs: [groupId], orderBy: 'role ASC, created_at ASC');
    return rows.map((r) => GroupMember.fromMap(r)).toList();
  }

  Future<void> removeGroupMember(String groupId, String userId) async {
    final db = await _localDb.database;
    await db.delete('group_members', where: 'group_id = ? AND user_id = ?', whereArgs: [groupId, userId]);
  }

  // ===========================================================================
  // 4. GROUP RESOURCES
  // ===========================================================================

  Future<void> saveGroupResource(GroupResource resource) async {
    final db = await _localDb.database;
    await db.insert('group_resources', resource.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveGroupResources(List<GroupResource> resources) async {
    final db = await _localDb.database;
    final batch = db.batch();
    for (final r in resources) {
      batch.insert('group_resources', r.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<GroupResource>> getGroupResources(String groupId) async {
    final db = await _localDb.database;
    final rows = await db.query('group_resources', where: 'group_id = ?', whereArgs: [groupId], orderBy: 'created_at DESC');
    return rows.map((r) => GroupResource.fromMap(r)).toList();
  }

  Future<void> removeGroupResource(String resourceId) async {
    final db = await _localDb.database;
    await db.delete('group_resources', where: 'id = ?', whereArgs: [resourceId]);
  }

  // ===========================================================================
  // 5. STUDY PACKS & ITEMS
  // ===========================================================================

  Future<void> saveStudyPack(StudyPack pack) async {
    final db = await _localDb.database;
    await db.transaction((txn) async {
      await txn.insert('study_packs', pack.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      if (pack.items.isNotEmpty) {
        await txn.delete('study_pack_items', where: 'study_pack_id = ?', whereArgs: [pack.id]);
        for (final item in pack.items) {
          await txn.insert('study_pack_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<void> saveStudyPacks(List<StudyPack> packs) async {
    final db = await _localDb.database;
    final batch = db.batch();
    for (final p in packs) {
      batch.insert('study_packs', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<StudyPack>> getStudyPacksForUser(String userId) async {
    final db = await _localDb.database;
    final rows = await db.query('study_packs', where: 'owner_id = ?', whereArgs: [userId], orderBy: 'updated_at DESC');
    final packs = <StudyPack>[];
    for (final r in rows) {
      final packId = r['id'] as String;
      final itemRows = await db.query('study_pack_items', where: 'study_pack_id = ?', whereArgs: [packId], orderBy: 'order_index ASC');
      final items = itemRows.map((ir) => StudyPackItem.fromMap(ir)).toList();
      packs.add(StudyPack.fromMap(r, items: items));
    }
    return packs;
  }

  Future<StudyPack?> getStudyPackById(String packId) async {
    final db = await _localDb.database;
    final rows = await db.query('study_packs', where: 'id = ?', whereArgs: [packId]);
    if (rows.isEmpty) return null;
    final itemRows = await db.query('study_pack_items', where: 'study_pack_id = ?', whereArgs: [packId], orderBy: 'order_index ASC');
    final items = itemRows.map((ir) => StudyPackItem.fromMap(ir)).toList();
    return StudyPack.fromMap(rows.first, items: items);
  }

  Future<void> deleteStudyPack(String packId) async {
    final db = await _localDb.database;
    await db.transaction((txn) async {
      await txn.delete('study_pack_items', where: 'study_pack_id = ?', whereArgs: [packId]);
      await txn.delete('study_packs', where: 'id = ?', whereArgs: [packId]);
    });
  }

  // ===========================================================================
  // 6. SHARE NOTIFICATIONS
  // ===========================================================================

  Future<void> saveNotification(ShareNotification notification) async {
    final db = await _localDb.database;
    await db.insert('share_notifications', notification.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveNotifications(List<ShareNotification> notifications) async {
    final db = await _localDb.database;
    final batch = db.batch();
    for (final n in notifications) {
      batch.insert('share_notifications', n.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<ShareNotification>> getNotificationsForUser(String userId) async {
    final db = await _localDb.database;
    final rows = await db.query('share_notifications', where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
    return rows.map((r) => ShareNotification.fromMap(r)).toList();
  }

  Future<void> markNotificationAsRead(String id) async {
    final db = await _localDb.database;
    await db.update('share_notifications', {'is_read': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    final db = await _localDb.database;
    await db.update('share_notifications', {'is_read': 1}, where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<int> getUnreadNotificationCount(String userId) async {
    final db = await _localDb.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM share_notifications WHERE user_id = ? AND is_read = 0', [userId]),
    );
    return count ?? 0;
  }
}
