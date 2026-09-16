import 'package:study_vault/core/ai/llm_service.dart';
import 'package:study_vault/core/ai/semantic_search_service.dart';
import 'package:study_vault/core/ai/context_builder.dart';
import 'package:study_vault/core/ai/prompt_builder.dart';
import 'package:study_vault/core/ai/ai_models.dart';

class AiOrchestrator {
  final LlmService _llm;
  final SemanticSearchService _search;

  AiOrchestrator(this._llm, this._search);

  Future<AiResponse> askQuestion({
    required String query,
    required String mode,
    List<String>? history,
    String? imagePath,
  }) async {
    // 1. Retrieve relevant chunks (RAG)
    final results = await _search.search(query);
    
    // 2. Build context
    final context = ContextBuilder.buildStructuredContext(results);
    
    // 3. Build prompt
    final prompt = PromptBuilder.buildRagPrompt(
      query: query,
      context: context,
      mode: mode,
    );

    // 4. Call LLM
    final answer = await _llm.generateAnswer(
      query: prompt,
      context: context,
      history: history,
      imagePath: imagePath,
    );


    // 5. Map results to AiSources
    final sources = results.map((r) => AiSource(
      fileId: r.fileId,
      fileName: r.fileName,
      pageNumber: r.pageNumber,
      chunkId: r.content.hashCode.toString(), // Placeholder
      similarity: r.similarity,
    )).toList();

    return AiResponse(
      answer: answer,
      sources: sources,
      confidence: results.isNotEmpty ? results.first.similarity : 0.0,
      usedContext: context,
    );
  }
}
