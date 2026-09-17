import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/onboarding/presentation/providers/onboarding_provider.dart';

/// Minimal academic splash screen.
/// Initializes core session state and routes without artificial delays.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppAnimations.slow,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: AppAnimations.decelerate,
    );
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. Session check via AuthRepository
      final authRepo = ref.read(authRepositoryProvider);
      final currentUser = authRepo.getCurrentUser();
      final isAuthenticated = currentUser != null;

      if (!mounted) return;

      if (isAuthenticated) {
        // 2. Preserve existing onboarding state logic
        final onboardingState = ref.read(onboardingProvider);
        if (onboardingState.isLoaded && !onboardingState.hasCompletedOnboarding) {
          context.go('/onboarding');
        } else {
          context.go('/home');
        }
      } else {
        // 3. Unauthenticated -> Login
        context.go('/login');
      }
    } catch (_) {
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // [Study Vault Logo]
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.brXl,
                  border: AppBorders.allStandard,
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: AppIcons.lg,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
              AppSpacing.v24,
              // Study Vault
              Text(
                'Study Vault',
                style: AppTypography.headline.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              AppSpacing.v8,
              // Your academic workspace
              Text(
                'Your academic workspace',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

