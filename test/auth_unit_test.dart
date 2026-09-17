import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/auth/domain/entities/auth_user.dart';
import 'package:study_vault/features/auth/domain/repositories/auth_repository.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';

class FakeAuthRepository implements AuthRepository {
  AuthUser? _currentUser;
  bool shouldFail = false;
  String failMessage = 'Mock error';

  @override
  AuthUser? getCurrentUser() => _currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (shouldFail) throw Exception(failMessage);
    _currentUser = AuthUser(id: 'test-user-id', email: email, fullName: 'Test User');
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (shouldFail) throw Exception(failMessage);
    _currentUser = AuthUser(id: 'test-user-id', email: email, fullName: fullName);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Future<void> resetPassword({required String email}) async {
    if (shouldFail) throw Exception(failMessage);
  }
}

void main() {
  group('AuthController Tests', () {
    late FakeAuthRepository fakeRepo;
    late AuthController authController;

    setUp(() {
      fakeRepo = FakeAuthRepository();
      authController = AuthController(fakeRepo);
    });

    test('Initial state is unauthenticated when no user is logged in', () {
      expect(authController.state.status, AuthStatus.unauthenticated);
      expect(authController.state.isAuthenticated, false);
      expect(authController.state.isLoading, false);
      expect(authController.state.hasError, false);
    });

    test('Sign in success updates state to authenticated', () async {
      final success = await authController.signIn(
        email: 'test@university.edu',
        password: 'password123',
      );

      expect(success, true);
      expect(authController.state.status, AuthStatus.authenticated);
      expect(authController.state.isAuthenticated, true);
      expect(authController.state.userId, 'test-user-id');
    });

    test('Sign in failure updates state to error', () async {
      fakeRepo.shouldFail = true;
      fakeRepo.failMessage = 'Network connection issue';

      final success = await authController.signIn(
        email: 'test@university.edu',
        password: 'wrongpassword',
      );

      expect(success, false);
      expect(authController.state.status, AuthStatus.error);
      expect(authController.state.hasError, true);
      expect(authController.state.errorMessage, isNotNull);
    });

    test('Sign up success updates state to authenticated', () async {
      final success = await authController.signUp(
        email: 'newstudent@university.edu',
        password: 'password123',
        fullName: 'New Student',
      );

      expect(success, true);
      expect(authController.state.status, AuthStatus.authenticated);
      expect(authController.state.userId, 'test-user-id');
    });

    test('Sign out updates state to unauthenticated', () async {
      await authController.signIn(
        email: 'test@university.edu',
        password: 'password123',
      );
      expect(authController.state.isAuthenticated, true);

      await authController.signOut();
      expect(authController.state.status, AuthStatus.unauthenticated);
      expect(authController.state.isAuthenticated, false);
    });

    test('Reset password triggers repository without crashing', () async {
      final success = await authController.resetPassword(email: 'test@university.edu');
      expect(success, true);
      expect(authController.state.successMessage, isNotNull);
    });
  });

  group('Validation Logic Tests', () {
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    test('Valid email addresses pass', () {
      expect(emailRegExp.hasMatch('student@mit.edu'), true);
      expect(emailRegExp.hasMatch('user.name@domain.co'), true);
      expect(emailRegExp.hasMatch('test_account@sub.university.edu'), true);
    });

    test('Invalid email addresses fail', () {
      expect(emailRegExp.hasMatch('invalid'), false);
      expect(emailRegExp.hasMatch('missingat.com'), false);
      expect(emailRegExp.hasMatch('@nodomain.com'), false);
      expect(emailRegExp.hasMatch('spaces in@email.com'), false);
    });
  });
}
