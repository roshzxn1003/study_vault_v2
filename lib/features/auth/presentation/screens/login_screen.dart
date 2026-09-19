import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_screen_container.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_header.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_button.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_divider.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:study_vault/features/onboarding/presentation/providers/onboarding_provider.dart';

/// Clean, academic login screen with inline validation and responsive layout.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  static final RegExp _emailRegExp = RegExp(
    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Clear any previous error banner
    ref.read(authControllerProvider.notifier).clearError();

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await ref.read(authControllerProvider.notifier).signIn(
      email: email,
      password: password,
    );

    if (success && mounted) {
      final onboardingState = ref.read(onboardingProvider);
      if (onboardingState.isLoaded && !onboardingState.hasCompletedOnboarding) {
        context.go('/onboarding');
      } else {
        context.go('/home');
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    ref.read(authControllerProvider.notifier).clearError();
    final success =
        await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (success && mounted) {
      final onboardingState = ref.read(onboardingProvider);
      if (onboardingState.isLoaded && !onboardingState.hasCompletedOnboarding) {
        context.go('/onboarding');
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return AuthScreenContainer(
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSpacing.v12,

              // Brand header
              const AuthHeader(
                title: 'Welcome back',
                subtitle: 'Continue to your study workspace.',
              ),

              AppSpacing.v32,

              // Error banner if authentication failed
              if (authState.hasError)
                AuthErrorBanner(
                  message: authState.errorMessage!,
                  onDismiss: () =>
                      ref.read(authControllerProvider.notifier).clearError(),
                ),

              // Email field
              AuthTextField(
                label: 'Email',
                hintText: 'name@university.edu',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                enabled: !authState.isLoading,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Please enter your email address.';
                  }
                  if (!_emailRegExp.hasMatch(trimmed)) {
                    return 'Please enter a valid email address.';
                  }
                  return null;
                },
              ),

              AppSpacing.v20,

              // Password field
              AuthTextField(
                label: 'Password',
                hintText: '••••••••',
                controller: _passwordController,
                isPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                enabled: !authState.isLoading,
                onFieldSubmitted: (_) => _handleLogin(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password.';
                  }
                  return null;
                },
              ),

              AppSpacing.v8,

              // Forgot password link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: authState.isLoading
                      ? null
                      : () {
                          ref.read(authControllerProvider.notifier).clearError();
                          context.push('/forgot-password');
                        },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              AppSpacing.v24,

              // Log In button
              AuthButton(
                text: 'Log In',
                isLoading: authState.isLoading,
                onPressed: _handleLogin,
              ),

              // Divider
              const AuthDivider(),

              // Continue with Google
              AuthButton(
                isSecondary: true,
                text: 'Continue with Google',
                isLoading: authState.isLoading,
                icon: const Icon(
                  Icons.g_mobiledata_rounded,
                  size: 24,
                  color: AppColors.textPrimary,
                ),
                onPressed: authState.isLoading ? null : _handleGoogleSignIn,
              ),

              AppSpacing.v24,

              // Switch to Sign Up
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: authState.isLoading
                        ? null
                        : () {
                            ref.read(authControllerProvider.notifier).clearError();
                            context.push('/signup');
                          },
                    child: Text(
                      'Create account',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.v16,
            ],
          ),
        ),
      ),
    );
  }
}

