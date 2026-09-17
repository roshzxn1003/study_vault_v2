import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/onboarding/domain/models/onboarding_models.dart';
import 'package:study_vault/features/onboarding/domain/models/onboarding_state.dart';
import 'package:uuid/uuid.dart';

/// Repository managing onboarding persistence, resume state, and workspace creation.
class OnboardingRepository {
  final LocalDbService _localDb;
  static const String _keyStatus = 'onboarding_status';
  static const String _keyDraft = 'onboarding_draft_data';
  static const String _keyLegacyCompleted = 'onboarding_completed';

  OnboardingRepository({LocalDbService? localDb})
      : _localDb = localDb ?? LocalDbService.instance;

  /// Loads the persisted onboarding state from disk.
  Future<OnboardingState> loadOnboardingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check explicit status or legacy boolean fallback
      final rawStatus = prefs.getString(_keyStatus);
      final legacyCompleted = prefs.getBool(_keyLegacyCompleted) ?? false;

      OnboardingStatus status;
      if (rawStatus != null) {
        status = OnboardingStatus.fromString(rawStatus);
      } else if (legacyCompleted) {
        status = OnboardingStatus.completed;
      } else {
        status = OnboardingStatus.notStarted;
      }

      // If in progress, restore draft state
      if (status == OnboardingStatus.inProgress) {
        final draftJsonStr = prefs.getString(_keyDraft);
        if (draftJsonStr != null && draftJsonStr.isNotEmpty) {
          try {
            final Map<String, dynamic> draftMap = jsonDecode(draftJsonStr);
            final restored = OnboardingState.fromJson(draftMap).copyWith(
              status: OnboardingStatus.inProgress,
              isLoaded: true,
            );
            return restored;
          } catch (e) {
            debugPrint('Failed to parse onboarding draft: $e');
          }
        }
      }

      return OnboardingState(
        status: status,
        isLoaded: true,
      );
    } catch (e) {
      debugPrint('Error reading onboarding status from preferences: $e');
      return const OnboardingState(
        status: OnboardingStatus.notStarted,
        isLoaded: true,
      );
    }
  }

  /// Saves the current in-progress onboarding state to support resuming.
  Future<void> saveDraft(OnboardingState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyStatus, OnboardingStatus.inProgress.toSerializedString());
      await prefs.setString(_keyDraft, jsonEncode(state.toJson()));
    } catch (e) {
      debugPrint('Error saving onboarding draft: $e');
    }
  }

  /// Clears any cached draft upon restart or reset.
  Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDraft);
      await prefs.setString(_keyStatus, OnboardingStatus.notStarted.toSerializedString());
      await prefs.setBool(_keyLegacyCompleted, false);
    } catch (e) {
      debugPrint('Error clearing onboarding draft: $e');
    }
  }

  /// Completes onboarding, marks state as completed, and provisions academic workspaces.
  Future<void> completeOnboarding({
    required String userId,
    required OnboardingState state,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStatus, OnboardingStatus.completed.toSerializedString());
    await prefs.setBool(_keyLegacyCompleted, true);
    await prefs.remove(_keyDraft);

    try {
      final db = await _localDb.database;
      final now = DateTime.now().toIso8601String();

      // 1. Ensure user has a workspace
      final existingWorkspaces = await db.query(
        'workspaces',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      String workspaceId;
      if (existingWorkspaces.isNotEmpty) {
        workspaceId = existingWorkspaces.first['id'] as String;
      } else {
        workspaceId = const Uuid().v4();
        await db.insert('workspaces', {
          'id': workspaceId,
          'user_id': userId,
          'name': 'My Study Vault',
          'created_at': now,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      // 2. College Workspace & Subjects
      if (state.isCollegeSelected && state.collegeData != null) {
        final c = state.collegeData!;
        final existingCollege = await db.query(
          'academic_structures',
          where: 'workspace_id = ? AND purpose = ?',
          whereArgs: [workspaceId, 'college'],
        );

        String structureId;
        if (existingCollege.isNotEmpty) {
          structureId = existingCollege.first['id'] as String;
          await db.update(
            'academic_structures',
            {
              'institution_name': c.institutionName,
              'degree': c.degree,
              'branch': c.branch,
              'academic_year': c.academicYear,
              'semester_or_class': c.semester,
            },
            where: 'id = ?',
            whereArgs: [structureId],
          );
        } else {
          structureId = const Uuid().v4();
          await db.insert('academic_structures', {
            'id': structureId,
            'workspace_id': workspaceId,
            'user_id': userId,
            'purpose': 'college',
            'institution_name': c.institutionName,
            'degree': c.degree,
            'branch': c.branch,
            'academic_year': c.academicYear,
            'semester_or_class': c.semester,
            'stream': null,
            'created_at': now,
          });
        }

        // Insert college subjects with duplicate check
        for (int i = 0; i < c.subjects.length; i++) {
          final subjectName = c.subjects[i].trim();
          if (subjectName.isEmpty) continue;

          final existingSubject = await db.query(
            'academic_subjects',
            where: 'academic_structure_id = ? AND LOWER(name) = ?',
            whereArgs: [structureId, subjectName.toLowerCase()],
          );

          if (existingSubject.isEmpty) {
            await db.insert('academic_subjects', {
              'id': const Uuid().v4(),
              'academic_structure_id': structureId,
              'user_id': userId,
              'name': subjectName,
              'order_index': i,
              'created_at': now,
            });
          }

          // Backing folder for document/vault integration
          final existingFolder = await db.query(
            'folders',
            where: 'user_id = ? AND LOWER(name) = ?',
            whereArgs: [userId, subjectName.toLowerCase()],
          );
          if (existingFolder.isEmpty) {
            await db.insert('folders', {
              'id': const Uuid().v4(),
              'user_id': userId,
              'name': subjectName,
              'parent_id': null,
              'created_at': now,
              'updated_at': now,
              'sync_status': 'synced',
            });
          }
        }
      }

      // 3. School Workspace & Subjects
      if (state.isSchoolSelected && state.schoolData != null) {
        final s = state.schoolData!;
        final existingSchool = await db.query(
          'academic_structures',
          where: 'workspace_id = ? AND purpose = ?',
          whereArgs: [workspaceId, 'school'],
        );

        String structureId;
        if (existingSchool.isNotEmpty) {
          structureId = existingSchool.first['id'] as String;
          await db.update(
            'academic_structures',
            {
              'institution_name': s.schoolName,
              'academic_year': s.academicYear,
              'semester_or_class': s.grade,
              'stream': s.stream,
            },
            where: 'id = ?',
            whereArgs: [structureId],
          );
        } else {
          structureId = const Uuid().v4();
          await db.insert('academic_structures', {
            'id': structureId,
            'workspace_id': workspaceId,
            'user_id': userId,
            'purpose': 'school',
            'institution_name': s.schoolName,
            'degree': null,
            'branch': null,
            'academic_year': s.academicYear,
            'semester_or_class': s.grade,
            'stream': s.stream,
            'created_at': now,
          });
        }

        for (int i = 0; i < s.subjects.length; i++) {
          final subjectName = s.subjects[i].trim();
          if (subjectName.isEmpty) continue;

          final existingSubject = await db.query(
            'academic_subjects',
            where: 'academic_structure_id = ? AND LOWER(name) = ?',
            whereArgs: [structureId, subjectName.toLowerCase()],
          );

          if (existingSubject.isEmpty) {
            await db.insert('academic_subjects', {
              'id': const Uuid().v4(),
              'academic_structure_id': structureId,
              'user_id': userId,
              'name': subjectName,
              'order_index': i,
              'created_at': now,
            });
          }

          final existingFolder = await db.query(
            'folders',
            where: 'user_id = ? AND LOWER(name) = ?',
            whereArgs: [userId, subjectName.toLowerCase()],
          );
          if (existingFolder.isEmpty) {
            await db.insert('folders', {
              'id': const Uuid().v4(),
              'user_id': userId,
              'name': subjectName,
              'parent_id': null,
              'created_at': now,
              'updated_at': now,
              'sync_status': 'synced',
            });
          }
        }
      }

      // 4. Personal Learning Workspace & Topics
      if (state.isPersonalLearningSelected && state.personalLearningData != null) {
        final p = state.personalLearningData!;
        final existingPl = await db.query(
          'academic_structures',
          where: 'workspace_id = ? AND purpose = ?',
          whereArgs: [workspaceId, 'personal_learning'],
        );

        String structureId;
        if (existingPl.isNotEmpty) {
          structureId = existingPl.first['id'] as String;
        } else {
          structureId = const Uuid().v4();
          await db.insert('academic_structures', {
            'id': structureId,
            'workspace_id': workspaceId,
            'user_id': userId,
            'purpose': 'personal_learning',
            'institution_name': null,
            'degree': null,
            'branch': null,
            'academic_year': null,
            'semester_or_class': null,
            'stream': null,
            'created_at': now,
          });
        }

        for (int i = 0; i < p.topics.length; i++) {
          final topicName = p.topics[i].trim();
          if (topicName.isEmpty) continue;

          final existingSubject = await db.query(
            'academic_subjects',
            where: 'academic_structure_id = ? AND LOWER(name) = ?',
            whereArgs: [structureId, topicName.toLowerCase()],
          );

          if (existingSubject.isEmpty) {
            await db.insert('academic_subjects', {
              'id': const Uuid().v4(),
              'academic_structure_id': structureId,
              'user_id': userId,
              'name': topicName,
              'order_index': i,
              'created_at': now,
            });
          }

          final existingFolder = await db.query(
            'folders',
            where: 'user_id = ? AND LOWER(name) = ?',
            whereArgs: [userId, topicName.toLowerCase()],
          );
          if (existingFolder.isEmpty) {
            await db.insert('folders', {
              'id': const Uuid().v4(),
              'user_id': userId,
              'name': topicName,
              'parent_id': null,
              'created_at': now,
              'updated_at': now,
              'sync_status': 'synced',
            });
          }
        }
      }
    } catch (e) {
      debugPrint('LocalDb error during onboarding complete: $e');
      // Do not rethrow raw exception; onboarding completion status is already marked in prefs.
    }
  }
}
