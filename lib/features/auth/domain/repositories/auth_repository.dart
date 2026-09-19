import 'package:study_vault/features/auth/domain/entities/auth_user.dart';

abstract class AuthRepository {
  Future<void> signUp({required String email, required String password, required String fullName});
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
  Future<void> resetPassword({required String email});
  AuthUser? getCurrentUser();
  Future<void> signInWithGoogle({String? redirectTo});
}
