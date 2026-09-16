class DocumentChunk {
  final String id;
  final String fileId;
  final String userId;
  final String content;
  final int chunkIndex;
  final int pageNumber;
  final int tokenCount;
  final List<double> embedding;
  final Map<String, dynamic> metadata;

  DocumentChunk({
    required this.id,
    required this.fileId,
    required this.userId,
    required this.content,
    required this.chunkIndex,
    required this.pageNumber,
    required this.tokenCount,
    required this.embedding,
    required this.metadata,
  });

  factory DocumentChunk.fromMap(Map<String, dynamic> map) {
    return DocumentChunk(
      id: map['id'],
      fileId: map['file_id'],
      userId: map['user_id'],
      content: map['content'],
      chunkIndex: map['chunk_index'],
      pageNumber: map['page_number'] ?? 0,
      tokenCount: map['token_count'] ?? 0,
      embedding: List<double>.from(map['embedding']),
      metadata: map['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_id': fileId,
      'user_id': userId,
      'content': content,
      'chunk_index': chunkIndex,
      'page_number': pageNumber,
      'token_count': tokenCount,
      'embedding': embedding,
      'metadata': metadata,
    };
  }
}
