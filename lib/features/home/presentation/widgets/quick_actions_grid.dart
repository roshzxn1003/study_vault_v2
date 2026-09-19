import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/design/widgets/add_material_sheet.dart';
import 'ai_topic_launcher_sheet.dart';
import 'quick_scratchpad_sheet.dart';
import 'exam_goal_dialog.dart';

class QuickActionsGrid extends ConsumerWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      {
        'label': 'AI Study Hub',
        'icon': Icons.auto_awesome_rounded,
        'color': AppColors.primary,
        'onTap': () => AiTopicLauncherSheet.show(context),
      },
      {
        'label': 'Add Material',
        'icon': Icons.add_circle_outline_rounded,
        'color': AppColors.cyan,
        'onTap': () => AddMaterialSheet.show(context),
      },
      {
        'label': 'Scan OCR',
        'icon': Icons.document_scanner_rounded,
        'color': AppColors.emerald,
        'onTap': () => context.push('/scan'),
      },
      {
        'label': 'Write Note',
        'icon': Icons.edit_note_rounded,
        'color': AppColors.primaryLight,
        'onTap': () => context.push('/notes/create'),
      },
      {
        'label': 'Scratchpad',
        'icon': Icons.sticky_note_2_rounded,
        'color': AppColors.amber,
        'onTap': () => QuickScratchpadSheet.show(context),
      },
      {
        'label': 'Exam Goal',
        'icon': Icons.flag_rounded,
        'color': AppColors.rose,
        'onTap': () => ExamGoalDialog.show(context),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        final color = action['color'] as Color;
        final onTap = action['onTap'] as VoidCallback;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      action['icon'] as IconData,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    action['label'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
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
}
