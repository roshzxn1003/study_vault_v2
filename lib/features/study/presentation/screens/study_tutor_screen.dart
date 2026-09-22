import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/ai/tutor_prompt_builder.dart';
import 'package:study_vault/core/providers/ai_providers.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/theme/app_colors.dart';
import 'package:study_vault/core/services/text_to_speech_service.dart';

class StudyTutorScreen extends ConsumerStatefulWidget {
  final String topic;
  const StudyTutorScreen({super.key, required this.topic});

  @override
  ConsumerState<StudyTutorScreen> createState() => _StudyTutorScreenState();
}

class _StudyTutorScreenState extends ConsumerState<StudyTutorScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final TextToSpeechService _tts = TextToSpeechService();
  int _currentStepIndex = 0;
  final List<String> _steps = const [
    "Intuitive explanation & mental model",
    "Technical concepts & invariants",
    "Real-world analogy & example",
    "Common exam traps & pitfalls",
    "Active recall & mastery quiz",
  ];
  bool _isThinking = false;
  final List<TutorChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _startTeaching();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _tts.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startTeaching() async {
    setState(() => _isThinking = true);
    final llm = ref.read(llmServiceProvider);
    final search = ref.read(semanticSearchServiceProvider);

    // 1. Search vault for context
    String context = "";
    try {
      final searchResults = await search.search(widget.topic, matchCount: 3);
      if (searchResults.isNotEmpty) {
        context = searchResults.map((r) => "${r.fileName}: ${r.content}").join("\n\n");
      }
    } catch (e) {
      debugPrint('StudyTutorScreen: Failed to retrieve search context: $e');
    }

    final prompt = TutorPromptBuilder.buildTeachingPrompt(
      topic: widget.topic,
      context: context,
      currentStep: _steps[_currentStepIndex],
    );

    final response = await llm.generateAnswer(
      query: prompt,
      context: context,
    );

    if (mounted) {
      setState(() {
        _messages.add(TutorChatMessage(role: 'assistant', content: response, createdAt: DateTime.now()));
        _isThinking = false;
      });
      _scrollToBottom();
    }
  }

  void _sendReply(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _messages.add(TutorChatMessage(role: 'user', content: text, createdAt: DateTime.now()));
      _controller.clear();
      _isThinking = true;
      if (_currentStepIndex < _steps.length - 1) {
        _currentStepIndex++;
      }
    });
    _scrollToBottom();

    final llm = ref.read(llmServiceProvider);
    final response = await llm.generateTutorStep(
      topic: widget.topic,
      currentStep: _steps[_currentStepIndex],
      userPrompt: text,
    );

    if (mounted) {
      setState(() {
        _messages.add(TutorChatMessage(role: 'assistant', content: response, createdAt: DateTime.now()));
        _isThinking = false;
      });
      _scrollToBottom();
    }
  }

  void _restartLesson() {
    setState(() {
      _messages.clear();
      _currentStepIndex = 0;
    });
    _startTeaching();
  }

  Future<void> _saveEntireLessonAsNote() async {
    final title = 'AI Tutor Lesson: ${widget.topic}';
    final contentBuffer = StringBuffer();
    contentBuffer.writeln('# $title\n');
    contentBuffer.writeln('Generated on ${DateTime.now().toLocal().toString().split('.')[0]}\n\n---\n');

    for (final m in _messages) {
      if (m.role == 'user') {
        contentBuffer.writeln('\n**Student**: ${m.content}\n');
      } else {
        contentBuffer.writeln('\n**AI Tutor**:\n${m.content}\n\n---\n');
      }
    }

    try {
      final db = await LocalDbService.instance.database;
      final now = DateTime.now().toIso8601String();
      await db.insert('notes', {
        'id': 'note_tutor_${DateTime.now().millisecondsSinceEpoch}',
        'user_id': 'guest',
        'title': title,
        'content': contentBuffer.toString(),
        'created_at': now,
        'updated_at': now,
        'sync_status': 'synced',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "$title" to your Study Vault!'),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving note: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentStepIndex + 1) / _steps.length;

    return Scaffold(
      appBar: AppBar(
        title: Text("AI Tutor • ${widget.topic}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Save Lesson to Vault',
            onPressed: _messages.isEmpty ? null : _saveEntireLessonAsNote,
          ),
          IconButton(
            icon: const Icon(Icons.quiz_outlined),
            tooltip: 'Take Quiz',
            onPressed: () => context.push('/study/quiz/${widget.topic}'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Restart Lesson',
            onPressed: _restartLesson,
          ),
        ],
      ),
      body: Column(
        children: [
          // Step Progress Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.surfaceElevated,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Step ${_currentStepIndex + 1} of ${_steps.length}: ${_steps[_currentStepIndex]}",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                    ),
                    Text(
                      "${(progress * 100).toInt()}% Done",
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.cardBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isThinking) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.school, size: 16, color: AppColors.primaryLight),
                        ),
                        const SizedBox(width: 12),
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "AI Tutor is thinking and formatting lesson...",
                          style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                return _ChatBubble(
                  message: _messages[index],
                  onSpeak: (t) => _tts.speak(t),
                );
              },
            ),
          ),

          // Suggestion Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _suggestionChip("Explain with an analogy 💡", () => _sendReply("Can you give me a simple real-world analogy for this?")),
                  const SizedBox(width: 8),
                  _suggestionChip("Show code/formula 💻", () => _sendReply("Show me a concrete code example or mathematical formula.")),
                  const SizedBox(width: 8),
                  _suggestionChip("Common pitfalls ⚠️", () => _sendReply("What are the most common exam traps or mistakes with this?")),
                  const SizedBox(width: 8),
                  _suggestionChip("Next step ➡️", () => _sendReply("I understood! Let's proceed to the next concept.")),
                ],
              ),
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              border: Border(top: BorderSide(color: AppColors.cardBorder)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isThinking,
                      decoration: InputDecoration(
                        hintText: "Ask a question or explain what you learned...",
                        hintStyle: const TextStyle(fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onSubmitted: (val) => _sendReply(val.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send_rounded, size: 18),
                    onPressed: _isThinking ? null : () => _sendReply(_controller.text.trim()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      backgroundColor: AppColors.surfaceElevated,
      side: const BorderSide(color: AppColors.cardBorder),
      onPressed: _isThinking ? null : onTap,
    );
  }
}

class TutorChatMessage {
  final String role;
  final String content;
  final DateTime createdAt;
  TutorChatMessage({required this.role, required this.content, required this.createdAt});
}

class _ChatBubble extends StatelessWidget {
  final TutorChatMessage message;
  final Function(String) onSpeak;
  const _ChatBubble({required this.message, required this.onSpeak});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: AppColors.cardBorder),
          boxShadow: isUser
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.school, size: 14, color: AppColors.primaryLight),
                      SizedBox(width: 6),
                      Text('AI Socratic Tutor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primaryLight)),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy_outlined, size: 15, color: AppColors.textSecondary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: message.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied explanation!'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.volume_up_outlined, size: 16, color: AppColors.textSecondary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => onSpeak(message.content),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            isUser
                ? Text(message.content, style: const TextStyle(color: Colors.white, fontSize: 14.5))
                : MarkdownBody(
                    data: message.content,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, height: 1.55),
                      h1: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                      h2: const TextStyle(color: AppColors.primaryLight, fontSize: 15, fontWeight: FontWeight.bold),
                      h3: const TextStyle(color: AppColors.cyan, fontSize: 14, fontWeight: FontWeight.bold),
                      strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      code: const TextStyle(backgroundColor: AppColors.surfaceVariant, color: AppColors.cyan, fontFamily: 'monospace'),
                      codeblockDecoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      blockquote: const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                      blockquoteDecoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
