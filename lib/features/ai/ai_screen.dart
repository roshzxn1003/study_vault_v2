import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_vault/features/ai/presentation/providers/chat_provider.dart';
import 'package:study_vault/core/services/text_to_speech_service.dart';
import 'package:study_vault/core/services/speech_service.dart';
import 'package:study_vault/core/theme/app_colors.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/database/local_db_service.dart';


class AIScreen extends ConsumerStatefulWidget {
  const AIScreen({super.key});

  @override
  ConsumerState<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends ConsumerState<AIScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextToSpeechService _tts = TextToSpeechService();
  final SpeechService _speech = SpeechService();
  bool _isListening = false;
  String? _attachedImagePath;

  @override
  void initState() {
    super.initState();
    _speech.init();
  }

  void _sendQuery(String text) {
    if (text.trim().isEmpty) return;
    ref.read(chatProvider.notifier).sendMessage(text.trim(), imagePath: _attachedImagePath);
    _controller.clear();
    setState(() => _attachedImagePath = null);
    _scrollToBottom();
  }


  void _toggleListening() async {
    if (_isListening) {
      _speech.stopListening();
      setState(() => _isListening = false);
    } else {
      final available = await _speech.init();
      if (available) {
        setState(() => _isListening = true);
        _speech.startListening((recognized) {
          setState(() {
            _controller.text = recognized;
          });
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech recognition not available on this device')),
          );
        }
      }
    }
  }

  Future<void> _pickImageAttachment() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _attachedImagePath = image.path;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document image attached for AI inspection')),
        );
      }
    }
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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _tts.stop();
    _speech.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Study Assistant'),
        actions: [
          if (chatState.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear Chat',
              onPressed: () => ref.read(chatProvider.notifier).clearChat(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Study Mode Selector
          _buildModeSelector(chatState.currentMode),
          const Divider(height: 1, color: AppColors.border),

          // Messages / Empty State
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState(chatState.currentMode)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatState.messages.length + (chatState.isThinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == chatState.messages.length && chatState.isThinking) {
                        return _buildThinkingIndicator(theme);
                      }
                      final msg = chatState.messages[index];
                      return ChatBubble(
                        message: msg,
                        onListen: () => _tts.speak(msg.content),
                        onShowSources: msg.sources != null && msg.sources!.isNotEmpty
                            ? () => _showSourcesModal(context, msg.sources!)
                            : null,
                      );
                    },
                  ),
          ),

          // Attached Image Preview
          if (_attachedImagePath != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceVariant,
              child: Row(
                children: [
                  const Icon(Icons.image, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Image attached for analysis', style: TextStyle(fontSize: 13)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _attachedImagePath = null),
                  ),
                ],
              ),
            ),

          // Input Bar
          _buildInputArea(chatState.isThinking, theme),
        ],
      ),
    );
  }

  Widget _buildModeSelector(String currentMode) {
    final modes = [
      {'id': 'ask', 'label': 'Ask Q&A', 'icon': Icons.chat_bubble_outline},
      {'id': 'explain', 'label': 'Explain Simply', 'icon': Icons.lightbulb_outline},
      {'id': 'summarize', 'label': 'Summarize', 'icon': Icons.summarize_outlined},
      {'id': 'quiz', 'label': 'Practice Quiz', 'icon': Icons.quiz_outlined},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: modes.map((m) {
            final isSelected = currentMode == m['id'];
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                selected: isSelected,
                avatar: Icon(
                  m['icon'] as IconData,
                  size: 16,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
                label: Text(
                  m['label'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                backgroundColor: AppColors.surfaceElevated,
                selectedColor: AppColors.primary,
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.cardBorder,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (_) => ref.read(chatProvider.notifier).setMode(m['id'] as String),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildThinkingIndicator(ThemeData theme) {
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
            child: const Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          const Text(
            "Searching vault & generating grounded answer...",
            style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String currentMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, size: 36, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your Personal AI Tutor',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask anything about your notes, lecture slides, or syllabus. Get step-by-step analogies, chapter summaries, and practice quizzes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 14),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _suggestionChip('💡 Explain DBMS ACID properties'),
              _suggestionChip('🔄 Deadlock Coffman conditions'),
              _suggestionChip('🌐 Compare TCP vs UDP'),
              _suggestionChip('📊 Serializability in transactions'),
              _suggestionChip('📝 Summarize Unit 1 notes'),
              _suggestionChip('🎯 Quiz me on Concurrency Control'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(String label) {
    return ActionChip(
      backgroundColor: AppColors.surfaceElevated,
      side: const BorderSide(color: AppColors.cardBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      label: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
      onPressed: () => _sendQuery(label),
    );
  }

  Widget _buildInputArea(bool isThinking, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: const Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
              tooltip: 'Attach Image / Note Scan',
              onPressed: _pickImageAttachment,
            ),
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.redAccent : AppColors.textSecondary,
              ),
              tooltip: 'Voice Input',
              onPressed: _toggleListening,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !isThinking,
                decoration: InputDecoration(
                  hintText: _isListening ? 'Listening...' : 'Ask your vault anything...',
                  hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onSubmitted: _sendQuery,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: isThinking ? null : () => _sendQuery(_controller.text),
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      ),
    );
  }

  void _showSourcesModal(BuildContext context, List<AiSource> sources) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.source, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  'Grounded Sources (${sources.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sources.map((s) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x1A6366F1),
                      child: Icon(Icons.description, color: AppColors.primary, size: 20),
                    ),
                    title: Text(s.fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('Page ${s.pageNumber} • Similarity: ${(s.similarity * 100).toStringAsFixed(0)}%'),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class ChatBubble extends ConsumerWidget {
  final ChatMessage message;
  final VoidCallback onListen;
  final VoidCallback? onShowSources;

  const ChatBubble({
    super.key,
    required this.message,
    required this.onListen,
    this.onShowSources,
  });

  Future<void> _saveAsNote(BuildContext context, WidgetRef ref) async {
    final titleMatch = RegExp(r'^#+\s+(.+)$', multiLine: true).firstMatch(message.content);
    final title = titleMatch?.group(1) ?? 'AI Study Note (${DateTime.now().month}/${DateTime.now().day})';
    
    try {
      final db = await LocalDbService.instance.database;
      final now = DateTime.now().toIso8601String();
      await db.insert('notes', {
        'id': 'note_ai_${DateTime.now().millisecondsSinceEpoch}',
        'user_id': 'guest',
        'title': title,
        'content': message.content,
        'created_at': now,
        'updated_at': now,
        'sync_status': 'synced'
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "$title" to your Study Vault!'),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving note: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser ? null : Border.all(color: AppColors.cardBorder),
          boxShadow: isUser
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isUser)
              Text(
                message.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.45,
                ),
              )
            else ...[
              MarkdownBody(
                data: message.content,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, height: 1.55),
                  h1: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  h2: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  h3: const TextStyle(color: AppColors.primaryLight, fontSize: 15, fontWeight: FontWeight.bold),
                  strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  tableBorder: TableBorder.all(color: AppColors.cardBorder),
                  tableHead: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight),
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
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),

              // Action Toolbar Under AI Message
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.volume_up_outlined, size: 18, color: AppColors.primaryLight),
                        onPressed: onListen,
                        tooltip: 'Read aloud',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.only(right: 12),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.textSecondary),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: message.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied AI response!'), duration: Duration(seconds: 1)),
                          );
                        },
                        tooltip: 'Copy text',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.only(right: 12),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmark_add_outlined, size: 18, color: AppColors.emerald),
                        onPressed: () => _saveAsNote(context, ref),
                        tooltip: 'Save as Note to Vault',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.only(right: 8),
                      ),
                    ],
                  ),
                  if (message.sources != null && message.sources!.isNotEmpty)
                    InkWell(
                      onTap: onShowSources,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.source, size: 12, color: AppColors.primaryLight),
                            const SizedBox(width: 4),
                            Text(
                              '${message.sources!.length} source(s)',
                              style: const TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}


