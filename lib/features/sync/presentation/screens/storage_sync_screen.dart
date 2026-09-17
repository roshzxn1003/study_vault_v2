import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
/// outbox queue stats, and manual sync / retry controls.
class StorageSyncScreen extends ConsumerStatefulWidget {
  const StorageSyncScreen({super.key});

  @override
  ConsumerState<StorageSyncScreen> createState() => _StorageSyncScreenState();
}

class _StorageSyncScreenState extends ConsumerState<StorageSyncScreen> {
  bool _isCleaningOutbox = false;

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

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);
    final countsAsync = ref.watch(outboxCountsProvider);
    final usageAsync = ref.watch(storageUsageProvider);
    final authRepo = ref.watch(authRepositoryProvider);
    final currentUser = authRepo.getCurrentUser();

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
                _buildArchitectureCard(),
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
      statusLabel = 'Up to date';
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
          Text(
            userEmail != null ? 'Connected Account: $userEmail' : 'Local Guest Account',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Last Synced: ${_formatSyncTime(syncState.lastSyncTime)}',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
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
                  text: syncState.isSyncing ? 'Syncing...' : 'Sync Now',
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
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.destructive,
                side: const BorderSide(color: AppColors.destructive),
                minimumSize: const Size.fromHeight(40),
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
          ],
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

  Widget _buildStorageUsageSection(AsyncValue<StorageUsage> usageAsync) {
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
              return Column(
                children: [
                  _buildStorageRow(
                    icon: Icons.storage_rounded,
                    title: 'Local SQLite Database',
                    subtitle: 'Workspaces, periods, subjects, outbox metadata',
                    size: _formatBytes(usage.localDbBytes),
                  ),
                  const Divider(color: AppColors.border, height: AppSpacing.md),
                  _buildStorageRow(
                    icon: Icons.folder_copy_outlined,
                    title: 'Local Material Files',
                    subtitle: 'Cached documents, images, and notes on device',
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
          const SizedBox(height: AppSpacing.md),
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
            'Study Vault is local-first. All workspaces, subjects, materials, and edits are written directly to your on-device SQLite database. When internet connectivity is available, an Outbox worker deterministically replicates changes to Supabase in the background.',
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
