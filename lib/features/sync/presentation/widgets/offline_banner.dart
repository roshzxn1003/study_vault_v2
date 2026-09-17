import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/tokens/app_colors.dart';
import 'package:study_vault/core/design/tokens/app_spacing.dart';
import 'package:study_vault/core/design/tokens/app_typography.dart';
import 'package:study_vault/features/sync/domain/models/sync_state.dart';
import 'package:study_vault/features/sync/presentation/providers/sync_provider.dart';

/// Non-intrusive banner indicating network reachability, outbox queue, or sync activity.
class OfflineBanner extends ConsumerWidget {
  /// Whether to show a compact dot/chip instead of a full banner bar.
  final bool compact;

  /// Optional callback when user taps "Retry" on failure state.
  final VoidCallback? onRetry;

  const OfflineBanner({
    super.key,
    this.compact = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final countsAsync = ref.watch(outboxCountsProvider);

    // If completely idle, no errors, and no pending outbox items, hide banner
    final hasPending = (countsAsync.value?.pending ?? 0) > 0;
    final hasFailed = (countsAsync.value?.failed ?? 0) > 0;

    if (syncState.status == SyncStatus.idle && !hasPending && !hasFailed && !syncState.isOffline) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return _buildCompactBadge(context, ref, syncState, hasPending, hasFailed);
    }

    return _buildFullBanner(context, ref, syncState, hasPending, hasFailed);
  }

  Widget _buildCompactBadge(
    BuildContext context,
    WidgetRef ref,
    SyncState syncState,
    bool hasPending,
    bool hasFailed,
  ) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    if (syncState.isOffline) {
      bg = AppColors.surfaceSecondary;
      fg = AppColors.textSecondary;
      icon = Icons.cloud_off_rounded;
      label = 'Offline';
    } else if (syncState.isSyncing) {
      bg = AppColors.primarySubtle;
      fg = AppColors.primary;
      icon = Icons.sync_rounded;
      label = 'Syncing';
    } else if (hasFailed || syncState.hasError) {
      bg = AppColors.destructiveSubtle;
      fg = AppColors.destructive;
      icon = Icons.sync_problem_rounded;
      label = 'Sync issue';
    } else if (hasPending) {
      bg = AppColors.surfaceSecondary;
      fg = AppColors.textMuted;
      icon = Icons.cloud_queue_rounded;
      label = 'Changes pending';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (syncState.isSyncing)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: fg),
            )
          else
            Icon(icon, size: 12, color: fg),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildFullBanner(
    BuildContext context,
    WidgetRef ref,
    SyncState syncState,
    bool hasPending,
    bool hasFailed,
  ) {
    Color bg;
    Color borderColor;
    Color fg;
    IconData icon;
    String message;
    Widget? action;

    if (syncState.isOffline) {
      bg = AppColors.surfaceSecondary;
      borderColor = AppColors.border;
      fg = AppColors.textSecondary;
      icon = Icons.cloud_off_rounded;
      message = hasPending
          ? 'Working offline. Changes are saved locally and will sync when connected.'
          : 'Working offline. Local vault is available.';
    } else if (syncState.isSyncing) {
      bg = AppColors.primarySubtle;
      borderColor = AppColors.primaryDark;
      fg = AppColors.primaryLight;
      icon = Icons.sync_rounded;
      message = 'Synchronizing vault with cloud...';
    } else if (hasFailed || syncState.hasError) {
      bg = AppColors.destructiveSubtle;
      borderColor = AppColors.destructiveLight;
      fg = AppColors.destructive;
      icon = Icons.error_outline_rounded;
      message = syncState.errorMessage ?? 'Some changes failed to sync.';
      action = TextButton(
        onPressed: onRetry ?? () => ref.read(syncProvider.notifier).retryFailed(),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          'Retry',
          style: AppTypography.caption.copyWith(
            color: AppColors.destructive,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (hasPending) {
      bg = AppColors.surface;
      borderColor = AppColors.border;
      fg = AppColors.textSecondary;
      icon = Icons.cloud_upload_outlined;
      message = 'Unsynced changes waiting in outbox queue.';
      action = TextButton(
        onPressed: () => ref.read(syncProvider.notifier).syncNow(),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          'Sync Now',
          style: AppTypography.caption.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (syncState.isSyncing)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          else
            Icon(icon, size: 16, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(color: fg),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
