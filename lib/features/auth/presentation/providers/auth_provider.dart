import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:study_vault/features/auth/domain/repositories/auth_repository.dart';
import 'package:study_vault/features/sync/presentation/providers/sync_provider.dart';
import 'package:study_vault/core/database/local_db_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthControllerState {
  final AuthStatus status;
  final String? errorMessage;
  final String? successMessage;
  final String? userId;

  const AuthControllerState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.successMessage,
    this.userId,
  });

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get hasError => status == AuthStatus.error && errorMessage != null;

  AuthControllerState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? successMessage,
    String? userId,
  }) {
    return AuthControllerState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      successMessage: successMessage,
      userId: userId ?? this.userId,
    );
  }
}

class AuthController extends StateNotifier<AuthControllerState> {
  final AuthRepository _repository;
  final Ref? _ref;

  AuthController(this._repository, [this._ref]) : super(const AuthControllerState()) {
    _checkCurrentUser();
  }

  void _triggerBackgroundSync() {
    try {
      _ref?.read(syncProvider.notifier).syncNow();
    } catch (e) {
      debugPrint('[AuthController] Sync trigger note: $e');
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _repository.signInWithGoogle();
      final user = _repository.getCurrentUser();
      if (user != null) {
        try {
          await LocalDbService.instance.migrateUserData('guest', user.id);
        } catch (e) {
          debugPrint('Auth migrate guest data on Google signin note: $e');
        }
        state = AuthControllerState(
          status: AuthStatus.authenticated,
          userId: user.id,
          successMessage: 'Signed in successfully',
        );
        _triggerBackgroundSync();
      }
      return true;
    } on AuthException catch (e) {
      state = AuthControllerState(
        status: AuthStatus.error,
        errorMessage: _mapAuthException(e),
      );
      return false;
    } catch (e) {
      state = AuthControllerState(
        status: AuthStatus.error,
        errorMessage: _mapGenericError(e),
      );
      return false;
    }
  }

  void _checkCurrentUser() {
    try {
      final user = _repository.getCurrentUser();
      if (user != null) {
        state = AuthControllerState(
          status: AuthStatus.authenticated,
          userId: user.id,
        );
        _triggerBackgroundSync();
      } else {
        state = const AuthControllerState(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      state = const AuthControllerState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _repository.signIn(email: email, password: password);
      final user = _repository.getCurrentUser();
      if (user != null) {
        try {
          await LocalDbService.instance.migrateUserData('guest', user.id);
        } catch (e) {
          debugPrint('Auth migrate guest data on signIn note: $e');
        }
        state = AuthControllerState(
          status: AuthStatus.authenticated,
          userId: user.id,
          successMessage: 'Signed in successfully',
        );
        _triggerBackgroundSync();
      } else {
        state = const AuthControllerState(
          status: AuthStatus.authenticated,
          successMessage: 'Signed in successfully',
        );
      }
      return true;
    } on AuthException catch (e) {
      state = AuthControllerState(
        status: AuthStatus.error,
        errorMessage: _mapAuthException(e),
      );
      return false;
    } catch (e) {
      state = AuthControllerState(
        status: AuthStatus.error,
        errorMessage: _mapGenericError(e),
      );
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _repository.signUp(email: email, password: password, fullName: fullName);
      final user = _repository.getCurrentUser();
      if (user != null) {
        try {
          await LocalDbService.instance.migrateUserData('guest', user.id);
        } catch (e) {
          debugPrint('Auth migrate guest data on signUp note: $e');
        }
        state = AuthControllerState(
          status: AuthStatus.authenticated,
          userId: user.id,
          successMessage: 'Account created successfully',
        );
        _triggerBackgroundSync();
      } else {
        // Confirmation email sent
        state = const AuthControllerState(
          status: AuthStatus.unauthenticated,
          successMessage: 'Please check your email to confirm your account.',
        );
      }
      return true;
    } on AuthException catch (e) {
      state = AuthControllerState(
        status: AuthStatus.error,
        errorMessage: _mapAuthException(e),
      );
      return false;
    } catch (e) {
      state = AuthControllerState(
        status: AuthStatus.error,
        errorMessage: _mapGenericError(e),
      );
      return false;
    }
  }

  Future<bool> resetPassword({required String email}) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _repository.resetPassword(email: email);
      state = const AuthControllerState(
        status: AuthStatus.unauthenticated,
        successMessage: 'Password reset link sent to your email.',
      );
      return true;
    } on AuthException catch (e) {
      state = AuthControllerState(
        status: AuthStatus.error,
        errorMessage: _mapAuthException(e),
      );
      return false;
    } catch (e) {
      state = AuthControllerState(
        status: AuthStatus.error,
        errorMessage: _mapGenericError(e),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final currentUser = _repository.getCurrentUser();
      final userId = currentUser?.id ?? state.userId;
      if (userId != null && userId.isNotEmpty) {
        try {
          await LocalDbService.instance.clearUserData(userId);
        } catch (e) {
          debugPrint('Auth clear user data on signOut note: $e');
        }
      }
    } catch (e) {
      debugPrint('Auth signOut user lookup note: $e');
    }
    try {
      await _repository.signOut();
    } catch (e) {
      debugPrint('Auth repo signOut note: $e');
    }
    state = const AuthControllerState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  static String _mapAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') || msg.contains('invalid grant')) {
      return 'Invalid email or password. Please verify your credentials.';
    }
    if (msg.contains('email not confirmed') || msg.contains('email_not_confirmed')) {
      return 'Email not confirmed. Please check your inbox for the verification link.';
    }
    if (msg.contains('user already registered') || msg.contains('already exists')) {
      return 'An account with this email already exists. Please log in instead.';
    }
    if (msg.contains('password') && (msg.contains('short') || msg.contains('weak') || msg.contains('least 6'))) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('missing oauth secret') || msg.contains('unsupported provider')) {
      return 'Google Sign-In is not fully configured in your Supabase project. Please configure your Google Client ID & Secret in Supabase Authentication Providers.';
    }
    if (msg.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    return e.message.isNotEmpty ? e.message : 'Authentication failed. Please try again.';
  }

  static String _mapGenericError(dynamic e) {
    final str = e.toString().toLowerCase();
    if (str.contains('socketexception') || str.contains('network') || str.contains('failed host lookup')) {
      return 'Network connection issue. Please check your internet connection.';
    }
    if (str.contains('timeout')) {
      return 'The request timed out. Please try again.';
    }
    return 'An unexpected error occurred. Please try again.';
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository();
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthControllerState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider), ref);
});

// Backward compatibility entity for existing stream-based watchers
class AuthState {
  final AuthStatus status;
  final String? userId;

  AuthState({required this.status, this.userId});

  factory AuthState.initializing() => AuthState(status: AuthStatus.initial);
  factory AuthState.authenticated(String userId) => AuthState(status: AuthStatus.authenticated, userId: userId);
  factory AuthState.unauthenticated() => AuthState(status: AuthStatus.unauthenticated);
}

final authStateProvider = StreamProvider<AuthState>((ref) {
  final auth = Supabase.instance.client.auth;

  return auth.onAuthStateChange.map((data) {
    final session = data.session;
    if (session != null) {
      return AuthState.authenticated(session.user.id);
    } else {
      return AuthState.unauthenticated();
    }
  });
});

final guestModeProvider = StateProvider<bool>((ref) => false);
