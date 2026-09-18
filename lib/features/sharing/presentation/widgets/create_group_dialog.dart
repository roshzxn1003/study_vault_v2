import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/widgets.dart';
import '../providers/sharing_providers.dart';
import '../../data/repositories/sharing_repository.dart';

/// Modal dialog to create a new Study Group.
class CreateGroupDialog extends ConsumerStatefulWidget {
  const CreateGroupDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateGroupDialog(),
    );
  }

  @override
  ConsumerState<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends ConsumerState<CreateGroupDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter a group name.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(studyGroupsProvider.notifier);
      await notifier.createGroup(
        name: name,
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created study group "$name"!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on SharingOfflineException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to create group: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      title: Row(
        children: [
          const Icon(Icons.group_add_outlined, color: AppColors.primaryLight, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Text('Create Study Group', style: AppTypography.title.copyWith(fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Group Name', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            AppTextField(
              controller: _nameController,
              hint: 'e.g. CSE Semester 3',
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Description (optional)', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            AppTextField(
              controller: _descController,
              hint: 'Study materials, syllabus discussion, and revision resources',
              maxLines: 2,
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
          text: 'Create Group',
          icon: const Icon(Icons.check_rounded),
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _handleCreate,
        ),
      ],
    );
  }
}
