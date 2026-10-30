import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/core/services/desktop_oauth_service.dart';
import 'package:study_vault/features/auth/domain/entities/auth_user.dart';
import 'package:study_vault/features/auth/domain/repositories/auth_repository.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/auth/presentation/screens/login_screen.dart';
import 'package:study_vault/features/classroom/presentation/providers/classroom_providers.dart';

class MockTestAuthRepo implements AuthRepository {
  AuthUser? _user;

  @override
  AuthUser? getCurrentUser() => _user;

  @override
  Future<void> signIn({required String email, required String password}) async {
    _user = AuthUser(id: 'test-user', email: email, fullName: 'Test Student');
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _user = AuthUser(id: 'test-user', email: email, fullName: fullName);
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }

  @override
  Future<void> resetPassword({required String email}) async {}

  @override
  Future<void> signInWithGoogle({String? redirectTo}) async {
    _user = AuthUser(
      id: 'google-test-id',
      email: 'student@google.com',
      fullName: 'Google Student',
    );
  }

  @override
  Future<void> exchangeCodeOrUrl(String urlOrCode) async {
    _user = AuthUser(
      id: 'exchanged-id',
      email: 'exchanged@test.com',
      fullName: 'Exchanged User',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Desktop OAuth & Guest Mode Tests', () {
    test('DesktopOAuthService computes correct default redirect URL', () {
      final service = DesktopOAuthService.instance;
      expect(service.redirectUrl, contains('localhost'));
      expect(service.redirectUrl, contains('/auth-callback'));
    });

    test('currentUserProfileProvider provides safe fallback profile when unauthenticated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final profile = container.read(currentUserProfileProvider);
      expect(profile.id, equals('guest'));
      expect(profile.name, contains('Guest'));
    });

    test('AuthController signInAsGuest toggles guest mode and authenticated state', () {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockTestAuthRepo()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(guestModeProvider), isFalse);
      container.read(authControllerProvider.notifier).signInAsGuest();

      expect(container.read(guestModeProvider), isTrue);
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);
      expect(container.read(authControllerProvider).userId, equals('guest'));
    });

    testWidgets('LoginScreen renders "Continue as Guest" and "Enter sign-in link" buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockTestAuthRepo()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: LoginScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue as Guest (Offline Vault)'), findsOneWidget);
      expect(find.text('Redirect not working? Enter sign-in link'), findsOneWidget);

      // Tap guest button
      await tester.tap(find.text('Continue as Guest (Offline Vault)'));
      await tester.pumpAndSettle();

      expect(container.read(guestModeProvider), isTrue);
    });

    testWidgets('LoginScreen paste link dialog opens and accepts input', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockTestAuthRepo()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: LoginScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap fallback link
      await tester.tap(find.text('Redirect not working? Enter sign-in link'));
      await tester.pumpAndSettle();

      expect(find.text('Complete Sign-In'), findsWidgets);
      expect(find.text('Cancel'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
