import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/ai/llm_service.dart';
import 'package:study_vault/core/providers/ai_providers.dart';
import 'package:study_vault/features/ai/data/repositories/ai_conversation_repository.dart';

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
  final String? conversationId;
  final String activeModel;
  final String? statusMessage;
  final List<AiConversationItem> conversations;
  final bool isLoadingHistory;

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
    this.conversationId,
    this.activeModel = 'gemini-1.5-flash',
    this.statusMessage,
    this.conversations = const [],
    this.isLoadingHistory = false,
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
    String? conversationId,
    bool clearConversation = false,
    String? activeModel,
    String? statusMessage,
    bool clearStatus = false,
    List<AiConversationItem>? conversations,
    bool? isLoadingHistory,
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
      conversationId: clearConversation ? null : (conversationId ?? this.conversationId),
      activeModel: activeModel ?? this.activeModel,
      statusMessage: clearStatus ? null : (statusMessage ?? this.statusMessage),
      conversations: conversations ?? this.conversations,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
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
  late final AiConversationRepository _conversationRepo;

  ChatNotifier(this.ref) : super(ChatState()) {
    _conversationRepo = ref.read(aiConversationRepositoryProvider);
    loadHistory();
  }

  /// Loads list of user conversations for drawer history.
  Future<void> loadHistory() async {
    try {
      state = state.copyWith(isLoadingHistory: true);
      final list = await _conversationRepo.listConversations();
      if (!mounted) return;
      state = state.copyWith(conversations: list, isLoadingHistory: false);
    } catch (e) {
      debugPrint('ChatNotifier: loadHistory failed: $e');
      if (mounted) {
        state = state.copyWith(isLoadingHistory: false);
      }
    }
  }

  /// Sets context filters for workspace/subject.
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

  /// Attaches or clears active material grounding.
  void setMaterial(String? materialId, String? materialTitle) {
    state = state.copyWith(
      activeMaterialId: materialId,
      activeMaterialTitle: materialTitle,
    );
  }

  /// Clears active material grounding (scopes queries to all materials).
  void clearMaterial() {
    state = ChatState(
      messages: state.messages,
      isGenerating: state.isGenerating,
      isThinking: state.isThinking,
      currentMode: state.currentMode,
      activeSubject: state.activeSubject,
      activeWorkspace: state.activeWorkspace,
      activeMaterialId: null,
      activeMaterialTitle: null,
      errorMessage: state.errorMessage,
      lastUserPrompt: state.lastUserPrompt,
      conversationId: state.conversationId,
      activeModel: state.activeModel,
      conversations: state.conversations,
      isLoadingHistory: state.isLoadingHistory,
    );
  }

  /// Switches active model ('gemini-1.5-flash', 'gemini-1.5-pro', etc.).
  void setModel(String model) {
    state = state.copyWith(activeModel: model);
  }

  /// Sets interaction mode ('ask', 'tutor', 'summarize', 'quiz', 'explain').
  void setMode(String mode) {
    state = state.copyWith(currentMode: mode);
  }

  /// Starts a fresh ChatGPT-style conversation session.
  void startNewChat({
    String? subject,
    String? workspace,
    String? materialId,
    String? materialTitle,
  }) {
    stopGeneration();
    state = ChatState(
      conversationId: null,
      messages: const [],
      activeSubject: subject ?? state.activeSubject,
      activeWorkspace: workspace ?? state.activeWorkspace,
      activeMaterialId: materialId ?? state.activeMaterialId,
      activeMaterialTitle: materialTitle ?? state.activeMaterialTitle,
      activeModel: state.activeModel,
      currentMode: state.currentMode,
      conversations: state.conversations,
    );
  }

  /// Loads an existing conversation session from the database.
  Future<void> loadConversation(String convId) async {
    if (state.conversationId == convId) return;
    stopGeneration();

    try {
      final msgs = await _conversationRepo.loadMessages(convId);
      if (!mounted) return;
      final conv = state.conversations.where((c) => c.id == convId).firstOrNull;

      state = state.copyWith(
        conversationId: convId,
        messages: msgs,
        activeMaterialId: conv?.materialId,
        currentMode: conv?.mode ?? state.currentMode,
        clearError: true,
      );
    } catch (e) {
      debugPrint('ChatNotifier: loadConversation failed: $e');
    }
  }

  /// Deletes a conversation session from the database.
  Future<void> deleteConversation(String convId) async {
    try {
      await _conversationRepo.deleteConversation(convId);
      if (state.conversationId == convId) {
        startNewChat();
      }
      await loadHistory();
    } catch (e) {
      debugPrint('ChatNotifier: deleteConversation failed: $e');
    }
  }

  /// Renames a conversation session in the database.
  Future<void> renameConversation(String convId, String newTitle) async {
    try {
      await _conversationRepo.renameConversation(convId, newTitle);
      await loadHistory();
    } catch (e) {
      debugPrint('ChatNotifier: renameConversation failed: $e');
    }
  }

  /// Sends a message and streams the AI response with token buffering.
  Future<void> sendMessage(String text, {String? imagePath}) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    // Cancel any ongoing generation
    stopGeneration();

    // Auto-create persistent conversation if not currently in a session
    String? convId = state.conversationId;
    if (convId == null) {
      try {
        final title = clean.length > 36 ? '${clean.substring(0, 36)}...' : clean;
        final newConv = await _conversationRepo.createConversation(
          title: title,
          workspaceId: state.activeWorkspace,
          subjectId: state.activeSubject,
          materialId: state.activeMaterialId,
          mode: state.currentMode,
        );
        convId = newConv.id;
        state = state.copyWith(conversationId: convId);
        loadHistory();
      } catch (e) {
        debugPrint('ChatNotifier: auto-create conversation failed: $e');
      }
    }

    final userMsg = ChatMessage(
      role: 'user',
      content: clean,
    );

    // Save user message to persistent DB
    if (convId != null) {
      _conversationRepo.saveMessage(convId, userMsg);
    }

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
          materialId: state.activeMaterialId,
          materialTitle: state.activeMaterialTitle,
          modelOverride: state.activeModel,
          isStrictGrounded: state.activeMaterialId != null,
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

    final convId = state.conversationId;
    if (convId != null) {
      final assistantMsg = ChatMessage(
        id: msgId,
        role: 'assistant',
        content: content.isEmpty ? "I couldn't generate a response. Please try again." : content,
        sources: sources,
        createdAt: DateTime.now(),
      );
      _conversationRepo.saveMessage(convId, assistantMsg);
      loadHistory();
    }
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

  void clearChat() {
    startNewChat();
  }

  @override
  void dispose() {
    stopGeneration();
    super.dispose();
  }
}
