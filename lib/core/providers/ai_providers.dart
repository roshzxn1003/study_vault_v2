import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/ai/embedding_service.dart';
import 'package:study_vault/core/ai/hybrid_retriever.dart';
import 'package:study_vault/core/ai/retriever.dart';
import 'package:study_vault/core/ai/semantic_search_service.dart';
import 'package:study_vault/core/ai/rag_retriever.dart';
import 'package:study_vault/core/ai/llm_service.dart';
import 'package:study_vault/core/ai/ai_orchestrator.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/providers/document_providers.dart';

/// Real Google text-embedding-004 embedding provider.
final embeddingServiceProvider = Provider<EmbeddingService>((ref) {
  return GoogleEmbeddingService();
});

/// Multi-tenant Hybrid Retriever combining semantic vector and keyword search.
final hybridRetrieverProvider = Provider<HybridRetriever>((ref) {
  final embeddingService = ref.watch(embeddingServiceProvider);
  return HybridRetriever(
    embeddingService: embeddingService,
    localDb: LocalDbService.instance,
  );
});

final retrieverProvider = Provider<Retriever>((ref) {
  return ref.watch(hybridRetrieverProvider);
});

final semanticSearchServiceProvider = Provider<SemanticSearchService>((ref) {
  final embeddingService = ref.watch(embeddingServiceProvider);
  return SemanticSearchService(embeddingService);
});

final ragRetrieverProvider = Provider<RagRetriever>((ref) {
  final searchService = ref.watch(semanticSearchServiceProvider);
  return RagRetriever(searchService);
});

/// Official Google Generative AI (Gemini) LLM provider with streaming and fallback.
final llmServiceProvider = Provider<LlmService>((ref) {
  return GeminiLlmService();
});

/// Central AI Orchestrator with RAG, structured output, and streaming support.
final aiOrchestratorProvider = Provider<AiOrchestrator>((ref) {
  final llm = ref.watch(llmServiceProvider);
  final retriever = ref.watch(retrieverProvider);
  final processor = ref.watch(documentProcessorProvider);
  final search = ref.watch(semanticSearchServiceProvider);
  return AiOrchestrator(
    llm,
    retriever,
    documentProcessor: processor,
    searchService: search,
  );
});
