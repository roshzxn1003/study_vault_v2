import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/services/file_action_service.dart';
import 'package:study_vault/features/sharing/presentation/widgets/share_material_dialog.dart';
import 'package:study_vault/features/sharing/presentation/widgets/share_to_group_dialog.dart';
import 'package:study_vault/features/sharing/presentation/screens/create_study_pack_screen.dart';
import '../../domain/models/models.dart';

/// Responsive, scrollable bottom action sheet for Study Vault materials.
/// Replaces cramped popup menus with a structured, mobile-optimized action layout.
class MaterialActionSheet extends StatelessWidget {
  final MaterialItem material;
  final VoidCallback? onRename;
  final VoidCallback? onMove;
  final VoidCallback? onEditLabels;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;

  const MaterialActionSheet({
    super.key,
    required this.material,
    this.onRename,
    this.onMove,
    this.onEditLabels,
    this.onToggleFavorite,
    this.onArchive,
    this.onRestore,
    this.onDelete,
  });

  /// Displays the action sheet modal.
  static Future<void> show({
    required BuildContext context,
    required MaterialItem material,
    VoidCallback? onRename,
    VoidCallback? onMove,
    VoidCallback? onEditLabels,
    VoidCallback? onToggleFavorite,
    VoidCallback? onArchive,
    VoidCallback? onRestore,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MaterialActionSheet(
        material: material,
        onRename: onRename,
        onMove: onMove,
        onEditLabels: onEditLabels,
        onToggleFavorite: onToggleFavorite,
        onArchive: onArchive,
        onRestore: onRestore,
        onDelete: onDelete,
      ),
    );
  }

  void _openViewer(BuildContext context) {
    Navigator.of(context).pop();
    if (material.type == VaultMaterialType.note) {
      context.push('/notes/${material.id}');
    } else {
      context.push('/files/${material.id}');
    }
  }

  void _openDetails(BuildContext context) {
    Navigator.of(context).pop();
    context.push('/vault/material/${material.id}');
  }

  void _openWith(BuildContext context) {
    Navigator.of(context).pop();
    final path = material.filePath ?? material.storagePath ?? material.remoteUrl ?? '';
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file path available to open.')),
      );
      return;
    }
    FileActionService.instance.openWith(
      context: context,
      filePath: path,
      mimeType: material.mimeType,
      title: material.title,
      storagePath: material.storagePath,
      remoteUrl: material.remoteUrl,
    );
  }

  void _shareSystemFile(BuildContext context) {
    Navigator.of(context).pop();
    final path = material.filePath ?? material.storagePath ?? material.remoteUrl ?? '';
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file path available to share.')),
      );
      return;
    }
    FileActionService.instance.shareSystemFile(
      context: context,
      filePath: path,
      title: material.title,
      storagePath: material.storagePath,
      remoteUrl: material.remoteUrl,
    );
  }

  void _downloadFile(BuildContext context) {
    Navigator.of(context).pop();
    final path = material.filePath ?? material.storagePath ?? material.remoteUrl ?? '';
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File path is not available.')),
      );
      return;
    }
    FileActionService.instance.downloadFile(
      context: context,
      sourceFilePath: path,
      fileName: material.originalFileName ?? '${material.title}.${material.type.fileExtension}',
      storagePath: material.storagePath,
      remoteUrl: material.remoteUrl,
    );
  }

  void _shareWithStudent(BuildContext context) {
    Navigator.of(context).pop();
    ShareMaterialDialog.show(
      context: context,
      resourceId: material.id,
      resourceTitle: material.title,
    );
  }

  void _shareToGroup(BuildContext context) {
    Navigator.of(context).pop();
    ShareToGroupDialog.show(
      context,
      preselectedResourceId: material.id,
      preselectedResourceTitle: material.title,
    );
  }

  void _addToStudyPack(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateStudyPackScreen(
          initialMaterialIds: [material.id],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;
    final type = material.type;

    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grab handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Material Header Preview
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: type.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(type.icon, color: type.color, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.title,
                          style: AppTypography.subtitle.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${type.label} • ${material.formattedFileSize.isNotEmpty ? material.formattedFileSize : material.locationSubtitle}',
                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSubtle),

            // Scrollable Action Items List
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  children: [
                    // 1. Primary Viewing Actions
                    _buildTile(
                      icon: Icons.visibility_outlined,
                      title: 'Open in Study Vault',
                      subtitle: 'Read and view within the internal app viewer',
                      color: AppColors.primaryLight,
                      onTap: () => _openViewer(context),
                    ),
                    _buildTile(
                      icon: Icons.open_in_new_rounded,
                      title: 'Open with...',
                      subtitle: 'Choose an installed Android app to view or edit',
                      color: AppColors.cyan,
                      onTap: () => _openWith(context),
                    ),
                    _buildTile(
                      icon: Icons.download_rounded,
                      title: 'Download / Export File',
                      subtitle: 'Save a standalone copy to device storage',
                      color: AppColors.emerald,
                      onTap: () => _downloadFile(context),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.borderSubtle),

                    // 2. Study & Sharing Actions
                    _buildTile(
                      icon: Icons.share_rounded,
                      title: 'Share File via Android',
                      subtitle: 'Send via WhatsApp, Bluetooth, Gmail, or other apps',
                      color: AppColors.primaryLight,
                      onTap: () => _shareSystemFile(context),
                    ),
                    _buildTile(
                      icon: Icons.person_add_alt_1_outlined,
                      title: 'Share with Student',
                      subtitle: 'Send directly to another Study Vault user',
                      color: AppColors.primaryLight,
                      onTap: () => _shareWithStudent(context),
                    ),
                    _buildTile(
                      icon: Icons.groups_outlined,
                      title: 'Share to Study Group',
                      subtitle: 'Post to group collaboration feed',
                      color: AppColors.emerald,
                      onTap: () => _shareToGroup(context),
                    ),
                    _buildTile(
                      icon: Icons.folder_zip_outlined,
                      title: 'Add to Study Pack',
                      subtitle: 'Curate into a revision bundle or quiz pack',
                      color: const Color(0xFF8B5CF6),
                      onTap: () => _addToStudyPack(context),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.borderSubtle),

                    // 3. Organization & Metadata
                    _buildTile(
                      icon: Icons.info_outline_rounded,
                      title: 'Material Details',
                      subtitle: 'View full file metadata, date, path, and stats',
                      color: AppColors.textPrimary,
                      onTap: () => _openDetails(context),
                    ),
                    if (onRename != null)
                      _buildTile(
                        icon: Icons.edit_outlined,
                        title: 'Rename Material',
                        subtitle: 'Change the display title of this material',
                        color: AppColors.textPrimary,
                        onTap: () {
                          Navigator.of(context).pop();
                          onRename?.call();
                        },
                      ),
                    if (onMove != null)
                      _buildTile(
                        icon: Icons.drive_file_move_outlined,
                        title: 'Move Location',
                        subtitle: 'Organize into a different subject or folder',
                        color: AppColors.textPrimary,
                        onTap: () {
                          Navigator.of(context).pop();
                          onMove?.call();
                        },
                      ),
                    if (onEditLabels != null)
                      _buildTile(
                        icon: Icons.label_outline_rounded,
                        title: 'Manage Labels',
                        subtitle: 'Tag with Exam, Notes, Revision, or custom labels',
                        color: AppColors.amber,
                        onTap: () {
                          Navigator.of(context).pop();
                          onEditLabels?.call();
                        },
                      ),
                    if (onToggleFavorite != null)
                      _buildTile(
                        icon: material.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                        title: material.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                        subtitle: material.isFavorite ? 'Remove star from this item' : 'Pin to your Favorites list',
                        color: const Color(0xFFF59E0B),
                        onTap: () {
                          Navigator.of(context).pop();
                          onToggleFavorite?.call();
                        },
                      ),
                    if (material.isArchived && onRestore != null)
                      _buildTile(
                        icon: Icons.unarchive_outlined,
                        title: 'Restore Material',
                        subtitle: 'Move back into your active vault library',
                        color: AppColors.textPrimary,
                        onTap: () {
                          Navigator.of(context).pop();
                          onRestore?.call();
                        },
                      )
                    else if (onArchive != null)
                      _buildTile(
                        icon: Icons.archive_outlined,
                        title: 'Archive Material',
                        subtitle: 'Hide from active vault without deleting',
                        color: AppColors.textMuted,
                        onTap: () {
                          Navigator.of(context).pop();
                          onArchive?.call();
                        },
                      ),
                    const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.borderSubtle),

                    // 4. Deletion Action
                    if (onDelete != null)
                      _buildTile(
                        icon: Icons.delete_outline_rounded,
                        title: 'Delete Material',
                        subtitle: 'Permanently remove from Study Vault',
                        color: AppColors.error,
                        isDestructive: true,
                        onTap: () {
                          Navigator.of(context).pop();
                          onDelete?.call();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDestructive ? AppColors.error : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDestructive ? AppColors.error.withValues(alpha: 0.7) : AppColors.textSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
