import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/features/academic/domain/models/models.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';

/// Dialog for adding or renaming learning topics in Personal Learning workspaces.
class PersonalTopicEditDialog extends ConsumerStatefulWidget {
  final PersonalTopicEntity? existingTopic;

  const PersonalTopicEditDialog({
    super.key,
    this.existingTopic,
  });

  static Future<bool?> show({
    required BuildContext context,
    PersonalTopicEntity? existingTopic,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => PersonalTopicEditDialog(existingTopic: existingTopic),
    );
  }

  @override
  ConsumerState<PersonalTopicEditDialog> createState() =>
      _PersonalTopicEditDialogState();
}

class _PersonalTopicEditDialogState
    extends ConsumerState<PersonalTopicEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isEditing => widget.existingTopic != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existingTopic?.name ?? '');
    _descController =
        TextEditingController(text: widget.existingTopic?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Topic name is required.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final notifier = ref.read(academicWorkspaceProvider.notifier);
    bool success;

    if (isEditing) {
      success = await notifier.renamePersonalTopic(
        widget.existingTopic!.id,
        name,
      );
    } else {
      success = await notifier.addPersonalTopic(
        name,
        description: _descController.text.trim(),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = ref.read(academicWorkspaceProvider).errorMessage ??
              'Failed to save topic.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modal,
        side: AppBorders.standard,
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: AppDimensions.dialogMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Rename Topic' : 'Add Topic',
                style: AppTypography.title,
              ),
              AppSpacing.v16,

              AppTextField(
                label: 'Topic / Skill Name *',
                hint: 'e.g. Python, Flutter, System Design',
                controller: _nameController,
                autofocus: true,
              ),
              AppSpacing.v12,

              AppTextField(
                label: 'Description (optional)',
                hint: 'Goals, roadmap, or course links',
                controller: _descController,
                maxLines: 2,
              ),

              if (_errorMessage != null) ...[
                AppSpacing.v12,
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.destructiveSubtle,
                    borderRadius: AppRadius.brSm,
                    border: Border.all(
                      color: AppColors.destructive.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.destructiveLight,
                    ),
                  ),
                ),
              ],

              AppSpacing.v24,

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton.tertiary(
                    text: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(false),
                    size: AppButtonSize.md,
                  ),
                  AppSpacing.h12,
                  AppButton.primary(
                    text: isEditing ? 'Save Changes' : 'Add Topic',
                    isLoading: _isLoading,
                    onPressed: _handleSave,
                    size: AppButtonSize.md,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
