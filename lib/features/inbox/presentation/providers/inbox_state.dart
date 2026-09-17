import 'package:study_vault/features/vault/domain/models/models.dart';

/// Immutable state for the real Inbox experience (Section 17).
class InboxState {
  final List<MaterialItem> items;
  final bool isLoading;
  final bool isBulkMode;
  final Set<String> selectedIds;
  final String? errorMessage;

  const InboxState({
    this.items = const [],
    this.isLoading = false,
    this.isBulkMode = false,
    this.selectedIds = const {},
    this.errorMessage,
  });

  int get totalCount => items.length;
  int get selectedCount => selectedIds.length;
  bool get isAllSelected => items.isNotEmpty && selectedIds.length == items.length;
  bool get hasItems => items.isNotEmpty;

  InboxState copyWith({
    List<MaterialItem>? items,
    bool? isLoading,
    bool? isBulkMode,
    Set<String>? selectedIds,
    String? errorMessage,
    bool clearError = false,
  }) {
    return InboxState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isBulkMode: isBulkMode ?? this.isBulkMode,
      selectedIds: selectedIds ?? this.selectedIds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
