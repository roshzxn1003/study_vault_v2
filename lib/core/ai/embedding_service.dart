import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:study_vault/core/ai/ai_config.dart';
import 'package:study_vault/core/ai/ai_models.dart';

/// Abstract service for generating vector embeddings and calculating similarity.
abstract class EmbeddingService {
  /// Embeds an individual [AiEmbeddingInput].
  Future<List<double>> embed(AiEmbeddingInput input);

  /// Backwards-compatible convenience method to embed plain text.
  Future<List<double>> generateEmbedding(
    String text, {
    AiEmbeddingTaskType taskType = AiEmbeddingTaskType.retrievalDocument,
  });

  /// Batch embeds multiple texts.
  Future<List<List<double>>> generateEmbeddings(
    List<String> texts, {
    AiEmbeddingTaskType taskType = AiEmbeddingTaskType.retrievalDocument,
  });

  /// Vector dimensionality of the underlying model (768 for text-embedding-004).
  int get dimension;

  /// Calculates cosine similarity between two float vectors.
  double calculateCosineSimilarity(List<double> a, List<double> b);
}

/// Official Google Generative AI Embedding Service using `text-embedding-004`.
class GoogleEmbeddingService implements EmbeddingService {
  @override
  int get dimension => 768; // Official text-embedding-004 dimensionality

  TaskType _mapTaskType(AiEmbeddingTaskType type) {
    switch (type) {
      case AiEmbeddingTaskType.retrievalQuery:
        return TaskType.retrievalQuery;
      case AiEmbeddingTaskType.retrievalDocument:
        return TaskType.retrievalDocument;
      case AiEmbeddingTaskType.semanticSimilarity:
        return TaskType.semanticSimilarity;
      case AiEmbeddingTaskType.classification:
        return TaskType.classification;
      case AiEmbeddingTaskType.clustering:
        return TaskType.clustering;
    }
  }

  @override
  Future<List<double>> embed(AiEmbeddingInput input) async {
    final apiKey = await AiConfig.getApiKey();
    if (apiKey.isEmpty) {
      // In offline/no-key mode, generate deterministic normalized embedding for offline testability
      return _generateOfflineFallbackVector(input.text);
    }

    try {
      final model = GenerativeModel(
        model: AiConfig.embeddingModel,
        apiKey: apiKey,
      );

      final response = await model
          .embedContent(
            Content.text(input.text),
            taskType: _mapTaskType(input.taskType),
            title: input.title,
          )
          .timeout(const Duration(seconds: 15));

      final values = response.embedding.values;
      if (values.isNotEmpty) {
        return values;
      }
    } catch (e) {
      debugPrint('Google embedding generation failed: $e. Falling back gracefully.');
    }

    return _generateOfflineFallbackVector(input.text);
  }

  @override
  Future<List<double>> generateEmbedding(
    String text, {
    AiEmbeddingTaskType taskType = AiEmbeddingTaskType.retrievalDocument,
  }) {
    return embed(AiEmbeddingInput(text: text, taskType: taskType));
  }

  @override
  Future<List<List<double>>> generateEmbeddings(
    List<String> texts, {
    AiEmbeddingTaskType taskType = AiEmbeddingTaskType.retrievalDocument,
  }) async {
    final results = <List<double>>[];
    // Batch sequentially or in small chunks of 5 to respect API rate limits
    for (int i = 0; i < texts.length; i += 5) {
      final end = (i + 5 < texts.length) ? i + 5 : texts.length;
      final batch = texts.sublist(i, end);
      final batchResults = await Future.wait(
        batch.map((t) => embed(AiEmbeddingInput(text: t, taskType: taskType))),
      );
      results.addAll(batchResults);
    }
    return results;
  }

  @override
  double calculateCosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA <= 0.0 || normB <= 0.0) return 0.0;
    return (dotProduct / (math.sqrt(normA) * math.sqrt(normB))).clamp(-1.0, 1.0);
  }

  /// Deterministic pseudo-embedding for testing or offline degradation when no API key is supplied.
  List<double> _generateOfflineFallbackVector(String text) {
    final clean = text.trim().toLowerCase();
    final vector = List<double>.filled(dimension, 0.0);
    if (clean.isEmpty) return vector;

    for (int i = 0; i < clean.length; i++) {
      final code = clean.codeUnitAt(i);
      final idx = (code * 31 + i) % dimension;
      vector[idx] += (code % 10) / 10.0;
    }

    // L2 Normalize
    double norm = 0.0;
    for (final v in vector) {
      norm += v * v;
    }
    norm = math.sqrt(norm);
    if (norm > 0) {
      for (int i = 0; i < dimension; i++) {
        vector[i] /= norm;
      }
    }
    return vector;
  }
}
