import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/vault_repository.dart';
import '../../domain/models/models.dart';
import 'vault_provider.dart';

/// State for a specific subject's folders and materials view.
class SubjectVaultState {
  final String subjectId;
  final String? currentFolderId;
  final List<VaultFolder> breadcrumbs;
  final List<VaultFolder> folders;
  final List<MaterialItem> materials;
  final String searchQuery;
  final MaterialSortOption sortOption;
  final bool isGridView;
  final bool isBulkSelectionMode;
  final Set<String> selectedMaterialIds;
  final bool isLoading;
  final String? errorMessage;

  const SubjectVaultState({
    required this.subjectId,
    this.currentFolderId,
    this.breadcrumbs = const [],
    this.folders = const [],
    this.materials = const [],
    this.searchQuery = '',
    this.sortOption = MaterialSortOption.recentlyUpdated,
    this.isGridView = true,
    this.isBulkSelectionMode = false,
    this.selectedMaterialIds = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isSearching => searchQuery.trim().isNotEmpty;
  int get selectedCount => selectedMaterialIds.length;
  bool get isRoot => currentFolderId == null;

  SubjectVaultState copyWith({
    String? subjectId,
    String? currentFolderId,
    bool clearFolder = false,
    List<VaultFolder>? breadcrumbs,
    List<VaultFolder>? folders,
    List<MaterialItem>? materials,
    String? searchQuery,
    MaterialSortOption? sortOption,
    bool? isGridView,
    bool? isBulkSelectionMode,
    Set<String>? selectedMaterialIds,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SubjectVaultState(
      subjectId: subjectId ?? this.subjectId,
      currentFolderId: clearFolder ? null : (currentFolderId ?? this.currentFolderId),
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      folders: folders ?? this.folders,
      materials: materials ?? this.materials,
      searchQuery: searchQuery ?? this.searchQuery,
      sortOption: sortOption ?? this.sortOption,
      isGridView: isGridView ?? this.isGridView,
      isBulkSelectionMode: isBulkSelectionMode ?? this.isBulkSelectionMode,
      selectedMaterialIds: selectedMaterialIds ?? this.selectedMaterialIds,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller managing a subject's material area, folders, and nested breadcrumb navigation.
class SubjectVaultNotifier extends StateNotifier<SubjectVaultState> {
  final String _subjectId;
  final VaultRepository _repository;
  final Ref _ref;
  Future<void>? _initFuture;

  SubjectVaultNotifier(this._subjectId, this._repository, this._ref)
      : super(SubjectVaultState(subjectId: _subjectId)) {
    Future.microtask(() => init());
  }

  String get _currentUserId {
    final authRepo = _ref.read(authRepositoryProvider);
    return authRepo.getCurrentUser()?.id ?? 'guest';
  }

  Future<void> init() {
    _initFuture ??= loadData();
    return _initFuture!;
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final userId = _currentUserId;

    try {
      // 1. Load folders for this subject at the current depth
      final folders = await _repository.getFolders(
        userId: userId,
        subjectId: _subjectId,
        parentId: state.currentFolderId,
      );

      // 2. Load breadcrumbs if navigated inside a subfolder
      List<VaultFolder> breadcrumbs = [];
      if (state.currentFolderId != null) {
        breadcrumbs = await _repository.getBreadcrumbs(state.currentFolderId!);
      }

      // 3. Load materials for this subject & current folder (or search matches)
      final filter = MaterialFilter(
        subjectId: _subjectId,
        folderId: state.isSearching ? null : state.currentFolderId,
        searchQuery: state.searchQuery,
      );

      final materials = await _repository.getMaterials(
        userId: userId,
        subjectId: _subjectId,
        filter: filter,
        sort: state.sortOption,
      );

      if (mounted) {
        state = state.copyWith(
          folders: folders,
          materials: materials,
          breadcrumbs: breadcrumbs,
          isLoading: false,
          clearError: true,
        );
      }
    } catch (e) {
      debugPrint('Error loading subject materials: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'We couldn\'t load materials for this subject.',
        );
      }
    }
  }

  void selectFolder(String? folderId) {
    state = state.copyWith(
      currentFolderId: folderId,
      clearFolder: folderId == null,
      selectedMaterialIds: {},
      isBulkSelectionMode: false,
    );
    loadData();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadData();
  }

  void setSort(MaterialSortOption sort) {
    state = state.copyWith(sortOption: sort);
    loadData();
  }

  void toggleViewMode() {
    state = state.copyWith(isGridView: !state.isGridView);
  }

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

  void clearSelection() {
    state = state.copyWith(
      selectedMaterialIds: {},
      isBulkSelectionMode: false,
    );
  }

  Future<VaultFolder> createFolder(String name) async {
    final folder = await _repository.createFolder(
      userId: _currentUserId,
      name: name,
      subjectId: _subjectId,
      parentId: state.currentFolderId,
    );
    await loadData();
    return folder;
  }

  Future<void> renameFolder(String folderId, String newName) async {
    await _repository.renameFolder(folderId, newName);
    await loadData();
  }

  Future<void> deleteFolder(String folderId, {bool deleteContents = false, String? moveContentsToParentId}) async {
    await _repository.deleteFolder(
      folderId,
      deleteContents: deleteContents,
      moveContentsToParentId: moveContentsToParentId,
    );
    if (state.currentFolderId == folderId) {
      state = state.copyWith(clearFolder: true);
    }
    await loadData();
  }

  Future<void> toggleFavorite(String materialId) async {
    final material = state.materials.firstWhere((m) => m.id == materialId);
    await _repository.toggleFavorite(materialId, !material.isFavorite);
    await loadData();
  }

  Future<void> renameMaterial(String materialId, String newTitle) async {
    await _repository.renameMaterial(materialId, newTitle);
    await loadData();
  }

  Future<void> moveMaterial(String materialId, {String? folderId, String? subjectId}) async {
    await _repository.moveMaterial(
      materialId,
      subjectId: subjectId ?? _subjectId,
      folderId: folderId,
    );
    await loadData();
  }

  Future<void> archiveMaterial(String materialId) async {
    await _repository.archiveMaterial(materialId);
    await loadData();
  }

  Future<void> deleteMaterial(String materialId) async {
    await _repository.deleteMaterial(materialId);
    await loadData();
  }

  Future<void> bulkMove({String? subjectId, String? folderId}) async {
    final ids = state.selectedMaterialIds.toList();
    if (ids.isEmpty) return;
    await _repository.bulkMove(ids, subjectId: subjectId ?? _subjectId, folderId: folderId);
    clearSelection();
    await loadData();
  }

  Future<void> bulkAddLabels(List<String> labelIds) async {
    final ids = state.selectedMaterialIds.toList();
    if (ids.isEmpty) return;
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
    await _repository.bulkDelete(ids);
    clearSelection();
    await loadData();
  }
}

/// Scoped provider for subject material and folder views.
final subjectVaultProvider = StateNotifierProvider.family<SubjectVaultNotifier, SubjectVaultState, String>(
  (ref, subjectId) {
    final repo = ref.watch(vaultRepositoryProvider);
    return SubjectVaultNotifier(subjectId, repo, ref);
  },
);
