import 'material_item.dart';

/// Library top-level tab views.
enum VaultTab {
  all(label: 'All'),
  subjects(label: 'Subjects'),
  folders(label: 'Folders'),
  recent(label: 'Recent'),
  favorites(label: 'Favorites'),
  downloads(label: 'Downloads'),
  trash(label: 'Trash');

  static const VaultTab archive = VaultTab.trash;

  final String label;
  const VaultTab({required this.label});
}

/// Supported sorting strategies for academic materials.
enum MaterialSortOption {
  recentlyUpdated(label: 'Recently updated'),
  recentlyOpened(label: 'Recently opened'),
  nameAsc(label: 'Name A–Z'),
  nameDesc(label: 'Name Z–A');

  final String label;
  const MaterialSortOption({required this.label});
}

/// Multi-facet filter for querying and refining vault materials.
class MaterialFilter {
  final String? subjectId;
  final String? academicPeriodId;
  final String? folderId;
  final VaultMaterialType? type;
  final Set<String> labelIds;
  final bool isFavoriteOnly;
  final bool isArchivedOnly;
  final bool? isInbox;
  final String? searchQuery;

  const MaterialFilter({
    this.subjectId,
    this.academicPeriodId,
    this.folderId,
    this.type,
    this.labelIds = const {},
    this.isFavoriteOnly = false,
    this.isArchivedOnly = false,
    this.isInbox,
    this.searchQuery,
  });

  bool get hasActiveFilters {
    return subjectId != null ||
        academicPeriodId != null ||
        folderId != null ||
        type != null ||
        labelIds.isNotEmpty ||
        isFavoriteOnly ||
        (searchQuery != null && searchQuery!.trim().isNotEmpty);
  }

  int get activeFilterCount {
    int count = 0;
    if (subjectId != null) count++;
    if (academicPeriodId != null) count++;
    if (folderId != null) count++;
    if (type != null) count++;
    if (labelIds.isNotEmpty) count += labelIds.length;
    if (isFavoriteOnly) count++;
    return count;
  }

  MaterialFilter copyWith({
    String? subjectId,
    bool clearSubject = false,
    String? academicPeriodId,
    bool clearPeriod = false,
    String? folderId,
    bool clearFolder = false,
    VaultMaterialType? type,
    bool clearType = false,
    Set<String>? labelIds,
    bool? isFavoriteOnly,
    bool? isArchivedOnly,
    bool? isInbox,
    bool clearInbox = false,
    String? searchQuery,
    bool clearSearch = false,
  }) {
    return MaterialFilter(
      subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
      academicPeriodId: clearPeriod ? null : (academicPeriodId ?? this.academicPeriodId),
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      type: clearType ? null : (type ?? this.type),
      labelIds: labelIds ?? this.labelIds,
      isFavoriteOnly: isFavoriteOnly ?? this.isFavoriteOnly,
      isArchivedOnly: isArchivedOnly ?? this.isArchivedOnly,
      isInbox: clearInbox ? null : (isInbox ?? this.isInbox),
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
    );
  }

  MaterialFilter reset() {
    return const MaterialFilter();
  }
}
