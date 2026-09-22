import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';

/// Premium academic AI assistant entry card on Home screen.
class AIAssistantCard extends StatelessWidget {
  const AIAssistantCard({super.key});

  @override
  Widget build(BuildContext context) {
    const examples = [
      'Summarize my DBMS notes',
      'Find Unit 3 questions',
      'Explain this document',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
          width: 1.2,
        ),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1B4B).withValues(alpha: 0.4),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  ),
                  borderRadius: AppRadius.button,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
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
                onPressed: () => context.push('/ai'),
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
                side: BorderSide(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                ),
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
