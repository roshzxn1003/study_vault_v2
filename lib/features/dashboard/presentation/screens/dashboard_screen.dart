import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/app_empty_state.dart';
import 'package:study_vault/features/academic/presentation/widgets/personal_topic_edit_dialog.dart';
import 'package:study_vault/features/academic/presentation/widgets/subject_edit_dialog.dart';
import 'package:study_vault/features/dashboard/presentation/providers/dashboard_provider.dart';
import '../widgets/dashboard_academic_header.dart';
import '../widgets/dashboard_quick_actions.dart';
import '../widgets/dashboard_search_bar.dart';
import '../widgets/historical_period_banner.dart';
import '../widgets/inbox_preview_section.dart';
import '../widgets/recent_materials_section.dart';
import '../widgets/subjects_section.dart';
import '../../../import/presentation/widgets/import_source_dialog.dart';

/// Main Study Vault Dashboard.
/// Personalizes the student experience around active workspace and academic context.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _handleAddSubject(BuildContext context, WidgetRef ref, bool isPersonal) async {
    if (isPersonal) {
      final added = await PersonalTopicEditDialog.show(context: context);
      if (added == true) {
        ref.read(dashboardProvider.notifier).refresh();
      }
    } else {
      final added = await SubjectEditDialog.show(context: context);
      if (added == true) {
        ref.read(dashboardProvider.notifier).refresh();
      }
    }
  }



  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);
    final isTabletOrDesktop = AppBreakpoints.isTablet(context) || AppBreakpoints.isDesktop(context);

    // Error State
    if (state.errorMessage != null && !state.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Something went wrong',
                description: state.errorMessage ?? 'We couldn\'t load your study space.',
                actionText: 'Try again',
                onAction: () => notifier.init(),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryLight,
          backgroundColor: AppColors.surface,
          onRefresh: () => notifier.refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Subtle Progress Loader
                    if (state.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.sm),
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          color: AppColors.primaryLight,
                          backgroundColor: Colors.transparent,
                        ),
                      ),

                    // 1. Academic Header
                    DashboardAcademicHeader(
                      state: state,
                      onWorkspaceSelected: (wsId) => notifier.selectWorkspace(wsId),
                      onPeriodSelected: (pId) => notifier.selectPeriod(pId),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // 2. Historical Period Banner (if viewing previous semester)
                    if (state.isViewingHistoricalPeriod)
                      HistoricalPeriodBanner(
                        periodName: state.selectedPeriodName,
                        currentPeriodName: state.currentPeriodName,
                        onSwitchToCurrent: () {
                          if (state.currentPeriod != null) {
                            notifier.selectPeriod(state.currentPeriod!.id);
                          }
                        },
                      ),

                    // 3. Search Bar Entry Point
                    const DashboardSearchBar(),

                    const SizedBox(height: AppSpacing.md),

                    // 4. Quick Actions
                    DashboardQuickActions(
                      isPersonalLearning: state.isPersonalLearning,
                      onAddSubject: () => _handleAddSubject(context, ref, state.isPersonalLearning),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // 5. Subjects Section (SUBJECTS FIRST)
                    SubjectsSection(
                      subjects: state.subjects,
                      personalTopics: state.personalTopics,
                      isPersonalLearning: state.isPersonalLearning,
                      onAddSubject: () => _handleAddSubject(context, ref, state.isPersonalLearning),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // 6. Inbox Preview & Recent Materials
                    if (isTabletOrDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InboxPreviewSection(
                              items: state.inboxItems,
                              totalCount: state.inboxTotalCount,
                              onAddMaterial: () => ImportSourceDialog.show(context),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: RecentMaterialsSection(
                              materials: state.recentMaterials,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      InboxPreviewSection(
                        items: state.inboxItems,
                        totalCount: state.inboxTotalCount,
                        onAddMaterial: () => ImportSourceDialog.show(context),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      RecentMaterialsSection(
                        materials: state.recentMaterials,
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
