import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/local_db_service.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../ai/presentation/providers/chat_provider.dart';

class QuickScratchpadSheet extends ConsumerStatefulWidget {
  const QuickScratchpadSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => const QuickScratchpadSheet(),
    );
  }

  @override
  ConsumerState<QuickScratchpadSheet> createState() => _QuickScratchpadSheetState();
}

class _QuickScratchpadSheetState extends ConsumerState<QuickScratchpadSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScratchpad();
  }

  Future<void> _loadScratchpad() async {
    final text = await LocalDbService.instance.getScratchpadContent();
    if (mounted) {
      setState(() {
        _controller.text = text;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    LocalDbService.instance.saveScratchpadContent(_controller.text);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveAsVaultNote() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final firstLine = text.split('\n').first;
    final title = firstLine.replaceAll('#', '').trim().isEmpty
        ? 'Quick Note ${DateTime.now().toLocal().toString().split(' ')[0]}'
        : (firstLine.length > 30 ? '${firstLine.substring(0, 30)}...' : firstLine);

    final noteId = const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    final db = await LocalDbService.instance.database;
    await db.insert('notes', {
      'id': noteId,
      'user_id': 'guest',
      'title': title,
      'content': text,
      'created_at': now,
      'updated_at': now,
      'sync_status': 'synced',
    });

    ref.invalidate(noteRepositoryProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "$title" into Study Vault!'),
          backgroundColor: AppColors.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
      context.push('/notes/$noteId');
    }
  }

  void _askAiAboutScratchpad() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    Navigator.pop(context);
    ref.read(chatProvider.notifier).sendMessage('Analyze and explain this study formula/note:\n\n$text');
    context.push('/ai');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: AppColors.amber, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Quick Scratchpad & Formulas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              : TextField(
                  controller: _controller,
                  maxLines: 8,
                  autofocus: true,
                  onChanged: (val) => LocalDbService.instance.saveScratchpadContent(val),
                  decoration: InputDecoration(
                    hintText: 'Jot down quick formulas, equations, lecture bullet points, or thoughts here...\nAuto-saves instantly.',
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _askAiAboutScratchpad,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Explain with AI', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saveAsVaultNote,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text('Save to Vault', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
