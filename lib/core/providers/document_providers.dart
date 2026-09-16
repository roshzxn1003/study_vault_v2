import 'package:study_vault/core/providers/ai_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/features/documents/data/repositories/document_repository.dart';
import 'package:study_vault/features/documents/domain/services/document_processor.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  final embeddingService = ref.watch(embeddingServiceProvider);
  return DocumentRepository(embeddingService);
});

final documentProcessorProvider = Provider<DocumentProcessor>((ref) {
  final embeddingService = ref.watch(embeddingServiceProvider);
  final documentRepo = ref.watch(documentRepositoryProvider);
  return DocumentProcessor(embeddingService, documentRepo);
});
