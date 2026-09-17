import 'package:flutter/material.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';

/// General rename dialog for folders and materials.
class RenameDialog extends StatefulWidget {
  final String title;
  final String initialValue;
  final String labelText;

  const RenameDialog({
    super.key,
    required this.title,
    required this.initialValue,
    this.labelText = 'New Name',
  });

  static Future<String?> show({
    required BuildContext context,
    required String title,
    required String initialValue,
    String labelText = 'New Name',
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => RenameDialog(
        title: title,
        initialValue: initialValue,
        labelText: labelText,
      ),
    );
  }

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Name cannot be empty');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      title: Text(widget.title, style: AppTypography.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: AppTypography.body.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: widget.labelText,
          errorText: _errorText,
          border: OutlineInputBorder(borderRadius: AppRadius.button),
        ),
        onSubmitted: (_) => _submit(),
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
          child: Text('Save', style: AppTypography.button),
        ),
      ],
    );
  }
}
