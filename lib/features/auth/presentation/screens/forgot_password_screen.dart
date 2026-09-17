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

/// Clean academic password reset screen with inline validation and confirmation state.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitted = false;
  String _targetEmail = '';

  static final RegExp _emailRegExp = RegExp(
    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
  );

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    ref.read(authControllerProvider.notifier).clearError();

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final success = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(email: email);

    if (success && mounted) {
      setState(() {
        _isSubmitted = true;
        _targetEmail = email;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    if (_isSubmitted) {
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
                  color: AppColors.primaryLight,
                ),
              ),
            ),
            AppSpacing.v24,
            Text(
              'Reset link sent',
              textAlign: TextAlign.center,
              style: AppTypography.headline.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            AppSpacing.v12,
            Text(
              'We sent password reset instructions to:\n$_targetEmail\n\nPlease check your inbox and follow the link to reset your password.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            AppSpacing.v32,
            AuthButton(
              text: 'Back to login',
              onPressed: () {
                ref.read(authControllerProvider.notifier).clearError();
                context.go('/login');
              },
            ),
          ],
        ),
      );
    }

    return AuthScreenContainer(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSpacing.v12,

            // Header
            const AuthHeader(
              title: 'Reset your password',
              subtitle: "Enter your email and we'll send you a reset link.",
            ),

            AppSpacing.v32,

            // Error banner
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
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              enabled: !authState.isLoading,
              onFieldSubmitted: (_) => _handleReset(),
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

            AppSpacing.v24,

            // Send reset link button
            AuthButton(
              text: 'Send reset link',
              isLoading: authState.isLoading,
              onPressed: _handleReset,
            ),

            AppSpacing.v24,

            // Back to login
            Center(
              child: GestureDetector(
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
                  'Back to login',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            AppSpacing.v16,
          ],
        ),
      ),
    );
  }
}

