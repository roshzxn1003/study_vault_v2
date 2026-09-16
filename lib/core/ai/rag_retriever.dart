import 'package:study_vault/core/ai/semantic_search_service.dart';

class RagContext {
  final String formattedContext;
  final List<SearchResult> sources;

  RagContext({required this.formattedContext, required this.sources});
}

class RagRetriever {
  final SemanticSearchService _searchService;

  RagRetriever(this._searchService);

  Future<RagContext> retrieveRelevantContext(String query) async {
    final results = await _searchService.search(query);
    
    if (results.isEmpty) {
      return RagContext(
        formattedContext: "No relevant context found in the vault.",
        sources: [],
      );
    }

    final buffer = StringBuffer();
    for (var i = 0; i < results.length; i++) {
      final res = results[i];
      buffer.writeln("SOURCE ${i + 1}");
      buffer.writeln("File: ${res.fileName}");
      buffer.writeln("Page: ${res.pageNumber}");
      buffer.writeln("\nContent:\n${res.content}");
      buffer.writeln("\n---\n");
    }

    return RagContext(
      formattedContext: buffer.toString(),
      sources: results,
    );
  }
}
