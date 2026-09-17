import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/app_empty_state.dart';
import 'package:study_vault/features/academic/domain/models/models.dart';
import 'package:study_vault/features/dashboard/domain/models/dashboard_models.dart';
import 'subject_card.dart';

/// Core dashboard section displaying the user's active academic subjects or topics.
/// Strictly implements "SUBJECTS FIRST" without generic file statistics.
class SubjectsSection extends StatelessWidget {
  final List<SubjectWithCount> subjects;
  final List<PersonalTopicEntity> personalTopics;
  final bool isPersonalLearning;
  final VoidCallback onAddSubject;

  const SubjectsSection({
    super.key,
    required this.subjects,
    required this.personalTopics,
    required this.isPersonalLearning,
    required this.onAddSubject,
  });

  @override
  Widget build(BuildContext context) {
    final title = isPersonalLearning ? 'Topics' : 'Subjects';
    final isEmpty = isPersonalLearning ? personalTopics.isEmpty : subjects.isEmpty;
    final isTabletOrDesktop = AppBreakpoints.isTablet(context) || AppBreakpoints.isDesktop(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppTypography.title.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (!isEmpty)
              TextButton.icon(
                onPressed: onAddSubject,
                icon: const Icon(Icons.add, size: 16, color: AppColors.primaryLight),
                label: Text(
                  isPersonalLearning ? 'Add Topic' : 'Add Subject',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Content / Empty State
        if (isEmpty)
          AppEmptyState(
            icon: isPersonalLearning ? Icons.lightbulb_outline : Icons.auto_stories_outlined,
            title: isPersonalLearning ? 'No topics yet' : 'No subjects added yet',
            description: isPersonalLearning
                ? 'Add topics and skills you are learning to organize your notes.'
                : 'You haven\'t added any subjects for this term yet.',
            actionText: isPersonalLearning ? 'Add Topic' : 'Add Subject',
            onAction: onAddSubject,
          )
        else if (isPersonalLearning)
          _buildPersonalTopicsLayout(context, isTabletOrDesktop)
        else
          _buildSubjectsLayout(context, isTabletOrDesktop),
      ],
    );
  }

  Widget _buildSubjectsLayout(BuildContext context, bool isTabletOrDesktop) {
    if (isTabletOrDesktop) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 2.2,
        ),
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          final s = subjects[index];
          return SubjectCard(
            subjectWithCount: s,
            onTap: () => context.push('/subject/${s.subject.id}'),
          );
        },
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: subjects.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final s = subjects[index];
        return SubjectCard(
          subjectWithCount: s,
          onTap: () => context.push('/subject/${s.subject.id}'),
        );
      },
    );
  }

  Widget _buildPersonalTopicsLayout(BuildContext context, bool isTabletOrDesktop) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: personalTopics.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final topic = personalTopics[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/subject/${topic.id}'),
            borderRadius: AppRadius.card,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.card,
                border: AppBorders.allStandard,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: AppRadius.button,
                      border: AppBorders.allStandard,
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic.name,
                          style: AppTypography.subtitle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (topic.description != null && topic.description!.isNotEmpty)
                          Text(
                            topic.description!,
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            'Personal Learning Topic',
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
