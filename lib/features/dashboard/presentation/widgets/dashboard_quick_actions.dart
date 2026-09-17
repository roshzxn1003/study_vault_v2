import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/features/import/presentation/widgets/import_source_dialog.dart';

/// Clean row of quick academic actions adhering to Section 15 constraints.
class DashboardQuickActions extends StatelessWidget {
  final bool isPersonalLearning;
  final VoidCallback onAddSubject;

  const DashboardQuickActions({
    super.key,
    required this.isPersonalLearning,
    required this.onAddSubject,
  });


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // 1. Add Subject / Topic
          _ActionButton(
            icon: Icons.add_rounded,
            label: isPersonalLearning ? 'Add Topic' : 'Add Subject',
            onTap: onAddSubject,
            isPrimary: true,
          ),
          const SizedBox(width: AppSpacing.sm),

          // 2. Add Material (Phase 7 Universal Ingestion)
          _ActionButton(
            icon: Icons.file_upload_outlined,
            label: 'Add Material',
            onTap: () => ImportSourceDialog.show(context),
          ),
          const SizedBox(width: AppSpacing.sm),

          // 3. Open Inbox
          _ActionButton(
            icon: Icons.inbox_outlined,
            label: 'Open Inbox',
            onTap: () => context.push('/inbox'),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.button,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isPrimary
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: AppRadius.button,
            border: Border.all(
              color: isPrimary
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isPrimary ? AppColors.primaryLight : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? AppColors.primaryLight : AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
