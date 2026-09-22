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
  final _searchController = TextEditingController();
  final Set<String> _selectedMaterialIds = {};
  String _searchQuery = '';
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
    _searchController.dispose();
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
    final allMaterials = vaultState.materials;
    final filteredMaterials = _searchQuery.isEmpty
        ? allMaterials
        : allMaterials.where((m) => m.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                AppButton(
                  text: 'Create Study Pack (${_selectedMaterialIds.length})',
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  isLoading: _isCreating,
                  onPressed: _isCreating ? null : _handleCreate,
                ),
              ],
            ),
          ),
        ),
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

                  // Section Header with Selection Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Materials (${_selectedMaterialIds.length}/${allMaterials.length})',
                        style: AppTypography.subtitle.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      if (allMaterials.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedMaterialIds.addAll(filteredMaterials.map((m) => m.id));
                                });
                              },
                              child: const Text('Select All'),
                            ),
                            if (_selectedMaterialIds.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedMaterialIds.clear();
                                  });
                                },
                                child: const Text('Clear', style: TextStyle(color: AppColors.textMuted)),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  if (allMaterials.length > 5) ...[
                    // Material search filter
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Filter materials...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.cardBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  if (allMaterials.isEmpty)
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
                  else if (filteredMaterials.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: AppRadius.card,
                      ),
                      child: const Center(
                        child: Text('No materials match your filter.', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    )
                  else
                    Card(
                      color: AppColors.surface,
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredMaterials.length,
                        separatorBuilder: (_, _) => const AppDivider(),
                        itemBuilder: (ctx, index) {
                          final mat = filteredMaterials[index];
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

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
