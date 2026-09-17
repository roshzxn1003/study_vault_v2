import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/features/dashboard/presentation/providers/dashboard_state.dart';
import 'period_selector_sheet.dart';

/// Clean academic header displaying greeting, academic identity, workspace switcher, and period picker.
class DashboardAcademicHeader extends StatelessWidget {
  final DashboardState state;
  final ValueChanged<String> onWorkspaceSelected;
  final ValueChanged<String> onPeriodSelected;

  const DashboardAcademicHeader({
    super.key,
    required this.state,
    required this.onWorkspaceSelected,
    required this.onPeriodSelected,
  });

  void _showWorkspacePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.bottomSheet,
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Switch Workspace',
                style: AppTypography.title,
              ),
              const SizedBox(height: AppSpacing.md),
              ...state.workspaces.map((ws) {
                final isSelected = ws.id == state.activeWorkspace?.id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.surfaceSecondary
                        : AppColors.surface,
                    borderRadius: AppRadius.button,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.cardBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    onTap: () {
                      Navigator.pop(ctx);
                      onWorkspaceSelected(ws.id);
                    },
                    leading: Icon(
                      ws.purpose.icon,
                      color: isSelected
                          ? AppColors.primaryLight
                          : AppColors.textSecondary,
                    ),
                    title: Text(
                      ws.name,
                      style: AppTypography.body.copyWith(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    subtitle: Text(
                      ws.purpose.title,
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primaryLight,
                            size: 20,
                          )
                        : null,
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMultipleWorkspaces = state.workspaces.length > 1;
    final hasPeriods = !state.isPersonalLearning && state.history.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Row: Greeting & Workspace Switcher / Academic Link
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subtle Greeting adhering to Section 13
                  Text(
                    state.greeting,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Prominent Academic Identity Title
                  Text(
                    state.academicIdentityTitle,
                    style: AppTypography.headline.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            // Link to full Academic Structure Screen
            IconButton(
              tooltip: 'Academic Workspace Management',
              onPressed: () => context.push('/academic'),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.button,
                  border: AppBorders.allStandard,
                ),
                child: const Icon(
                  Icons.account_tree_outlined,
                  size: 18,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xs),

        // Subtitle & Pill Selectors Row
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Workspace selector pill (if multiple)
            if (hasMultipleWorkspaces)
              ActionChip(
                backgroundColor: AppColors.surfaceSecondary,
                side: const BorderSide(color: AppColors.cardBorder),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                avatar: Icon(
                  state.activeWorkspace?.purpose.icon ?? Icons.school_outlined,
                  size: 14,
                  color: AppColors.primaryLight,
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.activeWorkspace?.name ?? 'Workspace',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                onPressed: () => _showWorkspacePicker(context),
              ),

            // Academic period switcher pill (e.g. [ Semester 3 ▾ ])
            if (hasPeriods)
              ActionChip(
                backgroundColor: AppColors.surfaceSecondary,
                side: BorderSide(
                  color: state.isViewingHistoricalPeriod
                      ? AppColors.warning.withValues(alpha: 0.5)
                      : AppColors.cardBorder,
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                avatar: Icon(
                  state.isViewingHistoricalPeriod
                      ? Icons.history_rounded
                      : Icons.calendar_month_outlined,
                  size: 14,
                  color: state.isViewingHistoricalPeriod
                      ? AppColors.warning
                      : AppColors.primaryLight,
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.selectedPeriodName,
                      style: AppTypography.caption.copyWith(
                        color: state.isViewingHistoricalPeriod
                            ? AppColors.warning
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                onPressed: () {
                  PeriodSelectorSheet.show(
                    context: context,
                    history: state.history,
                    selectedPeriodId: state.selectedPeriod?.id ?? '',
                    onPeriodSelected: onPeriodSelected,
                  );
                },
              ),

            // Secondary Context Text (e.g. "2026–27" or "Independent Study")
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                state.academicSubtitle,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
