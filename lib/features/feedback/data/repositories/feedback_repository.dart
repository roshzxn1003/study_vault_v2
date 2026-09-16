import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> submitFeedback({
    required String category,
    required String title,
    required String description,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabase.from('feedback').insert({
      'user_id': user.id,
      'category': category,
      'title': title,
      'description': description,
    });
  }

  Future<void> submitAiRating({
    required String messageId,
    required bool isHelpful,
    String? feedbackText,
  }) async {
    await _supabase.from('ai_feedback').insert({
      'message_id': messageId,
      'is_helpful': isHelpful,
      'feedback_text': feedbackText,
    });
  }
}
