import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DataExportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> exportUserData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Fetch all user-owned data
    final notes = await _supabase.from('notes').select().eq('user_id', user.id);
    final folders = await _supabase.from('folders').select().eq('user_id', user.id);
    final files = await _supabase.from('files').select().eq('user_id', user.id);
    final exams = await _supabase.from('exams').select().eq('user_id', user.id);

    final exportData = {
      'user_id': user.id,
      'exported_at': DateTime.now().toIso8601String(),
      'data': {
        'folders': folders,
        'notes': notes,
        'files': files,
        'exams': exams,
      }
    };

    return jsonEncode(exportData);
  }
}

final dataExportServiceProvider = Provider((ref) => DataExportService());
