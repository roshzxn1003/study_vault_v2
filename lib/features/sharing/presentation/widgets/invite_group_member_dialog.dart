import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/widgets.dart';
import '../providers/sharing_providers.dart';
import '../../domain/models/models.dart';
import 'student_search_sheet.dart';

/// Modal dialog allowing a group owner to invite another student to a study group.
class InviteGroupMemberDialog extends ConsumerStatefulWidget {
  final StudyGroup group;

  const InviteGroupMemberDialog({super.key, required this.group});

  static Future<bool?> show(BuildContext context, {required StudyGroup group}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InviteGroupMemberDialog(group: group),
    );
  }

  @override
  ConsumerState<InviteGroupMemberDialog> createState() => _InviteGroupMemberDialogState();
}

class _InviteGroupMemberDialogState extends ConsumerState<InviteGroupMemberDialog> {
  StudentProfile? _selectedStudent;
  bool _isInviting = false;
  String? _errorMessage;

  Future<void> _handleInvite() async {
    if (_selectedStudent == null) {
      setState(() => _errorMessage = 'Please select a student to invite.');
      return;
    }

    setState(() {
      _isInviting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(sharingRepositoryProvider);
      final profile = await ref.read(currentStudentProfileProvider.future);

      await repo.inviteMember(
        groupId: widget.group.id,
        userId: _selectedStudent!.id,
        invitedByUsername: profile?.username ?? 'owner',
        groupName: widget.group.name,
      );

      ref.invalidate(groupMembersProvider(widget.group.id));

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invited ${_selectedStudent!.displayUsername} to "${widget.group.name}"!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to send invitation: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      title: Row(
        children: [
          const Icon(Icons.person_add_alt_1_outlined, color: AppColors.primaryLight, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Text('Invite to Group', style: AppTypography.title.copyWith(fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Group: ${widget.group.name}', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
            const SizedBox(height: AppSpacing.md),
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
                      child: Text(_selectedStudent!.initial, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedStudent!.fullName, style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
                          Text(_selectedStudent!.displayUsername, style: const TextStyle(color: AppColors.primaryLight, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _selectedStudent = null),
                    ),
                  ],
                ),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        AppButton(
          text: 'Invite',
          icon: const Icon(Icons.send_rounded),
          isLoading: _isInviting,
          onPressed: _isInviting ? null : _handleInvite,
        ),
      ],
    );
  }
}
