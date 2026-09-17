import '../../domain/models/models.dart';

/// Immutable state for the main academic Vault experience.
class VaultState {
  final VaultTab activeTab;
  final List<MaterialItem> materials;
  final List<VaultFolder> folders;
  final List<VaultLabel> labels;
  final String? selectedFolderId;
  final List<VaultFolder> folderBreadcrumbs;
  final MaterialFilter filter;
  final MaterialSortOption sortOption;
  final bool isGridView;
  final bool isBulkSelectionMode;
  final Set<String> selectedMaterialIds;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  const VaultState({
    this.activeTab = VaultTab.all,
    this.materials = const [],
    this.folders = const [],
    this.labels = const [],
    this.selectedFolderId,
    this.folderBreadcrumbs = const [],
    this.filter = const MaterialFilter(),
    this.sortOption = MaterialSortOption.recentlyUpdated,
    this.isGridView = true,
    this.isBulkSelectionMode = false,
    this.selectedMaterialIds = const {},
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isSearching => searchQuery.trim().isNotEmpty;
  int get selectedCount => selectedMaterialIds.length;
  bool get isAllSelected => materials.isNotEmpty && selectedMaterialIds.length == materials.length;

  VaultState copyWith({
    VaultTab? activeTab,
    List<MaterialItem>? materials,
    List<VaultFolder>? folders,
    List<VaultLabel>? labels,
    String? selectedFolderId,
    bool clearSelectedFolder = false,
    List<VaultFolder>? folderBreadcrumbs,
    MaterialFilter? filter,
    MaterialSortOption? sortOption,
    bool? isGridView,
    bool? isBulkSelectionMode,
    Set<String>? selectedMaterialIds,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VaultState(
      activeTab: activeTab ?? this.activeTab,
      materials: materials ?? this.materials,
      folders: folders ?? this.folders,
      labels: labels ?? this.labels,
      selectedFolderId: clearSelectedFolder ? null : (selectedFolderId ?? this.selectedFolderId),
      folderBreadcrumbs: folderBreadcrumbs ?? this.folderBreadcrumbs,
      filter: filter ?? this.filter,
      sortOption: sortOption ?? this.sortOption,
      isGridView: isGridView ?? this.isGridView,
      isBulkSelectionMode: isBulkSelectionMode ?? this.isBulkSelectionMode,
      selectedMaterialIds: selectedMaterialIds ?? this.selectedMaterialIds,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
