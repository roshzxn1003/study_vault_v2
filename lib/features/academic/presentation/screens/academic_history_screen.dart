import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/features/academic/domain/models/models.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';

/// Screen displaying chronological academic history grouped by academic year.
/// Clearly differentiates between CURRENT and PREVIOUS periods.
class AcademicHistoryScreen extends ConsumerWidget {
  const AcademicHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(academicWorkspaceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        title: 'Academic History & Archive',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: state.history.isEmpty
          ? AppEmptyState(
              icon: Icons.history_edu_outlined,
              title: 'No academic history yet',
              description: 'Your previous semesters and classes will appear here as you progress.',
              actionText: 'Return to Workspace',
              onAction: () => context.pop(),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: state.history.length,
              itemBuilder: (context, index) {
                final yearWithPeriods = state.history[index];
                return _buildYearSection(context, ref, yearWithPeriods, state);
              },
            ),
    );
  }

  Widget _buildYearSection(
    BuildContext context,
    WidgetRef ref,
    AcademicYearWithPeriods yearWithPeriods,
    AcademicWorkspaceState state,
  ) {
    final year = yearWithPeriods.year;
    final periods = yearWithPeriods.periods;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year Header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.brSm,
                ),
                child: const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.primaryLight),
              ),
              AppSpacing.h8,
              Text(
                year.yearName,
                style: AppTypography.headline.copyWith(fontSize: 18),
              ),
              if (year.isCurrent) ...[
                AppSpacing.h8,
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Text(
                    'ACTIVE YEAR',
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.8,
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),

          AppSpacing.v12,

          // Periods in this year
          ...periods.map((periodWithCount) {
            final period = periodWithCount.period;
            final count = periodWithCount.subjectCount;
            final isCurrent = period.isCurrent;
            final isViewing = state.selectedPeriod?.id == period.id;

            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppColors.surface
                    : AppColors.surfaceSecondary.withValues(alpha: 0.6),
                borderRadius: AppRadius.brMd,
                border: Border.all(
                  color: isCurrent
                      ? AppColors.primaryLight.withValues(alpha: 0.4)
                      : AppColors.border,
                  width: isCurrent ? 1.5 : 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 4,
                ),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCurrent ? AppColors.primarySubtle : AppColors.surface,
                    borderRadius: AppRadius.brSm,
                    border: AppBorders.allStandard,
                  ),
                  child: Icon(
                    isCurrent ? Icons.star_rounded : Icons.archive_outlined,
                    size: 20,
                    color: isCurrent ? AppColors.primaryLight : AppColors.textMuted,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      period.name,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                    AppSpacing.h8,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.primarySubtle
                            : AppColors.surface,
                        borderRadius: AppRadius.brSm,
                      ),
                      child: Text(
                        isCurrent ? 'CURRENT' : 'PREVIOUS',
                        style: AppTypography.caption.copyWith(
                          fontSize: 10,
                          letterSpacing: 0.8,
                          color: isCurrent ? AppColors.primaryLight : AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  '$count subjects • Created ${period.createdAt.month}/${period.createdAt.year}',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isCurrent) ...[
                      TextButton(
                        onPressed: () => _confirmMakeCurrent(context, ref, period),
                        child: const Text('Make Current'),
                      ),
                      AppSpacing.h4,
                    ],
                    AppSecondaryButton(
                      text: isViewing ? 'Viewing' : 'Open',
                      size: AppButtonSize.sm,
                      onPressed: () {
                        ref.read(academicWorkspaceProvider.notifier).selectPeriod(period.id);
                        context.pop();
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _confirmMakeCurrent(
    BuildContext context,
    WidgetRef ref,
    AcademicPeriodEntity period,
  ) {
    AppModal.show(
      context: context,
      title: 'Make ${period.name} Current?',
      message:
          'This will designate ${period.name} as your primary active period. All other semesters remain fully intact in your academic history. No data will be deleted.',
      confirmText: 'Confirm Switch',
      onConfirm: () {
        ref.read(academicWorkspaceProvider.notifier).switchCurrentPeriod(period.id);
        Navigator.of(context).pop();
      },
    );
  }
}
