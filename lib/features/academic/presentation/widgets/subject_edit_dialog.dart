import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/features/academic/domain/models/models.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';

/// Modal dialog for adding or renaming a subject within the active academic period.
class SubjectEditDialog extends ConsumerStatefulWidget {
  final AcademicSubjectEntity? existingSubject;

  const SubjectEditDialog({
    super.key,
    this.existingSubject,
  });

  static Future<bool?> show({
    required BuildContext context,
    AcademicSubjectEntity? existingSubject,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => SubjectEditDialog(existingSubject: existingSubject),
    );
  }

  @override
  ConsumerState<SubjectEditDialog> createState() => _SubjectEditDialogState();
}

class _SubjectEditDialogState extends ConsumerState<SubjectEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _descController;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isEditing => widget.existingSubject != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existingSubject?.name ?? '');
    _codeController =
        TextEditingController(text: widget.existingSubject?.code ?? '');
    _descController =
        TextEditingController(text: widget.existingSubject?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Subject name is required.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final notifier = ref.read(academicWorkspaceProvider.notifier);
    bool success;

    if (isEditing) {
      success = await notifier.renameSubject(
        subjectId: widget.existingSubject!.id,
        newName: name,
        code: _codeController.text.trim(),
        description: _descController.text.trim(),
      );
    } else {
      success = await notifier.addSubject(
        name: name,
        code: _codeController.text.trim(),
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
              'Failed to save subject.';
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
                isEditing ? 'Rename Subject' : 'Add Subject',
                style: AppTypography.title,
              ),
              AppSpacing.v16,

              AppTextField(
                label: 'Subject Name *',
                hint: 'e.g. Operating Systems, Physics',
                controller: _nameController,
                autofocus: true,
              ),
              AppSpacing.v12,

              AppTextField(
                label: 'Course Code (optional)',
                hint: 'e.g. CS301, PHY101',
                controller: _codeController,
              ),
              AppSpacing.v12,

              AppTextField(
                label: 'Description (optional)',
                hint: 'Brief syllabus or professor notes',
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
                    text: isEditing ? 'Save Changes' : 'Add Subject',
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
