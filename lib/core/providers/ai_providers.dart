import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/ai/embedding_service.dart';
import 'package:study_vault/core/ai/semantic_search_service.dart';
import 'package:study_vault/core/ai/rag_retriever.dart';
import 'package:study_vault/core/ai/llm_service.dart';
import 'package:study_vault/core/ai/ai_orchestrator.dart';

final embeddingServiceProvider = Provider<EmbeddingService>((ref) {
  return MockEmbeddingService();
});

final semanticSearchServiceProvider = Provider<SemanticSearchService>((ref) {
  final embeddingService = ref.watch(embeddingServiceProvider);
  return SemanticSearchService(embeddingService);
});

final ragRetrieverProvider = Provider<RagRetriever>((ref) {
  final searchService = ref.watch(semanticSearchServiceProvider);
  return RagRetriever(searchService);
});

final llmServiceProvider = Provider<LlmService>((ref) {
  return GeminiLlmService();
});


final aiOrchestratorProvider = Provider<AiOrchestrator>((ref) {
  final llm = ref.watch(llmServiceProvider);
  final search = ref.watch(semanticSearchServiceProvider);
  return AiOrchestrator(llm, search);
});
