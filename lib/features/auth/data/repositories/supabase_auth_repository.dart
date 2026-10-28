import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/features/auth/domain/repositories/auth_repository.dart';
import 'package:study_vault/features/auth/domain/entities/auth_user.dart' as entity;

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient? _client;

  SupabaseAuthRepository([this._client]);

  SupabaseClient get _supabase {
    final client = _client;
    if (client != null) return client;
    return Supabase.instance.client;
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final res = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    if (res.user != null) {
      try {
        await _supabase.from('profiles').upsert({
          'id': res.user!.id,
          'full_name': fullName,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Table or trigger might handle profile creation or not exist yet
      }
    }
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> resetPassword({required String email}) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  @override
  entity.AuthUser? getCurrentUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    return entity.AuthUser(
      id: user.id,
      email: user.email ?? '',
      fullName: user.userMetadata?['full_name'] as String?,
    );
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  @override
  Future<void> signInWithGoogle({String? redirectTo}) async {
    final effectiveRedirectTo = redirectTo ??
        (kIsWeb ? null : 'io.supabase.studyvault://login-callback/');
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: effectiveRedirectTo,
    );
  }
}
