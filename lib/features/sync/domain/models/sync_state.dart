/// High-level synchronization states exposed to the UI.
enum SyncStatus {
  idle,
  syncing,
  uploading,
  downloading,
  synced,
  offline,
  failed,
}

/// Unified synchronization state model.
class SyncState {
  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final int pendingCount;
  final int failedCount;
  final int syncedFilesCount;
  final String? errorMessage;
  final bool isOnline;
  final int localStorageBytes;
  final int cloudStorageBytes;

  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncedAt,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.syncedFilesCount = 0,
    this.errorMessage,
    this.isOnline = true,
    this.localStorageBytes = 0,
    this.cloudStorageBytes = 0,
  });

  bool get isSyncing =>
      status == SyncStatus.syncing ||
      status == SyncStatus.uploading ||
      status == SyncStatus.downloading;
  bool get isUploading => status == SyncStatus.uploading;
  bool get isDownloading => status == SyncStatus.downloading;
  bool get hasPendingChanges => pendingCount > 0;
  bool get hasFailedChanges => failedCount > 0;
  bool get isOffline => !isOnline || status == SyncStatus.offline;
  bool get hasError => errorMessage != null || status == SyncStatus.failed;
  DateTime? get lastSyncTime => lastSyncedAt;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    int? pendingCount,
    int? failedCount,
    int? syncedFilesCount,
    String? errorMessage,
    bool? isOnline,
    int? localStorageBytes,
    int? cloudStorageBytes,
    bool clearError = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      syncedFilesCount: syncedFilesCount ?? this.syncedFilesCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isOnline: isOnline ?? this.isOnline,
      localStorageBytes: localStorageBytes ?? this.localStorageBytes,
      cloudStorageBytes: cloudStorageBytes ?? this.cloudStorageBytes,
    );
  }
}

/// Metrics model for on-device and remote cloud storage.
class StorageUsage {
  final int localDbBytes;
  final int localMaterialFilesBytes;
  final int remoteStorageBytes;

  const StorageUsage({
    this.localDbBytes = 0,
    this.localMaterialFilesBytes = 0,
    this.remoteStorageBytes = 0,
  });

  int get totalLocalBytes => localDbBytes + localMaterialFilesBytes;
}

