import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/vault_repository.dart';
import '../../domain/models/models.dart';
import 'vault_state.dart';

export 'vault_state.dart';

/// Provider for VaultRepository instance.
final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepository();
});

/// Central StateNotifier managing the Vault experience.
class VaultNotifier extends StateNotifier<VaultState> {
  final VaultRepository _repository;
  final Ref _ref;
  Future<void>? _initFuture;

  VaultNotifier(this._repository, this._ref) : super(const VaultState()) {
    Future.microtask(() => init());
  }

  String get _currentUserId {
    final authRepo = _ref.read(authRepositoryProvider);
    return authRepo.getCurrentUser()?.id ?? 'guest';
  }

  String? get _currentWorkspaceId {
    final academicState = _ref.read(academicWorkspaceProvider);
    return academicState.activeWorkspace?.id;
  }

  /// Bootstraps default labels and loads initial materials and folders.
  Future<void> init() {
    _initFuture ??= _performInit();
    return _initFuture!;
  }

  Future<void> _performInit() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final userId = _currentUserId;
    final workspaceId = _currentWorkspaceId;

    try {
      await _repository.ensureInitialized(userId: userId, workspaceId: workspaceId);
      final labels = await _repository.getLabels(userId: userId, workspaceId: workspaceId);
      state = state.copyWith(labels: labels);
      await loadData();
    } catch (e) {
      debugPrint('Error initializing vault: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'We couldn\'t load your vault materials.',
        );
      }
    }
  }

  /// Reloads materials and folders according to active tab, filter, and sort.
  Future<void> loadData() async {
    final userId = _currentUserId;
    final workspaceId = _currentWorkspaceId;

    try {
      // Build filter according to active tab
      MaterialFilter activeFilter = state.filter.copyWith(
        searchQuery: state.searchQuery,
      );

      switch (state.activeTab) {
        case VaultTab.all:
          activeFilter = activeFilter.copyWith(
            isFavoriteOnly: false,
            isArchivedOnly: false,
          );
          break;
        case VaultTab.recent:
          activeFilter = activeFilter.copyWith(
            isFavoriteOnly: false,
            isArchivedOnly: false,
          );
          break;
        case VaultTab.favorites:
          activeFilter = activeFilter.copyWith(
            isFavoriteOnly: true,
            isArchivedOnly: false,
          );
          break;
        case VaultTab.folders:
          activeFilter = activeFilter.copyWith(
            folderId: state.selectedFolderId,
            clearFolder: state.selectedFolderId == null,
            isArchivedOnly: false,
          );
          break;
        case VaultTab.archive:
          activeFilter = activeFilter.copyWith(
            isFavoriteOnly: false,
            isArchivedOnly: true,
          );
          break;
      }

      // Sort strategy: force recentlyOpened for Recent tab
      final sort = state.activeTab == VaultTab.recent
          ? MaterialSortOption.recentlyOpened
          : state.sortOption;

      // Query materials
      final materials = await _repository.getMaterials(
        userId: userId,
        workspaceId: workspaceId,
        filter: activeFilter,
        sort: sort,
      );

      // Query folders (only needed when on Folders tab or browsing root)
      List<VaultFolder> folders = [];
      List<VaultFolder> breadcrumbs = [];

      if (state.activeTab == VaultTab.folders) {
        folders = await _repository.getFolders(
          userId: userId,
          workspaceId: workspaceId,
          parentId: state.selectedFolderId,
        );

        if (state.selectedFolderId != null) {
          breadcrumbs = await _repository.getBreadcrumbs(state.selectedFolderId!);
        }
      }

      if (mounted) {
        state = state.copyWith(
          materials: materials,
          folders: folders,
          folderBreadcrumbs: breadcrumbs,
          isLoading: false,
          clearError: true,
        );
      }
    } catch (e) {
      debugPrint('Error loading vault data: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to load study materials.',
        );
      }
    }
  }

  /// Switches active top-level tab (All, Recent, Favorites, Folders, Archive).
  void setTab(VaultTab tab) {
    if (state.activeTab == tab) return;
    state = state.copyWith(
      activeTab: tab,
      selectedMaterialIds: {},
      isBulkSelectionMode: false,
    );
    loadData();
  }

  /// Drills down into a folder or navigates back up.
  void selectFolder(String? folderId) {
    state = state.copyWith(
      selectedFolderId: folderId,
      clearSelectedFolder: folderId == null,
      selectedMaterialIds: {},
      isBulkSelectionMode: false,
    );
    loadData();
  }

  /// Sets live debounced search query.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadData();
  }

  /// Applies user filter criteria.
  void applyFilter(MaterialFilter filter) {
    state = state.copyWith(filter: filter);
    loadData();
  }

  /// Updates sort strategy.
  void setSort(MaterialSortOption sort) {
    state = state.copyWith(sortOption: sort);
    loadData();
  }

  /// Toggles between responsive Grid and dense List view.
  void toggleViewMode() {
    state = state.copyWith(isGridView: !state.isGridView);
  }

  // ===========================================================================
  // BULK SELECTION ACTIONS
  // ===========================================================================

  void toggleBulkMode() {
    final next = !state.isBulkSelectionMode;
    state = state.copyWith(
      isBulkSelectionMode: next,
      selectedMaterialIds: next ? state.selectedMaterialIds : {},
    );
  }

  void toggleSelectMaterial(String id) {
    final updated = Set<String>.from(state.selectedMaterialIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(
      selectedMaterialIds: updated,
      isBulkSelectionMode: updated.isNotEmpty || state.isBulkSelectionMode,
    );
  }

  void selectAll() {
    final allIds = state.materials.map((m) => m.id).toSet();
    state = state.copyWith(
      selectedMaterialIds: allIds,
      isBulkSelectionMode: true,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      selectedMaterialIds: {},
      isBulkSelectionMode: false,
    );
  }

  Future<void> bulkMove({
    String? workspaceId,
    String? academicPeriodId,
    String? subjectId,
    String? folderId,
  }) async {
    final ids = state.selectedMaterialIds.toList();
    if (ids.isEmpty) return;

    await _repository.bulkMove(
      ids,
      workspaceId: workspaceId,
      academicPeriodId: academicPeriodId,
      subjectId: subjectId,
      folderId: folderId,
    );
    clearSelection();
    await loadData();
  }

  Future<void> bulkAddLabels(List<String> labelIds) async {
    final ids = state.selectedMaterialIds.toList();
    if (ids.isEmpty || labelIds.isEmpty) return;

    await _repository.bulkAddLabels(ids, labelIds);
    clearSelection();
    await loadData();
  }

  Future<void> bulkArchive() async {
    final ids = state.selectedMaterialIds.toList();
    if (ids.isEmpty) return;

    await _repository.bulkArchive(ids);
    clearSelection();
    await loadData();
  }

  Future<void> bulkDelete() async {
    final ids = state.selectedMaterialIds.toList();
    if (ids.isEmpty) return;

    state = state.copyWith(
      materials: state.materials.where((m) => !ids.contains(m.id)).toList(),
      selectedMaterialIds: {},
    );
    await _repository.bulkDelete(ids);
    clearSelection();
    await loadData();
  }

  // ===========================================================================
  // SINGLE MATERIAL ACTIONS
  // ===========================================================================

  Future<void> toggleFavorite(String id) async {
    final material = state.materials.where((m) => m.id == id).firstOrNull;
    if (material == null) return;
    await _repository.toggleFavorite(id, !material.isFavorite);
    await loadData();
  }

  Future<void> renameMaterial(String id, String newTitle) async {
    await _repository.renameMaterial(id, newTitle);
    await loadData();
  }

  Future<void> moveMaterial(
    String id, {
    String? workspaceId,
    String? academicPeriodId,
    String? subjectId,
    String? folderId,
  }) async {
    await _repository.moveMaterial(
      id,
      workspaceId: workspaceId,
      academicPeriodId: academicPeriodId,
      subjectId: subjectId,
      folderId: folderId,
    );
    await loadData();
  }

  Future<void> archiveMaterial(String id) async {
    await _repository.archiveMaterial(id);
    await loadData();
  }

  Future<void> restoreMaterial(String id) async {
    await _repository.restoreMaterial(id);
    await loadData();
  }

  Future<void> markOpened(String id) async {
    await _repository.markOpened(id);
  }

  Future<void> deleteMaterial(String id) async {
    state = state.copyWith(
      materials: state.materials.where((m) => m.id != id).toList(),
      selectedMaterialIds: state.selectedMaterialIds.where((it) => it != id).toSet(),
    );
    await _repository.deleteMaterial(id);
    await loadData();
  }

  // ===========================================================================
  // FOLDER & LABEL MANAGEMENT
  // ===========================================================================

  Future<VaultFolder> createFolder(
    String name, {
    String? parentId,
    String? subjectId,
  }) async {
    final userId = _currentUserId;
    final workspaceId = _currentWorkspaceId;

    final folder = await _repository.createFolder(
      userId: userId,
      name: name,
      workspaceId: workspaceId,
      subjectId: subjectId,
      parentId: parentId ?? state.selectedFolderId,
    );
    await loadData();
    return folder;
  }

  Future<void> renameFolder(String folderId, String newName) async {
    await _repository.renameFolder(folderId, newName);
    await loadData();
  }

  Future<void> moveFolder(String folderId, String? newParentId) async {
    await _repository.moveFolder(folderId, newParentId);
    await loadData();
  }

  Future<void> deleteFolder(
    String folderId, {
    bool deleteContents = false,
    String? moveContentsToParentId,
  }) async {
    await _repository.deleteFolder(
      folderId,
      deleteContents: deleteContents,
      moveContentsToParentId: moveContentsToParentId,
    );
    if (state.selectedFolderId == folderId) {
      state = state.copyWith(clearSelectedFolder: true);
    }
    await loadData();
  }

  Future<VaultLabel> createLabel(String name, {String? colorHex}) async {
    final userId = _currentUserId;
    final workspaceId = _currentWorkspaceId;
    final label = await _repository.createLabel(
      userId: userId,
      name: name,
      colorHex: colorHex,
      workspaceId: workspaceId,
    );
    final labels = await _repository.getLabels(userId: userId, workspaceId: workspaceId);
    state = state.copyWith(labels: labels);
    return label;
  }

  Future<void> renameLabel(String labelId, String newName) async {
    await _repository.renameLabel(labelId, newName);
    final userId = _currentUserId;
    final labels = await _repository.getLabels(userId: userId, workspaceId: _currentWorkspaceId);
    state = state.copyWith(labels: labels);
  }

  Future<void> deleteLabel(String labelId) async {
    await _repository.deleteLabel(labelId);
    final userId = _currentUserId;
    final labels = await _repository.getLabels(userId: userId, workspaceId: _currentWorkspaceId);
    state = state.copyWith(labels: labels);
    await loadData();
  }

  Future<void> setMaterialLabels(String materialId, List<String> labelIds) async {
    await _repository.setMaterialLabels(materialId, labelIds);
    await loadData();
  }
}

/// Main Vault provider.
final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  final repo = ref.watch(vaultRepositoryProvider);
  return VaultNotifier(repo, ref);
});
