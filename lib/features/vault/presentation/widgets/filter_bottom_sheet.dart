import 'package:flutter/material.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/features/academic/domain/models/models.dart';
import '../../domain/models/models.dart';

/// Modal bottom sheet allowing multi-facet filtering of Vault materials.
class FilterBottomSheet extends StatefulWidget {
  final MaterialFilter currentFilter;
  final List<AcademicSubjectEntity> availableSubjects;
  final List<VaultLabel> availableLabels;
  final ValueChanged<MaterialFilter> onApply;

  const FilterBottomSheet({
    super.key,
    required this.currentFilter,
    required this.availableSubjects,
    required this.availableLabels,
    required this.onApply,
  });

  static Future<void> show({
    required BuildContext context,
    required MaterialFilter currentFilter,
    required List<AcademicSubjectEntity> availableSubjects,
    required List<VaultLabel> availableLabels,
    required ValueChanged<MaterialFilter> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.bottomSheet,
      ),
      builder: (ctx) => FilterBottomSheet(
        currentFilter: currentFilter,
        availableSubjects: availableSubjects,
        availableLabels: availableLabels,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String? _selectedSubjectId;
  VaultMaterialType? _selectedType;
  late Set<String> _selectedLabelIds;
  late bool _isFavoriteOnly;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.currentFilter.subjectId;
    _selectedType = widget.currentFilter.type;
    _selectedLabelIds = Set<String>.from(widget.currentFilter.labelIds);
    _isFavoriteOnly = widget.currentFilter.isFavoriteOnly;
  }

  void _reset() {
    setState(() {
      _selectedSubjectId = null;
      _selectedType = null;
      _selectedLabelIds.clear();
      _isFavoriteOnly = false;
    });
  }

  void _apply() {
    final updated = widget.currentFilter.copyWith(
      subjectId: _selectedSubjectId,
      clearSubject: _selectedSubjectId == null,
      type: _selectedType,
      clearType: _selectedType == null,
      labelIds: _selectedLabelIds,
      isFavoriteOnly: _isFavoriteOnly,
    );
    widget.onApply(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Header Row: Title & Reset Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Materials',
                  style: AppTypography.title.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  child: Text(
                    'Reset All',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Material Type Filter
            Text(
              'Material Type',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All Types'),
                  selected: _selectedType == null,
                  onSelected: (_) => setState(() => _selectedType = null),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  backgroundColor: AppColors.surfaceSecondary,
                  labelStyle: AppTypography.caption.copyWith(
                    color: _selectedType == null ? AppColors.primaryLight : AppColors.textSecondary,
                    fontWeight: _selectedType == null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                ...VaultMaterialType.values.map((t) {
                  final isSel = _selectedType == t;
                  return ChoiceChip(
                    avatar: Icon(t.icon, size: 14, color: isSel ? t.color : AppColors.textMuted),
                    label: Text(t.label),
                    selected: isSel,
                    onSelected: (val) => setState(() => _selectedType = val ? t : null),
                    selectedColor: t.color.withValues(alpha: 0.15),
                    backgroundColor: AppColors.surfaceSecondary,
                    labelStyle: AppTypography.caption.copyWith(
                      color: isSel ? t.color : AppColors.textSecondary,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Subject Filter
            if (widget.availableSubjects.isNotEmpty) ...[
              Text(
                'Subject',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All Subjects'),
                      selected: _selectedSubjectId == null,
                      onSelected: (_) => setState(() => _selectedSubjectId = null),
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      backgroundColor: AppColors.surfaceSecondary,
                      labelStyle: AppTypography.caption.copyWith(
                        color: _selectedSubjectId == null
                            ? AppColors.primaryLight
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...widget.availableSubjects.map((s) {
                      final isSel = _selectedSubjectId == s.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s.name),
                          selected: isSel,
                          onSelected: (val) => setState(() => _selectedSubjectId = val ? s.id : null),
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          backgroundColor: AppColors.surfaceSecondary,
                          labelStyle: AppTypography.caption.copyWith(
                            color: isSel ? AppColors.primaryLight : AppColors.textSecondary,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Labels Multi-Select
            if (widget.availableLabels.isNotEmpty) ...[
              Text(
                'Labels',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.availableLabels.map((l) {
                  final isSel = _selectedLabelIds.contains(l.id);
                  return FilterChip(
                    label: Text(l.name),
                    selected: isSel,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedLabelIds.add(l.id);
                        } else {
                          _selectedLabelIds.remove(l.id);
                        }
                      });
                    },
                    selectedColor: l.color.withValues(alpha: 0.15),
                    backgroundColor: AppColors.surfaceSecondary,
                    labelStyle: AppTypography.caption.copyWith(
                      color: isSel ? l.color : AppColors.textSecondary,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Favorites Toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Favorites Only',
                style: AppTypography.body.copyWith(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                'Only show starred materials',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
              value: _isFavoriteOnly,
              activeThumbColor: AppColors.primaryLight,
              onChanged: (val) => setState(() => _isFavoriteOnly = val),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Apply Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                ),
                child: Text('Apply Filters', style: AppTypography.button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
