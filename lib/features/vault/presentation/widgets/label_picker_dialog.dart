import 'package:flutter/material.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import '../../domain/models/models.dart';

/// Dialog allowing multi-selection of labels for a material, with inline label creation.
class LabelPickerDialog extends StatefulWidget {
  final List<VaultLabel> availableLabels;
  final List<String> initialSelectedLabelIds;
  final Future<VaultLabel?> Function(String name)? onCreateLabel;

  const LabelPickerDialog({
    super.key,
    required this.availableLabels,
    required this.initialSelectedLabelIds,
    this.onCreateLabel,
  });

  static Future<List<String>?> show({
    required BuildContext context,
    required List<VaultLabel> availableLabels,
    required List<String> initialSelectedLabelIds,
    Future<VaultLabel?> Function(String name)? onCreateLabel,
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => LabelPickerDialog(
        availableLabels: availableLabels,
        initialSelectedLabelIds: initialSelectedLabelIds,
        onCreateLabel: onCreateLabel,
      ),
    );
  }

  @override
  State<LabelPickerDialog> createState() => _LabelPickerDialogState();
}

class _LabelPickerDialogState extends State<LabelPickerDialog> {
  late final List<VaultLabel> _labels;
  late final Set<String> _selectedIds;
  final TextEditingController _newLabelCtrl = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _labels = List.from(widget.availableLabels);
    _selectedIds = Set.from(widget.initialSelectedLabelIds);
  }

  @override
  void dispose() {
    _newLabelCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleCreateLabel() async {
    final name = _newLabelCtrl.text.trim();
    if (name.isEmpty) return;

    if (widget.onCreateLabel != null) {
      setState(() => _isCreating = true);
      try {
        final newLabel = await widget.onCreateLabel!(name);
        if (newLabel != null) {
          setState(() {
            _labels.add(newLabel);
            _selectedIds.add(newLabel.id);
            _newLabelCtrl.clear();
          });
        }
      } finally {
        if (mounted) setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      title: Row(
        children: [
          const Icon(Icons.label_outline_rounded, color: AppColors.primaryLight, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text('Edit Labels', style: AppTypography.title),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Inline New Label Creator
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newLabelCtrl,
                      style: AppTypography.body.copyWith(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'New label name...',
                        hintStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: AppRadius.button),
                      ),
                      onSubmitted: (_) => _handleCreateLabel(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    icon: _isCreating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryLight),
                    onPressed: _isCreating ? null : _handleCreateLabel,
                    tooltip: 'Add label',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Labels List
              if (_labels.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(
                    child: Text(
                      'No labels available',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _labels.map((l) {
                    final isSel = _selectedIds.contains(l.id);
                    return FilterChip(
                      label: Text(l.name),
                      selected: isSel,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedIds.add(l.id);
                          } else {
                            _selectedIds.remove(l.id);
                          }
                        });
                      },
                      selectedColor: l.color.withValues(alpha: 0.2),
                      backgroundColor: AppColors.surfaceSecondary,
                      labelStyle: AppTypography.caption.copyWith(
                        color: isSel ? l.color : AppColors.textSecondary,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: AppTypography.button.copyWith(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedIds.toList()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
          child: Text('Apply', style: AppTypography.button),
        ),
      ],
    );
  }
}
