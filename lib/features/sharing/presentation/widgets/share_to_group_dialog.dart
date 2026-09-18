import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/widgets.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';
import '../providers/sharing_providers.dart';
import '../../domain/models/models.dart';

/// Modal dialog for sharing a material from the Vault to a Study Group feed.
class ShareToGroupDialog extends ConsumerStatefulWidget {
  final String? preselectedResourceId;
  final String? preselectedResourceTitle;
  final String? preselectedGroupId;

  const ShareToGroupDialog({
    super.key,
    this.preselectedResourceId,
    this.preselectedResourceTitle,
    this.preselectedGroupId,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? preselectedResourceId,
    String? preselectedResourceTitle,
    String? preselectedGroupId,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShareToGroupDialog(
        preselectedResourceId: preselectedResourceId,
        preselectedResourceTitle: preselectedResourceTitle,
        preselectedGroupId: preselectedGroupId,
      ),
    );
  }

  @override
  ConsumerState<ShareToGroupDialog> createState() => _ShareToGroupDialogState();
}

class _ShareToGroupDialogState extends ConsumerState<ShareToGroupDialog> {
  String? _selectedGroupId;
  String? _selectedMaterialId;
  String? _selectedMaterialTitle;
  bool _canDownload = true;
  bool _canSaveCopy = true;
  bool _isSharing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.preselectedGroupId;
    _selectedMaterialId = widget.preselectedResourceId;
    _selectedMaterialTitle = widget.preselectedResourceTitle;
  }

  Future<void> _handleShare() async {
    if (_selectedGroupId == null) {
      setState(() => _errorMessage = 'Please select a study group.');
      return;
    }
    if (_selectedMaterialId == null) {
      setState(() => _errorMessage = 'Please select a material to share.');
      return;
    }

    setState(() {
      _isSharing = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final currentUserId = authRepo.getCurrentUser()?.id ?? 'guest';
      final profile = await ref.read(currentStudentProfileProvider.future);
      final repo = ref.read(sharingRepositoryProvider);

      final perms = <SharePermission>{
        SharePermission.view,
        if (_canDownload) SharePermission.download,
        if (_canSaveCopy) SharePermission.saveCopy,
      };

      await repo.shareMaterialToGroup(
        groupId: _selectedGroupId!,
        resourceId: _selectedMaterialId!,
        resourceTitle: _selectedMaterialTitle ?? 'Material',
        sharedBy: currentUserId,
        sharedByUsername: profile?.username,
        permissions: perms,
      );

      ref.invalidate(groupResourcesProvider(_selectedGroupId!));

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Material shared to study group feed!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to share to group: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsState = ref.watch(studyGroupsProvider);
    final vaultState = ref.watch(vaultProvider);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      title: Row(
        children: [
          const Icon(Icons.group_outlined, color: AppColors.primaryLight, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Text('Share to Study Group', style: AppTypography.title.copyWith(fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Study Group selection
              Text('Destination Group', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              if (groupsState.groups.isEmpty)
                Text('You are not a member of any study groups yet.', style: AppTypography.caption.copyWith(color: AppColors.textMuted))
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedGroupId ?? (groupsState.groups.isNotEmpty ? groupsState.groups.first.id : null),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: AppRadius.button),
                  ),
                  items: groupsState.groups.map((g) {
                    return DropdownMenuItem(value: g.id, child: Text(g.name));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedGroupId = val),
                ),
              const SizedBox(height: AppSpacing.md),

              // Material selection
              if (widget.preselectedResourceId != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: AppRadius.card,
                    border: AppBorders.allStandard,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 18, color: AppColors.primaryLight),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.preselectedResourceTitle ?? 'Material',
                          style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Text('Select Material from Vault', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: _selectedMaterialId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: AppRadius.button),
                  ),
                  items: vaultState.materials.map((m) {
                    return DropdownMenuItem(value: m.id, child: Text(m.title, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (val) {
                    final m = vaultState.materials.firstWhere((it) => it.id == val);
                    setState(() {
                      _selectedMaterialId = val;
                      _selectedMaterialTitle = m.title;
                    });
                  },
                ),
              ],

              const SizedBox(height: AppSpacing.md),

              // Permissions
              Text('Group Permissions', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              CheckboxListTile(
                value: true,
                onChanged: null,
                title: const Text('View by members', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: _canDownload,
                onChanged: (val) => setState(() => _canDownload = val ?? true),
                title: const Text('Allow members to download offline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: _canSaveCopy,
                onChanged: (val) => setState(() => _canSaveCopy = val ?? true),
                title: const Text('Allow members to save personal copy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
          text: 'Share to Group',
          icon: const Icon(Icons.send_rounded),
          isLoading: _isSharing,
          onPressed: _isSharing ? null : _handleShare,
        ),
      ],
    );
  }
}
