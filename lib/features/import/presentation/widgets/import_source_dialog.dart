import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/features/import/presentation/providers/import_provider.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';
import '../../domain/models/import_item.dart';

/// Modal dialog providing 5 primary ingestion avenues:
/// 1. File Picker (PDFs, Docs, etc.)
/// 2. Gallery (Images, Diagrams)
/// 3. Camera Capture
/// 4. Text Note
/// 5. Web Link / URL
class ImportSourceDialog extends ConsumerWidget {
  const ImportSourceDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ImportSourceDialog(),
    );
  }

  Future<void> _pickFiles(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'md', 'jpg', 'jpeg', 'png', 'webp'
        ],
      );

      if (result != null && result.files.isNotEmpty) {
        final files = result.files
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();

        if (files.isNotEmpty) {
          final shareService = ref.read(incomingShareServiceProvider);
          final items = await shareService.createItemsFromFiles(files, source: 'Files');
          if (items.isNotEmpty && context.mounted) {
            await ref.read(importProvider.notifier).stageItems(items);
            if (context.mounted) {
              context.push('/import');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
    }
  }

  Future<void> _pickFromGallery(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context);
    try {
      final picker = ImagePicker();
      final pickedImages = await picker.pickMultiImage();

      if (pickedImages.isNotEmpty) {
        final files = pickedImages.map((img) => File(img.path)).toList();
        final shareService = ref.read(incomingShareServiceProvider);
        final items = await shareService.createItemsFromFiles(files, source: 'Gallery');

        if (items.isNotEmpty && context.mounted) {
          await ref.read(importProvider.notifier).stageItems(items);
          if (context.mounted) {
            context.push('/import');
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking from gallery: $e');
    }
  }

  Future<void> _captureCamera(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context);
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        final file = File(photo.path);
        final shareService = ref.read(incomingShareServiceProvider);
        final items = await shareService.createItemsFromFiles([file], source: 'Camera');

        if (items.isNotEmpty && context.mounted) {
          await ref.read(importProvider.notifier).stageItems(items);
          if (context.mounted) {
            context.push('/import');
          }
        }
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
    }
  }

  void _showAddNoteDialog(BuildContext context, WidgetRef ref) {
    Navigator.pop(context);
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text('Create Note', style: AppTypography.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              style: AppTypography.body,
              decoration: const InputDecoration(
                labelText: 'Note Title',
                hintText: 'e.g. Process Scheduling Notes',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: contentController,
              maxLines: 5,
              style: AppTypography.body,
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'Type or paste study notes here...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTypography.button),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isEmpty && content.isEmpty) return;

              Navigator.pop(ctx);
              final item = ImportItem(
                id: UniqueKey().toString(),
                title: title.isNotEmpty ? title : 'Quick Note',
                type: VaultMaterialType.note,
                content: content,
                source: 'Manual Note',
              );

              await ref.read(importProvider.notifier).stageItems([item]);
              if (context.mounted) {
                context.push('/import');
              }
            },
            child: const Text('Add to Import'),
          ),
        ],
      ),
    );
  }

  void _showAddLinkDialog(BuildContext context, WidgetRef ref) {
    Navigator.pop(context);
    final titleController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text('Add Web Link', style: AppTypography.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              autofocus: true,
              keyboardType: TextInputType.url,
              style: AppTypography.body,
              decoration: const InputDecoration(
                labelText: 'URL / Link',
                hintText: 'https://...',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: titleController,
              style: AppTypography.body,
              decoration: const InputDecoration(
                labelText: 'Title (Optional)',
                hintText: 'e.g. Distributed Systems Paper',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTypography.button),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty) return;

              Navigator.pop(ctx);
              var displayTitle = titleController.text.trim();
              if (displayTitle.isEmpty) {
                try {
                  displayTitle = Uri.parse(url).host;
                } catch (_) {
                  displayTitle = 'Web Resource';
                }
              }

              final item = ImportItem(
                id: UniqueKey().toString(),
                title: displayTitle.isNotEmpty ? displayTitle : 'Web Resource',
                type: VaultMaterialType.link,
                content: url,
                source: 'Web Link',
              );

              await ref.read(importProvider.notifier).stageItems([item]);
              if (context.mounted) {
                context.push('/import');
              }
            },
            child: const Text('Add to Import'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                'Add Material',
                style: AppTypography.headline.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                'Import study materials, notes, or web references into your Vault.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildOption(
              icon: Icons.upload_file_rounded,
              color: const Color(0xFF3B82F6),
              title: 'Upload Files',
              subtitle: 'Import PDFs, documents, presentations, or spreadsheets',
              onTap: () => _pickFiles(context, ref),
            ),
            _buildOption(
              icon: Icons.photo_library_rounded,
              color: const Color(0xFF10B981),
              title: 'Choose from Gallery',
              subtitle: 'Select whiteboard diagrams, handwritten notes, or images',
              onTap: () => _pickFromGallery(context, ref),
            ),
            _buildOption(
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFFF59E0B),
              title: 'Scan with Camera',
              subtitle: 'Take a clear photo of lecture slides or textbook pages',
              onTap: () => _captureCamera(context, ref),
            ),
            _buildOption(
              icon: Icons.edit_note_rounded,
              color: const Color(0xFF8B5CF6),
              title: 'Create Text Note',
              subtitle: 'Type or paste quick summaries, formulas, or lecture notes',
              onTap: () => _showAddNoteDialog(context, ref),
            ),
            _buildOption(
              icon: Icons.link_rounded,
              color: const Color(0xFFEC4899),
              title: 'Add Web Link',
              subtitle: 'Save online articles, research papers, or documentation',
              onTap: () => _showAddLinkDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppRadius.card,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
