import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/features/academic/domain/models/models.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';
import 'package:study_vault/features/academic/presentation/widgets/semester_transition_dialog.dart';
import 'package:study_vault/features/academic/presentation/widgets/subject_edit_dialog.dart';
import 'package:study_vault/features/academic/presentation/widgets/personal_topic_edit_dialog.dart';

/// Primary Academic Workspace screen (/academic).
/// Displays active academic context, current/archived period switcher,
/// subject management with reordering, and personal learning topics.
class AcademicWorkspaceScreen extends ConsumerWidget {
  const AcademicWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(academicWorkspaceProvider);
    final notifier = ref.read(academicWorkspaceProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        title: 'Academic Workspace',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/academic/settings');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu_outlined, color: AppColors.textSecondary),
            tooltip: 'Academic History',
            onPressed: () => context.push('/academic/history'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            tooltip: 'Academic Settings',
            onPressed: () => context.push('/academic/settings'),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: AppLoadingState(message: 'Loading academic workspace...'))
          : RefreshIndicator(
              onRefresh: () => notifier.init(),
              color: AppColors.primaryLight,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  120,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Error banner
                    if (state.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.destructiveSubtle,
                          borderRadius: AppRadius.brMd,
                          border: Border.all(
                            color: AppColors.destructive.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.destructiveLight, size: 20),
                            AppSpacing.h12,
                            Expanded(
                              child: Text(
                                state.errorMessage!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.destructiveLight,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: AppColors.textMuted, size: 16),
                              onPressed: () => notifier.clearError(),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 1. Workspace Switcher (if multiple workspaces exist)
                    if (state.workspaces.length > 1) ...[
                      _buildWorkspaceSwitcher(context, ref, state),
                      AppSpacing.v16,
                    ],

                    // 2. Main Context Card
                    if (state.isPersonalLearning)
                      _buildPersonalLearningHeader(context, ref, state)
                    else
                      _buildAcademicPeriodHeader(context, ref, state),

                    AppSpacing.v20,

                    // 3. Archive Notice Banner (if viewing previous period)
                    if (!state.isPersonalLearning && !state.isViewingCurrentPeriod) ...[
                      _buildArchiveBanner(context, ref, state),
                      AppSpacing.v20,
                    ],

                    // 4. Subjects / Topics Header & Action Bar
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 420;
                        final titleWidget = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.isPersonalLearning ? 'Topics & Skills' : 'Subjects',
                              style: AppTypography.title,
                            ),
                            Text(
                              state.isPersonalLearning
                                  ? '${state.personalTopics.length} topics tracked'
                                  : '${state.subjects.length} subjects in ${state.selectedPeriod?.name ?? "semester"}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        );

                        final actionsWidget = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (!state.isPersonalLearning)
                              AppSecondaryButton(
                                text: 'Start Next',
                                icon: const Icon(Icons.arrow_forward, size: 14),
                                size: AppButtonSize.sm,
                                onPressed: () => _handleStartNextSemester(context, ref, state),
                              ),
                            AppButton.primary(
                              text: state.isPersonalLearning ? 'Add Topic' : 'Add Subject',
                              icon: const Icon(Icons.add, size: 14),
                              size: AppButtonSize.sm,
                              onPressed: () {
                                if (state.isPersonalLearning) {
                                  PersonalTopicEditDialog.show(context: context);
                                } else {
                                  SubjectEditDialog.show(context: context);
                                }
                              },
                            ),
                          ],
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              titleWidget,
                              const SizedBox(height: 10),
                              actionsWidget,
                            ],
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: titleWidget),
                            actionsWidget,
                          ],
                        );
                      },
                    ),

                    AppSpacing.v16,

                    // 5. Subjects / Topics List
                    if (state.isPersonalLearning)
                      _buildPersonalTopicsList(context, ref, state)
                    else
                      _buildSubjectsList(context, ref, state),

                    AppSpacing.v32,

                    // 6. Navigation Footer Actions
                    _buildFooterNavigation(context, state),

                    AppSpacing.v40,
                  ],
                ),
              ),
            ),
    );
  }

  // ===========================================================================
  // WIDGET HELPERS
  // ===========================================================================

  Widget _buildWorkspaceSwitcher(
    BuildContext context,
    WidgetRef ref,
    AcademicWorkspaceState state,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: AppBorders.allStandard,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                state.isCollege
                    ? Icons.school_outlined
                    : (state.isSchool
                        ? Icons.auto_stories_outlined
                        : Icons.lightbulb_outline_rounded),
                size: 18,
                color: AppColors.primaryLight,
              ),
              AppSpacing.h8,
              Text('Workspace:', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
              AppSpacing.h8,
              Text(
                state.activeWorkspace?.name ?? 'Workspace',
                style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: 'Switch Workspace',
            color: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.brMd,
              side: AppBorders.standard,
            ),
            icon: const Icon(Icons.unfold_more, size: 18, color: AppColors.textSecondary),
            onSelected: (wsId) {
              ref.read(academicWorkspaceProvider.notifier).selectWorkspace(wsId);
            },
            itemBuilder: (ctx) => state.workspaces.map((ws) {
              final isSelected = ws.id == state.activeWorkspace?.id;
              return PopupMenuItem<String>(
                value: ws.id,
                child: Row(
                  children: [
                    Icon(
                      ws.purpose.id == 'college'
                          ? Icons.school_outlined
                          : (ws.purpose.id == 'school'
                              ? Icons.auto_stories_outlined
                              : Icons.lightbulb_outline_rounded),
                      size: 16,
                      color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
                    ),
                    AppSpacing.h8,
                    Expanded(
                      child: Text(
                        ws.name,
                        style: AppTypography.bodySmall.copyWith(
                          color: isSelected ? AppColors.primaryLight : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check, size: 16, color: AppColors.primaryLight),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicPeriodHeader(
    BuildContext context,
    WidgetRef ref,
    AcademicWorkspaceState state,
  ) {
    final isCurrent = state.isViewingCurrentPeriod;
    final periodName = state.selectedPeriod?.name ?? 'Semester 1';
    final yearName = state.academicYears.isNotEmpty
        ? state.academicYears.first.yearName
        : '2026–27';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: AppBorders.allStandard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Institution & Degree
          if (state.institutionName.isNotEmpty) ...[
            Text(
              state.institutionName,
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
            AppSpacing.v4,
          ],
          Text(
            state.degreeOrClassTitle,
            style: AppTypography.headline.copyWith(fontSize: 22),
          ),
          AppSpacing.v12,

          // Period Switcher Bar
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Period Dropdown Selector
              InkWell(
                onTap: () => _showPeriodSelectorMenu(context, ref, state),
                borderRadius: AppRadius.brSm,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: AppRadius.brSm,
                    border: AppBorders.allStandard,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        periodName,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      AppSpacing.h4,
                      const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),

              // Status Badge (Current vs Previous / Archive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.primarySubtle
                      : AppColors.surfaceSecondary,
                  borderRadius: AppRadius.brSm,
                  border: Border.all(
                    color: isCurrent
                        ? AppColors.primaryLight.withValues(alpha: 0.3)
                        : AppColors.border,
                    width: AppBorders.subtleWidth,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCurrent ? Icons.fiber_manual_record : Icons.archive_outlined,
                      size: 10,
                      color: isCurrent ? AppColors.primaryLight : AppColors.textMuted,
                    ),
                    AppSpacing.h4,
                    Text(
                      isCurrent ? 'CURRENT' : 'PREVIOUS / ARCHIVE',
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        color: isCurrent ? AppColors.primaryLight : AppColors.textMuted,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Academic Year
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  yearName,
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalLearningHeader(
    BuildContext context,
    WidgetRef ref,
    AcademicWorkspaceState state,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: AppBorders.allStandard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: AppRadius.brMd,
                  border: AppBorders.allStandard,
                ),
                child: const Icon(Icons.lightbulb_outline_rounded,
                    size: 18, color: AppColors.primaryLight),
              ),
              AppSpacing.h12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Personal Learning', style: AppTypography.title),
                    Text(
                      'Independent study, courses, and programming roadmaps',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveBanner(
    BuildContext context,
    WidgetRef ref,
    AcademicWorkspaceState state,
  ) {
    final currentPeriod = state.currentPeriod;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_outlined, size: 20, color: AppColors.info),
          AppSpacing.h12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Viewing Archived ${state.selectedPeriod?.name ?? "Semester"}',
                  style: AppTypography.label.copyWith(color: AppColors.textPrimary),
                ),
                Text(
                  'This semester is preserved in your academic history. Contents are historical.',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (currentPeriod != null) ...[
            AppSpacing.h8,
            AppButton.tertiary(
              text: 'Return to ${currentPeriod.name}',
              size: AppButtonSize.sm,
              onPressed: () {
                ref.read(academicWorkspaceProvider.notifier).selectPeriod(currentPeriod.id);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubjectsList(
    BuildContext context,
    WidgetRef ref,
    AcademicWorkspaceState state,
  ) {
    if (state.subjects.isEmpty) {
      return AppEmptyState(
        icon: Icons.book_outlined,
        title: 'No subjects yet',
        description:
            'Add subjects to build your ${state.selectedPeriod?.name ?? "academic"} workspace.',
        actionText: 'Add Subject',
        onAction: () => SubjectEditDialog.show(context: context),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: state.subjects.length,
      onReorderItem: (oldIndex, newIndex) {
        ref.read(academicWorkspaceProvider.notifier).reorderSubjects(oldIndex, newIndex);
      },
      itemBuilder: (ctx, index) {
        final subject = state.subjects[index];
        return Container(
          key: ValueKey('academic_subject_${subject.id}'),
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: AppBorders.allStandard,
          ),
          child: Material(
            color: AppColors.surface,
            borderRadius: AppRadius.brMd,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
              onTap: () => context.push('/subject/${subject.id}'),
              leading: const AppFileTypeIcon(type: AppFileType.folder, size: 32),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    subject.name,
                    style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (subject.code != null && subject.code!.isNotEmpty) ...[
                  AppSpacing.h8,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: AppRadius.brSm,
                      border: AppBorders.allStandard,
                    ),
                    child: Text(
                      subject.code!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: subject.description != null && subject.description!.isNotEmpty
                ? Text(
                    subject.description!,
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
                  tooltip: 'Rename Subject',
                  onPressed: () {
                    SubjectEditDialog.show(context: context, existingSubject: subject);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
                  tooltip: 'Archive Subject',
                  onPressed: () => _confirmRemoveSubject(context, ref, subject),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.drag_indicator, size: 20, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    );
  }

  Widget _buildPersonalTopicsList(
    BuildContext context,
    WidgetRef ref,
    AcademicWorkspaceState state,
  ) {
    if (state.personalTopics.isEmpty) {
      return AppEmptyState(
        icon: Icons.lightbulb_outline_rounded,
        title: 'No topics added yet',
        description: 'Add topics and skills you are learning independently.',
        actionText: 'Add Topic',
        onAction: () => PersonalTopicEditDialog.show(context: context),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: state.personalTopics.length,
      onReorderItem: (oldIndex, newIndex) {
        ref.read(academicWorkspaceProvider.notifier).reorderPersonalTopics(oldIndex, newIndex);
      },
      itemBuilder: (ctx, index) {
        final topic = state.personalTopics[index];
        return Container(
          key: ValueKey('personal_topic_${topic.id}'),
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: AppBorders.allStandard,
          ),
          child: Material(
            color: AppColors.surface,
            borderRadius: AppRadius.brMd,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
              onTap: () => context.push('/subject/${topic.id}'),
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.brSm,
                ),
                child: const Icon(Icons.tag, size: 16, color: AppColors.primaryLight),
              ),
              title: Text(
                topic.name,
                style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: topic.description != null && topic.description!.isNotEmpty
                  ? Text(
                      topic.description!,
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
                    tooltip: 'Rename Topic',
                    onPressed: () {
                      PersonalTopicEditDialog.show(context: context, existingTopic: topic);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
                    tooltip: 'Remove Topic',
                    onPressed: () {
                      ref.read(academicWorkspaceProvider.notifier).removePersonalTopic(topic.id);
                    },
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.drag_indicator, size: 20, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooterNavigation(BuildContext context, AcademicWorkspaceState state) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: AppBorders.allStandard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.history_edu_outlined, size: 18, color: AppColors.textSecondary),
              AppSpacing.h8,
              Text('Academic History & Archive', style: AppTypography.label),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/academic/history'),
                child: const Text('View All'),
              ),
            ],
          ),
          AppSpacing.v8,
          Text(
            'Access previous semesters and past subject records without losing your learning history.',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          AppSpacing.v12,
          AppSecondaryButton(
            text: 'Manage Academic Profile & Settings',
            icon: const Icon(Icons.tune, size: 14),
            onPressed: () => context.push('/academic/settings'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // INTERACTION FLOWS
  // ===========================================================================

  void _showPeriodSelectorMenu(
    BuildContext context,
    WidgetRef ref,
    AcademicWorkspaceState state,
  ) {
    final allPeriods = <AcademicPeriodEntity>[];
    for (final year in state.history) {
      for (final p in year.periods) {
        allPeriods.add(p.period);
      }
    }

    if (allPeriods.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Academic Period', style: AppTypography.title),
                AppSpacing.v4,
                Text(
                  'Switch the active context to view current or archived semester subjects.',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
                AppSpacing.v16,
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: allPeriods.length,
                    itemBuilder: (c, i) {
                      final period = allPeriods[i];
                      final isSelected = period.id == state.selectedPeriod?.id;
                      final isCurrentPeriod = period.isCurrent;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primarySubtle
                              : AppColors.surfaceSecondary,
                          borderRadius: AppRadius.brMd,
                          border: Border.all(
                            color: isSelected ? AppColors.primaryLight : AppColors.border,
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            period.name,
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            isCurrentPeriod ? 'Current Active Semester' : 'Archived Semester',
                            style: AppTypography.caption.copyWith(
                              color: isCurrentPeriod
                                  ? AppColors.primaryLight
                                  : AppColors.textMuted,
                            ),
                          ),
                          trailing: isCurrentPeriod
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySubtle,
                                    borderRadius: AppRadius.brSm,
                                  ),
                                  child: Text(
                                    'CURRENT',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 10,
                                      color: AppColors.primaryLight,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () {
                            Navigator.of(ctx).pop();
                            ref.read(academicWorkspaceProvider.notifier).selectPeriod(period.id);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleStartNextSemester(
    BuildContext context,
    WidgetRef ref,
    AcademicWorkspaceState state,
  ) {
    final currentPeriod = state.currentPeriod;
    final currentName = currentPeriod?.name ?? 'Semester 1';

    // Guess next semester name
    String suggested = 'Semester 2';
    final match = RegExp(r'(\d+)').firstMatch(currentName);
    if (match != null) {
      final num = int.tryParse(match.group(1)!) ?? 1;
      suggested = currentName.replaceAll(match.group(1)!, '${num + 1}');
    }

    final previousSubjects = state.subjects.map((s) => s.name).toList();

    SemesterTransitionDialog.show(
      context: context,
      currentPeriodName: currentName,
      suggestedNextPeriodName: suggested,
      previousSubjectNames: previousSubjects,
    );
  }

  void _confirmRemoveSubject(
    BuildContext context,
    WidgetRef ref,
    AcademicSubjectEntity subject,
  ) {
    AppModal.show(
      context: context,
      title: 'Archive Subject?',
      message:
          'Archiving "${subject.name}" will remove it from the active semester view. Future attached notes and materials will remain safe in your vault.',
      confirmText: 'Archive',
      isDestructive: true,
      onConfirm: () {
        ref.read(academicWorkspaceProvider.notifier).removeSubject(subject.id);
        Navigator.of(context).pop();
      },
    );
  }
}
