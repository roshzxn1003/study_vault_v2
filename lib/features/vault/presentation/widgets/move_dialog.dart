import 'package:flutter/material.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/features/academic/domain/models/models.dart';
import '../../domain/models/models.dart';

/// Destination selected from MoveDialog.
class MoveDestination {
  final String? subjectId;
  final String? folderId;

  const MoveDestination({this.subjectId, this.folderId});
}

/// Dialog allowing relocation of materials or folders within the academic hierarchy.
class MoveDialog extends StatefulWidget {
  final String title;
  final List<AcademicSubjectEntity> availableSubjects;
  final List<VaultFolder> availableFolders;
  final String? currentSubjectId;
  final String? currentFolderId;
  final String? movingFolderId; // If set, disables selecting self or descendants

  const MoveDialog({
    super.key,
    required this.title,
    required this.availableSubjects,
    required this.availableFolders,
    this.currentSubjectId,
    this.currentFolderId,
    this.movingFolderId,
  });

  static Future<MoveDestination?> show({
    required BuildContext context,
    required String title,
    required List<AcademicSubjectEntity> availableSubjects,
    required List<VaultFolder> availableFolders,
    String? currentSubjectId,
    String? currentFolderId,
    String? movingFolderId,
  }) {
    return showDialog<MoveDestination>(
      context: context,
      builder: (ctx) => MoveDialog(
        title: title,
        availableSubjects: availableSubjects,
        availableFolders: availableFolders,
        currentSubjectId: currentSubjectId,
        currentFolderId: currentFolderId,
        movingFolderId: movingFolderId,
      ),
    );
  }

  @override
  State<MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<MoveDialog> {
  String? _selectedSubjectId;
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.currentSubjectId;
    _selectedFolderId = widget.currentFolderId;
  }

  bool _isInvalidFolder(String folderId) {
    if (widget.movingFolderId == null) return false;
    if (folderId == widget.movingFolderId) return true;

    // Cycle check: verify if folderId is a descendant of movingFolderId
    String? currentId = folderId;
    while (currentId != null && currentId.isNotEmpty) {
      final parent = widget.availableFolders.cast<VaultFolder?>().firstWhere(
            (f) => f?.id == currentId,
            orElse: () => null,
          );
      if (parent?.parentId == widget.movingFolderId) return true;
      currentId = parent?.parentId;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Filter folders by selected subject (or root folders)
    final filteredFolders = widget.availableFolders.where((f) {
      if (_selectedSubjectId != null && f.subjectId != null) {
        return f.subjectId == _selectedSubjectId;
      }
      return true;
    }).toList();

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      title: Text(widget.title, style: AppTypography.title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject Selection
              if (widget.availableSubjects.isNotEmpty) ...[
                Text(
                  'Select Subject',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedSubjectId,
                  dropdownColor: AppColors.surface,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: AppRadius.button),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No Subject (Vault Root)'),
                    ),
                    ...widget.availableSubjects.map((s) {
                      return DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedSubjectId = val;
                      _selectedFolderId = null;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Folder Selection
              Text(
                'Select Destination Folder',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // Root option and folders in RadioGroup
              RadioGroup<String?>(
                groupValue: _selectedFolderId,
                onChanged: (val) => setState(() => _selectedFolderId = val),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String?>(
                      title: Text('Root level (no folder)', style: AppTypography.body),
                      value: null,
                      activeColor: AppColors.primaryLight,
                      contentPadding: EdgeInsets.zero,
                    ),
                    ...filteredFolders.map((f) {
                      final isInvalid = _isInvalidFolder(f.id);
                      return RadioListTile<String?>(
                        title: Text(
                          f.name,
                          style: AppTypography.body.copyWith(
                            color: isInvalid ? AppColors.textMuted : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: isInvalid
                            ? Text('Cannot move into itself or subfolder', style: AppTypography.caption.copyWith(color: AppColors.error))
                            : null,
                        value: f.id,
                        activeColor: AppColors.primaryLight,
                        contentPadding: EdgeInsets.zero,
                        enabled: !isInvalid,
                      );
                    }),
                  ],
                ),
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
          onPressed: () {
            Navigator.pop(
              context,
              MoveDestination(
                subjectId: _selectedSubjectId,
                folderId: _selectedFolderId,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
          child: Text('Move', style: AppTypography.button),
        ),
      ],
    );
  }
}
