import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:study_vault/features/auth/domain/repositories/auth_repository.dart';

enum AuthStatus { initializing, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? userId;

  AuthState({required this.status, this.userId});

  factory AuthState.initializing() => AuthState(status: AuthStatus.initializing);
  factory AuthState.authenticated(String userId) => AuthState(status: AuthStatus.authenticated, userId: userId);
  factory AuthState.unauthenticated() => AuthState(status: AuthStatus.unauthenticated);
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository();
});

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

final guestModeProvider = StateProvider<bool>((ref) => true);

