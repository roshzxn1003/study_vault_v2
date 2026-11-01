import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';

/// Clean academic AI assistant entry card on Home screen adhering to Appllama single-accent lock.
class AIAssistantCard extends StatelessWidget {
  const AIAssistantCard({super.key});

  @override
  Widget build(BuildContext context) {
    const examples = [
      'Summarize active document',
      'Generate practice questions',
      'Active recall flashcards',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.25),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
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
                  color: AppColors.primary,
                  borderRadius: AppRadius.button,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask your study assistant',
                      style: AppTypography.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Context-aware answers, note summaries, and exam flashcards',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.primaryLight,
                  size: 20,
                ),
                tooltip: 'Open AI Assistant',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/ai');
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: examples.map((prompt) {
              return ActionChip(
                backgroundColor: AppColors.surfaceSecondary,
                side: AppBorders.standard,
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.chip),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                label: Text(
                  prompt,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                avatar: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 13,
                  color: AppColors.primaryLight,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.push(
                    Uri(path: '/ai', queryParameters: {'query': prompt}).toString(),
                  );
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
