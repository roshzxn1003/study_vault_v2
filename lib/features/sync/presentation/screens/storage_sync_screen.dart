import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/design/tokens/app_colors.dart';
import 'package:study_vault/core/design/tokens/app_spacing.dart';
import 'package:study_vault/core/design/tokens/app_typography.dart';
import 'package:study_vault/core/design/widgets/app_button.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/sync/domain/models/sync_state.dart';
import 'package:study_vault/features/sync/presentation/providers/sync_provider.dart';
import 'package:study_vault/features/sync/presentation/widgets/offline_banner.dart';

/// Storage & Synchronization Settings Screen.
/// Displays local SQLite storage metrics, Supabase cloud sync status,
/// outbox queue stats, toggles for Wi-Fi/auto-sync, and manual sync / retry controls.
class StorageSyncScreen extends ConsumerStatefulWidget {
  const StorageSyncScreen({super.key});

  @override
  ConsumerState<StorageSyncScreen> createState() => _StorageSyncScreenState();
}

class _StorageSyncScreenState extends ConsumerState<StorageSyncScreen> {
  bool _isCleaningOutbox = false;
  bool _isClearingCache = false;
  bool _autoSyncEnabled = true;
  bool _wifiOnly = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoSyncEnabled = prefs.getBool('sync_auto_enabled') ?? true;
        _wifiOnly = prefs.getBool('sync_wifi_only') ?? false;
      });
    }
  }

  Future<void> _updateAutoSync(bool val) async {
    setState(() => _autoSyncEnabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_auto_enabled', val);
  }

  Future<void> _updateWifiOnly(bool val) async {
    setState(() => _wifiOnly = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_wifi_only', val);
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double val = bytes.toDouble();
    while (val >= 1024 && i < suffixes.length - 1) {
      val /= 1024;
      i++;
    }
    return '${val.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatSyncTime(DateTime? dt) {
    if (dt == null) return 'Never';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showClearCacheDialog(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.destructive, size: 24),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Clear Local Cache?',
              style: AppTypography.title.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Text(
          'This will remove locally cached file copies to free up device space.\n\nYour materials and cloud files remain completely safe in your Supabase account and will download automatically when accessed.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.button.copyWith(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isClearingCache = true);
      try {
        await LocalDbService.instance.clearLocalCache(userId);

        // Delete temporary cached documents
        try {
          Directory baseDir;
          try {
            baseDir = await getApplicationDocumentsDirectory();
          } catch (_) {
            baseDir = await getTemporaryDirectory();
          }
          final matDir = Directory(p.join(baseDir.path, 'study_materials'));
          if (await matDir.exists()) {
            await for (final entity in matDir.list()) {
              if (entity is File) {
                await entity.delete();
              }
            }
          }
        } catch (e) {
          debugPrint('[StorageSyncScreen] Clear cache file delete note: $e');
        }

        ref.invalidate(storageUsageProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Local cache cleared. Cloud files remain safe.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed clearing cache: $e'),
              backgroundColor: AppColors.destructive,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isClearingCache = false);
        }
      }
    }
  }

  Future<void> _showSyncErrorsBottomSheet() async {
    final failedOps = await ref.read(syncProvider.notifier).getFailedOperations();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sync Issues (${failedOps.length})',
                      style: AppTypography.title.copyWith(color: AppColors.textPrimary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (failedOps.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(
                      child: Text(
                        'No sync errors found. All changes are synchronized!',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: failedOps.length,
                      separatorBuilder: (context, index) => const Divider(color: AppColors.border),
                      itemBuilder: (context, index) {
                        final op = failedOps[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.destructive.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.sync_problem_rounded, color: AppColors.destructive, size: 20),
                          ),
                          title: Text(
                            '${op.entityType.toUpperCase()} (${op.operation.name})',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            op.lastError ?? 'Unknown synchronization error',
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            'Try #${op.attemptCount}',
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                if (failedOps.isNotEmpty)
                  AppButton(
                    text: 'Retry All Now',
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await ref.read(syncProvider.notifier).retryFailed();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);
    final countsAsync = ref.watch(outboxCountsProvider);
    final usageAsync = ref.watch(storageUsageProvider);
    final authRepo = ref.watch(authRepositoryProvider);
    final currentUser = authRepo.getCurrentUser();
    final userId = currentUser?.id ?? 'guest';

    final pendingCount = countsAsync.value?.pending ?? 0;
    final failedCount = countsAsync.value?.failed ?? 0;
    final syncingCount = countsAsync.value?.syncing ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Storage & Sync',
          style: AppTypography.title.copyWith(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _buildSyncStatusCard(syncState, currentUser?.email),
                const SizedBox(height: AppSpacing.md),
                _buildOutboxSection(pendingCount, failedCount, syncingCount, syncState.isSyncing),
                const SizedBox(height: AppSpacing.md),
                _buildStorageUsageSection(usageAsync),
                const SizedBox(height: AppSpacing.md),
                _buildSyncPreferencesCard(),
                const SizedBox(height: AppSpacing.md),
                _buildDangerZoneCard(userId),
                const SizedBox(height: AppSpacing.md),
                _buildArchitectureCard(),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusCard(SyncState syncState, String? userEmail) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (syncState.isOffline) {
      statusColor = AppColors.textSecondary;
      statusLabel = 'Offline Mode';
      statusIcon = Icons.cloud_off_rounded;
    } else if (syncState.isDownloading) {
      statusColor = AppColors.info;
      statusLabel = 'Downloading Files...';
      statusIcon = Icons.cloud_download_rounded;
    } else if (syncState.isUploading) {
      statusColor = AppColors.primary;
      statusLabel = 'Uploading Files...';
      statusIcon = Icons.cloud_upload_rounded;
    } else if (syncState.isSyncing) {
      statusColor = AppColors.primary;
      statusLabel = 'Syncing...';
      statusIcon = Icons.sync_rounded;
    } else if (syncState.hasError) {
      statusColor = AppColors.destructive;
      statusLabel = 'Sync Issue';
      statusIcon = Icons.error_outline_rounded;
    } else {
      statusColor = AppColors.success;
      statusLabel = 'All Files Synced';
      statusIcon = Icons.cloud_done_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cloud Synchronization',
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      statusLabel,
                      style: AppTypography.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                userEmail != null ? Icons.account_circle_outlined : Icons.person_outline_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  userEmail != null
                      ? 'Connected: $userEmail'
                      : 'Local Guest Account (Login to sync across devices)',
                  style: AppTypography.bodySmall.copyWith(
                    color: userEmail != null ? AppColors.textPrimary : AppColors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Last Synced: ${_formatSyncTime(syncState.lastSyncTime)}',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          if (syncState.syncedFilesCount > 0) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${syncState.syncedFilesCount} materials synchronized in cloud',
              style: AppTypography.caption.copyWith(color: AppColors.primaryLight),
            ),
          ],
          if (syncState.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              syncState.errorMessage!,
              style: AppTypography.caption.copyWith(color: AppColors.destructive),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: syncState.isSyncing
                      ? (syncState.isDownloading ? 'Downloading...' : (syncState.isUploading ? 'Uploading...' : 'Syncing...'))
                      : 'Sync Now',
                  icon: syncState.isSyncing ? null : const Icon(Icons.sync_rounded, size: 18),
                  isLoading: syncState.isSyncing,
                  onPressed: syncState.isSyncing
                      ? null
                      : () async {
                          await ref.read(syncProvider.notifier).syncNow();
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageUsageSection(AsyncValue<StorageUsage> usageAsync) {
    const quotaBytes = 5 * 1024 * 1024 * 1024; // 5 GB Free Tier

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Storage Breakdown',
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          usageAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (err, _) => Text(
              'Unable to query storage metrics: $err',
              style: AppTypography.caption.copyWith(color: AppColors.destructive),
            ),
            data: (usage) {
              final usedBytes = usage.remoteStorageBytes;
              final fraction = (usedBytes / quotaBytes).clamp(0.0, 1.0);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cloud Storage Usage',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                      Text(
                        '${_formatBytes(usedBytes)} of 5.0 GB',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceSecondary,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        fraction > 0.9 ? AppColors.destructive : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildStorageRow(
                    icon: Icons.storage_rounded,
                    title: 'Local SQLite Database',
                    subtitle: 'Workspaces, periods, subjects, outbox metadata',
                    size: _formatBytes(usage.localDbBytes),
                  ),
                  const Divider(color: AppColors.border, height: AppSpacing.md),
                  _buildStorageRow(
                    icon: Icons.folder_copy_outlined,
                    title: 'Local Cached Documents',
                    subtitle: 'Locally cached materials and PDF previews',
                    size: _formatBytes(usage.localMaterialFilesBytes),
                  ),
                  const Divider(color: AppColors.border, height: AppSpacing.md),
                  _buildStorageRow(
                    icon: Icons.cloud_outlined,
                    title: 'Cloud Storage (Supabase)',
                    subtitle: 'Study materials uploaded to cloud bucket',
                    size: _formatBytes(usage.remoteStorageBytes),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total On-Device Usage',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatBytes(usage.totalLocalBytes),
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSyncPreferencesCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sync Preferences',
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Automatic Background Sync',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                'Continuously synchronize edits and files when connected',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
              value: _autoSyncEnabled,
              activeThumbColor: AppColors.primary,
              onChanged: _updateAutoSync,
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Sync on Wi-Fi Only',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                'Conserve cellular data by pausing file uploads on mobile networks',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
              value: _wifiOnly,
              activeThumbColor: AppColors.primary,
              onChanged: _updateWifiOnly,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutboxSection(int pending, int failed, int syncing, bool isSyncing) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Outbox Queue',
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (pending + failed + syncing > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${pending + failed + syncing} pending',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Pending',
                  value: pending.toString(),
                  icon: Icons.hourglass_top_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _buildMetricTile(
                  label: 'In Flight',
                  value: syncing.toString(),
                  icon: Icons.sync_rounded,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _buildMetricTile(
                  label: 'Failed',
                  value: failed.toString(),
                  icon: Icons.warning_amber_rounded,
                  color: failed > 0 ? AppColors.destructive : AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (failed > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                      side: const BorderSide(color: AppColors.destructive),
                      minimumSize: const Size.fromHeight(38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.error_outline_rounded, size: 16),
                    label: const Text('View Sync Errors'),
                    onPressed: _showSyncErrorsBottomSheet,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.destructive,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.replay_rounded, size: 16),
                    label: const Text('Retry Failed Mutations'),
                    onPressed: isSyncing
                        ? null
                        : () async {
                            await ref.read(syncProvider.notifier).retryFailed();
                          },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size.fromHeight(38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _isCleaningOutbox
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                : const Icon(Icons.cleaning_services_rounded, size: 16),
            label: const Text('Purge Synced Outbox Logs'),
            onPressed: _isCleaningOutbox
                ? null
                : () async {
                    setState(() => _isCleaningOutbox = true);
                    try {
                      final count = await ref.read(syncProvider.notifier).purgeSynced(
                            olderThan: const Duration(days: 0),
                          );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Cleaned $count synced outbox records.'),
                            backgroundColor: AppColors.surfaceSecondary,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _isCleaningOutbox = false);
                      }
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneCard(String userId) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.delete_sweep_outlined, color: AppColors.destructive, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Local Storage Management',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.destructive,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Running out of space on this device? Clear offline cached files. Your files remain securely backed up in the cloud and will re-download on demand.',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.destructive,
              side: BorderSide(color: AppColors.destructive.withValues(alpha: 0.6)),
              minimumSize: const Size.fromHeight(38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _isClearingCache
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.destructive),
                  )
                : const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('Clear Local File Cache'),
            onPressed: _isClearingCache ? null : () => _showClearCacheDialog(userId),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                label,
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: AppTypography.headline.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String size,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        Text(
          size,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildArchitectureCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Offline-First Architecture',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Study Vault is offline-first. All workspaces, subjects, materials, and edits are written directly to your on-device SQLite database. When internet connectivity is available, an Outbox worker replicates changes to Supabase and downloads missing files automatically in the background.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
