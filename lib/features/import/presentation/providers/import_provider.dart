import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';
import '../../data/repositories/import_repository.dart';
import '../../data/services/incoming_share_service.dart';
import '../../domain/models/import_item.dart';
import 'import_state.dart';

export 'import_state.dart';

final importRepositoryProvider = Provider<ImportRepository>((ref) {
  final vaultRepo = ref.watch(vaultRepositoryProvider);
  return ImportRepository(vaultRepository: vaultRepo);
});

final incomingShareServiceProvider = Provider<IncomingShareService>((ref) {
  final service = IncomingShareService();
  service.initIntentListener();
  ref.onDispose(() => service.dispose());
  return service;
});

class ImportNotifier extends StateNotifier<ImportState> {
  final ImportRepository _repository;
  final Ref _ref;

  ImportNotifier(this._repository, this._ref) : super(const ImportState());

  String get _currentUserId {
    final user = _ref.read(authRepositoryProvider).getCurrentUser();
    return user?.id ?? 'guest';
  }

  String? get _currentWorkspaceId {
    return _ref.read(academicWorkspaceProvider).activeWorkspace?.id;
  }

  /// Sets raw incoming items and stages them with duplicate checks & validation.
  Future<void> stageItems(List<ImportItem> rawItems) async {
    if (rawItems.isEmpty) {
      state = const ImportState();
      return;
    }

    state = state.copyWith(
      items: rawItems,
      isValidating: true,
      isImporting: false,
      isComplete: false,
      clearError: true,
    );

    try {
      final staged = await _repository.validateAndStageItems(
        rawItems,
        userId: _currentUserId,
      );

      state = state.copyWith(
        items: staged,
        isValidating: false,
      );
    } catch (e) {
      debugPrint('Error validating items: $e');
      state = state.copyWith(
        isValidating: false,
        errorMessage: 'Failed to inspect incoming items: $e',
      );
    }
  }

  /// Removes an item from the staging list before importing.
  void removeItem(String itemId) {
    final updated = state.items.where((i) => i.id != itemId).toList();
    state = state.copyWith(items: updated);
  }

  /// Clears duplicate warning for an item so it can be imported anyway (Section 26).
  void allowDuplicateImport(String itemId) {
    final updated = state.items.map((i) {
      if (i.id == itemId) {
        return i.copyWith(
          status: ImportItemStatus.pending,
          clearDuplicate: true,
        );
      }
      return i;
    }).toList();

    state = state.copyWith(items: updated);
  }

  /// Renames an item title before saving.
  void updateItemTitle(String itemId, String newTitle) {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;

    final updated = state.items.map((i) {
      if (i.id == itemId) {
        return i.copyWith(title: trimmed);
      }
      return i;
    }).toList();

    state = state.copyWith(items: updated);
  }

  /// Quick Save: imports all ready items directly to the Inbox (Section 14 & 16).
  Future<bool> quickSaveToInbox() async {
    final readyItems = state.items.where((i) =>
        i.status == ImportItemStatus.pending ||
        i.status == ImportItemStatus.duplicateDetected).toList();

    if (readyItems.isEmpty) return false;

    state = state.copyWith(
      isImporting: true,
      progressCurrent: 0,
      progressTotal: readyItems.length,
      clearError: true,
    );

    final result = await _repository.importBatch(
      readyItems,
      userId: _currentUserId,
      workspaceId: _currentWorkspaceId,
      isInbox: true,
      onProgress: (cur, tot) {
        state = state.copyWith(progressCurrent: cur, progressTotal: tot);
      },
    );

    // Refresh Vault and Inbox state
    await _ref.read(vaultProvider.notifier).loadData();

    final hasFailures = result.failed.isNotEmpty;
    state = state.copyWith(
      isImporting: false,
      isComplete: !hasFailures,
      items: [
        ...result.succeeded.map((m) => ImportItem(
          id: m.id,
          title: m.title,
          type: m.type,
          status: ImportItemStatus.success,
        )),
        ...result.failed,
      ],
      errorMessage: hasFailures ? '${result.failed.length} material(s) could not be imported.' : null,
    );

    return !hasFailures;
  }

  /// Save & Organize: imports materials directly into specified academic coordinates (Section 15).
  Future<bool> saveAndOrganize({
    required String workspaceId,
    required String academicPeriodId,
    required String subjectId,
    String? folderId,
    List<String>? labelIds,
  }) async {
    final readyItems = state.items.where((i) =>
        i.status == ImportItemStatus.pending ||
        i.status == ImportItemStatus.duplicateDetected).toList();

    if (readyItems.isEmpty) return false;

    state = state.copyWith(
      isImporting: true,
      progressCurrent: 0,
      progressTotal: readyItems.length,
      clearError: true,
    );

    final result = await _repository.importBatch(
      readyItems,
      userId: _currentUserId,
      workspaceId: workspaceId,
      academicPeriodId: academicPeriodId,
      subjectId: subjectId,
      folderId: folderId,
      labelIds: labelIds,
      isInbox: false,
      onProgress: (cur, tot) {
        state = state.copyWith(progressCurrent: cur, progressTotal: tot);
      },
    );

    await _ref.read(vaultProvider.notifier).loadData();

    final hasFailures = result.failed.isNotEmpty;
    state = state.copyWith(
      isImporting: false,
      isComplete: !hasFailures,
      items: [
        ...result.succeeded.map((m) => ImportItem(
          id: m.id,
          title: m.title,
          type: m.type,
          status: ImportItemStatus.success,
        )),
        ...result.failed,
      ],
      errorMessage: hasFailures ? '${result.failed.length} material(s) could not be imported.' : null,
    );

    return !hasFailures;
  }

  /// Retries importing any items that failed (Section 24).
  Future<void> retryFailed({bool isInbox = true}) async {
    final failedItems = state.items.where((i) => i.status == ImportItemStatus.failed).toList();
    if (failedItems.isEmpty) return;

    state = state.copyWith(
      isImporting: true,
      progressCurrent: 0,
      progressTotal: failedItems.length,
      clearError: true,
    );

    final result = await _repository.importBatch(
      failedItems,
      userId: _currentUserId,
      workspaceId: _currentWorkspaceId,
      isInbox: isInbox,
      onProgress: (cur, tot) {
        state = state.copyWith(progressCurrent: cur, progressTotal: tot);
      },
    );

    await _ref.read(vaultProvider.notifier).loadData();

    final hasRemainingFailures = result.failed.isNotEmpty;
    state = state.copyWith(
      isImporting: false,
      isComplete: !hasRemainingFailures,
      items: [
        ...state.items.where((i) => i.status == ImportItemStatus.success),
        ...result.succeeded.map((m) => ImportItem(
          id: m.id,
          title: m.title,
          type: m.type,
          status: ImportItemStatus.success,
        )),
        ...result.failed,
      ],
      errorMessage: hasRemainingFailures ? '${result.failed.length} material(s) still failed.' : null,
    );
  }

  /// Resets import staging.
  void clear() {
    state = const ImportState();
  }
}

final importProvider = StateNotifierProvider<ImportNotifier, ImportState>((ref) {
  final repo = ref.watch(importRepositoryProvider);
  return ImportNotifier(repo, ref);
});
