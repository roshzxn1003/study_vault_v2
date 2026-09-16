class AuthUser {
  final String id;
  final String email;
  final String? fullName;

  AuthUser({required this.id, required this.email, this.fullName});
}
