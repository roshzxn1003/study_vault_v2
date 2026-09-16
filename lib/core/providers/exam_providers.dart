import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/features/exam/data/repositories/exam_repository.dart';

final examRepositoryProvider = Provider((ref) => ExamRepository());

final examsProvider = FutureProvider((ref) async {
  final repo = ref.watch(examRepositoryProvider);
  return await repo.getExams();
});
