import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/providers/ai_providers.dart';
import 'package:study_vault/core/ai/ai_models.dart';

class ChatMessage {
  final String role;
  final String content;
  final List<AiSource>? sources;
  final DateTime createdAt;

  bool get isUser => role == 'user';

  ChatMessage({required this.role, required this.content, this.sources, required this.createdAt});
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isThinking;
  final String currentMode;

  ChatState({this.messages = const [], this.isThinking = false, this.currentMode = 'ask'});

  ChatState copyWith({List<ChatMessage>? messages, bool? isThinking, String? currentMode}) {
    return ChatState(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
      currentMode: currentMode ?? this.currentMode,
    );
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref ref;
  ChatNotifier(this.ref) : super(ChatState());

  Future<void> sendMessage(String text, {String? imagePath}) async {
    final userMsg = ChatMessage(
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(messages: [...state.messages, userMsg], isThinking: true);

    try {
      final orchestrator = ref.read(aiOrchestratorProvider);
      final response = await orchestrator.askQuestion(
        query: text,
        mode: state.currentMode,
        history: state.messages.map((m) => m.content).toList(),
        imagePath: imagePath,
      );

      final aiMsg = ChatMessage(
        role: 'assistant',
        content: response.answer,
        sources: response.sources,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(messages: [...state.messages, aiMsg], isThinking: false);
    } catch (e) {

      final errorMsg = ChatMessage(
        role: 'assistant',
        content: "Something went wrong while generating the answer. Please try again.",
        createdAt: DateTime.now(),
      );
      state = state.copyWith(messages: [...state.messages, errorMsg], isThinking: false);
    }
  }

  void setMode(String mode) {
    state = state.copyWith(currentMode: mode);
  }

  void clearChat() {
    state = ChatState();
  }
}
