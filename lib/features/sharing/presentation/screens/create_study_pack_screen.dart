import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/widgets.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';
import '../providers/sharing_providers.dart';

/// Screen allowing students to curate selected materials into a Study Pack.
class CreateStudyPackScreen extends ConsumerStatefulWidget {
  final List<String>? initialMaterialIds;

  const CreateStudyPackScreen({super.key, this.initialMaterialIds});

  @override
  ConsumerState<CreateStudyPackScreen> createState() => _CreateStudyPackScreenState();
}

class _CreateStudyPackScreenState extends ConsumerState<CreateStudyPackScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final Set<String> _selectedMaterialIds = {};
  bool _isCreating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialMaterialIds != null) {
      _selectedMaterialIds.addAll(widget.initialMaterialIds!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter a name for the Study Pack.');
      return;
    }
    if (_selectedMaterialIds.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one material.');
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final vaultState = ref.read(vaultProvider);
      final titles = <String, String>{};
      final types = <String, String>{};

      for (final m in vaultState.materials) {
        if (_selectedMaterialIds.contains(m.id)) {
          titles[m.id] = m.title;
          types[m.id] = m.type.toDbString();
        }
      }

      final pack = await ref.read(studyPacksProvider.notifier).createStudyPack(
        name: name,
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        materialIds: _selectedMaterialIds.toList(),
        materialTitles: titles,
        materialTypes: types,
      );

      if (mounted) {
        context.pop(pack);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created Study Pack "${pack.name}"!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to create study pack: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultProvider);
    final materials = vaultState.materials;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Create Study Pack', style: AppTypography.subtitle.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Pack Name', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.xs),
                  AppTextField(
                    controller: _nameController,
                    hint: 'e.g. Operating Systems — Unit 3 Revision',
                    autofocus: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Description (optional)', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.xs),
                  AppTextField(
                    controller: _descController,
                    hint: 'Revision materials, diagrams, and questions for upcoming exams',
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Materials (${_selectedMaterialIds.length} selected)',
                        style: AppTypography.subtitle.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      if (materials.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedMaterialIds.length == materials.length) {
                                _selectedMaterialIds.clear();
                              } else {
                                _selectedMaterialIds.addAll(materials.map((m) => m.id));
                              }
                            });
                          },
                          child: Text(_selectedMaterialIds.length == materials.length ? 'Deselect All' : 'Select All'),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  if (materials.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: AppRadius.card,
                      ),
                      child: const Center(
                        child: Text('No materials in Vault to include.', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    )
                  else
                    Card(
                      color: AppColors.surface,
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: materials.length,
                        separatorBuilder: (_, _) => const AppDivider(),
                        itemBuilder: (ctx, index) {
                          final mat = materials[index];
                          final isSelected = _selectedMaterialIds.contains(mat.id);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedMaterialIds.add(mat.id);
                                } else {
                                  _selectedMaterialIds.remove(mat.id);
                                }
                              });
                            },
                            title: Text(mat.title, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${mat.type.label} • ${mat.locationSubtitle}',
                              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                            ),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
                    ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ],

                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    text: 'Create Study Pack',
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    isLoading: _isCreating,
                    onPressed: _isCreating ? null : _handleCreate,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
