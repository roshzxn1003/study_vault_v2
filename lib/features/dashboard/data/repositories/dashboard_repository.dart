import 'package:flutter/foundation.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/dashboard/domain/models/dashboard_models.dart';

/// Read-only repository providing aggregated data for the main academic dashboard.
/// Strictly enforces non-destructive queries with zero fake data generation.
class DashboardRepository {
  final LocalDbService _localDb;

  DashboardRepository({LocalDbService? localDb})
      : _localDb = localDb ?? LocalDbService.instance;

  /// Counts real materials (files & notes) associated with each subject.
  Future<Map<String, int>> getSubjectMaterialCounts(List<String> subjectIds) async {
    if (subjectIds.isEmpty) return {};

    final result = <String, int>{};
    for (final id in subjectIds) {
      result[id] = 0;
    }

    try {
      final db = await _localDb.database;
      final placeholders = List.filled(subjectIds.length, '?').join(',');

      // Check materials table first (Phase 6 primary model)
      try {
        final matRows = await db.rawQuery(
          'SELECT subject_id, COUNT(*) as cnt FROM materials WHERE subject_id IN ($placeholders) AND is_archived = 0 GROUP BY subject_id',
          subjectIds,
        );
        if (matRows.isNotEmpty) {
          for (final row in matRows) {
            final sId = row['subject_id'] as String?;
            final count = (row['cnt'] as num?)?.toInt() ?? 0;
            if (sId != null && result.containsKey(sId)) {
              result[sId] = count;
            }
          }
          return result;
        }
      } catch (e) {
        debugPrint('Dashboard materials count query note: $e');
      }

      // Count matching files
      try {
        final fileRows = await db.rawQuery(
          'SELECT subject_id, COUNT(*) as cnt FROM files WHERE subject_id IN ($placeholders) GROUP BY subject_id',
          subjectIds,
        );
        for (final row in fileRows) {
          final sId = row['subject_id'] as String?;
          final count = (row['cnt'] as num?)?.toInt() ?? 0;
          if (sId != null && result.containsKey(sId)) {
            result[sId] = (result[sId] ?? 0) + count;
          }
        }
      } catch (e) {
        debugPrint('Files subject query fallback: $e');
      }

      // Count matching notes
      try {
        final noteRows = await db.rawQuery(
          'SELECT subject_id, COUNT(*) as cnt FROM notes WHERE subject_id IN ($placeholders) GROUP BY subject_id',
          subjectIds,
        );
        for (final row in noteRows) {
          final sId = row['subject_id'] as String?;
          final count = (row['cnt'] as num?)?.toInt() ?? 0;
          if (sId != null && result.containsKey(sId)) {
            result[sId] = (result[sId] ?? 0) + count;
          }
        }
      } catch (e) {
        debugPrint('Notes subject query fallback: $e');
      }
    } catch (e) {
      debugPrint('Error getting subject material counts: $e');
    }

    return result;
  }

  /// Retrieves the most recent real academic materials across files and notes.
  Future<List<DashboardRecentMaterial>> getRecentMaterials({
    required String userId,
    int limit = 5,
  }) async {
    final recentList = <DashboardRecentMaterial>[];

    try {
      final db = await _localDb.database;

      // Subject lookup map: id -> name
      final subjectMap = <String, String>{};
      try {
        final subjects = await db.query(
          'academic_subjects',
          columns: ['id', 'name'],
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        for (final s in subjects) {
          final id = s['id'] as String?;
          final name = s['name'] as String?;
          if (id != null && name != null) subjectMap[id] = name;
        }
      } catch (e) {
        debugPrint('Dashboard subjects query note: $e');
      }

      // Query recent materials (Phase 6 & 7)
      try {
        final mats = await db.query(
          'materials',
          where: 'user_id = ? AND is_archived = 0',
          whereArgs: [userId],
          orderBy: 'updated_at DESC',
          limit: limit,
        );

        for (final row in mats) {
          final id = row['id'] as String? ?? '';
          final title = row['title'] as String? ?? 'Untitled Material';
          final type = row['type'] as String? ?? 'PDF';
          final subjectId = row['subject_id'] as String?;
          final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();

          recentList.add(DashboardRecentMaterial(
            id: id,
            title: title,
            type: type,
            subjectName: subjectId != null ? subjectMap[subjectId] : null,
            createdAt: createdAt,
          ));
        }
      } catch (e) {
        debugPrint('Error querying recent materials: $e');
      }

      // Query recent files
      try {
        final files = await db.query(
          'files',
          where: 'user_id = ?',
          whereArgs: [userId],
          orderBy: 'created_at DESC',
          limit: limit,
        );

        for (final row in files) {
          final id = row['id'] as String? ?? '';
          final title = row['name'] as String? ?? 'Untitled Material';
          final type = row['file_type'] as String? ?? 'PDF';
          final subjectId = row['subject_id'] as String?;
          final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();

          recentList.add(DashboardRecentMaterial(
            id: id,
            title: title,
            type: type,
            subjectName: subjectId != null ? subjectMap[subjectId] : null,
            createdAt: createdAt,
          ));
        }
      } catch (e) {
        debugPrint('Error querying recent files: $e');
      }

      // Query recent notes
      try {
        final notes = await db.query(
          'notes',
          where: 'user_id = ?',
          whereArgs: [userId],
          orderBy: 'created_at DESC',
          limit: limit,
        );

        for (final row in notes) {
          final id = row['id'] as String? ?? '';
          final title = row['title'] as String? ?? 'Untitled Note';
          final subjectId = row['subject_id'] as String?;
          final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();

          recentList.add(DashboardRecentMaterial(
            id: id,
            title: title,
            type: 'Note',
            subjectName: subjectId != null ? subjectMap[subjectId] : null,
            createdAt: createdAt,
          ));
        }
      } catch (e) {
        debugPrint('Error querying recent notes: $e');
      }

      // Sort combined results chronologically descending
      recentList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (recentList.length > limit) {
        return recentList.sublist(0, limit);
      }
    } catch (e) {
      debugPrint('Error compiling recent materials: $e');
    }

    return recentList;
  }

  /// Retrieves unassigned/unfiled items pending organization in the Inbox.
  Future<({List<DashboardInboxItem> items, int totalCount})> getInboxPreview({
    required String userId,
    int limit = 4,
  }) async {
    final inboxItems = <DashboardInboxItem>[];
    int count = 0;

    try {
      final db = await _localDb.database;

      // 1. Query Phase 7 Inbox materials
      try {
        final inboxMaterials = await db.query(
          'materials',
          where: 'user_id = ? AND is_inbox = 1 AND is_archived = 0',
          whereArgs: [userId],
          orderBy: 'created_at DESC',
        );

        count += inboxMaterials.length;
        for (final row in inboxMaterials.take(limit)) {
          final id = row['id'] as String? ?? '';
          final title = row['title'] as String? ?? 'Pending Material';
          final type = row['type'] as String? ?? 'PDF';
          final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();

          inboxItems.add(DashboardInboxItem(
            id: id,
            title: title,
            type: type,
            createdAt: createdAt,
          ));
        }
      } catch (e) {
        debugPrint('Error querying inbox materials: $e');
      }

      // Unorganized files: subject_id IS NULL AND (folder_id IS NULL OR folder_id = '')
      try {
        final unorganizedFiles = await db.query(
          'files',
          where: 'user_id = ? AND (subject_id IS NULL OR subject_id = "") AND (folder_id IS NULL OR folder_id = "")',
          whereArgs: [userId],
          orderBy: 'created_at DESC',
        );

        count += unorganizedFiles.length;
        for (final row in unorganizedFiles.take(limit)) {
          final id = row['id'] as String? ?? '';
          final title = row['name'] as String? ?? 'Pending File';
          final type = row['file_type'] as String? ?? 'PDF';
          final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();

          inboxItems.add(DashboardInboxItem(
            id: id,
            title: title,
            type: type,
            createdAt: createdAt,
          ));
        }
      } catch (e) {
        debugPrint('Error querying unorganized files: $e');
      }

      // Unorganized notes: subject_id IS NULL AND (folder_id IS NULL OR folder_id = '')
      try {
        final unorganizedNotes = await db.query(
          'notes',
          where: 'user_id = ? AND (subject_id IS NULL OR subject_id = "") AND (folder_id IS NULL OR folder_id = "")',
          whereArgs: [userId],
          orderBy: 'created_at DESC',
        );

        count += unorganizedNotes.length;
        for (final row in unorganizedNotes.take(limit - inboxItems.length)) {
          final id = row['id'] as String? ?? '';
          final title = row['title'] as String? ?? 'Quick Note';
          final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();

          inboxItems.add(DashboardInboxItem(
            id: id,
            title: title,
            type: 'Note',
            createdAt: createdAt,
          ));
        }
      } catch (e) {
        debugPrint('Error querying unorganized notes: $e');
      }

      inboxItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('Error compiling inbox preview: $e');
    }

    return (items: inboxItems.take(limit).toList(), totalCount: count);
  }
}
