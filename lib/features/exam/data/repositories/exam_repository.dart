import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/exam.dart';

class ExamRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> createExam(Exam exam) async {
    await _supabase.from('exams').insert(exam.toMap());
  }

  Future<List<Exam>> getExams() async {
    final data = await _supabase.from('exams').select().order('exam_date');
    return data.map((map) => Exam.fromMap(map)).toList();
  }

  Future<void> deleteExam(String id) async {
    await _supabase.from('exams').delete().eq('id', id);
  }
}
