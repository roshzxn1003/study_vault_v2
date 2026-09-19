import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_screen_container.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_header.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_button.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_divider.dart';

/// Clean, academic sign-up screen with inline validation and responsive layout.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _confirmationEmailSent = false;
  String _registeredEmail = '';

  static final RegExp _emailRegExp = RegExp(
    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    ref.read(authControllerProvider.notifier).clearError();

    if (!_formKey.currentState!.validate()) return;

    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await ref.read(authControllerProvider.notifier).signUp(
      email: email,
      password: password,
      fullName: fullName,
    );

    if (success && mounted) {
      final authState = ref.read(authControllerProvider);
      if (authState.isAuthenticated) {
        // User session available immediately -> Route to onboarding entry point
        context.go('/onboarding');
      } else {
        // Email confirmation required by provider
        setState(() {
          _confirmationEmailSent = true;
          _registeredEmail = email;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    ref.read(authControllerProvider.notifier).clearError();
    final success =
        await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (success && mounted) {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    if (_confirmationEmailSent) {
      return AuthScreenContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSpacing.v32,
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.brXl,
                  border: AppBorders.allStandard,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: AppIcons.lg,
                  color: AppColors.emerald,
                ),
              ),
            ),
            AppSpacing.v24,
            Text(
              'Check your email',
              textAlign: TextAlign.center,
              style: AppTypography.headline.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            AppSpacing.v12,
            Text(
              'We sent a verification link to:\n$_registeredEmail\n\nPlease confirm your email address to activate your account.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            AppSpacing.v32,
            AuthButton(
              text: 'Go to Log In',
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      );
    }

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
                title: 'Create your account',
                subtitle: 'Start organizing your learning.',
              ),

              AppSpacing.v32,

              // Error banner
              if (authState.hasError)
                AuthErrorBanner(
                  message: authState.errorMessage!,
                  onDismiss: () =>
                      ref.read(authControllerProvider.notifier).clearError(),
                ),

              // Full name field
              AuthTextField(
                label: 'Full name',
                hintText: 'Jane Doe',
                controller: _nameController,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                enabled: !authState.isLoading,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Please enter your full name.';
                  }
                  if (trimmed.length < 2) {
                    return 'Name must be at least 2 characters.';
                  }
                  return null;
                },
              ),

              AppSpacing.v20,

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
                hintText: 'At least 6 characters',
                controller: _passwordController,
                isPassword: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                enabled: !authState.isLoading,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password.';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters.';
                  }
                  return null;
                },
              ),

              AppSpacing.v20,

              // Confirm password field
              AuthTextField(
                label: 'Confirm password',
                hintText: 'Re-enter your password',
                controller: _confirmPasswordController,
                isPassword: true,
                textInputAction: TextInputAction.done,
                enabled: !authState.isLoading,
                onFieldSubmitted: (_) => _handleSignUp(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password.';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match.';
                  }
                  return null;
                },
              ),

              AppSpacing.v24,

              // Create account button
              AuthButton(
                text: 'Create account',
                isLoading: authState.isLoading,
                onPressed: _handleSignUp,
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

              // Switch to Login
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: authState.isLoading
                        ? null
                        : () {
                            ref.read(authControllerProvider.notifier).clearError();
                            if (Navigator.of(context).canPop()) {
                              context.pop();
                            } else {
                              context.go('/login');
                            }
                          },
                    child: Text(
                      'Log in',
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

