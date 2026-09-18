import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/ai/llm_service.dart';
import 'package:study_vault/core/providers/ai_providers.dart';
import 'package:study_vault/core/database/local_db_service.dart';

class ChatMessage {
  final String id;
  final String role;
  final String content;
  final List<AiSource>? sources;
  final DateTime createdAt;
  final bool isPartial;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    this.sources,
    DateTime? createdAt,
    this.isPartial = false,
  })  : id = id ?? 'msg_${DateTime.now().microsecondsSinceEpoch}',
        createdAt = createdAt ?? DateTime.now();

  ChatMessage copyWith({
    String? content,
    List<AiSource>? sources,
    bool? isPartial,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      sources: sources ?? this.sources,
      createdAt: createdAt,
      isPartial: isPartial ?? this.isPartial,
    );
  }
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final bool isThinking;
  final String currentMode;
  final String? activeSubject;
  final String? activeWorkspace;
  final String? activeMaterialId;
  final String? activeMaterialTitle;
  final String? errorMessage;
  final String? lastUserPrompt;

  ChatState({
    this.messages = const [],
    this.isGenerating = false,
    this.isThinking = false,
    this.currentMode = 'ask',
    this.activeSubject,
    this.activeWorkspace,
    this.activeMaterialId,
    this.activeMaterialTitle,
    this.errorMessage,
    this.lastUserPrompt,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    bool? isThinking,
    String? currentMode,
    String? activeSubject,
    String? activeWorkspace,
    String? activeMaterialId,
    String? activeMaterialTitle,
    String? errorMessage,
    bool clearError = false,
    String? lastUserPrompt,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      isThinking: isThinking ?? this.isThinking,
      currentMode: currentMode ?? this.currentMode,
      activeSubject: activeSubject ?? this.activeSubject,
      activeWorkspace: activeWorkspace ?? this.activeWorkspace,
      activeMaterialId: activeMaterialId ?? this.activeMaterialId,
      activeMaterialTitle: activeMaterialTitle ?? this.activeMaterialTitle,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastUserPrompt: lastUserPrompt ?? this.lastUserPrompt,
    );
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref ref;
  AiCancelToken? _currentCancelToken;
  StreamSubscription<AiChunk>? _currentStreamSub;

  ChatNotifier(this.ref) : super(ChatState());

  void setContext({
    String? subject,
    String? workspace,
    String? materialId,
    String? materialTitle,
  }) {
    state = state.copyWith(
      activeSubject: subject,
      activeWorkspace: workspace,
      activeMaterialId: materialId,
      activeMaterialTitle: materialTitle,
    );
  }

  void setMode(String mode) {
    state = state.copyWith(currentMode: mode);
  }

  /// Sends a message and streams the AI response with token buffering.
  Future<void> sendMessage(String text, {String? imagePath}) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    // Cancel any ongoing generation
    stopGeneration();

    final userMsg = ChatMessage(
      role: 'user',
      content: clean,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isGenerating: true,
      isThinking: true,
      clearError: true,
      lastUserPrompt: clean,
    );

    final cancelToken = AiCancelToken();
    _currentCancelToken = cancelToken;

    final attachments = <AiAttachment>[];
    if (imagePath != null && imagePath.isNotEmpty) {
      attachments.add(AiAttachment(
        filePath: imagePath,
        mimeType: imagePath.endsWith('.png') ? 'image/png' : 'image/jpeg',
      ));
    }

    AiMode mode = AiMode.documentQa;
    if (state.currentMode == 'tutor') mode = AiMode.tutor;
    if (state.currentMode == 'summarize') mode = AiMode.summary;
    if (state.currentMode == 'quiz') mode = AiMode.quiz;
    if (state.currentMode == 'explain') mode = AiMode.explain;

    final aiMsgId = 'ai_${DateTime.now().microsecondsSinceEpoch}';
    final aiPlaceholder = ChatMessage(
      id: aiMsgId,
      role: 'assistant',
      content: '',
      isPartial: true,
    );

    state = state.copyWith(
      messages: [...state.messages, aiPlaceholder],
    );

    try {
      final orchestrator = ref.read(aiOrchestratorProvider);
      final stream = orchestrator.askStream(
        AiRequest(
          mode: mode,
          userMessage: clean,
          attachments: attachments,
          workspaceContext: state.activeWorkspace,
          subjectContext: state.activeSubject,
          academicContext: state.activeSubject != null ? 'Course: ${state.activeSubject}' : null,
          conversationHistory: state.messages.take(6).map((m) => AiChatMessage(
                role: m.role,
                content: m.content,
              )).toList(),
        ),
        cancelToken: cancelToken,
      );

      String currentAccumulated = '';
      List<AiSource>? finalSources;

      _currentStreamSub = stream.listen(
        (chunk) {
          if (cancelToken.isCancelled) return;

          currentAccumulated = chunk.accumulatedText;
          if (chunk.sources != null && chunk.sources!.isNotEmpty) {
            finalSources = chunk.sources;
          }

          // Update message in state
          final updated = state.messages.map((m) {
            if (m.id == aiMsgId) {
              return m.copyWith(
                content: currentAccumulated,
                sources: finalSources,
                isPartial: !chunk.isDone,
              );
            }
            return m;
          }).toList();

          state = state.copyWith(
            messages: updated,
            isThinking: false,
          );
        },
        onDone: () {
          _finalizeMessage(aiMsgId, currentAccumulated, finalSources);
        },
        onError: (error) {
          _handleStreamError(aiMsgId, error);
        },
      );
    } catch (e) {
      _handleStreamError(aiMsgId, e);
    }
  }

  /// Cancels active generation and preserves partial response safely.
  void stopGeneration() {
    if (_currentCancelToken != null && !_currentCancelToken!.isCancelled) {
      _currentCancelToken!.cancel();
    }
    _currentStreamSub?.cancel();
    _currentStreamSub = null;

    if (state.isGenerating) {
      // Mark last partial message as non-partial
      final updated = state.messages.map((m) {
        if (m.isPartial) {
          final content = m.content.isEmpty
              ? 'Generation stopped by user.'
              : '${m.content}\n\n*[Generation stopped]*';
          return m.copyWith(content: content, isPartial: false);
        }
        return m;
      }).toList();

      state = state.copyWith(
        messages: updated,
        isGenerating: false,
        isThinking: false,
      );
    }
  }

  /// Retries generating the response for the last user prompt.
  void retryLast() {
    if (state.lastUserPrompt != null && state.lastUserPrompt!.isNotEmpty) {
      // Remove last assistant error or incomplete message if present
      if (state.messages.isNotEmpty && state.messages.last.isAssistant) {
        final msgs = List<ChatMessage>.from(state.messages)..removeLast();
        state = state.copyWith(messages: msgs);
      }
      sendMessage(state.lastUserPrompt!);
    }
  }

  void _finalizeMessage(String msgId, String content, List<AiSource>? sources) {
    _currentCancelToken = null;
    _currentStreamSub = null;

    final updated = state.messages.map((m) {
      if (m.id == msgId) {
        return m.copyWith(
          content: content.isEmpty ? "I couldn't generate a response. Please try again." : content,
          sources: sources,
          isPartial: false,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(
      messages: updated,
      isGenerating: false,
      isThinking: false,
    );

    _persistLastMessage(msgId, content, sources);
  }

  void _handleStreamError(String msgId, Object error) {
    _currentCancelToken = null;
    _currentStreamSub = null;

    String errorText = "AI is temporarily unavailable. Your study materials remain accessible.";
    if (error is AiServiceException) {
      errorText = error.message;
    } else {
      errorText = error.toString();
    }

    final updated = state.messages.map((m) {
      if (m.id == msgId) {
        return m.copyWith(
          content: "⚠️ **Notice**: $errorText",
          isPartial: false,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(
      messages: updated,
      isGenerating: false,
      isThinking: false,
      errorMessage: errorText,
    );
  }

  Future<void> _persistLastMessage(String msgId, String content, List<AiSource>? sources) async {
    try {
      final db = await LocalDbService.instance.database;
      await db.insert('ai_messages', {
        'id': msgId,
        'conversation_id': 'default_session',
        'user_id': 'guest',
        'role': 'assistant',
        'content': content,
        'sources': sources?.map((s) => s.toMap()).toString(),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  void clearChat() {
    stopGeneration();
    state = ChatState(
      activeSubject: state.activeSubject,
      activeWorkspace: state.activeWorkspace,
      activeMaterialId: state.activeMaterialId,
      activeMaterialTitle: state.activeMaterialTitle,
      currentMode: state.currentMode,
    );
  }

  @override
  void dispose() {
    stopGeneration();
    super.dispose();
  }
}
