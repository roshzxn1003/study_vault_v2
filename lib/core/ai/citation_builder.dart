import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/ai/retriever.dart';

/// Builder and validator for source citations in RAG answers.
///
/// Grounding & Anti-Hallucination Guarantees:
/// - Only constructs citations for materials and pages that physically exist
///   in the retrieved context.
/// - Never invents page numbers or phantom document IDs.
class CitationBuilder {
  /// Builds a deduplicated list of [AiSource] citations from retrieved chunks.
  static List<AiSource> buildCitations(List<RetrievedChunk> chunks) {
    final Map<String, AiSource> uniqueSources = {};

    for (final chunk in chunks) {
      // Keyed by material and page so multiple chunks on same page merge cleanly
      final key = '${chunk.materialId}_p${chunk.pageNumber}';
      if (!uniqueSources.containsKey(key)) {
        uniqueSources[key] = AiSource(
          fileId: chunk.materialId,
          fileName: chunk.materialTitle,
          pageNumber: chunk.pageNumber,
          chunkId: chunk.chunkId,
          similarity: chunk.score,
          snippet: chunk.text.length > 150
              ? '${chunk.text.substring(0, 150)}...'
              : chunk.text,
        );
      }
    }

    return uniqueSources.values.toList();
  }

  /// Formats human-readable citation label, e.g. "OS Unit 3 Notes • p. 12"
  static String formatCitationChip(AiSource source) {
    if (source.pageNumber > 0) {
      return '${source.fileName} • p. ${source.pageNumber}';
    }
    return source.fileName;
  }
}
