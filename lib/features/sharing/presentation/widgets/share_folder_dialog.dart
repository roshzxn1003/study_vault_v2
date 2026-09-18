import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/widgets.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import '../providers/sharing_providers.dart';
import '../../domain/models/models.dart';
import 'student_search_sheet.dart';

/// Modal dialog for safely sharing an entire academic folder with another student.
class ShareFolderDialog extends ConsumerStatefulWidget {
  final String folderId;
  final String folderName;
  final int materialCount;
  final int subfolderCount;
  final List<String> materialIds;
  final Map<String, String> materialTitles;

  const ShareFolderDialog({
    super.key,
    required this.folderId,
    required this.folderName,
    required this.materialCount,
    this.subfolderCount = 0,
    required this.materialIds,
    required this.materialTitles,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String folderId,
    required String folderName,
    required int materialCount,
    int subfolderCount = 0,
    required List<String> materialIds,
    required Map<String, String> materialTitles,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShareFolderDialog(
        folderId: folderId,
        folderName: folderName,
        materialCount: materialCount,
        subfolderCount: subfolderCount,
        materialIds: materialIds,
        materialTitles: materialTitles,
      ),
    );
  }

  @override
  ConsumerState<ShareFolderDialog> createState() => _ShareFolderDialogState();
}

class _ShareFolderDialogState extends ConsumerState<ShareFolderDialog> {
  StudentProfile? _selectedStudent;
  bool _includeFutureMaterials = false;
  bool _canDownload = false;
  bool _canSaveCopy = true; // Folders commonly allow copying
  bool _isSharing = false;
  String? _errorMessage;

  Future<void> _handleShare() async {
    if (_selectedStudent == null) {
      setState(() => _errorMessage = 'Please select a student.');
      return;
    }

    setState(() {
      _isSharing = true;
      _errorMessage = null;
    });

    final authRepo = ref.read(authRepositoryProvider);
    final user = authRepo.getCurrentUser();
    final ownerId = user?.id ?? 'guest';
    final profile = await ref.read(currentStudentProfileProvider.future);
    final repo = ref.read(sharingRepositoryProvider);

    final perms = <SharePermission>{
      SharePermission.view,
      if (_canDownload) SharePermission.download,
      if (_canSaveCopy) SharePermission.saveCopy,
    };

    try {
      // Share folder as collective resource and individual materials
      await repo.shareMaterial(
        ownerId: ownerId,
        recipientId: _selectedStudent!.id,
        resourceId: widget.folderId,
        resourceType: 'folder',
        resourceTitle: 'Folder: ${widget.folderName}',
        permissions: perms,
        ownerUsername: profile?.username,
        recipientUsername: _selectedStudent!.username,
        message: 'Shared folder "${widget.folderName}" containing ${widget.materialCount} materials.',
      );

      if (widget.materialIds.isNotEmpty) {
        await repo.shareMultipleMaterials(
          ownerId: ownerId,
          recipientId: _selectedStudent!.id,
          resourceIds: widget.materialIds,
          resourceTitles: widget.materialTitles,
          permissions: perms,
          ownerUsername: profile?.username,
          recipientUsername: _selectedStudent!.username,
        );
      }

      ref.invalidate(sharedByMeProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared folder "${widget.folderName}" with ${_selectedStudent!.displayUsername}!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Sharing folder failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      title: Row(
        children: [
          const Icon(Icons.folder_shared_outlined, color: AppColors.primaryLight, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Share Folder "${widget.folderName}"', style: AppTypography.title.copyWith(fontSize: 18)),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.card,
                  border: AppBorders.allStandard,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.folderName, style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.materialCount} materials${widget.subfolderCount > 0 ? ' • ${widget.subfolderCount} subfolders' : ''}',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sibling or parent folders will remain strictly private.',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Recipient
              Text('Student Recipient', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              if (_selectedStudent == null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_search_rounded, size: 18),
                  label: const Text('Search student by @username'),
                  onPressed: () async {
                    final student = await StudentSearchSheet.show(context);
                    if (student != null) setState(() => _selectedStudent = student);
                  },
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                    child: Text(_selectedStudent!.initial, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                  ),
                  title: Text(_selectedStudent!.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_selectedStudent!.displayUsername, style: const TextStyle(color: AppColors.primaryLight)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _selectedStudent = null),
                  ),
                ),

              const SizedBox(height: AppSpacing.md),

              // Future materials checkbox
              CheckboxListTile(
                value: _includeFutureMaterials,
                onChanged: (val) => setState(() => _includeFutureMaterials = val ?? false),
                title: const Text('Include new materials added later?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),

              CheckboxListTile(
                value: _canDownload,
                onChanged: (val) => setState(() => _canDownload = val ?? false),
                title: const Text('Allow offline download', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),

              CheckboxListTile(
                value: _canSaveCopy,
                onChanged: (val) => setState(() => _canSaveCopy = val ?? false),
                title: const Text('Allow saving personal copies', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        AppButton(
          text: 'Continue',
          isLoading: _isSharing,
          onPressed: _isSharing ? null : _handleShare,
        ),
      ],
    );
  }
}
