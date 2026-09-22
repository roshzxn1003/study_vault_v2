import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:study_vault/core/ai/embedding_service.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/ai/retriever.dart';
import 'package:study_vault/core/database/local_db_service.dart';

/// Secure Hybrid Retriever combining semantic vector similarity and keyword search.
///
/// Multi-Tenant Security & Ownership Guarantees:
/// 1. Queries strictly verify that chunks belong to the authenticated `user_id` OR to a material
///    where the user has an active, unexpired, unrevoked share grant.
/// 2. Chunks from unauthorized users or private workspaces are strictly excluded before ranking.
class HybridRetriever implements Retriever {
  final EmbeddingService embeddingService;
  final LocalDbService _localDb;

  HybridRetriever({
    required this.embeddingService,
    LocalDbService? localDb,
  })  : _localDb = localDb ?? LocalDbService.instance;

  @override
  Future<List<RetrievedChunk>> retrieve(RetrievalQuery query) async {
    final cleanQuery = query.queryText.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      // 1. Resolve authorized material IDs for the active user
      final authorizedMaterials = await _resolveAuthorizedMaterials(query);
      if (authorizedMaterials.isEmpty) {
        return [];
      }

      final materialIdList = authorizedMaterials.keys.toList();

      // 2. Compute query embedding for semantic vector search
      List<double> queryVector = [];
      try {
        queryVector = await embeddingService.embed(
          AiEmbeddingInput(
            text: cleanQuery,
            taskType: AiEmbeddingTaskType.retrievalQuery,
          ),
        );
      } catch (e) {
        debugPrint('Query embedding generation error: $e');
      }

      // 3. Perform local vector retrieval & keyword retrieval on document_chunks
      final db = await _localDb.database;
      final placeholders = List.filled(materialIdList.length, '?').join(',');

      final chunkRows = await db.rawQuery(
        '''
        SELECT dc.*, m.title as material_title
        FROM document_chunks dc
        JOIN materials m ON dc.material_id = m.id
        WHERE dc.material_id IN ($placeholders)
        ORDER BY dc.page_number ASC, dc.chunk_index ASC
        ''',
        materialIdList,
      );

      final Map<String, RetrievedChunk> vectorMatches = {};
      final Map<String, RetrievedChunk> keywordMatches = {};

      // Tokenize query for keyword matching
      final queryTokens = cleanQuery
          .toLowerCase()
          .split(RegExp(r'[^\w]+'))
          .where((t) => t.length >= 3)
          .toSet();

      // Evaluate chunks
      for (final row in chunkRows) {
        final chunkId = row['id'] as String;
        final materialId = row['material_id'] as String;
        final title = (row['material_title'] as String?) ?? authorizedMaterials[materialId] ?? 'Material';
        final pageNum = (row['page_number'] as num?)?.toInt() ?? 1;
        final chunkIdx = (row['chunk_index'] as num?)?.toInt() ?? 0;
        final text = (row['text'] as String?) ?? '';
        final embStr = row['embedding'] as String?;

        // Semantic Vector Scoring
        if (queryVector.isNotEmpty && embStr != null && embStr.isNotEmpty) {
          try {
            final List<dynamic> rawList = jsonDecode(embStr);
            final List<double> chunkVector = rawList.map((e) => (e as num).toDouble()).toList();
            final sim = embeddingService.calculateCosineSimilarity(queryVector, chunkVector);
            if (sim >= query.minSimilarity) {
              vectorMatches[chunkId] = RetrievedChunk(
                chunkId: chunkId,
                materialId: materialId,
                materialTitle: title,
                pageNumber: pageNum,
                chunkIndex: chunkIdx,
                text: text,
                score: sim,
                matchType: 'semantic',
              );
            }
          } catch (e) {
            debugPrint('HybridRetriever: Error computing cosine similarity for chunk $chunkId: $e');
          }
        }

        // Keyword Term Frequency Scoring
        if (queryTokens.isNotEmpty && text.isNotEmpty) {
          final lowerText = text.toLowerCase();
          final lowerTitle = title.toLowerCase();
          int matchCount = 0;
          for (final token in queryTokens) {
            if (lowerText.contains(token)) matchCount += 2;
            if (lowerTitle.contains(token)) matchCount += 3;
          }
          if (matchCount > 0) {
            final keywordScore = (matchCount / (queryTokens.length * 2.5)).clamp(0.4, 0.95);
            keywordMatches[chunkId] = RetrievedChunk(
              chunkId: chunkId,
              materialId: materialId,
              materialTitle: title,
              pageNumber: pageNum,
              chunkIndex: chunkIdx,
              text: text,
              score: keywordScore,
              matchType: 'keyword',
            );
          }
        }
      }

      // If document_chunks had no hits, search material full text / notes as fallback
      if (vectorMatches.isEmpty && keywordMatches.isEmpty) {
        final fallbackHits = await _searchMaterialsContentFallback(query, authorizedMaterials, queryTokens);
        if (fallbackHits.isNotEmpty) {
          return fallbackHits.take(query.topK).toList();
        }
      }

      // 4. Hybrid Merge & Reciprocal Rank Fusion
      final allChunkIds = {...vectorMatches.keys, ...keywordMatches.keys};
      final scoredChunks = <RetrievedChunk>[];

      for (final id in allChunkIds) {
        final v = vectorMatches[id];
        final k = keywordMatches[id];

        final double vScore = v?.score ?? 0.0;
        final double kScore = k?.score ?? 0.0;

        double finalScore;
        String matchType;

        if (v != null && k != null) {
          finalScore = (vScore * 0.7) + (kScore * 0.3);
          matchType = 'hybrid';
        } else if (v != null) {
          finalScore = vScore;
          matchType = 'semantic';
        } else {
          finalScore = kScore;
          matchType = 'keyword';
        }

        final base = v ?? k!;
        scoredChunks.add(RetrievedChunk(
          chunkId: base.chunkId,
          materialId: base.materialId,
          materialTitle: base.materialTitle,
          pageNumber: base.pageNumber,
          chunkIndex: base.chunkIndex,
          text: base.text,
          score: finalScore,
          matchType: matchType,
          metadata: base.metadata,
        ));
      }

      // 5. Rank by score descending and deduplicate redundant chunks
      scoredChunks.sort((a, b) => b.score.compareTo(a.score));
      return scoredChunks.take(query.topK).toList();
    } catch (e) {
      debugPrint('Hybrid retrieval failed: $e');
      return [];
    }
  }

  /// Securely discovers all material IDs that the current user is authorized to read.
  Future<Map<String, String>> _resolveAuthorizedMaterials(RetrievalQuery query) async {
    final db = await _localDb.database;
    final Map<String, String> materials = {}; // materialId -> title

    // 1. User's own active materials
    final whereClauses = <String>['user_id = ?', 'is_archived = 0'];
    final whereArgs = <dynamic>[query.userId];

    if (query.materialId != null && query.materialId!.isNotEmpty) {
      whereClauses.add('id = ?');
      whereArgs.add(query.materialId);
    }
    if (query.subjectId != null && query.subjectId!.isNotEmpty) {
      whereClauses.add('subject_id = ?');
      whereArgs.add(query.subjectId);
    }
    if (query.workspaceId != null && query.workspaceId!.isNotEmpty) {
      whereClauses.add('workspace_id = ?');
      whereArgs.add(query.workspaceId);
    }
    if (query.academicPeriodId != null && query.academicPeriodId!.isNotEmpty) {
      whereClauses.add('academic_period_id = ?');
      whereArgs.add(query.academicPeriodId);
    }

    final ownRows = await db.query(
      'materials',
      columns: ['id', 'title'],
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
    );

    for (final r in ownRows) {
      materials[r['id'] as String] = (r['title'] as String?) ?? 'Study Material';
    }

    // 2. Active shared materials (if includeShared is true and specific material is not isolated)
    if (query.includeShared && query.materialId == null) {
      try {
        final shareRows = await db.rawQuery(
          '''
          SELECT s.resource_id, m.title
          FROM shares s
          JOIN materials m ON s.resource_id = m.id
          WHERE s.recipient_id = ?
            AND s.status = 'active'
            AND s.revoked_at IS NULL
            AND (s.expires_at IS NULL OR s.expires_at > datetime('now'))
          ''',
          [query.userId],
        );

        for (final r in shareRows) {
          materials[r['resource_id'] as String] = (r['title'] as String?) ?? 'Shared Material';
        }
      } catch (e) {
        debugPrint('HybridRetriever: Error querying shared materials for user ${query.userId}: $e');
      }
    }

    return materials;
  }

  /// Fallback search into raw material text/notes when document_chunks have not been generated.
  Future<List<RetrievedChunk>> _searchMaterialsContentFallback(
    RetrievalQuery query,
    Map<String, String> authorizedMaterials,
    Set<String> queryTokens,
  ) async {
    final db = await _localDb.database;
    final idList = authorizedMaterials.keys.toList();
    final placeholders = List.filled(idList.length, '?').join(',');

    final rows = await db.rawQuery(
      '''
      SELECT id, title, content, description
      FROM materials
      WHERE id IN ($placeholders)
      ''',
      idList,
    );

    final results = <RetrievedChunk>[];

    for (final row in rows) {
      final id = row['id'] as String;
      final title = (row['title'] as String?) ?? 'Note';
      final content = (row['content'] as String?) ?? (row['description'] as String?) ?? '';
      if (content.trim().isEmpty) continue;

      int matches = 0;
      final lowerContent = content.toLowerCase();
      final lowerTitle = title.toLowerCase();

      for (final t in queryTokens) {
        if (lowerContent.contains(t)) matches += 2;
        if (lowerTitle.contains(t)) matches += 3;
      }

      if (matches > 0 || queryTokens.isEmpty) {
        final score = queryTokens.isEmpty
            ? 0.7
            : (matches / (queryTokens.length * 2.0)).clamp(0.4, 0.9);

        results.add(RetrievedChunk(
          chunkId: 'content_$id',
          materialId: id,
          materialTitle: title,
          pageNumber: 1,
          chunkIndex: 0,
          text: content.length > 800 ? content.substring(0, 800) : content,
          score: score,
          matchType: 'keyword',
        ));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }
}
