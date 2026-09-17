import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';

/// Modal dialog providing safe, confirmed progression into the next academic period.
/// Enforces that previous semester data is NEVER deleted or moved automatically.
class SemesterTransitionDialog extends ConsumerStatefulWidget {
  final String currentPeriodName;
  final String suggestedNextPeriodName;
  final List<String> previousSubjectNames;

  const SemesterTransitionDialog({
    super.key,
    required this.currentPeriodName,
    required this.suggestedNextPeriodName,
    required this.previousSubjectNames,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String currentPeriodName,
    required String suggestedNextPeriodName,
    required List<String> previousSubjectNames,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => SemesterTransitionDialog(
        currentPeriodName: currentPeriodName,
        suggestedNextPeriodName: suggestedNextPeriodName,
        previousSubjectNames: previousSubjectNames,
      ),
    );
  }

  @override
  ConsumerState<SemesterTransitionDialog> createState() =>
      _SemesterTransitionDialogState();
}

class _SemesterTransitionDialogState
    extends ConsumerState<SemesterTransitionDialog> {
  late final TextEditingController _periodNameController;
  bool _copySubjects = false;
  late final Set<String> _selectedSubjectsToCopy;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _periodNameController =
        TextEditingController(text: widget.suggestedNextPeriodName);
    _selectedSubjectsToCopy = Set<String>.from(widget.previousSubjectNames);
  }

  @override
  void dispose() {
    _periodNameController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final nextName = _periodNameController.text.trim();
    if (nextName.isEmpty) {
      setState(() => _errorMessage = 'Please provide a semester/period name.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final notifier = ref.read(academicWorkspaceProvider.notifier);
    final success = await notifier.startNewSemester(
      newSemesterName: nextName,
      subjectsToCopy:
          _copySubjects ? _selectedSubjectsToCopy.toList() : null,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = ref.read(academicWorkspaceProvider).errorMessage ??
              'Failed to create new semester.';
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title with icon
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: AppRadius.brMd,
                      border: AppBorders.allStandard,
                    ),
                    child: const Icon(
                      Icons.school_outlined,
                      size: 20,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  AppSpacing.h12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start ${widget.suggestedNextPeriodName}?',
                          style: AppTypography.title,
                        ),
                        Text(
                          'Current: ${widget.currentPeriodName}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              AppSpacing.v16,

              // Safety Assurance Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.brMd,
                  border: AppBorders.allStandard,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: AppColors.info,
                    ),
                    AppSpacing.h8,
                    Expanded(
                      child: Text(
                        'Your ${widget.currentPeriodName} workspace will remain fully available in your academic history. Nothing from ${widget.currentPeriodName} will be deleted.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              AppSpacing.v16,

              // Period Name input
              AppTextField(
                label: 'New Semester / Period Name',
                controller: _periodNameController,
                hint: 'e.g. ${widget.suggestedNextPeriodName}',
              ),

              AppSpacing.v16,

              // Copy subjects option
              if (widget.previousSubjectNames.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Copy subjects from ${widget.currentPeriodName}?',
                        style: AppTypography.label,
                      ),
                    ),
                    Switch(
                      value: _copySubjects,
                      activeThumbColor: AppColors.primaryLight,
                      onChanged: (val) => setState(() => _copySubjects = val),
                    ),
                  ],
                ),
                if (_copySubjects) ...[
                  AppSpacing.v8,
                  Text(
                    'Select subjects to clone into your new semester. Creates separate new records; does not move previous subjects.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  AppSpacing.v8,
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: AppRadius.brMd,
                      border: AppBorders.allStandard,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: widget.previousSubjectNames.map((subject) {
                        final isChecked =
                            _selectedSubjectsToCopy.contains(subject);
                        return CheckboxListTile(
                          dense: true,
                          title: Text(subject, style: AppTypography.bodySmall),
                          value: isChecked,
                          activeColor: AppColors.primaryLight,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedSubjectsToCopy.add(subject);
                              } else {
                                _selectedSubjectsToCopy.remove(subject);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],

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

              // Action buttons
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
                    text: 'Create ${_periodNameController.text.trim().isNotEmpty ? _periodNameController.text.trim() : "Semester"}',
                    isLoading: _isLoading,
                    onPressed: _handleConfirm,
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
