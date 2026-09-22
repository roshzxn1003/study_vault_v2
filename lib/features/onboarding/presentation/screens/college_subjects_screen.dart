import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:study_vault/features/onboarding/presentation/widgets/onboarding_scaffold.dart';

/// Screen 3A: College subjects configuration with add, rename, remove, reorder,
/// and duplicate detection.
class CollegeSubjectsScreen extends ConsumerStatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const CollegeSubjectsScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  ConsumerState<CollegeSubjectsScreen> createState() => _CollegeSubjectsScreenState();
}

class _CollegeSubjectsScreenState extends ConsumerState<CollegeSubjectsScreen> {
  final TextEditingController _addSubjectController = TextEditingController();
  final FocusNode _addFocusNode = FocusNode();
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _addSubjectController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  void _handleAdd() {
    final text = _addSubjectController.text.trim();
    if (text.isEmpty) return;

    final success = ref.read(onboardingProvider.notifier).addSubject(
          purpose: OnboardingPurpose.college,
          subjectName: text,
        );

    if (success) {
      _addSubjectController.clear();
      setState(() => _isAdding = false);
    }
  }

  void _showRenameDialog(int index, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) {
        return AppModal(
          title: 'Rename Subject',
          confirmText: 'Save',
          onConfirm: () {
            ref.read(onboardingProvider.notifier).renameSubject(
                  purpose: OnboardingPurpose.college,
                  index: index,
                  newName: controller.text,
                );
            Navigator.of(ctx).pop();
          },
          content: AppTextField(
            label: 'Subject Name',
            controller: controller,
            autofocus: true,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final collegeData = onboarding.collegeData;
    final semesterTitle = collegeData?.semester ?? 'Current Semester';
    final subjects = collegeData?.subjects ?? [];

    return OnboardingScaffold(
      currentStep: OnboardingStep.subjects,
      onBack: widget.onBack,
      errorMessage: onboarding.errorMessage,
      onDismissError: () => notifier.clearError(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSpacing.v16,

          // Header
          Text(
            'Add your subjects',
            textAlign: TextAlign.center,
            style: AppTypography.display.copyWith(
              fontSize: 26,
              letterSpacing: -0.6,
            ),
          ),
          AppSpacing.v8,
          Text(
            'Organizing for $semesterTitle. You can rename, reorder, or add more.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          AppSpacing.v24,

          // Semester Badge Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.brMd,
              border: AppBorders.allStandard,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_stories_rounded,
                  size: AppIcons.md,
                  color: AppColors.primaryLight,
                ),
                AppSpacing.h12,
                Text(
                  semesterTitle,
                  style: AppTypography.title.copyWith(fontSize: 15),
                ),
                const Spacer(),
                Text(
                  '${subjects.length} ${subjects.length == 1 ? 'subject' : 'subjects'}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          AppSpacing.v16,

          // Subject List or Empty State
          if (subjects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: AppEmptyState(
                icon: AppIcons.subjects,
                title: 'No subjects added yet',
                description: 'Add your first subject to organize your study materials.',
                actionText: 'Add Subject',
                onAction: () {
                  setState(() => _isAdding = true);
                  _addFocusNode.requestFocus();
                },
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: subjects.length,
              onReorderItem: (oldIndex, newIndex) {
                notifier.reorderSubjects(
                  purpose: OnboardingPurpose.college,
                  oldIndex: oldIndex,
                  newIndex: newIndex,
                );
              },
              itemBuilder: (context, index) {
                final subject = subjects[index];
                return Container(
                  key: ValueKey('college_subject_${index}_$subject'),
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.brMd,
                    border: AppBorders.allStandard,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 2,
                    ),
                    leading: const AppFileTypeIcon(type: AppFileType.folder, size: 32),
                    title: Text(
                      subject,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIconButton(
                          icon: AppIcons.edit,
                          size: AppIcons.sm,
                          tooltip: 'Rename',
                          onPressed: () => _showRenameDialog(index, subject),
                        ),
                        AppIconButton(
                          icon: AppIcons.delete,
                          size: AppIcons.sm,
                          color: AppColors.destructive,
                          tooltip: 'Remove',
                          onPressed: () => notifier.removeSubject(
                            purpose: OnboardingPurpose.college,
                            index: index,
                          ),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.drag_indicator_rounded,
                              size: 20,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          AppSpacing.v12,

          // Add Subject Inline Input or Action Button
          if (_isAdding)
            Container(
              padding: AppSpacing.p16,
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: AppRadius.brMd,
                border: AppBorders.allStandard,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: 'New Subject Name',
                    hint: 'e.g. Computer Networks',
                    controller: _addSubjectController,
                    focusNode: _addFocusNode,
                    onSubmitted: (_) => _handleAdd(),
                  ),
                  AppSpacing.v12,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppSecondaryButton(
                        text: 'Cancel',
                        size: AppButtonSize.sm,
                        onPressed: () {
                          _addSubjectController.clear();
                          setState(() => _isAdding = false);
                        },
                      ),
                      AppSpacing.h8,
                      AppButton.primary(
                        text: 'Add Subject',
                        size: AppButtonSize.sm,
                        onPressed: _handleAdd,
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            AppSecondaryButton(
              text: '+ Add Subject',
              onPressed: () {
                setState(() => _isAdding = true);
                _addFocusNode.requestFocus();
              },
            ),

          AppSpacing.v32,

          // Primary Action
          AppButton.primary(
            text: 'Continue',
            onPressed: subjects.isNotEmpty ? widget.onContinue : null,
          ),
          AppSpacing.v24,
        ],
      ),
    );
  }
}
