import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/services/speech_service.dart';
import 'package:study_vault/core/services/text_to_speech_service.dart';
import 'package:study_vault/features/ai/presentation/providers/chat_provider.dart';
import 'package:study_vault/features/ai/presentation/widgets/streaming_message.dart';
import 'package:study_vault/features/vault/presentation/screens/material_detail_screen.dart';

/// Elite Academic AI Study Assistant Screen.
/// Follows Phase 2 clean, document-aware, non-distracting visual design.
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
          const SnackBar(content: Text('Document image attached for multimodal inspection')),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Study Assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (chatState.activeSubject != null || chatState.activeMaterialTitle != null)
              Text(
                chatState.activeMaterialTitle ?? chatState.activeSubject ?? '',
                style: const TextStyle(fontSize: 11, color: AppColors.primaryLight),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
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
          // Active Academic Context Banner
          if (chatState.activeSubject != null || chatState.activeMaterialTitle != null)
            _buildAcademicContextBanner(chatState),

          // Study Mode Selector
          _buildModeSelector(chatState.currentMode),
          const Divider(height: 1, color: AppColors.border),

          // Messages / Empty State
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState(chatState.currentMode)
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
                  const Icon(Icons.image, color: AppColors.primaryLight, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Image attached for multimodal reasoning', style: TextStyle(fontSize: 13)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _attachedImagePath = null),
                  ),
                ],
              ),
            ),

          // Input Bar with Stop Button
          _buildInputArea(chatState, theme),
        ],
      ),
    );
  }

  Widget _buildAcademicContextBanner(ChatState chatState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.auto_stories_outlined, size: 14, color: AppColors.primaryLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Grounded in: ${chatState.activeMaterialTitle ?? chatState.activeSubject}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLight),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () => ref.read(chatProvider.notifier).setContext(
                  subject: null,
                  workspace: null,
                  materialId: null,
                  materialTitle: null,
                ),
            child: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(String currentMode) {
    final modes = [
      {'id': 'ask', 'label': 'Ask Q&A', 'icon': Icons.chat_bubble_outline},
      {'id': 'tutor', 'label': 'Socratic Tutor', 'icon': Icons.psychology_outlined},
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
                  size: 15,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
                label: Text(
                  m['label'] as String,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                backgroundColor: AppColors.surfaceElevated,
                selectedColor: AppColors.primary,
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.cardBorder,
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

  Widget _buildEmptyState(String currentMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.school_outlined, size: 36, color: AppColors.primaryLight),
          ),
          const SizedBox(height: 20),
          const Text(
            'Study Vault Academic Intelligence',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask anything about your notes, syllabi, and textbooks. Get Socratic step-by-step reasoning with page citations.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 13.5),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _suggestionChip('💡 Explain DBMS ACID properties'),
              _suggestionChip('🔄 Deadlock Coffman conditions'),
              _suggestionChip('🌐 Compare TCP vs UDP'),
              _suggestionChip('📊 Serializability in transactions'),
              _suggestionChip('📝 Summarize Chapter 1 notes'),
              _suggestionChip('🎯 Quiz me on Scheduling Algorithms'),
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

  Widget _buildInputArea(ChatState chatState, ThemeData theme) {
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
              onPressed: chatState.isGenerating ? null : _pickImageAttachment,
            ),
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.redAccent : AppColors.textSecondary,
              ),
              tooltip: 'Voice Input',
              onPressed: chatState.isGenerating ? null : _toggleListening,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !chatState.isGenerating,
                decoration: InputDecoration(
                  hintText: _isListening
                      ? 'Listening...'
                      : (chatState.isGenerating ? 'Generating response...' : 'Ask your vault anything...'),
                  hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: _sendQuery,
              ),
            ),
            const SizedBox(width: 8),
            if (chatState.isGenerating)
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.rose),
                onPressed: () => ref.read(chatProvider.notifier).stopGeneration(),
                tooltip: 'Stop generating',
                icon: const Icon(Icons.stop_rounded, color: Colors.white),
              )
            else
              IconButton.filled(
                onPressed: () => _sendQuery(_controller.text),
                tooltip: 'Send prompt',
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
