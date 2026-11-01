import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/app_pressable.dart';
import 'package:study_vault/features/dashboard/domain/models/dashboard_models.dart';

/// Preview section displaying recent materials across the active workspace.
/// Strictly follows Section 17 & 18: real resource data only, zero fake demo materials.
class RecentMaterialsSection extends StatelessWidget {
  final List<DashboardRecentMaterial> materials;

  const RecentMaterialsSection({
    super.key,
    required this.materials,
  });

  @override
  Widget build(BuildContext context) {
    final hasMaterials = materials.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: AppBorders.allStandard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 18,
                color: AppColors.primaryLight,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Recent',
                style: AppTypography.subtitle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Material list or clean empty state
          if (!hasMaterials)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                'No recent materials yet.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: materials.length,
              separatorBuilder: (_, _) => const Divider(
                height: 14,
                color: AppColors.cardBorder,
              ),
              itemBuilder: (context, index) {
                final item = materials[index];
                IconData iconData;
                Color iconColor;
                switch (item.type.toUpperCase()) {
                  case 'NOTE':
                    iconData = Icons.edit_note_rounded;
                    iconColor = AppColors.fileNote;
                    break;
                  case 'IMAGE':
                  case 'IMG':
                    iconData = Icons.image_rounded;
                    iconColor = AppColors.fileImage;
                    break;
                  case 'LINK':
                  case 'URL':
                    iconData = Icons.link_rounded;
                    iconColor = AppColors.fileAudio;
                    break;
                  case 'PDF':
                    iconData = Icons.picture_as_pdf_rounded;
                    iconColor = AppColors.filePdf;
                    break;
                  default:
                    iconData = Icons.description_rounded;
                    iconColor = AppColors.primaryLight;
                }

                return AppPressable(
                  onTap: () => context.push('/vault/material/${item.id}'),
                  borderRadius: AppRadius.brSm,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: AppRadius.chip,
                        ),
                        child: Icon(
                          iconData,
                          size: 16,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.formattedSubtitle,
                              style: AppTypography.caption.tabular.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
