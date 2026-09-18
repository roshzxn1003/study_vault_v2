/// Represents a typed retrieval query for RAG and semantic search.
class RetrievalQuery {
  final String queryText;
  final String userId;
  final String? workspaceId;
  final String? subjectId;
  final String? academicPeriodId;
  final String? materialId;
  final int topK;
  final double minSimilarity;
  final bool includeShared;

  const RetrievalQuery({
    required this.queryText,
    required this.userId,
    this.workspaceId,
    this.subjectId,
    this.academicPeriodId,
    this.materialId,
    this.topK = 5,
    this.minSimilarity = 0.35,
    this.includeShared = true,
  });

  RetrievalQuery copyWith({
    String? queryText,
    String? userId,
    String? workspaceId,
    String? subjectId,
    String? academicPeriodId,
    String? materialId,
    int? topK,
    double? minSimilarity,
    bool? includeShared,
  }) {
    return RetrievalQuery(
      queryText: queryText ?? this.queryText,
      userId: userId ?? this.userId,
      workspaceId: workspaceId ?? this.workspaceId,
      subjectId: subjectId ?? this.subjectId,
      academicPeriodId: academicPeriodId ?? this.academicPeriodId,
      materialId: materialId ?? this.materialId,
      topK: topK ?? this.topK,
      minSimilarity: minSimilarity ?? this.minSimilarity,
      includeShared: includeShared ?? this.includeShared,
    );
  }
}

/// Represents an individual document chunk retrieved by semantic or hybrid search.
class RetrievedChunk {
  final String chunkId;
  final String materialId;
  final String materialTitle;
  final int pageNumber;
  final int chunkIndex;
  final String text;
  final double score; // 0.0 to 1.0
  final String matchType; // 'semantic', 'keyword', 'hybrid'
  final Map<String, dynamic> metadata;

  const RetrievedChunk({
    required this.chunkId,
    required this.materialId,
    required this.materialTitle,
    required this.pageNumber,
    required this.chunkIndex,
    required this.text,
    required this.score,
    required this.matchType,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
        'id': chunkId,
        'material_id': materialId,
        'material_title': materialTitle,
        'page_number': pageNumber,
        'chunk_index': chunkIndex,
        'text': text,
        'score': score,
        'match_type': matchType,
        'metadata': metadata,
      };

  factory RetrievedChunk.fromMap(Map<String, dynamic> map) => RetrievedChunk(
        chunkId: map['id'] ?? map['chunk_id'] ?? '',
        materialId: map['material_id'] ?? map['file_id'] ?? '',
        materialTitle: map['material_title'] ?? map['file_name'] ?? 'Study Material',
        pageNumber: (map['page_number'] as num?)?.toInt() ?? 1,
        chunkIndex: (map['chunk_index'] as num?)?.toInt() ?? 0,
        text: map['text'] ?? map['content'] ?? '',
        score: (map['score'] as num?)?.toDouble() ??
            (map['similarity'] as num?)?.toDouble() ??
            0.0,
        matchType: map['match_type'] ?? 'semantic',
        metadata: map['metadata'] != null
            ? Map<String, dynamic>.from(map['metadata'] as Map)
            : const {},
      );
}

/// Abstract contract for retrieving grounded chunks from study materials.
abstract class Retriever {
  Future<List<RetrievedChunk>> retrieve(RetrievalQuery query);
}
