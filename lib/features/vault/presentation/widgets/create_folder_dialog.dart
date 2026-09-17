import 'package:flutter/material.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';

/// Dialog to create a new folder with non-empty validation.
class CreateFolderDialog extends StatefulWidget {
  final String title;
  final String? parentFolderName;

  const CreateFolderDialog({
    super.key,
    this.title = 'Create Folder',
    this.parentFolderName,
  });

  static Future<String?> show({
    required BuildContext context,
    String title = 'Create Folder',
    String? parentFolderName,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => CreateFolderDialog(
        title: title,
        parentFolderName: parentFolderName,
      ),
    );
  }

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Folder name cannot be empty');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: AppRadius.button,
            ),
            child: const Icon(Icons.create_new_folder_outlined, color: AppColors.primaryLight, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(widget.title, style: AppTypography.title),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.parentFolderName != null) ...[
            Text(
              'Inside: ${widget.parentFolderName}',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            style: AppTypography.body.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Folder Name',
              hintText: 'e.g., Unit 3, Revision, Lab Notes',
              errorText: _errorText,
              labelStyle: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              hintStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
              border: OutlineInputBorder(borderRadius: AppRadius.button),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: AppTypography.button.copyWith(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
          child: Text('Create', style: AppTypography.button),
        ),
      ],
    );
  }
}
