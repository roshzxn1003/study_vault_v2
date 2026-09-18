import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/widgets.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';
import '../providers/sharing_providers.dart';
import '../../domain/models/models.dart';

/// Modal dialog allowing a recipient to save an independent personal copy of a shared resource into their Vault.
class SaveToVaultDialog extends ConsumerStatefulWidget {
  final ShareItem share;

  const SaveToVaultDialog({super.key, required this.share});

  static Future<bool?> show(BuildContext context, {required ShareItem share}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SaveToVaultDialog(share: share),
    );
  }

  @override
  ConsumerState<SaveToVaultDialog> createState() => _SaveToVaultDialogState();
}

class _SaveToVaultDialogState extends ConsumerState<SaveToVaultDialog> {
  String? _selectedWorkspaceId;
  String? _selectedPeriodId;
  String? _selectedSubjectId;
  String? _selectedFolderId;
  final List<String> _selectedLabelIds = [];

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final academic = ref.read(academicWorkspaceProvider);
      setState(() {
        _selectedWorkspaceId = academic.activeWorkspace?.id;
        _selectedPeriodId = academic.activePeriod?.id;
        if (academic.subjects.isNotEmpty) {
          _selectedSubjectId = academic.subjects.first.id;
        }
      });
    });
  }

  Future<void> _handleSave() async {
    if (_selectedWorkspaceId == null) {
      setState(() => _errorMessage = 'Please select a destination workspace.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final currentUserId = authRepo.getCurrentUser()?.id ?? 'guest';
      final sharingRepo = ref.read(sharingRepositoryProvider);

      await sharingRepo.saveCopyToVault(
        share: widget.share,
        currentUserId: currentUserId,
        workspaceId: _selectedWorkspaceId!,
        academicPeriodId: _selectedPeriodId,
        subjectId: _selectedSubjectId,
        folderId: _selectedFolderId,
        labelIds: _selectedLabelIds,
      );

      // Refresh personal vault
      ref.read(vaultProvider.notifier).loadData();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "${widget.share.resourceTitle}" as a personal copy in your Vault!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to save copy: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final academicState = ref.watch(academicWorkspaceProvider);
    final vaultState = ref.watch(vaultProvider);

    final workspaces = academicState.workspaces;
    final periods = academicState.periods;
    final subjects = academicState.subjects;
    final folders = vaultState.folders;
    final availableLabels = vaultState.labels;

    final sharer = widget.share.ownerUsername != null
        ? '@${widget.share.ownerUsername!.replaceAll('@', '')}'
        : 'Scholar';

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      title: Row(
        children: [
          const Icon(Icons.save_alt_rounded, color: AppColors.primaryLight, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Save to My Vault',
              style: AppTypography.title.copyWith(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Material Source Details
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.card,
                  border: AppBorders.allStandard,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.share.resourceTitle,
                      style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Shared by $sharer',
                      style: AppTypography.caption.copyWith(color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Once saved, you own your copy independently in your personal Vault.',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Destination: Workspace
              Text('Workspace', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: _selectedWorkspaceId,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: AppRadius.button),
                ),
                items: workspaces.map((w) {
                  return DropdownMenuItem(value: w.id, child: Text(w.name));
                }).toList(),
                onChanged: (val) => setState(() => _selectedWorkspaceId = val),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Destination: Academic Period
              if (periods.isNotEmpty) ...[
                Text('Academic Period', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPeriodId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: AppRadius.button),
                  ),
                  items: periods.map((p) {
                    return DropdownMenuItem(value: p.id, child: Text(p.name));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedPeriodId = val),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Destination: Subject
              if (subjects.isNotEmpty) ...[
                Text('Subject', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSubjectId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: AppRadius.button),
                  ),
                  items: subjects.map((s) {
                    return DropdownMenuItem(value: s.id, child: Text(s.name));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedSubjectId = val),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Destination: Folder
              if (folders.isNotEmpty) ...[
                Text('Folder (Optional)', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedFolderId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: AppRadius.button),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Vault Root (No Folder)')),
                    ...folders.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))),
                  ],
                  onChanged: (val) => setState(() => _selectedFolderId = val),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Destination: Labels
              if (availableLabels.isNotEmpty) ...[
                Text('Labels', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: availableLabels.map((lbl) {
                    final isSelected = _selectedLabelIds.contains(lbl.id);
                    return FilterChip(
                      label: Text(lbl.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedLabelIds.add(lbl.id);
                          } else {
                            _selectedLabelIds.remove(lbl.id);
                          }
                        });
                      },
                      selectedColor: AppColors.primaryLight.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.primaryLight,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSelected ? AppColors.primaryLight : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        AppButton(
          text: 'Save Copy',
          icon: const Icon(Icons.save_alt_rounded),
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _handleSave,
        ),
      ],
    );
  }
}
