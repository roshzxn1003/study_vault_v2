import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/app_empty_state.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';
import '../../domain/models/models.dart';
import '../providers/vault_provider.dart';
import '../widgets/bulk_action_bar.dart';
import '../widgets/create_folder_dialog.dart';
import '../widgets/delete_folder_dialog.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/folder_breadcrumbs.dart';
import '../widgets/folder_card.dart';
import '../widgets/label_picker_dialog.dart';
import '../widgets/material_card.dart';
import '../widgets/move_dialog.dart';
import '../widgets/rename_dialog.dart';
import '../widgets/sort_bottom_sheet.dart';
import '../widgets/vault_search_bar.dart';
import '../../../sharing/presentation/widgets/share_material_dialog.dart';
import '../../../sharing/presentation/widgets/share_to_group_dialog.dart';
import '../../../sharing/presentation/screens/create_study_pack_screen.dart';
import 'package:study_vault/core/design/widgets/add_material_sheet.dart';

/// Primary central Vault library screen.
/// Implements complete material, folder, label, search, filter, and bulk operations.
class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  // ===========================================================================
  // DIALOG & ACTION HANDLERS
  // ===========================================================================

  void _handleOpenFilters(BuildContext context, VaultState state) {
    final academicState = ref.read(academicWorkspaceProvider);
    FilterBottomSheet.show(
      context: context,
      currentFilter: state.filter,
      availableSubjects: academicState.subjects,
      availableLabels: state.labels,
      onApply: (filter) => ref.read(vaultProvider.notifier).applyFilter(filter),
    );
  }

  void _handleOpenSort(BuildContext context, VaultState state) {
    SortBottomSheet.show(
      context: context,
      currentSort: state.sortOption,
      onSelectSort: (sort) => ref.read(vaultProvider.notifier).setSort(sort),
    );
  }

  void _handleCreateFolder(BuildContext context) async {
    final name = await CreateFolderDialog.show(context: context);
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(vaultProvider.notifier).createFolder(name.trim());
    }
  }

  void _handleRenameFolder(BuildContext context, VaultFolder folder) async {
    final newName = await RenameDialog.show(
      context: context,
      title: 'Rename Folder',
      initialValue: folder.name,
      labelText: 'Folder Name',
    );
    if (newName != null && newName.trim().isNotEmpty) {
      await ref.read(vaultProvider.notifier).renameFolder(folder.id, newName.trim());
    }
  }

  void _handleMoveFolder(BuildContext context, VaultFolder folder) async {
    final academicState = ref.read(academicWorkspaceProvider);
    final vaultRepo = ref.read(vaultRepositoryProvider);
    final allFolders = await vaultRepo.getFolders(
      userId: folder.userId,
      workspaceId: folder.workspaceId,
    );

    if (!context.mounted) return;
    final destination = await MoveDialog.show(
      context: context,
      title: 'Move "${folder.name}"',
      availableSubjects: academicState.subjects,
      availableFolders: allFolders,
      currentFolderId: folder.parentId,
      movingFolderId: folder.id,
    );

    if (destination != null) {
      await ref.read(vaultProvider.notifier).moveFolder(folder.id, destination.folderId);
    }
  }

  void _handleDeleteFolder(BuildContext context, VaultFolder folder) async {
    final action = await DeleteFolderDialog.show(
      context: context,
      folder: folder,
    );

    if (action == DeleteFolderAction.deleteAll) {
      await ref.read(vaultProvider.notifier).deleteFolder(folder.id, deleteContents: true);
    } else if (action == DeleteFolderAction.moveContentsAndDelete) {
      await ref.read(vaultProvider.notifier).deleteFolder(
        folder.id,
        deleteContents: false,
        moveContentsToParentId: folder.parentId,
      );
    }
  }

  void _handleRenameMaterial(BuildContext context, MaterialItem material) async {
    final newTitle = await RenameDialog.show(
      context: context,
      title: 'Rename Material',
      initialValue: material.title,
      labelText: 'Display Title',
    );
    if (newTitle != null && newTitle.trim().isNotEmpty) {
      await ref.read(vaultProvider.notifier).renameMaterial(material.id, newTitle.trim());
    }
  }

  void _handleMoveMaterial(BuildContext context, MaterialItem material) async {
    final academicState = ref.read(academicWorkspaceProvider);
    final vaultRepo = ref.read(vaultRepositoryProvider);
    final allFolders = await vaultRepo.getFolders(
      userId: material.userId,
      workspaceId: material.workspaceId,
    );

    if (!context.mounted) return;
    final destination = await MoveDialog.show(
      context: context,
      title: 'Move "${material.title}"',
      availableSubjects: academicState.subjects,
      availableFolders: allFolders,
      currentSubjectId: material.subjectId,
      currentFolderId: material.folderId,
    );

    if (destination != null) {
      await ref.read(vaultProvider.notifier).moveMaterial(
        material.id,
        subjectId: destination.subjectId,
        folderId: destination.folderId,
      );
    }
  }

  void _handleEditLabels(BuildContext context, MaterialItem material, VaultState state) async {
    final selectedIds = await LabelPickerDialog.show(
      context: context,
      availableLabels: state.labels,
      initialSelectedLabelIds: material.labels.map((l) => l.id).toList(),
      onCreateLabel: (name) => ref.read(vaultProvider.notifier).createLabel(name),
    );

    if (selectedIds != null) {
      await ref.read(vaultProvider.notifier).setMaterialLabels(material.id, selectedIds);
    }
  }

  void _handleDeleteMaterial(BuildContext context, MaterialItem material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text('Delete "${material.title}"?', style: AppTypography.title),
        content: Text(
          'This action will permanently remove this material from your vault.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTypography.button.copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
            ),
            child: Text('Delete', style: AppTypography.button),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(vaultProvider.notifier).deleteMaterial(material.id);
    }
  }

  void _handleBulkMove(BuildContext context, VaultState state) async {
    final academicState = ref.read(academicWorkspaceProvider);
    final vaultRepo = ref.read(vaultRepositoryProvider);
    final allFolders = await vaultRepo.getFolders(
      userId: academicState.activeWorkspace?.userId ?? 'guest',
      workspaceId: academicState.activeWorkspace?.id,
    );

    if (!context.mounted) return;
    final destination = await MoveDialog.show(
      context: context,
      title: 'Move ${state.selectedCount} Materials',
      availableSubjects: academicState.subjects,
      availableFolders: allFolders,
    );

    if (destination != null) {
      await ref.read(vaultProvider.notifier).bulkMove(
        subjectId: destination.subjectId,
        folderId: destination.folderId,
      );
    }
  }

  void _handleBulkLabel(BuildContext context, VaultState state) async {
    final selectedIds = await LabelPickerDialog.show(
      context: context,
      availableLabels: state.labels,
      initialSelectedLabelIds: [],
      onCreateLabel: (name) => ref.read(vaultProvider.notifier).createLabel(name),
    );

    if (selectedIds != null && selectedIds.isNotEmpty) {
      await ref.read(vaultProvider.notifier).bulkAddLabels(selectedIds);
    }
  }

  void _handleBulkShare(BuildContext context, VaultState state) {
    final selectedIds = state.selectedMaterialIds.toList();
    final titles = <String, String>{};
    for (final m in state.materials) {
      if (selectedIds.contains(m.id)) {
        titles[m.id] = m.title;
      }
    }
    ShareMaterialDialog.show(
      context: context,
      multipleResourceIds: selectedIds,
      resourceTitles: titles,
    );
  }

  void _handleBulkCreatePack(BuildContext context, VaultState state) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateStudyPackScreen(
          initialMaterialIds: state.selectedMaterialIds.toList(),
        ),
      ),
    );
  }

  void _handleBulkDelete(BuildContext context, VaultState state) async {
    final count = state.selectedCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text('Delete $count materials?', style: AppTypography.title),
        content: Text(
          'This action will permanently remove the selected materials from your vault.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTypography.button.copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
            ),
            child: Text('Delete $count', style: AppTypography.button),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(vaultProvider.notifier).bulkDelete();
    }
  }

  // ===========================================================================
  // BUILD UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultProvider);
    final notifier = ref.read(vaultProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'vault_add_material_fab',
        onPressed: () => AddMaterialSheet.show(context, folderId: state.selectedFolderId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Material'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 1. Top Header: Title & Ingestion Action
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    top: AppSpacing.md,
                    bottom: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Vault',
                            style: AppTypography.headline.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Central Academic Library',
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Add Material quick button
                      IconButton(
                        icon: const Icon(Icons.add_rounded, color: AppColors.primaryLight, size: 24),
                        onPressed: () => AddMaterialSheet.show(context, folderId: state.selectedFolderId),
                        tooltip: 'Add Material',
                      ),
                    ],
                  ),
                ),

                // 2. Search Bar (Full Width)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                  child: VaultSearchBar(
                    initialQuery: state.searchQuery,
                    onSearchChanged: notifier.setSearchQuery,
                  ),
                ),

                const SizedBox(height: AppSpacing.xs),

                // 3. Top-Level Tabs: All, Recent, Favorites, Folders, Archive
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    children: VaultTab.values.map((tab) {
                      final isSelected = state.activeTab == tab;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(tab.label),
                          selected: isSelected,
                          onSelected: (_) => notifier.setTab(tab),
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          backgroundColor: AppColors.surface,
                          side: isSelected
                              ? const BorderSide(color: AppColors.primaryLight, width: 1.5)
                              : BorderSide(color: AppColors.border),
                          labelStyle: AppTypography.caption.copyWith(
                            color: isSelected ? AppColors.primaryLight : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 4),

                // 4. Secondary Action Row: Filter, Sort, View Mode, Select
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                  child: Row(
                    children: [
                      // Filter action button
                      InkWell(
                        onTap: () => _handleOpenFilters(context, state),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: state.filter.activeFilterCount > 0
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: state.filter.activeFilterCount > 0
                                  ? AppColors.primaryLight
                                  : AppColors.cardBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.filter_list_rounded,
                                size: 16,
                                color: state.filter.activeFilterCount > 0
                                    ? AppColors.primaryLight
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                state.filter.activeFilterCount > 0
                                    ? 'Filter (${state.filter.activeFilterCount})'
                                    : 'Filter',
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: state.filter.activeFilterCount > 0
                                      ? AppColors.primaryLight
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Sort action button
                      InkWell(
                        onTap: () => _handleOpenSort(context, state),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.swap_vert_rounded,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                state.sortOption.label,
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Grid / List Toggle
                      IconButton(
                        icon: Icon(
                          state.isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: notifier.toggleViewMode,
                        tooltip: state.isGridView ? 'Switch to list view' : 'Switch to grid view',
                      ),

                      // Bulk Select Mode Toggle
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        icon: Icon(
                          state.isBulkSelectionMode ? Icons.check_circle_rounded : Icons.checklist_rounded,
                          size: 16,
                          color: state.isBulkSelectionMode ? AppColors.primaryLight : AppColors.textSecondary,
                        ),
                        label: Text(
                          state.isBulkSelectionMode ? 'Cancel' : 'Select',
                          style: AppTypography.caption.copyWith(
                            color: state.isBulkSelectionMode ? AppColors.primaryLight : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: notifier.toggleBulkMode,
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: AppColors.borderSubtle),

                // Folders Sub-Bar (When on Folders Tab)
                if (state.activeTab == VaultTab.folders)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                    color: AppColors.surface,
                    child: Row(
                      children: [
                        Expanded(
                          child: FolderBreadcrumbs(
                            rootLabel: 'All Folders',
                            breadcrumbs: state.folderBreadcrumbs,
                            onSelectFolder: notifier.selectFolder,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.create_new_folder_outlined, size: 16, color: AppColors.primaryLight),
                          label: Text(
                            'New Folder',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () => _handleCreateFolder(context),
                        ),
                      ],
                    ),
                  ),

                // Main Content View
                Expanded(
                  child: _buildMainContent(context, state, notifier),
                ),
              ],
            ),

            // Bulk Action Bar (Overlay at bottom)
            if (state.isBulkSelectionMode && state.selectedCount > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BulkActionBar(
                  selectedCount: state.selectedCount,
                  isAllSelected: state.isAllSelected,
                  onSelectAll: state.isAllSelected ? notifier.clearSelection : notifier.selectAll,
                  onClearSelection: notifier.clearSelection,
                  onMove: () => _handleBulkMove(context, state),
                  onLabel: () => _handleBulkLabel(context, state),
                  onArchive: notifier.bulkArchive,
                  onDelete: () => _handleBulkDelete(context, state),
                  onShare: () => _handleBulkShare(context, state),
                  onCreatePack: () => _handleBulkCreatePack(context, state),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, VaultState state, VaultNotifier notifier) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryLight),
      );
    }

    if (state.errorMessage != null) {
      return Center(
        child: AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          description: state.errorMessage!,
          actionText: 'Try again',
          onAction: notifier.loadData,
        ),
      );
    }

    // Search Empty State
    if (state.isSearching && state.materials.isEmpty && state.folders.isEmpty) {
      return const Center(
        child: AppEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No materials found',
          description: 'Try a different search query or reset your filters.',
        ),
      );
    }

    // Tab-Specific Empty States
    if (state.materials.isEmpty && state.folders.isEmpty) {
      switch (state.activeTab) {
        case VaultTab.all:
          return Center(
            child: AppEmptyState(
              icon: Icons.folder_open_rounded,
              title: 'No materials yet',
              description: 'Materials you add will appear here in your central library.',
              actionText: 'Add Material',
              onAction: () => AddMaterialSheet.show(context, folderId: state.selectedFolderId),
            ),
          );
        case VaultTab.recent:
          return const Center(
            child: AppEmptyState(
              icon: Icons.schedule_rounded,
              title: 'No recent materials yet',
              description: 'Materials you open or update will appear here.',
            ),
          );
        case VaultTab.favorites:
          return const Center(
            child: AppEmptyState(
              icon: Icons.star_outline_rounded,
              title: 'No favorites yet',
              description: 'Tap the star icon on any material to access it quickly here.',
            ),
          );
        case VaultTab.folders:
          return Center(
            child: AppEmptyState(
              icon: Icons.create_new_folder_outlined,
              title: 'No folders created yet',
              description: 'Create folders to organize your study materials.',
              actionText: 'New Folder',
              onAction: () => _handleCreateFolder(context),
            ),
          );
        case VaultTab.archive:
          return const Center(
            child: AppEmptyState(
              icon: Icons.archive_outlined,
              title: 'Nothing archived',
              description: 'Archived materials are kept here safely without cluttering your active subjects.',
            ),
          );
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLarge = constraints.maxWidth >= 600;
        final crossAxisCount = constraints.maxWidth >= 1024
            ? 3
            : constraints.maxWidth >= 600
                ? 2
                : 1;

        return RefreshIndicator(
          onRefresh: notifier.loadData,
          color: AppColors.primaryLight,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: CustomScrollView(
              slivers: [
                // Folders Section (if any folders present)
                if (state.folders.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Folders (${state.folders.length})',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isLarge ? 2 : 1,
                    mainAxisExtent: 72,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.sm,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, index) {
                      final folder = state.folders[index];
                      return FolderCard(
                        folder: folder,
                        onTap: () => notifier.selectFolder(folder.id),
                        onRename: () => _handleRenameFolder(context, folder),
                        onMove: () => _handleMoveFolder(context, folder),
                        onDelete: () => _handleDeleteFolder(context, folder),
                      );
                    },
                    childCount: state.folders.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
              ],

              // Materials Section (if any materials present)
              if (state.materials.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Materials (${state.materials.length})',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                if (state.isGridView)
                  SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisExtent: 180,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, index) {
                        final material = state.materials[index];
                        final isSel = state.selectedMaterialIds.contains(material.id);
                        return MaterialCard(
                          material: material,
                          isSelected: isSel,
                          isSelectionMode: state.isBulkSelectionMode,
                          onTap: () {
                            notifier.markOpened(material.id);
                            context.push('/vault/material/${material.id}');
                          },
                          onLongPress: () {
                            if (!state.isBulkSelectionMode) {
                              notifier.toggleBulkMode();
                              notifier.toggleSelectMaterial(material.id);
                            }
                          },
                          onSelectChanged: (_) => notifier.toggleSelectMaterial(material.id),
                          onToggleFavorite: () => notifier.toggleFavorite(material.id),
                          onRename: () => _handleRenameMaterial(context, material),
                          onMove: () => _handleMoveMaterial(context, material),
                          onEditLabels: () => _handleEditLabels(context, material, state),
                          onArchive: () => notifier.archiveMaterial(material.id),
                          onRestore: () => notifier.restoreMaterial(material.id),
                          onDelete: () => _handleDeleteMaterial(context, material),
                          onShareStudent: () => ShareMaterialDialog.show(
                            context: context,
                            resourceId: material.id,
                            resourceTitle: material.title,
                          ),
                          onShareGroup: () => ShareToGroupDialog.show(
                            context,
                            preselectedResourceId: material.id,
                            preselectedResourceTitle: material.title,
                          ),
                          onCreatePack: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CreateStudyPackScreen(initialMaterialIds: [material.id]),
                            ),
                          ),
                        );
                      },
                      childCount: state.materials.length,
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, index) {
                        final material = state.materials[index];
                        final isSel = state.selectedMaterialIds.contains(material.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: SizedBox(
                            height: 160,
                            child: MaterialCard(
                              material: material,
                              isSelected: isSel,
                              isSelectionMode: state.isBulkSelectionMode,
                              onTap: () {
                                notifier.markOpened(material.id);
                                context.push('/vault/material/${material.id}');
                              },
                              onLongPress: () {
                                if (!state.isBulkSelectionMode) {
                                  notifier.toggleBulkMode();
                                  notifier.toggleSelectMaterial(material.id);
                                }
                              },
                              onSelectChanged: (_) => notifier.toggleSelectMaterial(material.id),
                              onToggleFavorite: () => notifier.toggleFavorite(material.id),
                              onRename: () => _handleRenameMaterial(context, material),
                              onMove: () => _handleMoveMaterial(context, material),
                              onEditLabels: () => _handleEditLabels(context, material, state),
                              onArchive: () => notifier.archiveMaterial(material.id),
                              onRestore: () => notifier.restoreMaterial(material.id),
                              onDelete: () => _handleDeleteMaterial(context, material),
                              onShareStudent: () => ShareMaterialDialog.show(
                                context: context,
                                resourceId: material.id,
                                resourceTitle: material.title,
                              ),
                              onShareGroup: () => ShareToGroupDialog.show(
                                context,
                                preselectedResourceId: material.id,
                                preselectedResourceTitle: material.title,
                              ),
                              onCreatePack: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CreateStudyPackScreen(initialMaterialIds: [material.id]),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: state.materials.length,
                    ),
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      );
    },
  );
  }
}
