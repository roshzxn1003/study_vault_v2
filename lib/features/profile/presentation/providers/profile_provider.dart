import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/providers/database_providers.dart';

final profileDataProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  return await repo.getProfile();
});

final updateProfileProvider = Provider((ref) {
  return ref.read(profileRepositoryProvider).updateProfile;
});
