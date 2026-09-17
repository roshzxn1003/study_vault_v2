import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/app_empty_state.dart';
import 'package:study_vault/features/import/presentation/widgets/import_source_dialog.dart';
import 'package:study_vault/features/import/presentation/widgets/organize_sheet.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';
import 'package:study_vault/features/vault/presentation/widgets/rename_dialog.dart';
import '../providers/inbox_provider.dart';

/// Screen presenting pending unorganized study materials awaiting academic sorting.
/// Implements Section 17-20: Needs Organization, Single & Bulk Organize, Open, Rename, Delete.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(inboxProvider.notifier).init());
  }

  Future<void> _handleOrganizeSingle(MaterialItem item) async {
    final result = await OrganizeSheet.show(
      context: context,
      title: 'Organize "${item.title}"',
    );

    if (result != null && mounted) {
      await ref.read(inboxProvider.notifier).organizeItem(
        item.id,
        workspaceId: result.workspaceId,
        academicPeriodId: result.academicPeriodId,
        subjectId: result.subjectId,
        folderId: result.folderId,
        labelIds: result.labelIds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${item.title}" moved to library.'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    }
  }

  Future<void> _handleBulkOrganize() async {
    final state = ref.read(inboxProvider);
    final count = state.selectedCount;
    if (count == 0) return;

    final result = await OrganizeSheet.show(
      context: context,
      title: 'Organize $count Materials',
    );

    if (result != null && mounted) {
      await ref.read(inboxProvider.notifier).bulkOrganize(
        workspaceId: result.workspaceId,
        academicPeriodId: result.academicPeriodId,
        subjectId: result.subjectId,
        folderId: result.folderId,
        labelIds: result.labelIds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count materials organized and moved to library.'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    }
  }

  void _handleRename(MaterialItem item) async {
    final newTitle = await RenameDialog.show(
      context: context,
      title: 'Rename Material',
      initialValue: item.title,
    );

    if (newTitle != null && mounted) {
      ref.read(inboxProvider.notifier).renameItem(item.id, newTitle);
    }
  }

  void _handleDelete(MaterialItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text('Delete Material?', style: AppTypography.title),
        content: Text(
          'Are you sure you want to permanently delete "${item.title}"?',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTypography.button),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(inboxProvider.notifier).deleteItem(item.id);
    }
  }

  void _handleBulkDelete() async {
    final state = ref.read(inboxProvider);
    final count = state.selectedCount;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text('Delete $count Materials?', style: AppTypography.title),
        content: Text(
          'Are you sure you want to delete $count selected items from your inbox?',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTypography.button),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(inboxProvider.notifier).bulkDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inboxProvider);
    final notifier = ref.read(inboxProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () {
            if (state.isBulkMode) {
              notifier.clearSelection();
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: state.isBulkMode
            ? Text(
                '${state.selectedCount} selected',
                style: AppTypography.subtitle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              )
            : Text(
                'Inbox',
                style: AppTypography.subtitle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
        actions: [
          if (state.hasItems && !state.isBulkMode)
            IconButton(
              icon: const Icon(Icons.checklist_rounded, color: AppColors.textSecondary),
              tooltip: 'Select Multiple',
              onPressed: () => notifier.toggleBulkMode(),
            ),
          if (state.isBulkMode)
            TextButton(
              onPressed: () {
                if (state.isAllSelected) {
                  notifier.clearSelection();
                } else {
                  notifier.selectAll();
                }
              },
              child: Text(
                state.isAllSelected ? 'Deselect All' : 'Select All',
                style: AppTypography.button.copyWith(color: AppColors.primaryLight),
              ),
            ),
          if (!state.isBulkMode)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: AppColors.primaryLight),
              tooltip: 'Add Material',
              onPressed: () => ImportSourceDialog.show(context),
            ),
        ],
      ),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : !state.hasItems
                ? Center(
                    child: AppEmptyState(
                      icon: Icons.all_inclusive_rounded,
                      title: "You're all caught up.",
                      description: 'Materials you share or import will appear here.',
                      actionText: 'Add Material',
                      onAction: () => ImportSourceDialog.show(context),
                    ),
                  )
                : Stack(
                    children: [
                      RefreshIndicator(
                        onRefresh: () => notifier.loadInbox(),
                        child: ListView(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.md,
                            right: AppSpacing.md,
                            top: AppSpacing.sm,
                            bottom: 100,
                          ),
                          children: [
                            // Section header
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                                vertical: AppSpacing.sm,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Needs organization',
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: AppRadius.chip,
                                    ),
                                    child: Text(
                                      '${state.totalCount}',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.primaryLight,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),

                            // List of inbox items
                            ...state.items.map((item) {
                              final isSelected = state.selectedIds.contains(item.id);
                              return _buildInboxItemCard(
                                context: context,
                                item: item,
                                isBulkMode: state.isBulkMode,
                                isSelected: isSelected,
                                onSelect: () => notifier.toggleSelection(item.id),
                                onLongPress: () {
                                  if (!state.isBulkMode) {
                                    notifier.toggleBulkMode();
                                    notifier.toggleSelection(item.id);
                                  }
                                },
                              );
                            }),
                          ],
                        ),
                      ),

                      // Floating Bulk Action Bar
                      if (state.isBulkMode)
                        Positioned(
                          left: AppSpacing.md,
                          right: AppSpacing.md,
                          bottom: AppSpacing.md,
                          child: _buildBulkActionBar(state),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildInboxItemCard({
    required BuildContext context,
    required MaterialItem item,
    required bool isBulkMode,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onLongPress,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () {
          if (isBulkMode) {
            onSelect();
          } else {
            context.push('/material/${item.id}');
          }
        },
        onLongPress: onLongPress,
        borderRadius: AppRadius.card,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(
              color: isSelected ? AppColors.primaryLight : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              if (isBulkMode) ...[
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primaryLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (_) => onSelect(),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
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
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          item.type.label,
                          style: AppTypography.caption.copyWith(
                            color: item.type.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(' • ', style: TextStyle(color: AppColors.textTertiary)),
                        Text(
                          item.relativeUpdatedTime == 'Just now'
                              ? 'Received today'
                              : 'Received ${item.relativeUpdatedTime}',
                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                        ),
                        if (item.source != null) ...[
                          const Text(' • ', style: TextStyle(color: AppColors.textTertiary)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              item.source!,
                              style: AppTypography.caption.copyWith(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!isBulkMode) ...[
                ElevatedButton(
                  onPressed: () => _handleOrganizeSingle(item),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                  ),
                  child: const Text('Organize', style: TextStyle(fontSize: 12)),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondary),
                  color: AppColors.surface,
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
                  onSelected: (action) {
                    switch (action) {
                      case 'open':
                        context.push('/material/${item.id}');
                        break;
                      case 'organize':
                        _handleOrganizeSingle(item);
                        break;
                      case 'favorite':
                        ref.read(inboxProvider.notifier).toggleFavorite(item.id);
                        break;
                      case 'rename':
                        _handleRename(item);
                        break;
                      case 'delete':
                        _handleDelete(item);
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Open'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'organize',
                      child: Row(
                        children: [
                          Icon(Icons.folder_shared_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Organize'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'favorite',
                      child: Row(
                        children: [
                          Icon(
                            item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 18,
                            color: item.isFavorite ? AppColors.warning : null,
                          ),
                          const SizedBox(width: 8),
                          Text(item.isFavorite ? 'Unfavorite' : 'Favorite'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Rename'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulkActionBar(InboxState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            '${state.selectedCount} selected',
            style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            tooltip: 'Delete Selected',
            onPressed: state.selectedCount > 0 ? _handleBulkDelete : null,
          ),
          const SizedBox(width: AppSpacing.xs),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_shared_rounded, size: 16),
            label: Text('Organize (${state.selectedCount})'),
            onPressed: state.selectedCount > 0 ? _handleBulkOrganize : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
            ),
          ),
        ],
      ),
    );
  }
}
