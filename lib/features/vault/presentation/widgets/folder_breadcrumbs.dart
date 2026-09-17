import 'package:flutter/material.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import '../../domain/models/models.dart';

/// Breadcrumb navigation component for deeply nested folder hierarchies.
class FolderBreadcrumbs extends StatelessWidget {
  final String rootLabel;
  final List<VaultFolder> breadcrumbs;
  final ValueChanged<String?> onSelectFolder;

  const FolderBreadcrumbs({
    super.key,
    required this.rootLabel,
    required this.breadcrumbs,
    required this.onSelectFolder,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Root Item
          InkWell(
            onTap: () => onSelectFolder(null),
            borderRadius: AppRadius.chip,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.home_outlined, size: 16, color: AppColors.primaryLight),
                  const SizedBox(width: 4),
                  Text(
                    rootLabel,
                    style: AppTypography.caption.copyWith(
                      color: breadcrumbs.isEmpty ? AppColors.textPrimary : AppColors.primaryLight,
                      fontWeight: breadcrumbs.isEmpty ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Breadcrumb Trail
          for (int i = 0; i < breadcrumbs.length; i++) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
            ),
            InkWell(
              onTap: i == breadcrumbs.length - 1
                  ? null
                  : () => onSelectFolder(breadcrumbs[i].id),
              borderRadius: AppRadius.chip,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  breadcrumbs[i].name,
                  style: AppTypography.caption.copyWith(
                    color: i == breadcrumbs.length - 1
                        ? AppColors.textPrimary
                        : AppColors.primaryLight,
                    fontWeight: i == breadcrumbs.length - 1 ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
