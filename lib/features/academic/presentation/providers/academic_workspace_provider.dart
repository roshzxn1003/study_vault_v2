import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/features/academic/data/repositories/academic_workspace_repository.dart';
import 'package:study_vault/features/academic/domain/models/models.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_state.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/sync/domain/models/sync_state.dart';
import 'package:study_vault/features/sync/presentation/providers/sync_provider.dart';

export 'academic_workspace_state.dart';

/// Provider for AcademicWorkspaceRepository.
final academicWorkspaceRepositoryProvider = Provider<AcademicWorkspaceRepository>((ref) {
  return AcademicWorkspaceRepository();
});

/// StateNotifier coordinating academic workspaces, periods, subjects, and topics.
class AcademicWorkspaceNotifier extends StateNotifier<AcademicWorkspaceState> {
  final AcademicWorkspaceRepository _repository;
  final Ref _ref;

  AcademicWorkspaceNotifier(this._repository, this._ref)
      : super(const AcademicWorkspaceState()) {
    init();

    // Re-bootstrap when background sync completes pulling cloud workspaces/subjects
    _ref.listen<SyncState>(syncProvider, (previous, current) {
      if ((previous?.status == SyncStatus.syncing ||
              previous?.status == SyncStatus.downloading ||
              previous?.status == SyncStatus.uploading) &&
          current.status == SyncStatus.synced) {
        debugPrint('[AcademicWorkspaceNotifier] Sync finished. Reloading workspaces from DB.');
        init();
      }
    });
  }

  String get _currentUserId {
    final authRepo = _ref.read(authRepositoryProvider);
    return authRepo.getCurrentUser()?.id ?? 'guest';
  }

  /// Bootstraps workspaces, academic history, current period, and active subjects.
  Future<void> init() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final userId = _currentUserId;

    try {
      await _repository.ensureInitialized(userId: userId);
      final workspaces = await _repository.getWorkspaces(userId);

      if (workspaces.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      // Default to active or first workspace, prioritizing workspaces with actual academic structure
      AcademicWorkspace activeWs;
      if (state.activeWorkspace != null &&
          workspaces.any((w) => w.id == state.activeWorkspace!.id)) {
        activeWs = state.activeWorkspace!;
      } else {
        activeWs = workspaces.first;
        for (final ws in workspaces) {
          final years = await _repository.getAcademicYears(ws.id);
          if (years.isNotEmpty) {
            activeWs = ws;
            break;
          }
        }
      }

      await _loadWorkspaceData(activeWs, workspaces);
    } catch (e) {
      debugPrint('Error initializing AcademicWorkspaceNotifier: $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }

  Future<void> _loadWorkspaceData(
    AcademicWorkspace activeWs,
    List<AcademicWorkspace> allWorkspaces,
  ) async {
    final structure = await _repository.getAcademicStructure(activeWs.id);
    final years = await _repository.getAcademicYears(activeWs.id);
    final currentPeriod = await _repository.getCurrentPeriod(activeWs.id);
    final history = await _repository.getAcademicHistory(activeWs.id);

    AcademicPeriodEntity? selectedPeriod = state.selectedPeriod;
    if (selectedPeriod == null ||
        !history.any((y) => y.periods.any((p) => p.period.id == selectedPeriod!.id))) {
      selectedPeriod = currentPeriod;
    }

    List<AcademicSubjectEntity> subjects = [];
    if (selectedPeriod != null) {
      subjects = await _repository.getSubjectsForPeriod(selectedPeriod.id);
    }

    List<PersonalTopicEntity> personalTopics = [];
    if (activeWs.purpose.id == 'personal_learning') {
      personalTopics = await _repository.getPersonalTopics(activeWs.id);
    }

    if (mounted) {
      state = state.copyWith(
        workspaces: allWorkspaces,
        activeWorkspace: activeWs,
        academicProfile: structure,
        academicYears: years,
        currentPeriod: currentPeriod,
        selectedPeriod: selectedPeriod,
        subjects: subjects,
        personalTopics: personalTopics,
        history: history,
        isLoading: false,
        clearError: true,
      );
    }
  }

  /// Switches active workspace (e.g. College -> Personal Learning).
  Future<void> selectWorkspace(String workspaceId) async {
    final allWorkspaces = await _repository.getWorkspaces(_currentUserId);
    final ws = allWorkspaces.where((w) => w.id == workspaceId).firstOrNull ??
        allWorkspaces.firstOrNull ??
        state.activeWorkspace;
    if (ws == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    state = state.copyWith(workspaces: allWorkspaces, activeWorkspace: ws, selectedPeriod: null, isLoading: true);
    await _loadWorkspaceData(ws, allWorkspaces);
  }

  /// Switches the period being viewed (e.g. looking at previous Semester 3).
  Future<void> selectPeriod(String periodId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final period = await _repository.getPeriodById(periodId);
      if (period != null) {
        final subjects = await _repository.getSubjectsForPeriod(period.id);
        if (mounted) {
          state = state.copyWith(
            selectedPeriod: period,
            subjects: subjects,
            isLoading: false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }

  /// Transitions the workspace to a NEW academic period (e.g. Semester 4).
  ///
  /// CRITICAL RULES:
  /// - Old period becomes PREVIOUS (is_current = 0).
  /// - New period becomes CURRENT (is_current = 1).
  /// - Never moves or deletes previous subjects.
  /// - Optional subject copy creates BRAND NEW subject records.
  Future<bool> startNewSemester({
    required String newSemesterName,
    String? academicYearName,
    List<String>? subjectsToCopy,
  }) async {
    final activeWs = state.activeWorkspace;
    if (activeWs == null) return false;
    final userId = _currentUserId;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // 1. Resolve Academic Year
      String yearId;
      if (academicYearName != null && academicYearName.trim().isNotEmpty) {
        final yr = await _repository.createAcademicYear(
          workspaceId: activeWs.id,
          userId: userId,
          yearName: academicYearName.trim(),
          isCurrent: true,
        );
        yearId = yr.id;
      } else if (state.currentPeriod != null) {
        yearId = state.currentPeriod!.academicYearId;
      } else if (state.academicYears.isNotEmpty) {
        yearId = state.academicYears.first.id;
      } else {
        final yr = await _repository.createAcademicYear(
          workspaceId: activeWs.id,
          userId: userId,
          yearName: '2026–27',
          isCurrent: true,
        );
        yearId = yr.id;
      }

      // 2. Create New Period
      final newPeriod = await _repository.startNewPeriod(
        workspaceId: activeWs.id,
        userId: userId,
        academicYearId: yearId,
        newPeriodName: newSemesterName.trim(),
        periodType: state.isSchool ? AcademicPeriodType.classGrade : AcademicPeriodType.semester,
        subjectsToCopy: subjectsToCopy,
      );

      // 3. Reload full workspace data and select the new period
      state = state.copyWith(selectedPeriod: newPeriod);
      await _loadWorkspaceData(activeWs, state.workspaces);
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: e is ArgumentError ? e.message.toString() : e.toString(),
        );
      }
      return false;
    }
  }

  /// Manually switches which period is marked as CURRENT in the database.
  Future<void> switchCurrentPeriod(String targetPeriodId) async {
    final activeWs = state.activeWorkspace;
    if (activeWs == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.switchCurrentPeriod(
        workspaceId: activeWs.id,
        targetPeriodId: targetPeriodId,
      );
      final period = await _repository.getPeriodById(targetPeriodId);
      state = state.copyWith(selectedPeriod: period);
      await _loadWorkspaceData(activeWs, state.workspaces);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }

  /// Adds a new subject to the currently viewed academic period.
  Future<bool> addSubject({
    required String name,
    String? code,
    String? description,
  }) async {
    final targetPeriod = state.selectedPeriod ?? state.currentPeriod;
    if (targetPeriod == null) {
      state = state.copyWith(errorMessage: 'No active academic period selected.');
      return false;
    }

    try {
      await _repository.addSubject(
        periodId: targetPeriod.id,
        userId: _currentUserId,
        name: name,
        code: code,
        description: description,
      );

      // Refresh subjects for this period
      final updatedSubjects = await _repository.getSubjectsForPeriod(targetPeriod.id);
      final updatedHistory = await _repository.getAcademicHistory(targetPeriod.workspaceId);

      if (mounted) {
        state = state.copyWith(
          subjects: updatedSubjects,
          history: updatedHistory,
          clearError: true,
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          errorMessage: e is ArgumentError ? e.message.toString() : e.toString(),
        );
      }
      return false;
    }
  }

  /// Renames an existing subject with duplicate checking.
  Future<bool> renameSubject({
    required String subjectId,
    required String newName,
    String? code,
    String? description,
  }) async {
    try {
      await _repository.renameSubject(
        subjectId: subjectId,
        newName: newName,
        code: code,
        description: description,
      );

      if (state.selectedPeriod != null) {
        final updatedSubjects = await _repository.getSubjectsForPeriod(state.selectedPeriod!.id);
        if (mounted) {
          state = state.copyWith(subjects: updatedSubjects, clearError: true);
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          errorMessage: e is ArgumentError ? e.message.toString() : e.toString(),
        );
      }
      return false;
    }
  }

  /// Safely archives a subject.
  Future<void> removeSubject(String subjectId) async {
    final targetPeriod = state.selectedPeriod ?? state.currentPeriod;
    try {
      await _repository.removeSubject(subjectId);
      if (targetPeriod != null) {
        final updatedSubjects = await _repository.getSubjectsForPeriod(targetPeriod.id);
        final updatedHistory = await _repository.getAcademicHistory(targetPeriod.workspaceId);
        if (mounted) {
          state = state.copyWith(
            subjects: updatedSubjects,
            history: updatedHistory,
            clearError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(errorMessage: e.toString());
      }
    }
  }

  /// Reorders subjects.
  Future<void> reorderSubjects(int oldIndex, int newIndex) async {
    final targetPeriod = state.selectedPeriod ?? state.currentPeriod;
    if (targetPeriod == null) return;

    final list = List<AcademicSubjectEntity>.from(state.subjects);
    if (oldIndex < 0 || oldIndex >= list.length || newIndex < 0 || newIndex >= list.length) return;

    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(subjects: list);

    final ids = list.map((s) => s.id).toList();
    await _repository.reorderSubjects(periodId: targetPeriod.id, orderedSubjectIds: ids);
  }

  // ===========================================================================
  // PERSONAL TOPICS
  // ===========================================================================

  /// Adds a personal learning topic.
  Future<bool> addPersonalTopic(String name, {String? description}) async {
    final activeWs = state.activeWorkspace;
    if (activeWs == null) return false;

    try {
      await _repository.addPersonalTopic(
        workspaceId: activeWs.id,
        userId: _currentUserId,
        name: name,
        description: description,
      );

      final updated = await _repository.getPersonalTopics(activeWs.id);
      if (mounted) {
        state = state.copyWith(personalTopics: updated, clearError: true);
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          errorMessage: e is ArgumentError ? e.message.toString() : e.toString(),
        );
      }
      return false;
    }
  }

  /// Renames a personal learning topic.
  Future<bool> renamePersonalTopic(String topicId, String newName) async {
    final activeWs = state.activeWorkspace;
    if (activeWs == null) return false;

    try {
      await _repository.renamePersonalTopic(topicId: topicId, newName: newName);
      final updated = await _repository.getPersonalTopics(activeWs.id);
      if (mounted) {
        state = state.copyWith(personalTopics: updated, clearError: true);
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          errorMessage: e is ArgumentError ? e.message.toString() : e.toString(),
        );
      }
      return false;
    }
  }

  /// Removes a personal learning topic.
  Future<void> removePersonalTopic(String topicId) async {
    final activeWs = state.activeWorkspace;
    if (activeWs == null) return;

    try {
      await _repository.removePersonalTopic(topicId);
      final updated = await _repository.getPersonalTopics(activeWs.id);
      if (mounted) {
        state = state.copyWith(personalTopics: updated, clearError: true);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(errorMessage: e.toString());
      }
    }
  }

  /// Reorders personal learning topics.
  Future<void> reorderPersonalTopics(int oldIndex, int newIndex) async {
    final activeWs = state.activeWorkspace;
    if (activeWs == null) return;

    final list = List<PersonalTopicEntity>.from(state.personalTopics);
    if (oldIndex < 0 || oldIndex >= list.length || newIndex < 0 || newIndex >= list.length) return;

    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(personalTopics: list);

    final ids = list.map((t) => t.id).toList();
    await _repository.reorderPersonalTopics(workspaceId: activeWs.id, orderedTopicIds: ids);
  }

  // ===========================================================================
  // PROFILE & SETTINGS
  // ===========================================================================

  /// Updates academic profile metadata.
  Future<bool> updateProfile({
    String? institutionName,
    String? degree,
    String? branch,
    String? stream,
  }) async {
    final activeWs = state.activeWorkspace;
    final structureId = state.academicProfile?['id'] as String?;
    if (activeWs == null || structureId == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.updateAcademicProfile(
        structureId: structureId,
        institutionName: institutionName,
        degree: degree,
        branch: branch,
        stream: stream,
      );
      await _loadWorkspaceData(activeWs, state.workspaces);
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Global Riverpod Provider for Academic Workspace controller.
final academicWorkspaceProvider =
    StateNotifierProvider<AcademicWorkspaceNotifier, AcademicWorkspaceState>((ref) {
  final repo = ref.watch(academicWorkspaceRepositoryProvider);
  return AcademicWorkspaceNotifier(repo, ref);
});
