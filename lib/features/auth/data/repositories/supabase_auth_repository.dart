import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/features/auth/domain/repositories/auth_repository.dart';
import 'package:study_vault/features/auth/domain/entities/auth_user.dart' as entity;

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

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
}
