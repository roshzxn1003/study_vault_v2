import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/app_empty_state.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';
import 'package:study_vault/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';
import 'package:study_vault/features/vault/presentation/providers/subject_vault_provider.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';
import 'package:study_vault/features/vault/presentation/widgets/bulk_action_bar.dart';
import 'package:study_vault/features/vault/presentation/widgets/create_folder_dialog.dart';
import 'package:study_vault/features/vault/presentation/widgets/delete_folder_dialog.dart';
import 'package:study_vault/features/vault/presentation/widgets/folder_breadcrumbs.dart';
import 'package:study_vault/features/vault/presentation/widgets/folder_card.dart';
import 'package:study_vault/features/vault/presentation/widgets/label_picker_dialog.dart';
import 'package:study_vault/features/vault/presentation/widgets/material_card.dart';
import 'package:study_vault/features/vault/presentation/widgets/move_dialog.dart';
import 'package:study_vault/features/vault/presentation/widgets/rename_dialog.dart';
import 'package:study_vault/features/vault/presentation/widgets/sort_bottom_sheet.dart';
import 'package:study_vault/core/design/widgets/add_material_sheet.dart';

/// Comprehensive Subject Material & Folder view screen.
/// Implements Section 6 with hierarchical folder drill-down, nested breadcrumbs,
/// material cards, search within subject, and bulk actions.
class SubjectDetailScreen extends ConsumerStatefulWidget {
  final String subjectId;

  const SubjectDetailScreen({
    super.key,
    required this.subjectId,
  });

  @override
  ConsumerState<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends ConsumerState<SubjectDetailScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handleCreateFolder(BuildContext context, SubjectVaultNotifier notifier, String? parentFolderName) async {
    final name = await CreateFolderDialog.show(
      context: context,
      title: 'Create Subject Folder',
      parentFolderName: parentFolderName,
    );
    if (name != null && name.trim().isNotEmpty) {
      await notifier.createFolder(name.trim());
    }
  }

  void _handleRenameFolder(BuildContext context, VaultFolder folder, SubjectVaultNotifier notifier) async {
    final newName = await RenameDialog.show(
      context: context,
      title: 'Rename Folder',
      initialValue: folder.name,
      labelText: 'Folder Name',
    );
    if (newName != null && newName.trim().isNotEmpty) {
      await notifier.renameFolder(folder.id, newName.trim());
    }
  }

  void _handleDeleteFolder(BuildContext context, VaultFolder folder, SubjectVaultNotifier notifier) async {
    final action = await DeleteFolderDialog.show(
      context: context,
      folder: folder,
    );

    if (action == DeleteFolderAction.deleteAll) {
      await notifier.deleteFolder(folder.id, deleteContents: true);
    } else if (action == DeleteFolderAction.moveContentsAndDelete) {
      await notifier.deleteFolder(
        folder.id,
        deleteContents: false,
        moveContentsToParentId: folder.parentId,
      );
    }
  }

  void _handleRenameMaterial(BuildContext context, MaterialItem material, SubjectVaultNotifier notifier) async {
    final newTitle = await RenameDialog.show(
      context: context,
      title: 'Rename Material',
      initialValue: material.title,
      labelText: 'Display Title',
    );
    if (newTitle != null && newTitle.trim().isNotEmpty) {
      await notifier.renameMaterial(material.id, newTitle.trim());
    }
  }

  void _handleMoveMaterial(MaterialItem material, SubjectVaultNotifier notifier) async {
    final academicState = ref.read(academicWorkspaceProvider);
    final vaultRepo = ref.read(vaultRepositoryProvider);
    final allFolders = await vaultRepo.getFolders(
      userId: material.userId,
      workspaceId: material.workspaceId,
    );

    if (!mounted) return;
    final destination = await MoveDialog.show(
      context: context,
      title: 'Move "${material.title}"',
      availableSubjects: academicState.subjects,
      availableFolders: allFolders,
      currentSubjectId: material.subjectId,
      currentFolderId: material.folderId,
    );

    if (destination != null) {
      await notifier.moveMaterial(
        material.id,
        subjectId: destination.subjectId,
        folderId: destination.folderId,
      );
    }
  }

  void _handleEditLabels(BuildContext context, MaterialItem material, SubjectVaultNotifier notifier) async {
    final vaultState = ref.read(vaultProvider);
    final selectedIds = await LabelPickerDialog.show(
      context: context,
      availableLabels: vaultState.labels,
      initialSelectedLabelIds: material.labels.map((l) => l.id).toList(),
      onCreateLabel: (name) => ref.read(vaultProvider.notifier).createLabel(name),
    );

    if (selectedIds != null) {
      final repo = ref.read(vaultRepositoryProvider);
      await repo.setMaterialLabels(material.id, selectedIds);
      await notifier.loadData();
    }
  }

  void _handleDeleteMaterial(BuildContext context, MaterialItem material, SubjectVaultNotifier notifier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text('Delete "${material.title}"?', style: AppTypography.title),
        content: Text(
          'This action will permanently delete this material from your subject.',
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
      await notifier.deleteMaterial(material.id);
    }
  }

  void _handleBulkMove(SubjectVaultState subState, SubjectVaultNotifier notifier) async {
    final academicState = ref.read(academicWorkspaceProvider);
    final vaultRepo = ref.read(vaultRepositoryProvider);
    final allFolders = await vaultRepo.getFolders(
      userId: academicState.activeWorkspace?.userId ?? 'guest',
      workspaceId: academicState.activeWorkspace?.id,
    );

    if (!mounted) return;
    final destination = await MoveDialog.show(
      context: context,
      title: 'Move ${subState.selectedCount} Materials',
      availableSubjects: academicState.subjects,
      availableFolders: allFolders,
      currentSubjectId: widget.subjectId,
    );

    if (destination != null) {
      await notifier.bulkMove(
        subjectId: destination.subjectId,
        folderId: destination.folderId,
      );
    }
  }

  void _handleBulkLabel(BuildContext context, SubjectVaultNotifier notifier) async {
    final vaultState = ref.read(vaultProvider);
    final selectedIds = await LabelPickerDialog.show(
      context: context,
      availableLabels: vaultState.labels,
      initialSelectedLabelIds: [],
      onCreateLabel: (name) => ref.read(vaultProvider.notifier).createLabel(name),
    );

    if (selectedIds != null && selectedIds.isNotEmpty) {
      await notifier.bulkAddLabels(selectedIds);
    }
  }

  void _handleBulkDelete(BuildContext context, SubjectVaultState subState, SubjectVaultNotifier notifier) async {
    final count = subState.selectedCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text('Delete $count materials?', style: AppTypography.title),
        content: Text(
          'This action will permanently delete the selected materials from this subject.',
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
      await notifier.bulkDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashState = ref.watch(dashboardProvider);
    final subState = ref.watch(subjectVaultProvider(widget.subjectId));
    final notifier = ref.read(subjectVaultProvider(widget.subjectId).notifier);

    // Locate subject in state or personal topics
    final subjectWithCount = dashState.subjects.where(
          (s) => s.subject.id == widget.subjectId,
        ).firstOrNull;
    final personalTopic = dashState.personalTopics.where(
          (t) => t.id == widget.subjectId,
        ).firstOrNull;

    final subjectName = subjectWithCount?.subject.name ??
        personalTopic?.name ??
        'Subject Details';
    final subjectCode = subjectWithCount?.subject.code;
    final subjectDesc = subjectWithCount?.subject.description ?? personalTopic?.description;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          subjectName,
          style: AppTypography.subtitle.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (subjectCode != null && subjectCode.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: AppRadius.chip,
                    border: AppBorders.allStandard,
                  ),
                  child: Text(
                    subjectCode.trim().toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primaryLight, size: 26),
            tooltip: 'Add Material',
            onPressed: () => AddMaterialSheet.show(
              context,
              subjectId: widget.subjectId,
              folderId: subState.currentFolderId,
              destinationLabel: subjectName,
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: FloatingActionButton.extended(
          heroTag: 'subject_add_material_fab',
          onPressed: () => AddMaterialSheet.show(
            context,
            subjectId: widget.subjectId,
            folderId: subState.currentFolderId,
            destinationLabel: subjectName,
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Material'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: notifier.loadData,
              color: AppColors.primaryLight,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Academic Context Header Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadius.card,
                            border: AppBorders.allStandard,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    dashState.activeWorkspace?.purpose.icon ?? Icons.school_outlined,
                                    size: 16,
                                    color: AppColors.primaryLight,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    dashState.academicIdentityTitle,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '• ${dashState.academicSubtitle}',
                                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                subjectName,
                                style: AppTypography.headline.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (subjectDesc != null && subjectDesc.trim().isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  subjectDesc.trim(),
                                  style: AppTypography.body.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.sm),
                              // AI Tutor & Study Quick Actions
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primaryLight,
                                        side: const BorderSide(color: AppColors.primaryLight),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                                      ),
                                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                                      label: Text('Ask AI about $subjectName', maxLines: 1, overflow: TextOverflow.ellipsis),
                                      onPressed: () {
                                        context.push('/ai?subject=${Uri.encodeComponent(subjectName)}');
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    ActionChip(
                                      avatar: const Icon(Icons.style_rounded, size: 14, color: AppColors.emerald),
                                      label: const Text('Flashcards'),
                                      onPressed: () => context.push('/study/flashcards/$subjectName'),
                                      backgroundColor: AppColors.surfaceSecondary,
                                      side: const BorderSide(color: AppColors.borderSubtle),
                                      labelStyle: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(width: 6),
                                    ActionChip(
                                      avatar: const Icon(Icons.quiz_rounded, size: 14, color: AppColors.amber),
                                      label: const Text('Practice Quiz'),
                                      onPressed: () => context.push('/study/quiz/$subjectName'),
                                      backgroundColor: AppColors.surfaceSecondary,
                                      side: const BorderSide(color: AppColors.borderSubtle),
                                      labelStyle: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(width: 6),
                                    ActionChip(
                                      avatar: const Icon(Icons.psychology_rounded, size: 14, color: AppColors.cyan),
                                      label: const Text('Socratic Tutor'),
                                      onPressed: () => context.push('/study/learn/$subjectName'),
                                      backgroundColor: AppColors.surfaceSecondary,
                                      side: const BorderSide(color: AppColors.borderSubtle),
                                      labelStyle: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Search within Subject Bar
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadius.button,
                            border: AppBorders.allStandard,
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: notifier.setSearchQuery,
                            style: AppTypography.body.copyWith(color: AppColors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search within $subjectName...',
                              hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted, fontSize: 14),
                              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        notifier.setSearchQuery('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Nested Folder Breadcrumbs
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadius.button,
                            border: AppBorders.allSubtle,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: FolderBreadcrumbs(
                                  rootLabel: subjectName,
                                  breadcrumbs: subState.breadcrumbs,
                                  onSelectFolder: notifier.selectFolder,
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.create_new_folder_outlined, size: 16, color: AppColors.primaryLight),
                                label: Text(
                                  '+ New Folder',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.primaryLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () => _handleCreateFolder(
                                  context,
                                  notifier,
                                  subState.breadcrumbs.isNotEmpty ? subState.breadcrumbs.last.name : subjectName,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        // Folders Grid (at current level)
                        if (subState.folders.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Folders (${subState.folders.length})',
                                style: AppTypography.subtitle.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 72,
                              crossAxisSpacing: AppSpacing.md,
                              mainAxisSpacing: AppSpacing.sm,
                            ),
                            itemCount: subState.folders.length,
                            itemBuilder: (ctx, index) {
                              final folder = subState.folders[index];
                              return FolderCard(
                                folder: folder,
                                onTap: () => notifier.selectFolder(folder.id),
                                onRename: () => _handleRenameFolder(context, folder, notifier),
                                onDelete: () => _handleDeleteFolder(context, folder, notifier),
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],

                        // Materials Section Header: Count + Sort + Grid/List Toggle + Select Mode
                        Row(
                          children: [
                            Text(
                              'Materials (${subState.materials.length})',
                              style: AppTypography.subtitle.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),

                            // Sort Action
                            IconButton(
                              icon: const Icon(Icons.swap_vert_rounded, size: 20, color: AppColors.textSecondary),
                              onPressed: () {
                                SortBottomSheet.show(
                                  context: context,
                                  currentSort: subState.sortOption,
                                  onSelectSort: notifier.setSort,
                                );
                              },
                              tooltip: 'Sort materials',
                            ),

                            // Grid/List Toggle
                            IconButton(
                              icon: Icon(
                                subState.isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: notifier.toggleViewMode,
                              tooltip: subState.isGridView ? 'List view' : 'Grid view',
                            ),

                            // Bulk Select Toggle
                            TextButton.icon(
                              icon: Icon(
                                subState.isBulkSelectionMode ? Icons.check_circle_rounded : Icons.checklist_rounded,
                                size: 16,
                                color: subState.isBulkSelectionMode ? AppColors.primaryLight : AppColors.textSecondary,
                              ),
                              label: Text(
                                subState.isBulkSelectionMode ? 'Cancel' : 'Select',
                                style: AppTypography.caption.copyWith(
                                  color: subState.isBulkSelectionMode ? AppColors.primaryLight : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: notifier.toggleBulkMode,
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Materials Content or Empty State
                        if (subState.isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.xl),
                              child: CircularProgressIndicator(color: AppColors.primaryLight),
                            ),
                          )
                        else if (subState.materials.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                            child: Center(
                                child: AppEmptyState(
                                  icon: Icons.folder_open_outlined,
                                  title: subState.isRoot
                                      ? 'No materials in this subject yet.'
                                      : 'This folder is empty.',
                                  description: subState.isRoot
                                      ? 'Upload PDFs, notes, slides, or scans to study efficiently.'
                                      : 'No materials inside this folder.',
                                  actionText: 'Add Material',
                                  onAction: () => AddMaterialSheet.show(
                                    context,
                                    subjectId: widget.subjectId,
                                    folderId: subState.currentFolderId,
                                    destinationLabel: subjectName,
                                  ),
                                ),
                            ),
                          )
                        else if (subState.isGridView)
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 180,
                              crossAxisSpacing: AppSpacing.md,
                              mainAxisSpacing: AppSpacing.md,
                            ),
                            itemCount: subState.materials.length,
                            itemBuilder: (ctx, index) {
                              final material = subState.materials[index];
                              final isSel = subState.selectedMaterialIds.contains(material.id);
                              return MaterialCard(
                                material: material,
                                isSelected: isSel,
                                isSelectionMode: subState.isBulkSelectionMode,
                                onTap: () => context.push('/vault/material/${material.id}'),
                                onLongPress: () {
                                  if (!subState.isBulkSelectionMode) {
                                    notifier.toggleBulkMode();
                                    notifier.toggleSelectMaterial(material.id);
                                  }
                                },
                                onSelectChanged: (_) => notifier.toggleSelectMaterial(material.id),
                                onToggleFavorite: () => notifier.toggleFavorite(material.id),
                                onRename: () => _handleRenameMaterial(context, material, notifier),
                                onMove: () => _handleMoveMaterial(material, notifier),
                                onEditLabels: () => _handleEditLabels(context, material, notifier),
                                onArchive: () => notifier.archiveMaterial(material.id),
                                onDelete: () => _handleDeleteMaterial(context, material, notifier),
                              );
                            },
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: subState.materials.length,
                            itemBuilder: (ctx, index) {
                              final material = subState.materials[index];
                              final isSel = subState.selectedMaterialIds.contains(material.id);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: SizedBox(
                                  height: 160,
                                  child: MaterialCard(
                                    material: material,
                                    isSelected: isSel,
                                    isSelectionMode: subState.isBulkSelectionMode,
                                    onTap: () => context.push('/vault/material/${material.id}'),
                                    onLongPress: () {
                                      if (!subState.isBulkSelectionMode) {
                                        notifier.toggleBulkMode();
                                        notifier.toggleSelectMaterial(material.id);
                                      }
                                    },
                                    onSelectChanged: (_) => notifier.toggleSelectMaterial(material.id),
                                    onToggleFavorite: () => notifier.toggleFavorite(material.id),
                                    onRename: () => _handleRenameMaterial(context, material, notifier),
                                    onMove: () => _handleMoveMaterial(material, notifier),
                                    onEditLabels: () => _handleEditLabels(context, material, notifier),
                                    onArchive: () => notifier.archiveMaterial(material.id),
                                    onDelete: () => _handleDeleteMaterial(context, material, notifier),
                                  ),
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bulk Action Bar Overlay
            if (subState.isBulkSelectionMode && subState.selectedCount > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BulkActionBar(
                  selectedCount: subState.selectedCount,
                  isAllSelected: subState.materials.isNotEmpty && subState.selectedCount == subState.materials.length,
                  onSelectAll: () {
                    for (final m in subState.materials) {
                      if (!subState.selectedMaterialIds.contains(m.id)) {
                        notifier.toggleSelectMaterial(m.id);
                      }
                    }
                  },
                  onClearSelection: notifier.clearSelection,
                  onMove: () => _handleBulkMove(subState, notifier),
                  onLabel: () => _handleBulkLabel(context, notifier),
                  onArchive: notifier.bulkArchive,
                  onDelete: () => _handleBulkDelete(context, subState, notifier),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
