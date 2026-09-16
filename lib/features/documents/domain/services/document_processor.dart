import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:study_vault/core/ai/embedding_service.dart';
import 'package:study_vault/features/documents/domain/entities/document_chunk.dart';
import 'package:study_vault/features/documents/data/repositories/document_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DocumentProcessor {
  final EmbeddingService _embeddingService;
  final DocumentRepository _documentRepo;
  final SupabaseClient _supabase = Supabase.instance.client;

  DocumentProcessor(this._embeddingService, this._documentRepo);

  Future<void> processDocument(String fileId) async {
    try {
      await _documentRepo.updateProcessingStatus(fileId, 'processing');

      // 1. Get file details
      final fileData = await _supabase
          .from('files')
          .select('storage_path')
          .eq('id', fileId)
          .single();

      final String storagePath = fileData['storage_path'];
      
      // 2. Download file from Supabase Storage
      final bytes = await _supabase.storage.from('study-files').download(storagePath);
      
      // 3. Extract Text (PDF)
      final extractedPages = await _extractPdfText(bytes);
      
      // 4. Clean and Chunk
      final chunks = await _chunkText(extractedPages, fileId);
      
      // 5. Generate Embeddings & Store
      final chunksWithEmbeddings = await _embedChunks(chunks);
      await _documentRepo.storeChunks(chunksWithEmbeddings);
      
      await _documentRepo.updateProcessingStatus(fileId, 'completed');
    } catch (e) {
      await _documentRepo.updateProcessingStatus(fileId, 'failed', error: e.toString());
      rethrow;
    }
  }

  Future<List<Map<String, String>>> _extractPdfText(List<int> bytes) async {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final List<Map<String, String>> pages = [];

    for (int i = 0; i < document.pages.count; i++) {
      final String text = PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
      pages.add({'page': (i + 1).toString(), 'text': text});
    }
    document.dispose();
    return pages;
  }

  Future<List<DocumentChunk>> _chunkText(List<Map<String, String>> pages, String fileId) async {
    final List<DocumentChunk> chunks = [];
    final user = _supabase.auth.currentUser;
    final userId = user?.id ?? 'guest';
    
    int chunkIndex = 0;
    String currentTextAccumulator = "";
    int currentPage = 1;

    for (var page in pages) {
      currentPage = int.parse(page['page']!);
      String pageText = _cleanText(page['text']!);
      
      while (pageText.isNotEmpty) {
        if (currentTextAccumulator.length < 800) {
          int take = (800 - currentTextAccumulator.length).clamp(0, pageText.length);
          currentTextAccumulator += pageText.substring(0, take);
          pageText = pageText.substring(take);
        } else {
          chunks.add(DocumentChunk(
            id: '',
            fileId: fileId,
            userId: userId,
            content: currentTextAccumulator,
            chunkIndex: chunkIndex++,
            pageNumber: currentPage,
            tokenCount: currentTextAccumulator.length ~/ 4,
            embedding: [],
            metadata: {'source': 'pdf'},
          ));
          
          currentTextAccumulator = currentTextAccumulator.substring(currentTextAccumulator.length > 100 ? currentTextAccumulator.length - 100 : 0);
        }
      }
    }

    if (currentTextAccumulator.isNotEmpty) {
      chunks.add(DocumentChunk(
        id: '',
        fileId: fileId,
        userId: userId,
        content: currentTextAccumulator,
        chunkIndex: chunkIndex,
        pageNumber: currentPage,
        tokenCount: currentTextAccumulator.length ~/ 4,
        embedding: [],
        metadata: {'source': 'pdf'},
      ));
    }

    return chunks;
  }

  Future<List<DocumentChunk>> _embedChunks(List<DocumentChunk> chunks) async {
    final texts = chunks.map((c) => c.content).toList();
    final embeddings = await _embeddingService.generateEmbeddings(texts);
    
    List<DocumentChunk> embeddedChunks = [];
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      embeddedChunks.add(
        DocumentChunk(
          id: chunk.id,
          fileId: chunk.fileId,
          userId: chunk.userId,
          content: chunk.content,
          chunkIndex: chunk.chunkIndex,
          pageNumber: chunk.pageNumber,
          tokenCount: chunk.tokenCount,
          embedding: embeddings[i],
          metadata: chunk.metadata,
        ),
      );
    }
    return embeddedChunks;
  }

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
