import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/ai/embedding_service.dart';
import 'package:study_vault/core/ai/hybrid_retriever.dart';
import 'package:study_vault/core/ai/retriever.dart';
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
      fileId: map['file_id'] ?? map['material_id'] ?? 'local_id',
      fileName: map['file_name'] ?? map['material_title'] ?? 'Study Note',
      content: map['content'] ?? map['text'] ?? '',
      pageNumber: map['page_number'] ?? 1,
      similarity: (map['similarity'] as num?)?.toDouble() ??
          (map['score'] as num?)?.toDouble() ??
          0.85,
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : {},
    );
  }

  factory SearchResult.fromRetrievedChunk(RetrievedChunk chunk) {
    return SearchResult(
      fileId: chunk.materialId,
      fileName: chunk.materialTitle,
      content: chunk.text,
      pageNumber: chunk.pageNumber,
      similarity: chunk.score,
      metadata: {
        'match_type': chunk.matchType,
        'chunk_index': chunk.chunkIndex,
        ...chunk.metadata,
      },
    );
  }
}

/// Semantic search service backed by multi-tenant [HybridRetriever].
class SemanticSearchService {
  final EmbeddingService embeddingService;
  final HybridRetriever _hybridRetriever;

  SemanticSearchService(this.embeddingService, {LocalDbService? localDb})
      : _hybridRetriever = HybridRetriever(
          embeddingService: embeddingService,
          localDb: localDb ?? LocalDbService.instance,
        );

  Future<List<SearchResult>> search(
    String query, {
    int matchCount = 5,
    String? workspaceId,
    String? subjectId,
    String? materialId,
  }) async {
    String userId = 'guest';
    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser != null) {
        userId = authUser.id;
      }
    } catch (_) {}

    final chunks = await _hybridRetriever.retrieve(RetrievalQuery(
      queryText: query,
      userId: userId,
      workspaceId: workspaceId,
      subjectId: subjectId,
      materialId: materialId,
      topK: matchCount,
    ));

    return chunks.map((c) => SearchResult.fromRetrievedChunk(c)).toList();
  }
}
