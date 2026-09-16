import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/providers/database_providers.dart';
import 'package:study_vault/features/scan/presentation/providers/scan_provider.dart';

class OCRReviewScreen extends ConsumerStatefulWidget {
  const OCRReviewScreen({super.key});

  @override
  ConsumerState<OCRReviewScreen> createState() => _OCRReviewScreenState();
}

class _OCRReviewScreenState extends ConsumerState<OCRReviewScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final extractedText = ref.read(scanProvider).extractedText ?? "";
    _titleController = TextEditingController(text: "Scanned Notes ${DateTime.now().toString().split(' ')[0]}");
    _contentController = TextEditingController(text: extractedText);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveScannedNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No text to save")));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final noteRepo = ref.read(noteRepositoryProvider);
      await noteRepo.createNote(
        title: title.isEmpty ? "Scanned Note" : title,
        content: content,
      );

      ref.read(scanProvider.notifier).clear();
      ref.invalidate(noteRepositoryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Saved scanned note to your Study Vault!"),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); // Pop review screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Extracted Notes'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Note Title',
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Extracted text will appear here...',
                  alignLabelWithHint: true,
                  labelText: 'Extracted Content',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: _isSaving ? null : _saveScannedNote,
                    child: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save to Vault'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
