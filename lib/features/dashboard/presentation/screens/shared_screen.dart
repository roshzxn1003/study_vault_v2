import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/app_empty_state.dart';

/// Clean placeholder screen for the 'Shared' bottom navigation tab destination.
class SharedScreen extends StatelessWidget {
  const SharedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          'Shared Study Packs',
          style: AppTypography.subtitle.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppEmptyState(
              icon: Icons.share_outlined,
              title: 'Study Packs & Sharing',
              description:
                  'Peer notes, verified question banks, and collaborative study groups will arrive in a future phase.',
              actionText: 'Back to Dashboard',
              onAction: () => context.go('/home'),
            ),
          ),
        ),
      ),
    );
  }
}
