import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/theme/app_theme.dart';
import 'package:study_vault/features/auth/domain/entities/auth_user.dart';
import 'package:study_vault/features/auth/domain/repositories/auth_repository.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_header.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_button.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_divider.dart';
import 'package:study_vault/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:study_vault/features/auth/presentation/screens/login_screen.dart';
import 'package:study_vault/features/auth/presentation/screens/signup_screen.dart';
import 'package:study_vault/features/auth/presentation/screens/forgot_password_screen.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  AuthUser? getCurrentUser() => null;
  @override
  Future<void> signIn({required String email, required String password}) async {}
  @override
  Future<void> signUp({required String email, required String password, required String fullName}) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> resetPassword({required String email}) async {}
}

Widget createTestApp(Widget child) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Auth UI Component Widget Tests', () {
    testWidgets('AuthHeader renders title, subtitle, and brand text', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const AuthHeader(
            title: 'Welcome back',
            subtitle: 'Continue to your study workspace.',
          ),
        ),
      );

      expect(find.text('Study Vault'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Continue to your study workspace.'), findsOneWidget);
    });

    testWidgets('AuthButton shows text and responds to taps', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        createTestApp(
          AuthButton(
            text: 'Log In',
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Log In'), findsOneWidget);
      await tester.tap(find.text('Log In'));
      expect(tapped, true);
    });

    testWidgets('AuthButton shows loading spinner when isLoading is true', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          AuthButton(
            text: 'Log In',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AuthTextField toggles password visibility', (tester) async {
      final controller = TextEditingController(text: 'secret123');

      await tester.pumpWidget(
        createTestApp(
          AuthTextField(
            label: 'Password',
            controller: controller,
            isPassword: true,
          ),
        ),
      );

      final toggleButton = find.byType(IconButton);
      expect(toggleButton, findsOneWidget);

      await tester.tap(toggleButton);
      await tester.pump();

      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('AuthDivider displays label', (tester) async {
      await tester.pumpWidget(createTestApp(const AuthDivider(label: 'or')));
      expect(find.text('or'), findsOneWidget);
    });

    testWidgets('AuthErrorBanner displays message', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const AuthErrorBanner(message: 'Invalid credentials provided'),
        ),
      );

      expect(find.text('Invalid credentials provided'), findsOneWidget);
    });
  });

  group('Login, Signup & Forgot Password Screen Rendering Tests', () {
    testWidgets('LoginScreen renders email, password, and login button', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const LoginScreen()));

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.widgetWithText(AuthButton, 'Log In'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets('LoginScreen inline validation triggers on empty submit', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const LoginScreen()));

      final buttonFinder = find.widgetWithText(AuthButton, 'Log In');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email address.'), findsOneWidget);
      expect(find.text('Please enter your password.'), findsOneWidget);
    });

    testWidgets('SignupScreen renders all required fields', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const SignupScreen()));

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
      expect(find.widgetWithText(AuthButton, 'Create account'), findsOneWidget);
    });

    testWidgets('SignupScreen inline validation triggers on empty submit', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const SignupScreen()));

      final buttonFinder = find.widgetWithText(AuthButton, 'Create account');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your full name.'), findsOneWidget);
      expect(find.text('Please enter your email address.'), findsOneWidget);
      expect(find.text('Please enter a password.'), findsOneWidget);
      expect(find.text('Please confirm your password.'), findsOneWidget);
    });

    testWidgets('ForgotPasswordScreen renders email field and submit button', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const ForgotPasswordScreen()));

      expect(find.text('Reset your password'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.widgetWithText(AuthButton, 'Send reset link'), findsOneWidget);
      expect(find.text('Back to login'), findsOneWidget);
    });
  });
}
