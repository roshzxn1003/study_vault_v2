import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/ai/presentation/providers/chat_provider.dart';

class ChatExportResult {
  final String noteId;
  final String title;
  final String content;

  const ChatExportResult({
    required this.noteId,
    required this.title,
    required this.content,
  });
}

class ChatExportService {
  /// Compiles a [ChatState] session into a structured Markdown study guide
  /// and saves it into the local database `notes` table.
  /// Also triggers gamification study action tracking (`note_created`).
  static Future<ChatExportResult?> exportToStudyNote({
    required ChatState chatState,
    LocalDbService? localDbService,
  }) async {
    if (chatState.messages.isEmpty) return null;

    final firstUserPrompt = chatState.messages.firstWhere(
      (m) => m.isUser && m.content.isNotEmpty,
      orElse: () => ChatMessage(role: 'user', content: 'Study Session'),
    );
    final rawTitle = firstUserPrompt.content.length > 40
        ? '${firstUserPrompt.content.substring(0, 40)}...'
        : firstUserPrompt.content;
    final noteTitle = 'AI Study Guide: $rawTitle';

    final buffer = StringBuffer();
    buffer.writeln('# $noteTitle');
    buffer.writeln();
    buffer.writeln('*Exported from AI Study Assistant on ${DateTime.now().toLocal().toString().split('.').first}*');
    buffer.writeln('**Mode**: ${chatState.currentMode.toUpperCase()}');
    if (chatState.activeSubject != null) {
      buffer.writeln('**Subject**: ${chatState.activeSubject}');
    }
    if (chatState.activeMaterialTitle != null) {
      buffer.writeln('**Document Grounding**: ${chatState.activeMaterialTitle}');
    }
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    for (final msg in chatState.messages) {
      if (msg.isUser) {
        buffer.writeln('### ❓ Question / Topic');
        buffer.writeln(msg.content);
        buffer.writeln();
      } else if (msg.isAssistant && msg.content.isNotEmpty) {
        buffer.writeln('### 💡 AI Study Insight');
        buffer.writeln(msg.content);
        if (msg.sources != null && msg.sources!.isNotEmpty) {
          buffer.writeln();
          buffer.writeln('**Citations & References:**');
          for (final s in msg.sources!) {
            buffer.writeln('- *${s.fileName}* (Page ${s.pageNumber})');
          }
        }
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }
    }

    final dbService = localDbService ?? LocalDbService.instance;
    final db = await dbService.database;
    final now = DateTime.now().toIso8601String();
    final noteId = 'note_ai_export_${DateTime.now().millisecondsSinceEpoch}';
    final content = buffer.toString();

    await db.insert('notes', {
      'id': noteId,
      'user_id': 'guest',
      'title': noteTitle,
      'content': content,
      'created_at': now,
      'updated_at': now,
      'sync_status': 'synced'
    });

    await dbService.recordStudyAction('note_created');

    return ChatExportResult(
      noteId: noteId,
      title: noteTitle,
      content: content,
    );
  }
}
