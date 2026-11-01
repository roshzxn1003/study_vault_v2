import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/services/speech_service.dart';
import 'package:study_vault/core/services/text_to_speech_service.dart';
import 'package:study_vault/features/ai/data/repositories/ai_conversation_repository.dart';
import 'package:study_vault/features/ai/data/services/chat_export_service.dart';
import 'package:study_vault/features/ai/presentation/providers/chat_provider.dart';
import 'package:study_vault/features/ai/presentation/widgets/material_attachment_dialog.dart';
import 'package:study_vault/features/ai/presentation/widgets/streaming_message.dart';
import 'package:study_vault/features/ai/presentation/widgets/voice_study_modal.dart';

/// Modern ChatGPT-style AI Study Assistant screen.
/// Includes model selector pill, conversation history drawer,
/// material grounding integration, and floating signature input bar.
class AIScreen extends ConsumerStatefulWidget {
  final String? initialSubject;
  final String? initialMaterialId;
  final String? initialMaterialTitle;
  final String? initialMode;
  final String? initialQuery;

  const AIScreen({
    super.key,
    this.initialSubject,
    this.initialMaterialId,
    this.initialMaterialTitle,
    this.initialMode,
    this.initialQuery,
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
      if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
        _sendQuery(widget.initialQuery!.trim());
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
        'id': 'auto',
        'title': 'Auto-Router (Gemini + Claude)',
        'desc': 'Smart task routing with automatic failover across Gemini, Claude, and open models.',
        'icon': Icons.psychology_rounded,
        'badge': 'Recommended',
      },
      {
        'id': 'gemini-3.5-flash-lite',
        'title': 'Gemini 3.5 Flash-Lite',
        'desc': 'Fast, lightweight & responsive. Ideal for everyday questions and lecture notes.',
        'icon': Icons.bolt_rounded,
        'badge': 'Verified Fast',
      },
      {
        'id': 'gemini-3.8-flash',
        'title': 'Gemini 3.8 Flash',
        'desc': 'Latest flagship reasoning model with built-in thought chains.',
        'icon': Icons.auto_awesome_rounded,
        'badge': 'Deep Thinking',
      },
      {
        'id': 'gemini-3.5-flash',
        'title': 'Gemini 3.5 Flash',
        'desc': 'High throughput multimodal study companion for complex documents.',
        'icon': Icons.flash_on_rounded,
        'badge': 'High Throughput',
      },
      {
        'id': 'claude-3-7-sonnet-20250219',
        'title': 'Claude 3.7 Sonnet',
        'desc': 'Anthropic flagship with thinking budget for university math proofs & advanced logic.',
        'icon': Icons.calculate_rounded,
        'badge': 'Hybrid Reasoning',
      },
      {
        'id': 'claude-3-5-sonnet-20241022',
        'title': 'Claude 3.5 Sonnet',
        'desc': 'Gold-standard code generation and zero-error quiz & flashcard extraction.',
        'icon': Icons.terminal_rounded,
        'badge': 'Code & Quizzes',
      },
      {
        'id': 'claude-3-5-haiku-20241022',
        'title': 'Claude 3.5 Haiku',
        'desc': 'High-speed micro-tutor for rapid definitions and active recall drills.',
        'icon': Icons.speed_rounded,
        'badge': 'High Speed',
      },
      {
        'id': 'gemma-2-2b-it',
        'title': 'Gemma 2 (2B)',
        'desc': 'Google lightweight on-device open model. Fast offline definitions, notes, and study cards.',
        'icon': Icons.memory_rounded,
        'badge': 'Mobile Edge (1.4 GB)',
      },
      {
        'id': 'llama-3.2-3b-instruct',
        'title': 'Llama 3.2 (3B)',
        'desc': 'Meta compact open model with excellent multilingual tutoring and exam reasoning on mobile.',
        'icon': Icons.memory_rounded,
        'badge': 'Mobile Edge (2.1 GB)',
      },
      {
        'id': 'llama-3.2-1b-instruct',
        'title': 'Llama 3.2 (1B)',
        'desc': 'Ultra-compact edge model optimized for low-end mobile hardware, instant quiz drills, and zero lag.',
        'icon': Icons.bolt_outlined,
        'badge': 'Ultra-Lite (750 MB)',
      },
      {
        'id': 'qwen-2.5-1.5b-instruct',
        'title': 'Qwen 2.5 (1.5B)',
        'desc': 'State-of-the-art small open model for coding syntax, math problem solving, and structured JSON.',
        'icon': Icons.code_rounded,
        'badge': 'Math & Code (1.1 GB)',
      },
      {
        'id': 'deepseek-r1-distill-qwen-1.5b',
        'title': 'DeepSeek-R1 (1.5B)',
        'desc': 'Distilled open reasoning model with step-by-step thinking traces designed for mobile processors.',
        'icon': Icons.psychology_outlined,
        'badge': 'Reasoning CoT (1.2 GB)',
      },
      {
        'id': 'ollama-local',
        'title': 'Ollama Local Network Node',
        'desc': 'Connect mobile app over Wi-Fi to your PC running Ollama with 0 mobile battery drain.',
        'icon': Icons.wifi_tethering_rounded,
        'badge': 'PC Wi-Fi Link',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: ListView(
              controller: scrollController,
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select AI Model',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Gemini & Claude', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ...models.map((m) {
                  final isSelected = currentModel == m['id'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isDark ? Colors.white12 : Colors.black12),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Material(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.08)
                          : (isDark ? const Color(0xFF282830) : const Color(0xFFF9FAFB)),
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
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
                            Flexible(
                              child: Text(
                                m['title'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? theme.colorScheme.primary : null,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                    ),
                  );
                }),
              ],
            ),
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

  Future<void> _exportChatAsStudyNote(ChatState chatState) async {
    if (chatState.messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No conversation messages to export yet'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final result = await ChatExportService.exportToStudyNote(chatState: chatState);
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported study guide to Vault Notes as "${result.title}"'),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View Note',
              textColor: Colors.white,
              onPressed: () {
                context.push('/notes/${result.noteId}');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting study note: $e')),
        );
      }
    }
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

    final modelDisplayName = switch (chatState.activeModel) {
      'auto' => 'Auto (Gemini + Claude)',
      'gemini-3.5-flash-lite' => 'Gemini 3.5 Flash-Lite',
      'gemini-3.8-flash' => 'Gemini 3.8 Flash',
      'gemini-3.5-flash' => 'Gemini 3.5 Flash',
      'claude-3-7-sonnet-20250219' => 'Claude 3.7 Sonnet',
      'claude-3-5-sonnet-20241022' => 'Claude 3.5 Sonnet',
      'claude-3-5-haiku-20241022' => 'Claude 3.5 Haiku',
      'gemma-2-2b-it' => 'Gemma 2 (2B)',
      'llama-3.2-3b-instruct' => 'Llama 3.2 (3B)',
      'llama-3.2-1b-instruct' => 'Llama 3.2 (1B)',
      'qwen-2.5-1.5b-instruct' => 'Qwen 2.5 (1.5B)',
      'deepseek-r1-distill-qwen-1.5b' => 'DeepSeek-R1 (1.5B)',
      'ollama-local' => 'Ollama Local Node',
      _ => chatState.activeModel,
    };

    final modelIcon = switch (chatState.activeModel) {
      'auto' => Icons.psychology_rounded,
      'gemini-3.5-flash-lite' => Icons.bolt_rounded,
      'gemini-3.8-flash' => Icons.auto_awesome_rounded,
      'gemini-3.5-flash' => Icons.flash_on_rounded,
      'claude-3-7-sonnet-20250219' => Icons.calculate_rounded,
      'claude-3-5-sonnet-20241022' => Icons.terminal_rounded,
      'claude-3-5-haiku-20241022' => Icons.speed_rounded,
      'gemma-2-2b-it' => Icons.memory_rounded,
      'llama-3.2-3b-instruct' => Icons.memory_rounded,
      'llama-3.2-1b-instruct' => Icons.bolt_outlined,
      'qwen-2.5-1.5b-instruct' => Icons.code_rounded,
      'deepseek-r1-distill-qwen-1.5b' => Icons.psychology_outlined,
      'ollama-local' => Icons.wifi_tethering_rounded,
      _ => Icons.bolt_rounded,
    };

    final bool canGoBack = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      drawer: _buildHistoryDrawer(context, chatState, theme, isDark),
      appBar: AppBar(
        leading: canGoBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back to Study Space',
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              )
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: 'Chat History',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
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
                  modelIcon,
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
          if (canGoBack)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.history_rounded, size: 20),
                tooltip: 'Chat History',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: 'Return to Dashboard',
              onPressed: () => context.go('/home'),
            ),
          IconButton(
            key: const ValueKey('voice_study_mode_button'),
            icon: const Icon(Icons.headset_mic_rounded, size: 20),
            tooltip: 'Hands-Free Voice Study Mode',
            onPressed: () {
              VoiceStudyModal.show(
                context,
                initialContext: chatState.activeMaterialTitle != null
                    ? 'Material: ${chatState.activeMaterialTitle}'
                    : null,
                topicOrSubject: chatState.activeSubject,
              );
            },
          ),
          IconButton(
            key: const ValueKey('export_chat_button'),
            icon: const Icon(Icons.bookmark_add_outlined, size: 20),
            tooltip: 'Export as Study Note',
            onPressed: () => _exportChatAsStudyNote(chatState),
          ),
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

          // Quick Action Shortcut Pills (when chatting)
          if (chatState.messages.isNotEmpty && !chatState.isGenerating)
            _buildQuickActionShortcuts(chatState, theme, isDark),

          // Modern Signature Floating Input Area
          _buildChatGPTInputArea(chatState, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildGroundingBar(ChatState chatState, ThemeData theme, bool isDark) {
    final hasAttached = chatState.activeMaterialTitle != null;
    if (!hasAttached && chatState.activeSubject == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
      child: Row(
        children: [
          Icon(
            hasAttached ? Icons.description_rounded : Icons.folder_open_rounded,
            size: 15,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Text(
                  hasAttached ? 'Grounded in: ' : 'Subject: ',
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
                        : chatState.activeSubject!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            tooltip: 'Clear grounding context',
            onPressed: () => ref.read(chatProvider.notifier).clearMaterial(),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 26,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'What do you want to learn today?',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
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
                  side: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
                ),
                icon: Icon(
                  chatState.activeMaterialTitle != null
                      ? Icons.description_rounded
                      : Icons.attach_file_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  chatState.activeMaterialTitle != null
                      ? 'Grounded: ${chatState.activeMaterialTitle}'
                      : '+ Attach Material from Vault',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                onPressed: () => MaterialAttachmentDialog.show(context),
              ),

              const SizedBox(height: 28),

              // ChatGPT style 2x2 prompt cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 480;
                  final cards = [
                    (
                      icon: Icons.lightbulb_outline_rounded,
                      title: 'Explain Concepts',
                      subtitle: 'Break down complex proofs with intuitive analogies',
                      query: 'Explain key concepts from my study material with intuitive analogies.',
                    ),
                    (
                      icon: Icons.summarize_outlined,
                      title: 'Summarize Materials',
                      subtitle: 'Extract formulas, theorems, and core definitions',
                      query: 'Summarize my uploaded notes highlighting core formulas and definitions.',
                    ),
                    (
                      icon: Icons.quiz_outlined,
                      title: 'Mastery Quiz',
                      subtitle: 'Generate challenging exam-level recall questions',
                      query: 'Generate a 5-question mastery quiz testing my understanding of this topic.',
                    ),
                    (
                      icon: Icons.psychology_outlined,
                      title: 'Step-by-Step Mentoring',
                      subtitle: 'Interactive reasoning hints and active recall',
                      query: 'Act as my tutor and guide me step-by-step through solving problems on this material.',
                    ),
                  ];

                  if (isWide) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildPromptCard(cards[0], isDark)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildPromptCard(cards[1], isDark)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildPromptCard(cards[2], isDark)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildPromptCard(cards[3], isDark)),
                          ],
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: cards
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: _buildPromptCard(c, isDark),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptCard(
    ({IconData icon, String title, String subtitle, String query}) card,
    bool isDark,
  ) {
    return Material(
      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _sendQuery(card.query),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(card.icon, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                card.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionShortcuts(ChatState chatState, ThemeData theme, bool isDark) {
    final shortcuts = [
      {'label': '📝 Summarize', 'query': 'Summarize key takeaways and core formulas from this material.'},
      {'label': '🎯 Practice Quiz', 'query': 'Generate a 5-question practice quiz testing my understanding of this topic.'},
      {'label': '💡 Key Pitfalls', 'query': 'What are common exam traps and misconceptions for this topic?'},
      {'label': '🃏 Flashcards', 'query': 'Create 5 active recall flashcards with question on front and answer on back.'},
      {'label': '🔍 Step-by-Step', 'query': 'Explain this step-by-step with a clear practical analogy.'},
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shortcuts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (ctx, idx) {
          final s = shortcuts[idx];
          return ActionChip(
            backgroundColor: AppColors.surfaceElevated,
            side: const BorderSide(color: AppColors.cardBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            label: Text(s['label']!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            onPressed: () => _sendQuery(s['query']!),
          );
        },
      ),
    );
  }

  Widget _buildChatGPTInputArea(ChatState chatState, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121216) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
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
                      color: _isListening
                          ? Colors.redAccent
                          : (isDark ? Colors.white60 : Colors.black45),
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
            const SizedBox(height: 6),
            Text(
              'Study Vault AI can make mistakes. Verify important facts with your course materials.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
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
    ),
  );
  }
}
