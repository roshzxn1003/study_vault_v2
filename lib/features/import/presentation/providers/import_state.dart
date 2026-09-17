import '../../domain/models/import_item.dart';

/// Immutable state for the Universal Import flow.
class ImportState {
  final List<ImportItem> items;
  final bool isValidating;
  final bool isImporting;
  final bool isComplete;
  final int progressCurrent;
  final int progressTotal;
  final String? errorMessage;

  const ImportState({
    this.items = const [],
    this.isValidating = false,
    this.isImporting = false,
    this.isComplete = false,
    this.progressCurrent = 0,
    this.progressTotal = 0,
    this.errorMessage,
  });

  bool get hasDuplicates => items.any((i) => i.status == ImportItemStatus.duplicateDetected);
  bool get hasFailures => items.any((i) => i.status == ImportItemStatus.failed);
  int get readyCount => items.where((i) => i.status == ImportItemStatus.pending).length;
  int get duplicateCount => items.where((i) => i.status == ImportItemStatus.duplicateDetected).length;
  int get failedCount => items.where((i) => i.status == ImportItemStatus.failed).length;
  int get successCount => items.where((i) => i.status == ImportItemStatus.success).length;

  ImportState copyWith({
    List<ImportItem>? items,
    bool? isValidating,
    bool? isImporting,
    bool? isComplete,
    int? progressCurrent,
    int? progressTotal,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ImportState(
      items: items ?? this.items,
      isValidating: isValidating ?? this.isValidating,
      isImporting: isImporting ?? this.isImporting,
      isComplete: isComplete ?? this.isComplete,
      progressCurrent: progressCurrent ?? this.progressCurrent,
      progressTotal: progressTotal ?? this.progressTotal,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
