import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:study_vault/features/onboarding/presentation/widgets/onboarding_scaffold.dart';

/// Screen 3C: Personal learning setup. Only asks for learning topics/skills;
/// explicitly does NOT ask for semester, class, degree, or academic year.
class PersonalLearningScreen extends ConsumerStatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const PersonalLearningScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  ConsumerState<PersonalLearningScreen> createState() => _PersonalLearningScreenState();
}

class _PersonalLearningScreenState extends ConsumerState<PersonalLearningScreen> {
  final TextEditingController _addTopicController = TextEditingController();
  final FocusNode _addFocusNode = FocusNode();
  bool _isAdding = false;

  static const List<String> _suggestedTopics = [
    'Python',
    'Flutter',
    'Web Development',
    'UI Design',
    'Git & GitHub',
    'Machine Learning',
    'Data Structures',
    'Photography',
    'Certification Prep',
  ];

  @override
  void dispose() {
    _addTopicController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  void _handleAdd([String? directText]) {
    final text = directText ?? _addTopicController.text.trim();
    if (text.isEmpty) return;

    final success = ref.read(onboardingProvider.notifier).addTopic(text);
    if (success) {
      _addTopicController.clear();
      setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final topics = onboarding.personalLearningData?.topics ?? [];

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
            'What are you learning?',
            textAlign: TextAlign.center,
            style: AppTypography.display.copyWith(
              fontSize: 26,
              letterSpacing: -0.6,
            ),
          ),
          AppSpacing.v8,
          Text(
            'Add courses, programming languages, skills, or independent projects.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          AppSpacing.v24,

          // Suggested Topic Chips
          Text(
            'Popular learning areas',
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.v8,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedTopics.map((topic) {
              final isAdded = topics.any((t) => t.toLowerCase() == topic.toLowerCase());
              return AppChip(
                label: topic,
                isSelected: isAdded,
                icon: isAdded ? const Icon(Icons.check, size: 14) : const Icon(Icons.add, size: 14),
                onTap: () {
                  if (!isAdded) {
                    _handleAdd(topic);
                  }
                },
              );
            }).toList(),
          ),

          AppSpacing.v24,

          // Configured Topics List
          Row(
            children: [
              Text(
                'Your learning spaces',
                style: AppTypography.label.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${topics.length} ${topics.length == 1 ? 'topic' : 'topics'}',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          AppSpacing.v12,

          if (topics.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: AppEmptyState(
                icon: AppIcons.vault,
                title: 'No topics added yet',
                description: 'Pick from the suggestions above or add your own custom skill.',
                actionText: 'Add Topic',
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
              itemCount: topics.length,
              onReorderItem: (oldIndex, newIndex) {
                notifier.reorderTopics(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final topic = topics[index];
                return Container(
                  key: ValueKey('personal_topic_${index}_$topic'),
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
                    leading: const AppFileTypeIcon(type: AppFileType.note, size: 32),
                    title: Text(
                      topic,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIconButton(
                          icon: AppIcons.delete,
                          size: AppIcons.sm,
                          color: AppColors.destructive,
                          tooltip: 'Remove',
                          onPressed: () => notifier.removeTopic(index),
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

          // Add Topic Inline Field
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
                    label: 'New Topic or Skill',
                    hint: 'e.g. Docker, Spanish, System Design',
                    controller: _addTopicController,
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
                          _addTopicController.clear();
                          setState(() => _isAdding = false);
                        },
                      ),
                      AppSpacing.h8,
                      AppButton.primary(
                        text: 'Add Topic',
                        size: AppButtonSize.sm,
                        onPressed: () => _handleAdd(),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            AppSecondaryButton(
              text: '+ Add Custom Topic',
              onPressed: () {
                setState(() => _isAdding = true);
                _addFocusNode.requestFocus();
              },
            ),

          AppSpacing.v32,

          // Primary Continue
          AppButton.primary(
            text: 'Continue',
            onPressed: widget.onContinue,
          ),
          AppSpacing.v24,
        ],
      ),
    );
  }
}
