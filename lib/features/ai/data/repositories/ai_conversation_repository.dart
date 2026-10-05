import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/ai/presentation/providers/chat_provider.dart';

class AiConversationItem {
  final String id;
  final String userId;
  final String? workspaceId;
  final String? subjectId;
  final String? materialId;
  final String title;
  final String mode;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiConversationItem({
    required this.id,
    required this.userId,
    this.workspaceId,
    this.subjectId,
    this.materialId,
    required this.title,
    required this.mode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiConversationItem.fromMap(Map<String, dynamic> map) {
    return AiConversationItem(
      id: map['id'] as String,
      userId: map['user_id'] as String? ?? 'guest',
      workspaceId: map['workspace_id'] as String?,
      subjectId: map['subject_id'] as String?,
      materialId: map['material_id'] as String?,
      title: (map['title'] as String?) ?? 'Study Session',
      mode: (map['mode'] as String?) ?? 'ask',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'workspace_id': workspaceId,
        'subject_id': subjectId,
        'material_id': materialId,
        'title': title,
        'mode': mode,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

final aiConversationRepositoryProvider = Provider<AiConversationRepository>((ref) {
  return AiConversationRepository();
});

class AiConversationRepository {
  final LocalDbService _localDb;

  AiConversationRepository({LocalDbService? localDb})
      : _localDb = localDb ?? LocalDbService.instance;

  String get _currentUserId {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) return user.id;
    } catch (_) {}
    return 'guest';
  }

  /// Creates a new persistent conversation session.
  Future<AiConversationItem> createConversation({
    required String title,
    String? workspaceId,
    String? subjectId,
    String? materialId,
    String mode = 'ask',
    String? userId,
  }) async {
    final db = await _localDb.database;
    final now = DateTime.now();
    final item = AiConversationItem(
      id: 'conv_${now.microsecondsSinceEpoch}',
      userId: userId ?? _currentUserId,
      workspaceId: workspaceId,
      subjectId: subjectId,
      materialId: materialId,
      title: title.trim().isEmpty ? 'New Study Chat' : title.trim(),
      mode: mode,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('ai_conversations', item.toMap());
    return item;
  }

  /// Lists all conversations belonging to the user, sorted most recent first.
  Future<List<AiConversationItem>> listConversations({String? userId}) async {
    final db = await _localDb.database;
    final uId = userId ?? _currentUserId;

    final rows = await db.query(
      'ai_conversations',
      where: 'user_id = ?',
      whereArgs: [uId],
      orderBy: 'updated_at DESC',
    );

    return rows.map((r) => AiConversationItem.fromMap(r)).toList();
  }

  /// Retrieves all messages for a given conversation.
  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'ai_messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );

    return rows.map((r) {
      List<AiSource>? sources;
      final rawSources = r['sources'] as String?;
      if (rawSources != null && rawSources.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawSources);
          if (decoded is List) {
            sources = decoded.map((s) => AiSource.fromMap(Map<String, dynamic>.from(s))).toList();
          }
        } catch (e) {
          debugPrint('Error decoding sources for message ${r['id']}: $e');
        }
      }

      return ChatMessage(
        id: r['id'] as String,
        role: r['role'] as String,
        content: r['content'] as String,
        sources: sources,
        createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      );
    }).toList();
  }

  /// Persists an individual message to the database and touches conversation updated_at.
  Future<void> saveMessage(
    String conversationId,
    ChatMessage message, {
    String? userId,
  }) async {
    final db = await _localDb.database;
    final now = DateTime.now().toIso8601String();
    final uId = userId ?? _currentUserId;

    String? encodedSources;
    if (message.sources != null && message.sources!.isNotEmpty) {
      encodedSources = jsonEncode(message.sources!.map((s) => s.toMap()).toList());
    }

    await db.insert('ai_messages', {
      'id': message.id,
      'conversation_id': conversationId,
      'user_id': uId,
      'role': message.role,
      'content': message.content,
      'sources': encodedSources,
      'created_at': message.createdAt.toIso8601String(),
    });

    await db.update(
      'ai_conversations',
      {'updated_at': now},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  /// Updates conversation title.
  Future<void> renameConversation(String conversationId, String newTitle) async {
    final db = await _localDb.database;
    await db.update(
      'ai_conversations',
      {'title': newTitle.trim(), 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  /// Deletes conversation and all child messages safely.
  Future<void> deleteConversation(String conversationId) async {
    final db = await _localDb.database;
    await db.transaction((txn) async {
      await txn.delete('ai_messages', where: 'conversation_id = ?', whereArgs: [conversationId]);
      await txn.delete('ai_conversations', where: 'id = ?', whereArgs: [conversationId]);
    });
  }
}
