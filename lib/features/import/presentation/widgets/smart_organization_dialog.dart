import 'package:flutter/material.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';

typedef SmartOrgDecision = ({
  String title,
  String subject,
  String? folder,
  List<String> labels,
  bool accepted,
});

/// Interactive modal for reviewing AI-suggested organization metadata.
///
/// CRITICAL SAFETY GUARANTEE:
/// User confirmation is mandatory. The system NEVER modifies user materials,
/// folders, or labels automatically without user clicking [Accept].
class SmartOrganizationDialog extends StatefulWidget {
  final SmartOrganizationSuggestion suggestion;
  final String originalFileName;
  final List<String> availableSubjects;
  final List<String> availableFolders;

  const SmartOrganizationDialog({
    super.key,
    required this.suggestion,
    required this.originalFileName,
    this.availableSubjects = const [],
    this.availableFolders = const [],
  });

  static Future<SmartOrgDecision?> show({
    required BuildContext context,
    required SmartOrganizationSuggestion suggestion,
    required String originalFileName,
    List<String> availableSubjects = const [],
    List<String> availableFolders = const [],
  }) {
    return showDialog<SmartOrgDecision>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SmartOrganizationDialog(
        suggestion: suggestion,
        originalFileName: originalFileName,
        availableSubjects: availableSubjects,
        availableFolders: availableFolders,
      ),
    );
  }

  @override
  State<SmartOrganizationDialog> createState() => _SmartOrganizationDialogState();
}

class _SmartOrganizationDialogState extends State<SmartOrganizationDialog> {
  late TextEditingController _titleController;
  late String _selectedSubject;
  String? _selectedFolder;
  late List<String> _selectedLabels;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.suggestion.suggestedTitle);
    _selectedSubject = widget.suggestion.suggestedSubject;
    _selectedFolder = widget.suggestion.suggestedFolder;
    _selectedLabels = List<String>.from(widget.suggestion.suggestedLabels);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _handleAccept() {
    Navigator.of(context).pop((
      title: _titleController.text.trim(),
      subject: _selectedSubject,
      folder: _selectedFolder,
      labels: _selectedLabels,
      accepted: true,
    ));
  }

  void _handleReject() {
    Navigator.of(context).pop((
      title: widget.originalFileName,
      subject: 'Unfiled',
      folder: null,
      labels: <String>[],
      accepted: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: AppColors.primaryLight, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Organization Suggestion',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Review suggested organization before applying',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 14),

              // Original file notice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Imported File: ${widget.originalFileName}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 14),

              // Title Field / Suggestion
              const Text(
                'Suggested Title',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              if (_isEditing)
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )
              else
                Text(
                  _titleController.text,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),

              const SizedBox(height: 12),

              // Subject Suggestion
              const Text(
                'Subject',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedSubject,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primaryLight),
              ),

              if (_selectedFolder != null && _selectedFolder!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Suggested Folder',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.folder_outlined, size: 16, color: AppColors.amber),
                    const SizedBox(width: 6),
                    Text(
                      _selectedFolder!,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Suggested Labels
              const Text(
                'Suggested Labels',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedLabels.map((l) {
                  return Chip(
                    label: Text(l, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                    backgroundColor: AppColors.surfaceElevated,
                    side: const BorderSide(color: AppColors.cardBorder),
                    deleteIcon: _isEditing ? const Icon(Icons.close, size: 14) : null,
                    onDeleted: _isEditing
                        ? () {
                            setState(() => _selectedLabels.remove(l));
                          }
                        : null,
                  );
                }).toList(),
              ),

              // AI Rationale
              if (widget.suggestion.rationale.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: AppColors.primaryLight),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.suggestion.rationale,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Decision Actions: Accept, Edit, Reject
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _handleReject,
                    child: const Text('Keep Original', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => setState(() => _isEditing = !_isEditing),
                    child: Text(_isEditing ? 'Done Editing' : 'Edit'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _handleAccept,
                    child: const Text('Accept'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
