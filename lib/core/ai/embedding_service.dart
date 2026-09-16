/// Abstract service for generating embeddings.
/// This allows switching between providers (OpenAI, Gemini, Voyage, etc.)
abstract class EmbeddingService {
  Future<List<double>> generateEmbedding(String text);
  Future<List<List<double>>> generateEmbeddings(List<String> texts);
  int get dimension;
}

/// A Mock/Placeholder implementation for development.
/// In production, this would call a real API.
class MockEmbeddingService implements EmbeddingService {
  @override
  int get dimension => 1536; // Standard for OpenAI text-embedding-3-small

  @override
  Future<List<double>> generateEmbedding(String text) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));
    // Generate a deterministic pseudo-random vector for testing
    return List.generate(dimension, (i) => (text.length + i) % 100 / 100.0);
  }

  @override
  Future<List<List<double>>> generateEmbeddings(List<String> texts) async {
    return Future.wait(texts.map((t) => generateEmbedding(t)));
  }
}
