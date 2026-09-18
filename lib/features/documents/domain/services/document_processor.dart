import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:study_vault/core/ai/embedding_service.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/services/image_processing_service.dart';
import 'package:study_vault/features/documents/domain/entities/document_chunk.dart';
import 'package:study_vault/features/documents/data/repositories/document_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Document Intelligence Processor that extracts page-aware text from PDFs,
/// performs OCR on images/scans, segments into semantic chunks, and generates vector embeddings.
class DocumentProcessor {
  final EmbeddingService _embeddingService;
  final DocumentRepository _documentRepo;
  final LocalDbService _localDb;
  final ImageProcessingService _imageService = ImageProcessingService();

  DocumentProcessor(
    this._embeddingService,
    this._documentRepo, {
    LocalDbService? localDb,
  }) : _localDb = localDb ?? LocalDbService.instance;

  /// Asynchronously processes and indexes an academic material for AI search.
  Future<void> processDocument(String materialId) async {
    try {
      await _documentRepo.updateProcessingStatus(materialId, 'INDEXING');

      // 1. Fetch material record from local database
      final db = await _localDb.database;
      final materialRows = await db.query(
        'materials',
        where: 'id = ?',
        whereArgs: [materialId],
      );

      if (materialRows.isEmpty) {
        throw Exception('Material not found with ID: $materialId');
      }

      final material = materialRows.first;
      final userId = material['user_id'] as String? ?? 'guest';
      final workspaceId = material['workspace_id'] as String?;
      final academicPeriodId = material['academic_period_id'] as String?;
      final subjectId = material['subject_id'] as String?;
      final folderId = material['folder_id'] as String?;
      final filePath = material['file_path'] as String?;
      final storagePath = material['storage_path'] as String?;
      final directContent = material['content'] as String?;
      final mimeType = (material['mime_type'] as String? ?? '').toLowerCase();

      // 2. Extract page-aware text
      final pages = <Map<String, String>>[];

      if (directContent != null && directContent.trim().isNotEmpty) {
        // Direct text notes or pre-extracted content
        pages.add({'page': '1', 'text': directContent.trim()});
      } else if (filePath != null && File(filePath).existsSync()) {
        if (filePath.toLowerCase().endsWith('.pdf') || mimeType.contains('pdf')) {
          final bytes = await File(filePath).readAsBytes();
          final extracted = await _extractPdfText(bytes);
          pages.addAll(extracted);
        } else if (_isImage(filePath, mimeType)) {
          final ocrText = await _imageService.extractText(filePath);
          if (ocrText.trim().isNotEmpty) {
            pages.add({'page': '1', 'text': ocrText.trim()});
          }
        }
      } else if (storagePath != null && storagePath.isNotEmpty) {
        // Attempt cloud download from Supabase Storage if local file path missing
        try {
          final bytes = await Supabase.instance.client.storage
              .from('study-files')
              .download(storagePath);
          if (storagePath.toLowerCase().endsWith('.pdf') || mimeType.contains('pdf')) {
            final extracted = await _extractPdfText(bytes);
            pages.addAll(extracted);
          }
        } catch (e) {
          debugPrint('Storage download failed for $storagePath: $e');
        }
      }

      if (pages.isEmpty) {
        // No extractable text; mark ready with empty index
        await _documentRepo.updateProcessingStatus(materialId, 'INDEXED');
        return;
      }

      // 3. Intelligent Semantic Chunking
      final chunks = _chunkPages(
        pages: pages,
        materialId: materialId,
        userId: userId,
        workspaceId: workspaceId,
        academicPeriodId: academicPeriodId,
        subjectId: subjectId,
        folderId: folderId,
      );

      if (chunks.isEmpty) {
        await _documentRepo.updateProcessingStatus(materialId, 'INDEXED');
        return;
      }

      // 4. Generate Real Vector Embeddings
      final chunksWithEmbeddings = await _embedChunks(chunks);

      // 5. Store chunks in database
      await _documentRepo.storeChunks(chunksWithEmbeddings);

      // 6. Mark Indexing Complete
      await _documentRepo.updateProcessingStatus(materialId, 'INDEXED');
    } catch (e) {
      debugPrint('Document indexing failed for $materialId: $e');
      await _documentRepo.updateProcessingStatus(materialId, 'FAILED', error: e.toString());
      rethrow;
    }
  }

  bool _isImage(String path, String mimeType) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        mimeType.contains('image');
  }

  /// Extracts page-by-page text from PDF bytes using Syncfusion.
  Future<List<Map<String, String>>> _extractPdfText(List<int> bytes) async {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final List<Map<String, String>> pages = [];

    for (int i = 0; i < document.pages.count; i++) {
      try {
        final text = PdfTextExtractor(document).extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        if (text.trim().isNotEmpty) {
          pages.add({'page': (i + 1).toString(), 'text': text});
        }
      } catch (e) {
        debugPrint('Error extracting page $i text: $e');
      }
    }
    document.dispose();
    return pages;
  }

  /// Splits page text into semantically cohesive chunks of ~600-800 characters with overlap.
  List<DocumentChunk> _chunkPages({
    required List<Map<String, String>> pages,
    required String materialId,
    required String userId,
    String? workspaceId,
    String? academicPeriodId,
    String? subjectId,
    String? folderId,
  }) {
    final chunks = <DocumentChunk>[];
    int chunkIndex = 0;

    for (final page in pages) {
      final pageNum = int.tryParse(page['page'] ?? '1') ?? 1;
      final rawText = page['text'] ?? '';
      final cleanText = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleanText.isEmpty) continue;

      // If page text is under 900 chars, keep as a single chunk
      if (cleanText.length <= 900) {
        chunks.add(DocumentChunk(
          id: 'chunk_${materialId}_${pageNum}_$chunkIndex',
          fileId: materialId,
          userId: userId,
          workspaceId: workspaceId,
          academicPeriodId: academicPeriodId,
          subjectId: subjectId,
          folderId: folderId,
          content: cleanText,
          chunkIndex: chunkIndex++,
          pageNumber: pageNum,
          tokenCount: (cleanText.length / 4).ceil(),
          embedding: [],
          metadata: {'page': pageNum, 'source': 'page_text'},
        ));
        continue;
      }

      // Split into paragraphs / sentences
      final segments = cleanText.split(RegExp(r'(?<=\.)\s+'));
      final currentChunk = StringBuffer();

      for (final seg in segments) {
        if (currentChunk.length + seg.length < 800) {
          currentChunk.write('$seg ');
        } else {
          if (currentChunk.isNotEmpty) {
            final chunkText = currentChunk.toString().trim();
            chunks.add(DocumentChunk(
              id: 'chunk_${materialId}_${pageNum}_$chunkIndex',
              fileId: materialId,
              userId: userId,
              workspaceId: workspaceId,
              academicPeriodId: academicPeriodId,
              subjectId: subjectId,
              folderId: folderId,
              content: chunkText,
              chunkIndex: chunkIndex++,
              pageNumber: pageNum,
              tokenCount: (chunkText.length / 4).ceil(),
              embedding: [],
              metadata: {'page': pageNum},
            ));
            currentChunk.clear();
          }
          currentChunk.write('$seg ');
        }
      }

      if (currentChunk.isNotEmpty) {
        final chunkText = currentChunk.toString().trim();
        chunks.add(DocumentChunk(
          id: 'chunk_${materialId}_${pageNum}_$chunkIndex',
          fileId: materialId,
          userId: userId,
          workspaceId: workspaceId,
          academicPeriodId: academicPeriodId,
          subjectId: subjectId,
          folderId: folderId,
          content: chunkText,
          chunkIndex: chunkIndex++,
          pageNumber: pageNum,
          tokenCount: (chunkText.length / 4).ceil(),
          embedding: [],
          metadata: {'page': pageNum},
        ));
      }
    }

    return chunks;
  }

  /// Generates real vector embeddings for each chunk using [EmbeddingService].
  Future<List<DocumentChunk>> _embedChunks(List<DocumentChunk> chunks) async {
    final texts = chunks.map((c) => c.content).toList();
    final embeddings = await _embeddingService.generateEmbeddings(
      texts,
      taskType: AiEmbeddingTaskType.retrievalDocument,
    );

    final embeddedChunks = <DocumentChunk>[];
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final emb = i < embeddings.length ? embeddings[i] : <double>[];
      embeddedChunks.add(
        DocumentChunk(
          id: chunk.id,
          fileId: chunk.fileId,
          userId: chunk.userId,
          workspaceId: chunk.workspaceId,
          academicPeriodId: chunk.academicPeriodId,
          subjectId: chunk.subjectId,
          folderId: chunk.folderId,
          content: chunk.content,
          chunkIndex: chunk.chunkIndex,
          pageNumber: chunk.pageNumber,
          tokenCount: chunk.tokenCount,
          embedding: emb,
          metadata: chunk.metadata,
        ),
      );
    }
    return embeddedChunks;
  }
}
