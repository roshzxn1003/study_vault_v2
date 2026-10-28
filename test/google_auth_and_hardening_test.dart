import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/ai/ai_config.dart';
import 'package:study_vault/features/auth/domain/repositories/auth_repository.dart';
import 'package:study_vault/features/auth/domain/entities/auth_user.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/auth/presentation/widgets/google_logo_icon.dart';
import 'package:study_vault/features/auth/presentation/screens/login_screen.dart';
import 'package:study_vault/features/auth/presentation/screens/signup_screen.dart';

class MockGoogleAuthRepository implements AuthRepository {
  bool signInWithGoogleCalled = false;
  String? lastRedirectTo;
  AuthUser? simulatedUser;

  @override
  Future<void> signInWithGoogle({String? redirectTo}) async {
    signInWithGoogleCalled = true;
    lastRedirectTo = redirectTo;
  }

  @override
  AuthUser? getCurrentUser() => simulatedUser;

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {}

  @override
  Future<void> signOut() async {
    simulatedUser = null;
  }

  @override
  Future<void> resetPassword({required String email}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Google OAuth & Security Hardening Tests', () {
    testWidgets('GoogleLogo widget renders cleanly with 4-color custom painter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GoogleLogo(size: 24),
            ),
          ),
        ),
      );

      expect(find.byType(GoogleLogo), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('LoginScreen displays Continue with Google button and GoogleLogo', (tester) async {
      final mockRepo = MockGoogleAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(GoogleLogo), findsOneWidget);

      await tester.ensureVisible(find.text('Continue with Google'));
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(mockRepo.signInWithGoogleCalled, isTrue);
    });

    testWidgets('SignupScreen displays Continue with Google button and GoogleLogo', (tester) async {
      final mockRepo = MockGoogleAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: SignupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(GoogleLogo), findsOneWidget);

      await tester.ensureVisible(find.text('Continue with Google'));
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(mockRepo.signInWithGoogleCalled, isTrue);
    });

    test('AuthController.signInWithGoogle executes cleanly and handles null browser user safely', () async {
      final mockRepo = MockGoogleAuthRepository();
      final controller = AuthController(mockRepo);

      final result = await controller.signInWithGoogle();

      expect(result, isTrue);
      expect(mockRepo.signInWithGoogleCalled, isTrue);
      // When external browser launches without immediate session, state reverts to unauthenticated
      expect(controller.state.status, AuthStatus.unauthenticated);

      controller.dispose();
    });

    test('AuthController.signInWithGoogle marks authenticated if session returned immediately', () async {
      final mockRepo = MockGoogleAuthRepository();
      mockRepo.simulatedUser = AuthUser(
        id: 'google-user-123',
        email: 'student@gmail.com',
        fullName: 'Study Student',
      );
      final controller = AuthController(mockRepo);

      final result = await controller.signInWithGoogle();

      expect(result, isTrue);
      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.userId, 'google-user-123');

      controller.dispose();
    });

    test('AiConfig XOR unmasking safely decodes valid fallback Gemini key', () async {
      final key = await AiConfig.getApiKey();
      expect(key, isNotEmpty);
      expect(key.startsWith('AQ.'), isTrue);
    });

    test('AndroidManifest.xml has android:allowBackup="false" and OAuth intent-filters', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final content = manifestFile.readAsStringSync();

      expect(content.contains('android:allowBackup="false"'), isTrue);
      expect(content.contains('android:scheme="io.supabase.studyvault"'), isTrue);
      expect(content.contains('android:host="login-callback"'), isTrue);
      expect(content.contains('android:scheme="studyvault"'), isTrue);
    });

    test('iOS Info.plist has CFBundleURLSchemes for io.supabase.studyvault', () {
      final plistFile = File('ios/Runner/Info.plist');
      expect(plistFile.existsSync(), isTrue);
      final content = plistFile.readAsStringSync();

      expect(content.contains('<key>CFBundleURLTypes</key>'), isTrue);
      expect(content.contains('<string>io.supabase.studyvault</string>'), isTrue);
      expect(content.contains('<string>studyvault</string>'), isTrue);
    });
  });
}
