import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/ai/embedding_service.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/documents/domain/entities/document_chunk.dart';

/// Offline-First Document Repository storing chunks and indexing status
/// in local SQLite, with optional cloud synchronization to Supabase pgvector.
class DocumentRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalDbService _localDb;
  final EmbeddingService _embeddingService;

  EmbeddingService get embeddingService => _embeddingService;

  DocumentRepository(this._embeddingService, {LocalDbService? localDb})
      : _localDb = localDb ?? LocalDbService.instance;

  /// Updates indexing state in local SQLite and attempts remote update if online.
  Future<void> updateProcessingStatus(String materialId, String status, {String? error}) async {
    final now = DateTime.now().toIso8601String();
    try {
      final db = await _localDb.database;
      await db.update(
        'materials',
        {
          'indexing_status': status,
          'indexing_error': error,
          'indexed_at': now,
        },
        where: 'id = ?',
        whereArgs: [materialId],
      );
    } catch (e) {
      debugPrint('Error updating local material indexing status: $e');
    }

    // Attempt remote Supabase status update if authenticated
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('document_processing').upsert({
          'file_id': materialId,
          'user_id': user.id,
          'status': status,
          'error_message': error,
          'updated_at': now,
        });
      }
    } catch (e) {
      debugPrint('Document processing cloud status update note: $e');
    }
  }

  /// Stores document chunks safely in local SQLite (replacing existing chunks)
  /// and syncs to Supabase when connected.
  Future<void> storeChunks(List<DocumentChunk> chunks) async {
    if (chunks.isEmpty) return;
    final db = await _localDb.database;
    final materialId = chunks.first.materialId;

    await db.transaction((txn) async {
      // Clean previous chunks for this document to prevent stale duplication
      await txn.delete('document_chunks', where: 'material_id = ?', whereArgs: [materialId]);

      for (final chunk in chunks) {
        await txn.insert('document_chunks', {
          'id': chunk.id.isNotEmpty ? chunk.id : 'chunk_${DateTime.now().microsecondsSinceEpoch}_${chunk.chunkIndex}',
          'material_id': chunk.materialId,
          'user_id': chunk.userId,
          'workspace_id': chunk.workspaceId,
          'academic_period_id': chunk.academicPeriodId,
          'subject_id': chunk.subjectId,
          'folder_id': chunk.folderId,
          'page_number': chunk.pageNumber,
          'chunk_index': chunk.chunkIndex,
          'text': chunk.content,
          'embedding': jsonEncode(chunk.embedding),
          'token_count': chunk.tokenCount,
          'metadata': jsonEncode(chunk.metadata),
          'created_at': chunk.createdAt.toIso8601String(),
          'updated_at': chunk.updatedAt.toIso8601String(),
        });
      }
    });

    // Cloud pgvector sync if authenticated
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final List<Map<String, dynamic>> chunkMaps = chunks.map((c) => c.toMap()).toList();
        await _supabase.from('document_chunks').insert(chunkMaps);
      }
    } catch (e) {
      debugPrint('Cloud document_chunks sync skipped or failed (offline-first preserved): $e');
    }
  }

  /// Removes all chunks associated with a material.
  Future<void> clearChunks(String materialId) async {
    final db = await _localDb.database;
    await db.delete('document_chunks', where: 'material_id = ?', whereArgs: [materialId]);

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('document_chunks').delete().eq('file_id', materialId);
      }
    } catch (e) {
      debugPrint('Cloud document_chunks delete note: $e');
    }
  }

  /// Gets current indexing status from local SQLite.
  Future<String?> getProcessingStatus(String materialId) async {
    try {
      final db = await _localDb.database;
      final rows = await db.query(
        'materials',
        columns: ['indexing_status'],
        where: 'id = ?',
        whereArgs: [materialId],
      );
      if (rows.isNotEmpty) {
        return rows.first['indexing_status'] as String?;
      }
    } catch (e) {
      debugPrint('getProcessingStatus localDb error: $e');
    }
    return 'NOT_INDEXED';
  }

  /// Retrieves all local chunks for a material.
  Future<List<DocumentChunk>> getChunks(String materialId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'document_chunks',
      where: 'material_id = ?',
      whereArgs: [materialId],
      orderBy: 'page_number ASC, chunk_index ASC',
    );
    return rows.map((r) => DocumentChunk.fromMap(r)).toList();
  }
}
