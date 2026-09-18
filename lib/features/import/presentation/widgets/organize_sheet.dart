import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/features/academic/domain/models/models.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/onboarding/domain/models/onboarding_models.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';
import 'package:study_vault/features/vault/presentation/widgets/label_picker_dialog.dart';
import 'package:study_vault/core/providers/ai_providers.dart';
import 'package:study_vault/features/import/presentation/widgets/smart_organization_dialog.dart';

typedef OrganizeResult = ({
  String workspaceId,
  String academicPeriodId,
  String subjectId,
  String? folderId,
  List<String> labelIds,
});

/// Modal sheet implementing Save & Organize (Section 15 & 19).
/// Allows choosing Workspace, Period, Subject, Folder, and Labels from real database records.
class OrganizeSheet extends ConsumerStatefulWidget {
  final String title;
  final String? initialSubjectId;
  final String? initialFolderId;

  const OrganizeSheet({
    super.key,
    this.title = 'Organize Material',
    this.initialSubjectId,
    this.initialFolderId,
  });

  static Future<OrganizeResult?> show({
    required BuildContext context,
    String title = 'Organize Material',
    String? initialSubjectId,
    String? initialFolderId,
  }) {
    return showModalBottomSheet<OrganizeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => OrganizeSheet(
        title: title,
        initialSubjectId: initialSubjectId,
        initialFolderId: initialFolderId,
      ),
    );
  }

  @override
  ConsumerState<OrganizeSheet> createState() => _OrganizeSheetState();
}

class _OrganizeSheetState extends ConsumerState<OrganizeSheet> {
  AcademicWorkspace? _selectedWorkspace;
  AcademicPeriodEntity? _selectedPeriod;
  AcademicSubjectEntity? _selectedSubject;
  VaultFolder? _selectedFolder;
  final Set<String> _selectedLabelIds = {};

  List<AcademicPeriodEntity> _availablePeriods = [];
  List<AcademicSubjectEntity> _availableSubjects = [];
  List<VaultFolder> _availableFolders = [];
  List<VaultLabel> _availableLabels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    final academicState = ref.read(academicWorkspaceProvider);
    final vaultRepo = ref.read(vaultRepositoryProvider);
    final authUser = ref.read(authRepositoryProvider).getCurrentUser();
    final userId = authUser?.id ?? 'guest';

    _selectedWorkspace = academicState.activeWorkspace;
    _selectedPeriod = academicState.currentPeriod;

    // Collect all periods across years
    final periods = <AcademicPeriodEntity>[];
    for (final year in academicState.history) {
      periods.addAll(year.periods.map((p) => p.period));
    }
    if (_selectedPeriod != null && !periods.any((p) => p.id == _selectedPeriod!.id)) {
      periods.insert(0, _selectedPeriod!);
    }
    _availablePeriods = periods;
    if (_selectedPeriod == null && periods.isNotEmpty) {
      _selectedPeriod = periods.first;
    }

    // Load subjects
    _availableSubjects = academicState.subjects;
    if (widget.initialSubjectId != null) {
      _selectedSubject = _availableSubjects.cast<AcademicSubjectEntity?>().firstWhere(
            (s) => s?.id == widget.initialSubjectId,
            orElse: () => null,
          );
    }
    _selectedSubject ??= _availableSubjects.isNotEmpty ? _availableSubjects.first : null;

    // Load folders for selected subject
    if (_selectedSubject != null) {
      _availableFolders = await vaultRepo.getFolders(
        userId: userId,
        subjectId: _selectedSubject!.id,
      );
      if (widget.initialFolderId != null) {
        _selectedFolder = _availableFolders.cast<VaultFolder?>().firstWhere(
              (f) => f?.id == widget.initialFolderId,
              orElse: () => null,
            );
      }
    }

    // Load labels
    _availableLabels = await vaultRepo.getLabels(userId: userId);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onSubjectChanged(AcademicSubjectEntity? subject) async {
    if (subject == null) return;
    setState(() {
      _selectedSubject = subject;
      _selectedFolder = null;
    });

    final vaultRepo = ref.read(vaultRepositoryProvider);
    final authUser = ref.read(authRepositoryProvider).getCurrentUser();
    final folders = await vaultRepo.getFolders(
      userId: authUser?.id ?? 'guest',
      subjectId: subject.id,
    );

    if (mounted) {
      setState(() => _availableFolders = folders);
    }
  }

  void _onAddLabel() async {
    final vaultRepo = ref.read(vaultRepositoryProvider);
    final authUser = ref.read(authRepositoryProvider).getCurrentUser();
    final result = await LabelPickerDialog.show(
      context: context,
      availableLabels: _availableLabels,
      initialSelectedLabelIds: _selectedLabelIds.toList(),
      onCreateLabel: (name) async {
        return await vaultRepo.createLabel(
          userId: authUser?.id ?? 'guest',
          name: name,
        );
      },
    );
    if (result != null && mounted) {
      final labels = await vaultRepo.getLabels(userId: authUser?.id ?? 'guest');
      setState(() {
        _availableLabels = labels;
        _selectedLabelIds.clear();
        _selectedLabelIds.addAll(result);
      });
    }
  }

  bool _isSuggestingAi = false;

  Future<void> _runSmartAiSuggest() async {
    setState(() => _isSuggestingAi = true);
    try {
      final orchestrator = ref.read(aiOrchestratorProvider);
      final suggestion = await orchestrator.suggestOrganization(
        widget.title,
        rawFileName: widget.title,
        existingSubjects: _availableSubjects.map((s) => s.name).toList(),
        existingFolders: _availableFolders.map((f) => f.name).toList(),
        existingLabels: _availableLabels.map((l) => l.name).toList(),
      );

      if (!mounted) return;

      final decision = await SmartOrganizationDialog.show(
        context: context,
        suggestion: suggestion,
        originalFileName: widget.title,
        availableSubjects: _availableSubjects.map((s) => s.name).toList(),
        availableFolders: _availableFolders.map((f) => f.name).toList(),
      );

      if (decision != null && decision.accepted && mounted) {
        // Apply suggested subject
        final matchedSubject = _availableSubjects.cast<AcademicSubjectEntity?>().firstWhere(
          (s) => s?.name.toLowerCase() == decision.subject.toLowerCase(),
          orElse: () => _selectedSubject ?? (_availableSubjects.isNotEmpty ? _availableSubjects.first : null),
        );
        if (matchedSubject != null) {
          await _onSubjectChanged(matchedSubject);
        }

        // Apply suggested folder
        if (decision.folder != null && decision.folder!.isNotEmpty) {
          final matchedFolder = _availableFolders.cast<VaultFolder?>().firstWhere(
            (f) => f?.name.toLowerCase() == decision.folder!.toLowerCase(),
            orElse: () => _selectedFolder,
          );
          if (matchedFolder != null) {
            setState(() => _selectedFolder = matchedFolder);
          }
        }

        // Apply suggested labels
        if (decision.labels.isNotEmpty) {
          final vaultRepo = ref.read(vaultRepositoryProvider);
          final authUser = ref.read(authRepositoryProvider).getCurrentUser();
          final userId = authUser?.id ?? 'guest';
          for (final lbl in decision.labels) {
            final existing = _availableLabels.cast<VaultLabel?>().firstWhere(
              (l) => l?.name.toLowerCase() == lbl.toLowerCase(),
              orElse: () => null,
            );
            if (existing != null) {
              _selectedLabelIds.add(existing.id);
            } else {
              final created = await vaultRepo.createLabel(userId: userId, name: lbl);
              _selectedLabelIds.add(created.id);
            }
          }
          final refreshed = await vaultRepo.getLabels(userId: userId);
          setState(() => _availableLabels = refreshed);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Suggestion error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSuggestingAi = false);
      }
    }
  }

  void _submit() {
    if (_selectedWorkspace == null || _selectedPeriod == null || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an Academic Period and Subject.')),
      );
      return;
    }

    Navigator.pop<OrganizeResult>(context, (
      workspaceId: _selectedWorkspace!.id,
      academicPeriodId: _selectedPeriod!.id,
      subjectId: _selectedSubject!.id,
      folderId: _selectedFolder?.id,
      labelIds: _selectedLabelIds.toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final academicState = ref.watch(academicWorkspaceProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.md,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: ListView(
            controller: scrollController,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: AppTypography.headline.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Assign academic location, semester, and tags for long-term organization.',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: AppColors.primarySubtle,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isSuggestingAi
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome, size: 14, color: AppColors.primaryLight),
                    label: const Text(
                      'AI Suggest',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                    ),
                    onPressed: _isSuggestingAi ? null : _runSmartAiSuggest,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // 1. Workspace Selector
              _buildSectionLabel('Workspace'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: AppRadius.card,
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AcademicWorkspace>(
                    value: _selectedWorkspace,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    items: academicState.workspaces.map((ws) {
                      return DropdownMenuItem(
                        value: ws,
                        child: Text(ws.name, style: AppTypography.body),
                      );
                    }).toList(),
                    onChanged: (ws) => setState(() => _selectedWorkspace = ws),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 2. Academic Period Selector
              _buildSectionLabel(
                _selectedWorkspace?.purpose == OnboardingPurpose.college
                    ? 'Semester / Term'
                    : _selectedWorkspace?.purpose == OnboardingPurpose.school
                        ? 'Class / Grade'
                        : 'Topic',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: AppRadius.card,
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AcademicPeriodEntity>(
                    value: _selectedPeriod,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    items: _availablePeriods.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(p.name, style: AppTypography.body),
                      );
                    }).toList(),
                    onChanged: (p) => setState(() => _selectedPeriod = p),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 3. Subject Selector
              _buildSectionLabel('Subject'),
              if (_availableSubjects.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: AppRadius.card,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'No subjects found in this period.',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: AppRadius.card,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AcademicSubjectEntity>(
                      value: _selectedSubject,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      items: _availableSubjects.map((sub) {
                        return DropdownMenuItem(
                          value: sub,
                          child: Text(
                            sub.code != null ? '${sub.name} (${sub.code})' : sub.name,
                            style: AppTypography.body,
                          ),
                        );
                      }).toList(),
                      onChanged: _onSubjectChanged,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),

              // 4. Folder Selector (Optional)
              _buildSectionLabel('Folder (Optional)'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: AppRadius.card,
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<VaultFolder?>(
                    value: _selectedFolder,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    items: [
                      DropdownMenuItem<VaultFolder?>(
                        value: null,
                        child: Text('Vault Root (No folder)', style: AppTypography.body),
                      ),
                      ..._availableFolders.map((f) {
                        return DropdownMenuItem<VaultFolder?>(
                          value: f,
                          child: Text(f.name, style: AppTypography.body),
                        );
                      }),
                    ],
                    onChanged: (f) => setState(() => _selectedFolder = f),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 5. Labels (Multi-Select Chips)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionLabel('Labels'),
                  TextButton.icon(
                    onPressed: _onAddLabel,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Label'),
                  ),
                ],
              ),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: _availableLabels.map((l) {
                  final isSelected = _selectedLabelIds.contains(l.id);
                  return FilterChip(
                    selected: isSelected,
                    label: Text(l.name),
                    labelStyle: AppTypography.caption.copyWith(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    selectedColor: l.color,
                    backgroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.chip,
                      side: BorderSide(
                        color: isSelected ? l.color : AppColors.border,
                      ),
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedLabelIds.add(l.id);
                        } else {
                          _selectedLabelIds.remove(l.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Save Button
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                ),
                child: Text('Save & Organize', style: AppTypography.button),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
