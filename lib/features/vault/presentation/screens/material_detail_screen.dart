import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';
import '../../domain/models/models.dart';
import '../providers/vault_provider.dart';
import '../widgets/label_picker_dialog.dart';
import '../widgets/move_dialog.dart';
import '../widgets/rename_dialog.dart';

/// Screen presenting comprehensive metadata, content preview, and actions for an academic material.
class MaterialDetailScreen extends ConsumerStatefulWidget {
  final String materialId;

  const MaterialDetailScreen({
    super.key,
    required this.materialId,
  });

  @override
  ConsumerState<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends ConsumerState<MaterialDetailScreen> {
  MaterialItem? _material;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaterial();
  }

  Future<void> _loadMaterial() async {
    setState(() => _isLoading = true);
    final repo = ref.read(vaultRepositoryProvider);
    final item = await repo.getMaterialById(widget.materialId);
    if (item != null) {
      await repo.markOpened(widget.materialId);
    }
    if (mounted) {
      setState(() {
        _material = item;
        _isLoading = false;
      });
    }
  }

  void _showShareNotice(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Row(
          children: [
            const Icon(Icons.share_rounded, color: AppColors.primaryLight, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text('Student Sharing', style: AppTypography.title),
          ],
        ),
        content: Text(
          'Student-to-student academic sharing, study group packs, and peer distribution will be fully implemented in Phase 8 & 9.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Understood', style: AppTypography.button.copyWith(color: AppColors.primaryLight)),
          ),
        ],
      ),
    );
  }

  void _handleRename() async {
    if (_material == null) return;
    final newTitle = await RenameDialog.show(
      context: context,
      title: 'Rename Material',
      initialValue: _material!.title,
      labelText: 'Display Title',
    );
    if (newTitle != null && newTitle.trim().isNotEmpty) {
      final repo = ref.read(vaultRepositoryProvider);
      await repo.renameMaterial(_material!.id, newTitle.trim());
      await _loadMaterial();
      ref.read(vaultProvider.notifier).loadData();
    }
  }

  void _handleMove() async {
    if (_material == null) return;
    final academicState = ref.read(academicWorkspaceProvider);
    final vaultRepo = ref.read(vaultRepositoryProvider);
    final allFolders = await vaultRepo.getFolders(
      userId: _material!.userId,
      workspaceId: _material!.workspaceId,
    );

    if (!mounted) return;
    final destination = await MoveDialog.show(
      context: context,
      title: 'Move "${_material!.title}"',
      availableSubjects: academicState.subjects,
      availableFolders: allFolders,
      currentSubjectId: _material!.subjectId,
      currentFolderId: _material!.folderId,
    );

    if (destination != null) {
      await vaultRepo.moveMaterial(
        _material!.id,
        subjectId: destination.subjectId,
        folderId: destination.folderId,
      );
      await _loadMaterial();
      ref.read(vaultProvider.notifier).loadData();
    }
  }

  void _handleEditLabels() async {
    if (_material == null) return;
    final vaultState = ref.read(vaultProvider);
    final selectedIds = await LabelPickerDialog.show(
      context: context,
      availableLabels: vaultState.labels,
      initialSelectedLabelIds: _material!.labels.map((l) => l.id).toList(),
      onCreateLabel: (name) => ref.read(vaultProvider.notifier).createLabel(name),
    );

    if (selectedIds != null) {
      final repo = ref.read(vaultRepositoryProvider);
      await repo.setMaterialLabels(_material!.id, selectedIds);
      await _loadMaterial();
      ref.read(vaultProvider.notifier).loadData();
    }
  }

  void _handleToggleFavorite() async {
    if (_material == null) return;
    final repo = ref.read(vaultRepositoryProvider);
    await repo.toggleFavorite(_material!.id, !_material!.isFavorite);
    await _loadMaterial();
    ref.read(vaultProvider.notifier).loadData();
  }

  void _handleArchiveToggle() async {
    if (_material == null) return;
    final repo = ref.read(vaultRepositoryProvider);
    if (_material!.isArchived) {
      await repo.restoreMaterial(_material!.id);
    } else {
      await repo.archiveMaterial(_material!.id);
    }
    await _loadMaterial();
    ref.read(vaultProvider.notifier).loadData();
  }

  void _handleDelete() async {
    if (_material == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text('Delete "${_material!.title}"?', style: AppTypography.title),
        content: Text(
          'This action will permanently delete this material from your vault.',
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

    if (confirmed == true && mounted) {
      final repo = ref.read(vaultRepositoryProvider);
      await repo.deleteMaterial(_material!.id);
      if (mounted) {
        ref.read(vaultProvider.notifier).loadData();
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryLight)),
      );
    }

    final material = _material;
    if (material == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Text('Material not found', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final type = material.type;

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
          'Material Details',
          style: AppTypography.subtitle.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              material.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: material.isFavorite ? const Color(0xFFF59E0B) : AppColors.textMuted,
            ),
            onPressed: _handleToggleFavorite,
            tooltip: material.isFavorite ? 'Unfavorite' : 'Favorite',
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.textSecondary),
            onPressed: () => _showShareNotice(context),
            tooltip: 'Share material',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: _handleDelete,
            tooltip: 'Delete material',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Type Banner
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: type.color.withValues(alpha: 0.12),
                                borderRadius: AppRadius.chip,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(type.icon, size: 14, color: type.color),
                                  const SizedBox(width: 4),
                                  Text(
                                    type.label,
                                    style: AppTypography.caption.copyWith(
                                      color: type.color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (material.isArchived) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.textMuted.withValues(alpha: 0.15),
                                  borderRadius: AppRadius.chip,
                                ),
                                child: Text(
                                  'Archived',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          material.title,
                          style: AppTypography.headline.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (material.originalFileName != null &&
                            material.originalFileName != material.title) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Original file: ${material.originalFileName}',
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Academic Context & Location
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
                        Text(
                          'Academic Organization',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildMetaRow(Icons.book_outlined, 'Subject', material.subjectName ?? 'Vault Root'),
                        if (material.folderName != null)
                          _buildMetaRow(Icons.folder_outlined, 'Folder', material.folderName!),
                        _buildMetaRow(Icons.update_rounded, 'Updated', material.relativeUpdatedTime),
                        _buildMetaRow(Icons.visibility_outlined, 'Last Opened', material.relativeOpenedTime),
                        if (material.formattedFileSize.isNotEmpty)
                          _buildMetaRow(Icons.data_usage_rounded, 'File Size', material.formattedFileSize),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Labels Section
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Labels',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.primaryLight),
                              label: Text(
                                'Manage Labels',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: _handleEditLabels,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (material.labels.isEmpty)
                          Text(
                            'No labels attached yet.',
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: material.labels.map((l) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: l.color.withValues(alpha: 0.12),
                                  borderRadius: AppRadius.chip,
                                ),
                                child: Text(
                                  l.name,
                                  style: AppTypography.caption.copyWith(
                                    color: l.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Description / Notes Content
                  if (material.description != null && material.description!.isNotEmpty)
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
                          Text(
                            'Description',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            material.description!,
                            style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),

                  if (material.content != null && material.content!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
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
                          Text(
                            'Content',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            material.content!,
                            style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Primary Action Buttons
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Rename'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceSecondary,
                          foregroundColor: AppColors.textPrimary,
                          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                        ),
                        onPressed: _handleRename,
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.drive_file_move_outlined, size: 18),
                        label: const Text('Move'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceSecondary,
                          foregroundColor: AppColors.textPrimary,
                          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                        ),
                        onPressed: _handleMove,
                      ),
                      ElevatedButton.icon(
                        icon: Icon(
                          material.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                          size: 18,
                        ),
                        label: Text(material.isArchived ? 'Restore' : 'Archive'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceSecondary,
                          foregroundColor: AppColors.textPrimary,
                          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                        ),
                        onPressed: _handleArchiveToggle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$label: ',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
