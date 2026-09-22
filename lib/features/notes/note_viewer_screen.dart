import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'presentation/providers/notes_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/text_to_speech_service.dart';
import '../../core/providers/database_providers.dart';
import '../ai/presentation/providers/chat_provider.dart';

class NoteViewerScreen extends ConsumerStatefulWidget {
  final String id;
  const NoteViewerScreen({super.key, required this.id});

  @override
  ConsumerState<NoteViewerScreen> createState() => _NoteViewerScreenState();
}

class _NoteViewerScreenState extends ConsumerState<NoteViewerScreen> {
  final TextToSpeechService _tts = TextToSpeechService();
  bool _isPlaying = false;

  void _toggleTTS(String text) async {
    if (_isPlaying) {
      await _tts.stop();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      await _tts.speak(text);
      setState(() => _isPlaying = false);
    }
  }

  void _confirmDelete(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Note?'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(noteRepositoryProvider).deleteNote(widget.id);
                if (context.mounted) {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                  ref.invalidate(allNotesProvider);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Something went wrong: $e'),
                      action: SnackBarAction(
                        label: 'Retry',
                        onPressed: () => _confirmDelete(context, title),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(noteDetailsProvider(widget.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Study Note"),
        actions: [
          noteAsync.when(
            data: (note) => Row(
              children: [
                IconButton(
                  icon: Icon(_isPlaying ? Icons.stop_circle : Icons.volume_up_outlined),
                  tooltip: _isPlaying ? 'Stop Audio' : 'Read Aloud',
                  onPressed: () => _toggleTTS('${note['title']}. ${note['content']}'),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  tooltip: 'Copy Note',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '${note['title']}\n\n${note['content']}'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Note copied to clipboard!')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  tooltip: 'Delete Note',
                  onPressed: () => _confirmDelete(context, note['title'] ?? 'Note'),
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
          ),

        ],
      ),
      body: noteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (note) {
          final content = note['content'] ?? '';
          final title = note['title'] ?? 'Untitled Note';

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Study Note', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            "Updated: ${note['updated_at']?.toString().split('T')[0] ?? 'Recently'}",
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 16),
                      MarkdownBody(
                        data: content,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 15, height: 1.6, color: AppColors.textPrimary),
                          h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          h2: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                          h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.cyan),
                          strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          tableBorder: TableBorder.all(color: AppColors.cardBorder),
                          tableHead: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                          code: const TextStyle(backgroundColor: AppColors.surfaceVariant, color: AppColors.cyan),
                          codeblockDecoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          blockquote: const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // AI Actions Footer Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceElevated,
                  border: Border(top: BorderSide(color: AppColors.cardBorder)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _aiActionButton(
                        icon: Icons.auto_awesome,
                        label: 'Ask AI',
                        onTap: () {
                          ref.read(chatProvider.notifier).sendMessage('Explain the key concepts in this note: $title');
                          context.push('/ai');
                        },
                      ),
                      _aiActionButton(
                        icon: Icons.summarize_outlined,
                        label: 'Summarize',
                        onTap: () {
                          ref.read(chatProvider.notifier).setMode('summarize');
                          ref.read(chatProvider.notifier).sendMessage('Summarize this note for exam revision: $title\n$content');
                          context.push('/ai');
                        },
                      ),
                      _aiActionButton(
                        icon: Icons.quiz_outlined,
                        label: 'Take Quiz',
                        onTap: () => context.push('/study/quiz/$title'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _aiActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primaryLight),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

