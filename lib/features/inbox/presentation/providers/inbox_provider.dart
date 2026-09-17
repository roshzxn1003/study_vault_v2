import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/vault/data/repositories/vault_repository.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';
import 'inbox_state.dart';

export 'inbox_state.dart';

class InboxNotifier extends StateNotifier<InboxState> {
  final VaultRepository _repository;
  final Ref _ref;
  Future<void>? _initFuture;

  InboxNotifier(this._repository, this._ref) : super(const InboxState());

  String get _currentUserId {
    return _ref.read(authRepositoryProvider).getCurrentUser()?.id ?? 'guest';
  }

  String? get _currentWorkspaceId {
    return _ref.read(academicWorkspaceProvider).activeWorkspace?.id;
  }

  Future<void> init() {
    _initFuture ??= loadInbox();
    return _initFuture!;
  }

  /// Reloads materials residing in the Inbox awaiting organization.
  Future<void> loadInbox() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final materials = await _repository.getInboxMaterials(
        userId: _currentUserId,
        workspaceId: _currentWorkspaceId,
      );
      state = state.copyWith(
        items: materials,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading inbox materials: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load inbox items.',
      );
    }
  }

  /// Moves a single material out of the inbox into the chosen subject/folder.
  Future<void> organizeItem(
    String materialId, {
    required String workspaceId,
    required String academicPeriodId,
    required String subjectId,
    String? folderId,
    List<String>? labelIds,
  }) async {
    try {
      await _repository.organizeMaterial(
        materialId,
        workspaceId: workspaceId,
        academicPeriodId: academicPeriodId,
        subjectId: subjectId,
        folderId: folderId,
        labelIds: labelIds,
      );
      await loadInbox();
      await _ref.read(vaultProvider.notifier).loadData();
    } catch (e) {
      debugPrint('Error organizing item: $e');
      state = state.copyWith(errorMessage: 'Failed to organize material.');
    }
  }

  /// Bulk organizes selected materials and removes them from the inbox.
  Future<void> bulkOrganize({
    required String workspaceId,
    required String academicPeriodId,
    required String subjectId,
    String? folderId,
    List<String>? labelIds,
  }) async {
    if (state.selectedIds.isEmpty) return;

    try {
      await _repository.bulkOrganizeMaterials(
        state.selectedIds.toList(),
        workspaceId: workspaceId,
        academicPeriodId: academicPeriodId,
        subjectId: subjectId,
        folderId: folderId,
        labelIds: labelIds,
      );
      state = state.copyWith(
        selectedIds: const {},
        isBulkMode: false,
      );
      await loadInbox();
      await _ref.read(vaultProvider.notifier).loadData();
    } catch (e) {
      debugPrint('Error bulk organizing items: $e');
      state = state.copyWith(errorMessage: 'Failed to organize selected materials.');
    }
  }

  /// Renames an inbox material title.
  Future<void> renameItem(String materialId, String newTitle) async {
    try {
      await _repository.renameMaterial(materialId, newTitle);
      await loadInbox();
      await _ref.read(vaultProvider.notifier).loadData();
    } catch (e) {
      debugPrint('Error renaming item: $e');
      state = state.copyWith(errorMessage: 'Failed to rename material.');
    }
  }

  /// Toggles favorite flag on an inbox item.
  Future<void> toggleFavorite(String materialId) async {
    try {
      final item = state.items.cast<MaterialItem?>().firstWhere(
            (i) => i?.id == materialId,
            orElse: () => null,
          );
      if (item == null) return;
      await _repository.toggleFavorite(materialId, !item.isFavorite);
      await loadInbox();
      await _ref.read(vaultProvider.notifier).loadData();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  /// Deletes a single item permanently from the inbox.
  Future<void> deleteItem(String materialId) async {
    try {
      await _repository.deleteMaterial(materialId);
      await loadInbox();
      await _ref.read(vaultProvider.notifier).loadData();
    } catch (e) {
      debugPrint('Error deleting inbox item: $e');
      state = state.copyWith(errorMessage: 'Failed to delete material.');
    }
  }

  /// Bulk deletes selected inbox materials.
  Future<void> bulkDelete() async {
    if (state.selectedIds.isEmpty) return;
    try {
      await _repository.bulkDelete(state.selectedIds.toList());
      state = state.copyWith(
        selectedIds: const {},
        isBulkMode: false,
      );
      await loadInbox();
      await _ref.read(vaultProvider.notifier).loadData();
    } catch (e) {
      debugPrint('Error bulk deleting inbox items: $e');
      state = state.copyWith(errorMessage: 'Failed to delete selected materials.');
    }
  }

  void toggleBulkMode() {
    state = state.copyWith(
      isBulkMode: !state.isBulkMode,
      selectedIds: const {},
    );
  }

  void toggleSelection(String id) {
    final current = Set<String>.from(state.selectedIds);
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    state = state.copyWith(
      selectedIds: current,
      isBulkMode: current.isNotEmpty || state.isBulkMode,
    );
  }

  void selectAll() {
    final allIds = state.items.map((i) => i.id).toSet();
    state = state.copyWith(
      selectedIds: allIds,
      isBulkMode: true,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      selectedIds: const {},
      isBulkMode: false,
    );
  }
}

final inboxProvider = StateNotifierProvider<InboxNotifier, InboxState>((ref) {
  final repo = ref.watch(vaultRepositoryProvider);
  return InboxNotifier(repo, ref);
});
