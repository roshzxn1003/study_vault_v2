import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/ai/embedding_service.dart';
import 'package:study_vault/features/documents/domain/entities/document_chunk.dart';

class DocumentRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final EmbeddingService _embeddingService;
  EmbeddingService get embeddingService => _embeddingService;

  DocumentRepository(this._embeddingService);

  Future<void> updateProcessingStatus(String fileId, String status, {String? error}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabase.from('document_processing').upsert({
      'file_id': fileId,
      'user_id': user.id,
      'status': status,
      'error_message': error,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> storeChunks(List<DocumentChunk> chunks) async {
    final List<Map<String, dynamic>> chunkMaps = chunks.map((c) => c.toMap()).toList();
    await _supabase.from('document_chunks').insert(chunkMaps);
  }

  Future<void> clearChunks(String fileId) async {
    await _supabase.from('document_chunks').delete().eq('file_id', fileId);
  }

  Future<String?> getProcessingStatus(String fileId) async {
    final data = await _supabase
        .from('document_processing')
        .select('status')
        .eq('file_id', fileId)
        .maybeSingle();
    return data?['status'] as String?;
  }
}
