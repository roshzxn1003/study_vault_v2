import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/services/speech_service.dart';
import 'package:study_vault/core/services/text_to_speech_service.dart';
import 'package:study_vault/features/ai/data/repositories/ai_conversation_repository.dart';
import 'package:study_vault/features/ai/presentation/providers/chat_provider.dart';
import 'package:study_vault/features/ai/presentation/widgets/material_attachment_dialog.dart';
import 'package:study_vault/features/ai/presentation/widgets/streaming_message.dart';
import 'package:study_vault/features/vault/presentation/screens/material_detail_screen.dart';

/// Modern ChatGPT-style AI Study Assistant screen.
/// Includes model selector pill, conversation history drawer,
/// material grounding integration, and floating signature input bar.
class AIScreen extends ConsumerStatefulWidget {
  final String? initialSubject;
  final String? initialMaterialId;
  final String? initialMaterialTitle;
  final String? initialMode;

  const AIScreen({
    super.key,
    this.initialSubject,
    this.initialMaterialId,
    this.initialMaterialTitle,
    this.initialMode,
  });

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialSubject != null || widget.initialMaterialId != null) {
        ref.read(chatProvider.notifier).setContext(
              subject: widget.initialSubject,
              materialId: widget.initialMaterialId,
              materialTitle: widget.initialMaterialTitle,
            );
      }
      if (widget.initialMode != null) {
        ref.read(chatProvider.notifier).setMode(widget.initialMode!);
      }
    });
  }

  void _sendQuery(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    HapticFeedback.lightImpact();
    ref.read(chatProvider.notifier).sendMessage(clean, imagePath: _attachedImagePath);
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

  Future<void> _pickImageAttachment(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _attachedImagePath = image.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image attached for multimodal AI reasoning'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access image: $e')),
        );
      }
    }
  }

  void _showAttachmentOptions() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_stories_rounded, color: theme.colorScheme.primary),
                ),
                title: const Text('Attach Material from Vault', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Select a PDF, document, or lecture note to ground AI answers'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  MaterialAttachmentDialog.show(context);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.teal),
                ),
                title: const Text('Take Photo / Scan Note', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Capture whiteboard or book page with camera'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImageAttachment(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.orange),
                ),
                title: const Text('Upload Image from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Attach diagram or screenshot for multimodal analysis'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImageAttachment(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showModelPicker(String currentModel) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final models = [
      {
        'id': 'gemini-1.5-flash',
        'title': 'Gemini 1.5 Flash',
        'desc': 'Fast, lightweight & responsive. Recommended for everyday study questions.',
        'icon': Icons.bolt_rounded,
        'badge': 'Recommended',
      },
      {
        'id': 'gemini-1.5-pro',
        'title': 'Gemini 1.5 Pro',
        'desc': 'Complex reasoning, deep academic analysis & multi-step problem solving.',
        'icon': Icons.auto_awesome_rounded,
        'badge': 'Pro Reasoning',
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Select Model',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              ...models.map((m) {
                final isSelected = currentModel == m['id'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.08)
                        : (isDark ? const Color(0xFF282830) : const Color(0xFFF9FAFB)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : (isDark ? Colors.white12 : Colors.black12),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? theme.colorScheme.primary
                          : (isDark ? Colors.white10 : Colors.black12),
                      foregroundColor: isSelected ? Colors.white : theme.colorScheme.primary,
                      child: Icon(m['icon'] as IconData, size: 20),
                    ),
                    title: Row(
                      children: [
                        Text(
                          m['title'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? theme.colorScheme.primary : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            m['badge'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(m['desc'] as String, style: const TextStyle(fontSize: 12)),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                        : null,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(chatProvider.notifier).setModel(m['id'] as String);
                      Navigator.of(ctx).pop();
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
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

  void _navigateToSourceMaterial(AiSource source) {
    if (source.fileId.isNotEmpty && source.fileId != 'local_id') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MaterialDetailScreen(materialId: source.fileId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Source: ${source.fileName} (Page ${source.pageNumber})')),
      );
    }
  }

  void _showRenameDialog(AiConversationItem conv) {
    final textCtrl = TextEditingController(text: conv.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Conversation'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter conversation title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newTitle = textCtrl.text.trim();
              if (newTitle.isNotEmpty) {
                ref.read(chatProvider.notifier).renameConversation(conv.id, newTitle);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
    final isDark = theme.brightness == Brightness.dark;

    final modelDisplayName = chatState.activeModel.contains('pro')
        ? 'Gemini 1.5 Pro'
        : 'Gemini 1.5 Flash';

    return Scaffold(
      drawer: _buildHistoryDrawer(context, chatState, theme, isDark),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Chat History',
            onPressed: () {
              Scaffold.of(ctx).openDrawer();
            },
          ),
        ),
        centerTitle: true,
        title: GestureDetector(
          onTap: () => _showModelPicker(chatState.activeModel),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF282830) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  chatState.activeModel.contains('pro')
                      ? Icons.auto_awesome_rounded
                      : Icons.bolt_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  modelDisplayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, size: 20),
            tooltip: 'New Chat',
            onPressed: () {
              HapticFeedback.mediumImpact();
              ref.read(chatProvider.notifier).startNewChat();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Grounding Context Pill & Mode Selector
          _buildGroundingBar(chatState, theme, isDark),
          _buildModeSelector(chatState.currentMode, theme),
          const Divider(height: 1, color: AppColors.border),

          // Messages / Empty State
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState(chatState, theme, isDark)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatState.messages[index];
                      return StreamingMessageWidget(
                        message: msg,
                        onListen: () => _tts.speak(msg.content),
                        onStop: chatState.isGenerating
                            ? () => ref.read(chatProvider.notifier).stopGeneration()
                            : null,
                        onRetry: () => ref.read(chatProvider.notifier).retryLast(),
                        onOpenSource: _navigateToSourceMaterial,
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
                  const Icon(Icons.image_rounded, color: AppColors.primaryLight, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Image attached for multimodal reasoning', style: TextStyle(fontSize: 13)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() => _attachedImagePath = null),
                  ),
                ],
              ),
            ),

          // Modern Signature Floating Input Area
          _buildChatGPTInputArea(chatState, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildGroundingBar(ChatState chatState, ThemeData theme, bool isDark) {
    final hasAttached = chatState.activeMaterialTitle != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: isDark ? const Color(0xFF1B1B22) : const Color(0xFFF9FAFB),
      child: Row(
        children: [
          Icon(
            hasAttached ? Icons.description_rounded : Icons.all_inclusive_rounded,
            size: 15,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              onTap: () => MaterialAttachmentDialog.show(context),
              child: Row(
                children: [
                  Text(
                    hasAttached ? 'Attached Doc: ' : 'Grounding: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      hasAttached
                          ? chatState.activeMaterialTitle!
                          : (chatState.activeSubject != null
                              ? 'Subject (${chatState.activeSubject})'
                              : 'All Library Materials'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasAttached)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              tooltip: 'Clear document attachment',
              onPressed: () => ref.read(chatProvider.notifier).clearMaterial(),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            )
          else
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.tune_rounded, size: 14),
              label: const Text('Change', style: TextStyle(fontSize: 11.5)),
              onPressed: () => MaterialAttachmentDialog.show(context),
            ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(String currentMode, ThemeData theme) {
    final modes = [
      {'id': 'ask', 'label': 'Ask Q&A', 'icon': Icons.chat_bubble_outline_rounded},
      {'id': 'tutor', 'label': 'Socratic Tutor', 'icon': Icons.psychology_outlined},
      {'id': 'explain', 'label': 'Explain Simply', 'icon': Icons.lightbulb_outline_rounded},
      {'id': 'summarize', 'label': 'Summarize', 'icon': Icons.summarize_outlined},
      {'id': 'quiz', 'label': 'Practice Quiz', 'icon': Icons.quiz_outlined},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: modes.map((m) {
            final isSelected = currentMode == m['id'];
            return Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: FilterChip(
                selected: isSelected,
                avatar: Icon(
                  m['icon'] as IconData,
                  size: 14,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
                label: Text(
                  m['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                backgroundColor: AppColors.surfaceElevated,
                selectedColor: theme.colorScheme.primary,
                side: BorderSide(
                  color: isSelected ? theme.colorScheme.primary : AppColors.cardBorder,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (_) => ref.read(chatProvider.notifier).setMode(m['id'] as String),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ChatState chatState, ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 38,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'What do you want to learn today?',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask questions, solve problems, or quiz yourself. Answers are strictly grounded in your study materials with page citations.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.45,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 20),

          // Attach material shortcut button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
            ),
            icon: Icon(Icons.attach_file_rounded, size: 18, color: theme.colorScheme.primary),
            label: Text(
              chatState.activeMaterialTitle != null
                  ? 'Grounded: ${chatState.activeMaterialTitle}'
                  : '+ Attach Material from Vault',
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
            ),
            onPressed: () => MaterialAttachmentDialog.show(context),
          ),

          const SizedBox(height: 24),

          // Prompt starter cards
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _suggestionChip('💡 Explain DBMS ACID properties'),
              _suggestionChip('🔄 Deadlock Coffman conditions'),
              _suggestionChip('🌐 Compare TCP vs UDP'),
              _suggestionChip('📊 Summarize key exam topics'),
              _suggestionChip('🎯 Quiz me on Scheduling Algorithms'),
              _suggestionChip('📝 Generate 5 flashcards from notes'),
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
      label: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
      onPressed: () => _sendQuery(label),
    );
  }

  Widget _buildChatGPTInputArea(ChatState chatState, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: const Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF282830) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // + Attachment Button
              IconButton(
                icon: const Icon(Icons.add_rounded, size: 24),
                color: isDark ? Colors.white70 : Colors.black54,
                tooltip: 'Attach Vault Material or Photo',
                onPressed: chatState.isGenerating ? null : _showAttachmentOptions,
              ),

              // Expanding Multi-line Text Field
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !chatState.isGenerating,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendQuery,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: _isListening
                        ? 'Listening...'
                        : (chatState.isGenerating
                            ? 'Generating response...'
                            : (chatState.activeMaterialTitle != null
                                ? 'Ask about ${chatState.activeMaterialTitle}...'
                                : 'Message Study Vault...')),
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  ),
                ),
              ),

              // Voice Mic Button
              IconButton(
                icon: Icon(
                  _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: _isListening ? Colors.redAccent : (isDark ? Colors.white60 : Colors.black45),
                ),
                tooltip: 'Voice Input',
                onPressed: chatState.isGenerating ? null : _toggleListening,
              ),

              // Circular Send / Stop Button
              Padding(
                padding: const EdgeInsets.only(bottom: 4, right: 4),
                child: chatState.isGenerating
                    ? Material(
                        color: AppColors.rose,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => ref.read(chatProvider.notifier).stopGeneration(),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.stop_rounded, size: 20, color: Colors.white),
                          ),
                        ),
                      )
                    : Material(
                        color: _controller.text.trim().isNotEmpty
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? Colors.white24 : Colors.black12),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _controller.text.trim().isNotEmpty
                              ? () => _sendQuery(_controller.text)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              size: 20,
                              color: _controller.text.trim().isNotEmpty
                                  ? (isDark ? Colors.black87 : Colors.white)
                                  : (isDark ? Colors.white38 : Colors.black26),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryDrawer(
    BuildContext context,
    ChatState chatState,
    ThemeData theme,
    bool isDark,
  ) {
    final conversations = chatState.conversations;

    // Grouping by date
    final now = DateTime.now();
    final today = <AiConversationItem>[];
    final yesterday = <AiConversationItem>[];
    final prev7Days = <AiConversationItem>[];
    final older = <AiConversationItem>[];

    for (final conv in conversations) {
      final diff = now.difference(conv.updatedAt).inDays;
      if (diff == 0 && now.day == conv.updatedAt.day) {
        today.add(conv);
      } else if (diff <= 1) {
        yesterday.add(conv);
      } else if (diff <= 7) {
        prev7Days.add(conv);
      } else {
        older.add(conv);
      }
    }

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF18181E) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                    child: Icon(Icons.school_rounded, color: theme.colorScheme.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Study Vault AI',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // New Chat Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('New Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(chatProvider.notifier).startNewChat();
                  },
                ),
              ),
            ),

            const Divider(height: 16, color: AppColors.border),

            // Conversations List
            Expanded(
              child: conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 40, color: isDark ? Colors.white24 : Colors.black26),
                          const SizedBox(height: 10),
                          Text(
                            'No previous chats',
                            style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        if (today.isNotEmpty) ...[
                          _drawerSectionTitle('Today'),
                          ...today.map((c) => _drawerConversationTile(c, chatState, theme, isDark)),
                        ],
                        if (yesterday.isNotEmpty) ...[
                          _drawerSectionTitle('Yesterday'),
                          ...yesterday.map((c) => _drawerConversationTile(c, chatState, theme, isDark)),
                        ],
                        if (prev7Days.isNotEmpty) ...[
                          _drawerSectionTitle('Previous 7 Days'),
                          ...prev7Days.map((c) => _drawerConversationTile(c, chatState, theme, isDark)),
                        ],
                        if (older.isNotEmpty) ...[
                          _drawerSectionTitle('Older'),
                          ...older.map((c) => _drawerConversationTile(c, chatState, theme, isDark)),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _drawerConversationTile(
    AiConversationItem conv,
    ChatState chatState,
    ThemeData theme,
    bool isDark,
  ) {
    final isSelected = chatState.conversationId == conv.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: Icon(
          Icons.chat_bubble_outline_rounded,
          size: 17,
          color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white60 : Colors.black54),
        ),
        title: Text(
          conv.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.colorScheme.primary : null,
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_horiz_rounded,
            size: 16,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          padding: EdgeInsets.zero,
          onSelected: (val) {
            if (val == 'rename') {
              _showRenameDialog(conv);
            } else if (val == 'delete') {
              ref.read(chatProvider.notifier).deleteConversation(conv.id);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Rename'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).pop();
          ref.read(chatProvider.notifier).loadConversation(conv.id);
        },
      ),
    );
  }
}
