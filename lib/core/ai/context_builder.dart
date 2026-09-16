import 'package:study_vault/core/ai/semantic_search_service.dart';

class ContextBuilder {
  static String buildStructuredContext(List<SearchResult> results) {
    if (results.isEmpty) {
      return "No relevant context found in the user's study materials.";
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

    return buffer.toString();
  }
}
