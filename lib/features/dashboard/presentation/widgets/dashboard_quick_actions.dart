import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/add_material_sheet.dart';
import 'package:study_vault/features/vault/presentation/widgets/create_folder_dialog.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';

/// Clean row of quick academic actions adhering to Section 15 constraints.
class DashboardQuickActions extends ConsumerWidget {
  final bool isPersonalLearning;
  final VoidCallback onAddSubject;

  const DashboardQuickActions({
    super.key,
    required this.isPersonalLearning,
    required this.onAddSubject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // 1. Add Material (Primary)
          _ActionButton(
            icon: Icons.add_rounded,
            label: 'Add Material',
            accentColor: AppColors.primary,
            onTap: () => AddMaterialSheet.show(context),
            isPrimary: true,
          ),
          const SizedBox(width: AppSpacing.sm),

          // 2. New Folder
          _ActionButton(
            icon: Icons.create_new_folder_outlined,
            label: 'New Folder',
            accentColor: AppColors.fileFolder,
            onTap: () async {
              final name = await CreateFolderDialog.show(context: context);
              if (name != null && name.trim().isNotEmpty) {
                await ref.read(vaultProvider.notifier).createFolder(name.trim());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Folder "${name.trim()}" created in Library'),
                      backgroundColor: AppColors.emerald,
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(width: AppSpacing.sm),

          // 3. Scan (Camera OCR)
          _ActionButton(
            icon: Icons.document_scanner_outlined,
            label: 'Scan Note',
            accentColor: AppColors.emerald,
            onTap: () => context.push('/scan'),
          ),
          const SizedBox(width: AppSpacing.sm),

          // 4. Create Note
          _ActionButton(
            icon: Icons.edit_note_rounded,
            label: 'Create Note',
            accentColor: AppColors.fileNote,
            onTap: () => context.push('/notes/create'),
          ),
          const SizedBox(width: AppSpacing.sm),

          // 5. Add Subject
          _ActionButton(
            icon: Icons.auto_stories_outlined,
            label: isPersonalLearning ? 'Add Topic' : 'Add Subject',
            accentColor: AppColors.fileImage,
            onTap: onAddSubject,
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
  final Color accentColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.accentColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.button,
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: isPrimary
                ? AppColors.primary
                : AppColors.surface,
            borderRadius: AppRadius.button,
            border: Border.all(
              color: isPrimary
                  ? AppColors.primaryLight
                  : AppColors.border,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? Colors.white.withValues(alpha: 0.2)
                      : accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isPrimary ? Colors.white : accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isPrimary ? Colors.white : AppColors.textPrimary,
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
