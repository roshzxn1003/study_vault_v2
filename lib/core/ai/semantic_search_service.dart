import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/ai/embedding_service.dart';
import 'package:study_vault/core/database/local_db_service.dart';

class SearchResult {
  final String fileId;
  final String fileName;
  final String content;
  final int pageNumber;
  final double similarity;
  final Map<String, dynamic> metadata;

  SearchResult({
    required this.fileId,
    required this.fileName,
    required this.content,
    required this.pageNumber,
    required this.similarity,
    required this.metadata,
  });

  factory SearchResult.fromMap(Map<String, dynamic> map) {
    return SearchResult(
      fileId: map['file_id'] ?? 'local_id',
      fileName: map['file_name'] ?? 'Study Note',
      content: map['content'] ?? '',
      pageNumber: map['page_number'] ?? 1,
      similarity: (map['similarity'] as num?)?.toDouble() ?? 0.85,
      metadata: map['metadata'] ?? {},
    );
  }
}

class SemanticSearchService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final EmbeddingService _embeddingService;

  SemanticSearchService(this._embeddingService);

  Future<List<SearchResult>> search(String query, {int matchCount = 5}) async {
    try {
      final queryEmbedding = await _embeddingService.generateEmbedding(query);
      final List<dynamic> response = await _supabase.rpc(
        'match_documents',
        params: {
          'query_embedding': queryEmbedding,
          'match_threshold': 0.4,
          'match_count': matchCount,
        },
      );

      if (response.isNotEmpty) {
        return response.map((item) => SearchResult.fromMap(item)).toList();
      }
    } catch (_) {
      // Remote RPC offline or unavailable - fallback to local SQLite search
    }

    // Local SQLite fallback
    try {
      final db = await LocalDbService.instance.database;
      final tokens = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.length > 2).toList();
      
      final notes = await db.query('notes');
      final results = <SearchResult>[];

      for (final note in notes) {
        final title = (note['title'] as String? ?? '').toLowerCase();
        final content = (note['content'] as String? ?? '').toLowerCase();

        int matches = 0;
        for (final t in tokens) {
          if (title.contains(t) || content.contains(t)) matches++;
        }

        if (matches > 0 || tokens.isEmpty) {
          final sim = tokens.isEmpty ? 0.75 : (matches / tokens.length).clamp(0.5, 0.95);
          results.add(SearchResult(
            fileId: note['id'] as String? ?? 'note_id',
            fileName: note['title'] as String? ?? 'Study Note',
            content: note['content'] as String? ?? '',
            pageNumber: 1,
            similarity: sim,
            metadata: {'type': 'note', 'folder_id': note['folder_id']},
          ));
        }
      }

      results.sort((a, b) => b.similarity.compareTo(a.similarity));
      return results.take(matchCount).toList();
    } catch (_) {
      return [];
    }
  }
}

