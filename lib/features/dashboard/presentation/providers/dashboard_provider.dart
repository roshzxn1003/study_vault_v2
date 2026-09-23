import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:study_vault/features/dashboard/domain/models/dashboard_models.dart';
import 'package:study_vault/features/dashboard/presentation/providers/dashboard_state.dart';

export 'dashboard_state.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

class DashboardNotifier extends StateNotifier<DashboardState> {
  final DashboardRepository _repository;
  final Ref _ref;
  Future<void>? _initFuture;

  DashboardNotifier(this._repository, this._ref)
      : super(const DashboardState()) {
    Future.microtask(() => init());

    // Automatically update dashboard whenever academic workspace state changes (e.g. from sync or switch)
    _ref.listen<AcademicWorkspaceState>(academicWorkspaceProvider, (previous, current) {
      if (previous != current) {
        _syncWithAcademicState(current);
      }
    });
  }

  String get _currentUserId {
    final authRepo = _ref.read(authRepositoryProvider);
    return authRepo.getCurrentUser()?.id ?? 'guest';
  }

  String? get _currentUserFullName {
    final authRepo = _ref.read(authRepositoryProvider);
    return authRepo.getCurrentUser()?.fullName;
  }

  /// Bootstraps and coordinates dashboard data with academic workspace state.
  Future<void> init() {
    _initFuture ??= _performInit();
    return _initFuture!;
  }

  Future<void> _performInit() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final academicNotifier = _ref.read(academicWorkspaceProvider.notifier);
      await academicNotifier.init();

      final academicState = _ref.read(academicWorkspaceProvider);
      await _syncWithAcademicState(academicState);
    } catch (e) {
      debugPrint('Error initializing dashboard: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'We couldn\'t load your study space.',
        );
      }
    }
  }

  /// Synchronizes dashboard subjects, recent materials, and inbox with academic state.
  Future<void> _syncWithAcademicState(AcademicWorkspaceState academicState) async {
    final userId = _currentUserId;
    final fullName = _currentUserFullName;

    // 1. Fetch material counts for subjects
    final subjectIds = academicState.subjects.map((s) => s.id).toList();
    final countsMap = await _repository.getSubjectMaterialCounts(subjectIds);

    final subjectsWithCount = academicState.subjects.map((s) {
      return SubjectWithCount(
        subject: s,
        materialCount: countsMap[s.id] ?? 0,
      );
    }).toList();

    // 2. Fetch recent materials
    final recentMaterials = await _repository.getRecentMaterials(
      userId: userId,
      limit: 5,
    );

    // 3. Fetch inbox preview
    final inboxResult = await _repository.getInboxPreview(
      userId: userId,
      limit: 4,
    );

    if (mounted) {
      state = state.copyWith(
        activeWorkspace: academicState.activeWorkspace,
        workspaces: academicState.workspaces,
        currentPeriod: academicState.currentPeriod,
        selectedPeriod: academicState.selectedPeriod,
        history: academicState.history,
        academicProfile: academicState.academicProfile,
        subjects: subjectsWithCount,
        personalTopics: academicState.personalTopics,
        recentMaterials: recentMaterials,
        inboxItems: inboxResult.items,
        inboxTotalCount: inboxResult.totalCount,
        userFullName: fullName,
        isLoading: false,
        clearError: true,
      );
    }
  }

  /// Switches active academic period for viewing (e.g. browsing historical Semester 2).
  ///
  /// CRITICAL RULE: Purely updates visual view context without mutating `is_current`.
  Future<void> selectPeriod(String periodId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final academicNotifier = _ref.read(academicWorkspaceProvider.notifier);
      await academicNotifier.selectPeriod(periodId);
      final academicState = _ref.read(academicWorkspaceProvider);
      await _syncWithAcademicState(academicState);
    } catch (e) {
      debugPrint('Error switching viewing period: $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }

  /// Switches active workspace (e.g. College -> Personal Learning).
  Future<void> selectWorkspace(String workspaceId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final academicNotifier = _ref.read(academicWorkspaceProvider.notifier);
      await academicNotifier.selectWorkspace(workspaceId);
      final academicState = _ref.read(academicWorkspaceProvider);
      await _syncWithAcademicState(academicState);
    } catch (e) {
      debugPrint('Error switching workspace: $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }

  /// Pull-to-refresh reload handler.
  Future<void> refresh() async {
    _initFuture = null;
    final academicNotifier = _ref.read(academicWorkspaceProvider.notifier);
    await academicNotifier.init();
    final academicState = _ref.read(academicWorkspaceProvider);
    await _syncWithAcademicState(academicState);
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return DashboardNotifier(repo, ref);
});
