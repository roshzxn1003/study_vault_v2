import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/services/connectivity_service.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/sync/data/repositories/outbox_repository.dart';
import 'package:study_vault/features/sync/data/services/remote_sync_service.dart';
import 'package:study_vault/features/sync/data/services/supabase_sync_service.dart';
import 'package:study_vault/features/sync/data/services/sync_engine.dart';
import 'package:study_vault/features/sync/domain/models/sync_state.dart';

/// Provider for OutboxRepository.
final outboxRepositoryProvider = Provider<OutboxRepository>((ref) {
  return OutboxRepository();
});

/// Provider for RemoteSyncService.
final remoteSyncServiceProvider = Provider<RemoteSyncService>((ref) {
  return SupabaseSyncService();
});

/// Provider for ConnectivityService.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Provider for central SyncEngine instance.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final outboxRepo = ref.watch(outboxRepositoryProvider);
  final remoteService = ref.watch(remoteSyncServiceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);

  final engine = SyncEngine(
    outboxRepo: outboxRepo,
    remoteService: remoteService,
    connectivityService: connectivity,
  );

  ref.onDispose(() {
    engine.dispose();
  });

  return engine;
});

/// StateNotifier coordinating sync operations and UI state.
class SyncNotifier extends StateNotifier<SyncState> {
  final SyncEngine _engine;
  final OutboxRepository _outboxRepo;
  final Ref _ref;

  SyncNotifier(this._engine, this._outboxRepo, this._ref) : super(_engine.state) {
    _engine.addListener(_onEngineStateChanged);
  }

  void _onEngineStateChanged(SyncState newState) {
    if (mounted) {
      state = newState;
    }
  }

  String get _currentUserId {
    final authRepo = _ref.read(authRepositoryProvider);
    return authRepo.getCurrentUser()?.id ?? 'guest';
  }

  /// Triggers an immediate full synchronization pass.
  Future<void> syncNow() async {
    final userId = _currentUserId;
    await _engine.syncAll(userId: userId);
  }

  /// Resets failed outbox mutations to pending and initiates a retry pass.
  Future<void> retryFailed() async {
    final userId = _currentUserId;
    await _outboxRepo.retryAllFailed(userId: userId);
    await _engine.syncAll(userId: userId);
  }

  /// Purges old successfully synchronized mutations.
  Future<int> purgeSynced({Duration olderThan = const Duration(days: 7)}) async {
    return await _outboxRepo.purgeSyncedOperations(olderThan: olderThan);
  }

  /// Calculates storage usage on device and cloud.
  Future<StorageUsage> getStorageUsage() async {
    final userId = _currentUserId;
    return await _engine.calculateStorageUsage(userId: userId);
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngineStateChanged);
    super.dispose();
  }
}

/// Main Riverpod provider for Sync State & Operations.
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final engine = ref.watch(syncEngineProvider);
  final outboxRepo = ref.watch(outboxRepositoryProvider);
  return SyncNotifier(engine, outboxRepo, ref);
});

/// FutureProvider to fetch current local and remote storage metrics.
final storageUsageProvider = FutureProvider.autoDispose<StorageUsage>((ref) async {
  // Watch sync state so usage recalculates upon successful sync
  ref.watch(syncProvider);
  final notifier = ref.read(syncProvider.notifier);
  return await notifier.getStorageUsage();
});

/// StreamProvider monitoring real-time network connectivity.
final networkStatusProvider = StreamProvider.autoDispose<NetworkStatus>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  return connectivity.onStatusChanged;
});

/// FutureProvider to fetch counts of pending, failed, and syncing mutations.
final outboxCountsProvider = FutureProvider.autoDispose<({int pending, int failed, int syncing, int total})>((ref) async {
  ref.watch(syncProvider);
  final outbox = ref.watch(outboxRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final userId = authRepo.getCurrentUser()?.id ?? 'guest';
  return await outbox.getCounts(userId: userId);
});
