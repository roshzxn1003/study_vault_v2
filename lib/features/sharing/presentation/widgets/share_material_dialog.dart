import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/widgets.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import '../providers/sharing_providers.dart';
import '../../domain/models/models.dart';
import '../../data/repositories/sharing_repository.dart';
import 'student_search_sheet.dart';

/// Modal dialog for sharing one or more academic materials with another student.
class ShareMaterialDialog extends ConsumerStatefulWidget {
  final String? resourceId;
  final String? resourceTitle;
  final List<String>? multipleResourceIds;
  final Map<String, String>? resourceTitles;
  final StudentProfile? preselectedStudent;

  const ShareMaterialDialog({
    super.key,
    this.resourceId,
    this.resourceTitle,
    this.multipleResourceIds,
    this.resourceTitles,
    this.preselectedStudent,
  });

  static Future<bool?> show({
    required BuildContext context,
    String? resourceId,
    String? resourceTitle,
    List<String>? multipleResourceIds,
    Map<String, String>? resourceTitles,
    StudentProfile? preselectedStudent,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShareMaterialDialog(
        resourceId: resourceId,
        resourceTitle: resourceTitle,
        multipleResourceIds: multipleResourceIds,
        resourceTitles: resourceTitles,
        preselectedStudent: preselectedStudent,
      ),
    );
  }

  @override
  ConsumerState<ShareMaterialDialog> createState() => _ShareMaterialDialogState();
}

class _ShareMaterialDialogState extends ConsumerState<ShareMaterialDialog> {
  StudentProfile? _selectedStudent;
  final _messageController = TextEditingController();

  // Conservative permissions: View is enabled by default
  bool _canDownload = false;
  bool _canSaveCopy = false;

  // Expiry option: 'never', '1_day', '7_days', '30_days', 'custom'
  String _expiryOption = 'never';
  DateTime? _customExpiryDate;

  bool _isSharing = false;
  String? _errorMessage;
  ShareItem? _existingDuplicateShare;

  @override
  void initState() {
    super.initState();
    _selectedStudent = widget.preselectedStudent;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool get _isMultiple => widget.multipleResourceIds != null && widget.multipleResourceIds!.isNotEmpty;
  int get _itemCount => _isMultiple ? widget.multipleResourceIds!.length : 1;

  DateTime? _calculateExpiry() {
    final now = DateTime.now();
    switch (_expiryOption) {
      case '1_day':
        return now.add(const Duration(days: 1));
      case '7_days':
        return now.add(const Duration(days: 7));
      case '30_days':
        return now.add(const Duration(days: 30));
      case 'custom':
        return _customExpiryDate;
      case 'never':
      default:
        return null;
    }
  }

  Future<void> _handleShare() async {
    if (_selectedStudent == null) {
      setState(() => _errorMessage = 'Please select a student to share with.');
      return;
    }

    setState(() {
      _isSharing = true;
      _errorMessage = null;
      _existingDuplicateShare = null;
    });

    final authRepo = ref.read(authRepositoryProvider);
    final user = authRepo.getCurrentUser();
    final ownerId = user?.id ?? 'guest';
    final profile = await ref.read(currentStudentProfileProvider.future);

    final perms = <SharePermission>{
      SharePermission.view,
      if (_canDownload) SharePermission.download,
      if (_canSaveCopy) SharePermission.saveCopy,
    };

    final expiry = _calculateExpiry();
    final message = _messageController.text.trim().isNotEmpty ? _messageController.text.trim() : null;

    final repo = ref.read(sharingRepositoryProvider);

    try {
      if (_isMultiple) {
        await repo.shareMultipleMaterials(
          ownerId: ownerId,
          recipientId: _selectedStudent!.id,
          resourceIds: widget.multipleResourceIds!,
          resourceTitles: widget.resourceTitles ?? {},
          permissions: perms,
          expiresAt: expiry,
          message: message,
          ownerUsername: profile?.username,
          recipientUsername: _selectedStudent!.username,
        );
      } else {
        await repo.shareMaterial(
          ownerId: ownerId,
          recipientId: _selectedStudent!.id,
          resourceId: widget.resourceId!,
          resourceTitle: widget.resourceTitle ?? 'Academic Material',
          permissions: perms,
          expiresAt: expiry,
          message: message,
          ownerUsername: profile?.username,
          ownerName: profile?.fullName,
          recipientUsername: _selectedStudent!.username,
        );
      }

      ref.invalidate(sharedByMeProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully shared with ${_selectedStudent!.displayUsername}!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on DuplicateShareException catch (e) {
      setState(() {
        _existingDuplicateShare = e.existingShare;
        _errorMessage = e.message;
      });
    } on SharingOfflineException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to share material: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _isMultiple
        ? 'Share $_itemCount Materials'
        : 'Share "${widget.resourceTitle ?? 'Material'}"';

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      title: Row(
        children: [
          const Icon(Icons.share_outlined, color: AppColors.primaryLight, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              titleText,
              style: AppTypography.title.copyWith(fontSize: 18),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recipient selection
              Text('Student Recipient', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              if (_selectedStudent == null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    side: AppBorders.standard,
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                  ),
                  icon: const Icon(Icons.person_search_rounded, size: 18),
                  label: const Text('Search student by @username'),
                  onPressed: () async {
                    final student = await StudentSearchSheet.show(context);
                    if (student != null) {
                      setState(() {
                        _selectedStudent = student;
                        _errorMessage = null;
                        _existingDuplicateShare = null;
                      });
                    }
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: AppRadius.card,
                    border: AppBorders.allStandard,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                        child: Text(
                          _selectedStudent!.initial,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selectedStudent!.fullName, style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
                            Text(_selectedStudent!.displayUsername, style: AppTypography.caption.copyWith(color: AppColors.primaryLight)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _selectedStudent = null),
                        tooltip: 'Change recipient',
                      ),
                    ],
                  ),
                ),

              // Duplicate share warning banner
              if (_existingDuplicateShare != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: AppRadius.card,
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                          const SizedBox(width: 8),
                          Text('Already shared', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.warning)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This resource is already actively shared with ${_selectedStudent!.displayUsername}.',
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.md),

              // Permissions section
              Text('Permissions', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              CheckboxListTile(
                value: true,
                onChanged: null, // View is immutable default
                title: const Text('View', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Recipient can open and read', style: TextStyle(fontSize: 12)),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _canDownload,
                onChanged: (val) => setState(() => _canDownload = val ?? false),
                title: const Text('Download', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Recipient can download original file', style: TextStyle(fontSize: 12)),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _canSaveCopy,
                onChanged: (val) => setState(() => _canSaveCopy = val ?? false),
                title: const Text('Save a copy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Recipient can save independent copy to their Vault', style: TextStyle(fontSize: 12)),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: AppSpacing.sm),

              // Expiry Dropdown
              Text('Expiry', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: _expiryOption,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: AppRadius.button),
                ),
                items: const [
                  DropdownMenuItem(value: 'never', child: Text('Never')),
                  DropdownMenuItem(value: '1_day', child: Text('1 day')),
                  DropdownMenuItem(value: '7_days', child: Text('7 days')),
                  DropdownMenuItem(value: '30_days', child: Text('30 days')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom date...')),
                ],
                onChanged: (val) async {
                  if (val == 'custom') {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 14)),
                      firstDate: DateTime.now().add(const Duration(hours: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        _expiryOption = 'custom';
                        _customExpiryDate = picked;
                      });
                    }
                  } else if (val != null) {
                    setState(() {
                      _expiryOption = val;
                      _customExpiryDate = null;
                    });
                  }
                },
              ),

              const SizedBox(height: AppSpacing.md),

              // Optional message
              Text('Message (optional)', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              AppTextField(
                controller: _messageController,
                hint: 'e.g. Good for tomorrow\'s revision',
                maxLines: 2,
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_errorMessage!, style: AppTypography.caption.copyWith(color: AppColors.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: AppTypography.button.copyWith(color: AppColors.textSecondary)),
        ),
        AppButton(
          text: 'Share',
          icon: const Icon(Icons.send_rounded),
          isLoading: _isSharing,
          onPressed: _isSharing ? null : _handleShare,
        ),
      ],
    );
  }
}
