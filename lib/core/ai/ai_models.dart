class AiSource {
  final String fileId;
  final String fileName;
  final int pageNumber;
  final String chunkId;
  final double similarity;

  AiSource({
    required this.fileId,
    required this.fileName,
    required this.pageNumber,
    required this.chunkId,
    required this.similarity,
  });

  factory AiSource.fromMap(Map<String, dynamic> map) {
    return AiSource(
      fileId: map['file_id'],
      fileName: map['file_name'] ?? 'Unknown',
      pageNumber: map['page_number'] ?? 0,
      chunkId: map['id'],
      similarity: (map['similarity'] as num).toDouble(),
    );
  }
}

class AiResponse {
  final String answer;
  final List<AiSource> sources;
  final double confidence;
  final String usedContext;

  AiResponse({
    required this.answer,
    required this.sources,
    required this.confidence,
    required this.usedContext,
  });
}
