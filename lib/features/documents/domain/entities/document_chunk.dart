/// Represents a chunk of academic material indexed for semantic vector and hybrid search.
class DocumentChunk {
  final String id;
  final String fileId; // Material ID
  final String userId;
  final String? workspaceId;
  final String? academicPeriodId;
  final String? subjectId;
  final String? folderId;
  final String content;
  final int chunkIndex;
  final int pageNumber;
  final int tokenCount;
  final List<double> embedding;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get materialId => fileId;

  DocumentChunk({
    required this.id,
    required this.fileId,
    required this.userId,
    this.workspaceId,
    this.academicPeriodId,
    this.subjectId,
    this.folderId,
    required this.content,
    required this.chunkIndex,
    required this.pageNumber,
    required this.tokenCount,
    required this.embedding,
    required this.metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory DocumentChunk.fromMap(Map<String, dynamic> map) {
    List<double> emb = [];
    if (map['embedding'] != null) {
      if (map['embedding'] is List) {
        emb = (map['embedding'] as List).map((e) => (e as num).toDouble()).toList();
      }
    }

    return DocumentChunk(
      id: map['id'] ?? '',
      fileId: map['material_id'] ?? map['file_id'] ?? '',
      userId: map['user_id'] ?? 'guest',
      workspaceId: map['workspace_id'],
      academicPeriodId: map['academic_period_id'],
      subjectId: map['subject_id'],
      folderId: map['folder_id'],
      content: map['text'] ?? map['content'] ?? '',
      chunkIndex: (map['chunk_index'] as num?)?.toInt() ?? 0,
      pageNumber: (map['page_number'] as num?)?.toInt() ?? 1,
      tokenCount: (map['token_count'] as num?)?.toInt() ?? 0,
      embedding: emb,
      metadata: map['metadata'] != null
          ? (map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata'] as Map) : {})
          : {},
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_id': fileId,
      'material_id': fileId,
      'user_id': userId,
      'workspace_id': workspaceId,
      'academic_period_id': academicPeriodId,
      'subject_id': subjectId,
      'folder_id': folderId,
      'content': content,
      'text': content,
      'chunk_index': chunkIndex,
      'page_number': pageNumber,
      'token_count': tokenCount,
      'embedding': embedding,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
