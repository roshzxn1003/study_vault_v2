import 'package:study_vault/core/ai/retriever.dart';
import 'package:study_vault/core/ai/semantic_search_service.dart';

/// Context Builder for RAG pipeline.
/// Controls token budgeting, deduplication, and structured context formatting.
class ContextBuilder {
  static const int defaultMaxContextChars = 8000; // ~2000 tokens

  /// Builds structured context from [RetrievedChunk] items.
  static String buildContextFromChunks(
    List<RetrievedChunk> chunks, {
    int maxChars = defaultMaxContextChars,
  }) {
    if (chunks.isEmpty) {
      return "No relevant context found in the user's Study Vault materials.";
    }

    final buffer = StringBuffer();
    final seen = <String>{};
    int accumulatedChars = 0;

    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      // Deduplicate identical or near-identical text
      final textSig = '${chunk.materialId}_${chunk.pageNumber}_${chunk.chunkIndex}';
      if (seen.contains(textSig)) continue;
      seen.add(textSig);

      final chunkContent = chunk.text.trim();
      if (accumulatedChars + chunkContent.length > maxChars) {
        break;
      }

      buffer.writeln("=== [SOURCE ${i + 1}] ===");
      buffer.writeln("Document: ${chunk.materialTitle}");
      buffer.writeln("Material ID: ${chunk.materialId}");
      buffer.writeln("Page: ${chunk.pageNumber}");
      buffer.writeln("Relevance Score: ${(chunk.score * 100).toStringAsFixed(1)}%");
      buffer.writeln("Content:\n$chunkContent\n");

      accumulatedChars += chunkContent.length + 100;
    }

    return buffer.toString().trim();
  }

  /// Backwards-compatible builder for [SearchResult] lists.
  static String buildStructuredContext(List<SearchResult> results) {
    if (results.isEmpty) {
      return "No relevant context found in the user's study materials.";
    }

    final buffer = StringBuffer();
    for (var i = 0; i < results.length; i++) {
      final res = results[i];
      buffer.writeln("=== [SOURCE ${i + 1}] ===");
      buffer.writeln("File: ${res.fileName}");
      buffer.writeln("File ID: ${res.fileId}");
      buffer.writeln("Page: ${res.pageNumber}");
      buffer.writeln("\nContent:\n${res.content}");
      buffer.writeln("\n---\n");
    }

    return buffer.toString().trim();
  }
}
