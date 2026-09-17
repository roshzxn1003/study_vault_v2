import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/app_empty_state.dart';
import 'package:study_vault/features/inbox/presentation/providers/inbox_provider.dart';
import '../../domain/models/import_item.dart';
import '../providers/import_provider.dart';
import '../widgets/organize_sheet.dart';

/// Screen presenting incoming or staged study materials ready for ingestion.
/// Provides 1-tap Quick Save to Inbox, Save & Organize, duplicate handling, and progress feedback.
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  Future<void> _handleQuickSave(BuildContext context, WidgetRef ref) async {
    final success = await ref.read(importProvider.notifier).quickSaveToInbox();
    if (context.mounted && success) {
      ref.read(inboxProvider.notifier).loadInbox();
    }
  }

  Future<void> _handleSaveAndOrganize(BuildContext context, WidgetRef ref) async {
    final result = await OrganizeSheet.show(context: context);
    if (result != null && context.mounted) {
      final success = await ref.read(importProvider.notifier).saveAndOrganize(
        workspaceId: result.workspaceId,
        academicPeriodId: result.academicPeriodId,
        subjectId: result.subjectId,
        folderId: result.folderId,
        labelIds: result.labelIds,
      );
      if (context.mounted && success) {
        ref.read(inboxProvider.notifier).loadInbox();
      }
    }
  }

  void _showDuplicateDialog(
    BuildContext context,
    WidgetRef ref,
    ImportItem item,
  ) {
    final match = item.duplicateMatch;
    final location = match != null ? match.locationSubtitle : 'Library';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Text('Duplicate Material', style: AppTypography.title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This material may already exist in your Vault.',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.title,
              style: AppTypography.body.copyWith(color: AppColors.primaryLight),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Existing location: $location',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(importProvider.notifier).removeItem(item.id);
            },
            child: Text('Keep Existing', style: AppTypography.button),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(importProvider.notifier).allowDuplicateImport(item.id);
            },
            child: const Text('Import Anyway'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () {
            ref.read(importProvider.notifier).clear();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          'Add to Study Vault',
          style: AppTypography.subtitle.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (!state.isImporting && !state.isComplete && state.items.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(importProvider.notifier).clear();
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
              child: Text(
                'Cancel',
                style: AppTypography.button.copyWith(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: state.isValidating
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: AppSpacing.md),
                    Text('Inspecting incoming materials...'),
                  ],
                ),
              )
            : state.items.isEmpty
                ? Center(
                    child: AppEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No materials ready',
                      description: 'Share files from other apps or choose Add Material.',
                      actionText: 'Return to Dashboard',
                      onAction: () => context.go('/home'),
                    ),
                  )
                : state.isComplete
                    ? _buildSuccessView(context, ref, state)
                    : _buildStagingView(context, ref, state),
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context, WidgetRef ref, ImportState state) {
    final count = state.successCount;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              count == 1 ? 'Saved to Inbox' : '$count materials saved to Inbox',
              style: AppTypography.headline.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your study material is stored safely offline and ready to organize.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(importProvider.notifier).clear();
                  context.go('/inbox');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                ),
                child: Text('Organize Now', style: AppTypography.button),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  ref.read(importProvider.notifier).clear();
                  context.go('/home');
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                ),
                child: Text('Done', style: AppTypography.button),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStagingView(BuildContext context, WidgetRef ref, ImportState state) {
    final count = state.items.length;

    return Column(
      children: [
        // Subtitle & Progress
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    state.isImporting
                        ? 'Importing ${state.progressCurrent} of ${state.progressTotal}...'
                        : '$count ${count == 1 ? 'material' : 'materials'} ready',
                    style: AppTypography.title.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (state.hasDuplicates)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: AppRadius.chip,
                      ),
                      child: Text(
                        '${state.duplicateCount} duplicate',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              if (state.isImporting) ...[
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(
                  value: state.progressTotal > 0
                      ? state.progressCurrent / state.progressTotal
                      : null,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                ),
              ],
            ],
          ),
        ),

        // Error Banner if present
        if (state.errorMessage != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AppColors.error.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: AppTypography.caption.copyWith(color: AppColors.error),
                  ),
                ),
                if (state.hasFailures && !state.isImporting)
                  TextButton(
                    onPressed: () => ref.read(importProvider.notifier).retryFailed(),
                    child: const Text('Retry'),
                  ),
              ],
            ),
          ),

        // Items List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.items.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (ctx, i) {
              final item = state.items[i];
              return _buildItemCard(context, ref, item, state.isImporting);
            },
          ),
        ),

        // Bottom Actions Bar
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isImporting ? null : () => _handleSaveAndOrganize(context, ref),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                  ),
                  child: Text('Save & Organize', style: AppTypography.button),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: state.isImporting ? null : () => _handleQuickSave(context, ref),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                  ),
                  child: state.isImporting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Save to Inbox', style: AppTypography.button),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    WidgetRef ref,
    ImportItem item,
    bool isImporting,
  ) {
    final isDuplicate = item.status == ImportItemStatus.duplicateDetected;
    final isFailed = item.status == ImportItemStatus.failed;
    final isSuccess = item.status == ImportItemStatus.success;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: isDuplicate
              ? AppColors.warning
              : isFailed
                  ? AppColors.error
                  : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.type.color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.button,
                ),
                child: Icon(item.type.icon, color: item.type.color, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          item.type.label,
                          style: AppTypography.caption.copyWith(
                            color: item.type.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (item.fileSize > 0) ...[
                          const Text(' • ', style: TextStyle(color: AppColors.textTertiary)),
                          Text(
                            item.formattedFileSize,
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                        if (item.source != null) ...[
                          const Text(' • ', style: TextStyle(color: AppColors.textTertiary)),
                          Text(
                            item.source!,
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isSuccess)
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
              else if (isImporting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (!isImporting)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary),
                  onPressed: () => ref.read(importProvider.notifier).removeItem(item.id),
                ),
            ],
          ),

          // Duplicate Notice
          if (isDuplicate) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: AppRadius.card,
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Potential duplicate found in Vault.',
                      style: AppTypography.caption.copyWith(color: AppColors.warning),
                    ),
                  ),
                  InkWell(
                    onTap: () => _showDuplicateDialog(context, ref, item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Review',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Failure Notice
          if (isFailed && item.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: AppRadius.card,
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      item.errorMessage!,
                      style: AppTypography.caption.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
