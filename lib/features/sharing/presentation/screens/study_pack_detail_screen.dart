import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/widgets.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';
import '../providers/sharing_providers.dart';
import '../../domain/models/models.dart';
import '../../data/repositories/sharing_repository.dart';
import '../widgets/share_material_dialog.dart';

/// Screen presenting details, contents, sharing, and save-copy capabilities for a Study Pack.
class StudyPackDetailScreen extends ConsumerStatefulWidget {
  final StudyPack pack;

  const StudyPackDetailScreen({super.key, required this.pack});

  @override
  ConsumerState<StudyPackDetailScreen> createState() => _StudyPackDetailScreenState();
}

class _StudyPackDetailScreenState extends ConsumerState<StudyPackDetailScreen> {
  bool _isSavingToVault = false;

  String get _currentUserId => ref.read(authRepositoryProvider).getCurrentUser()?.id ?? 'guest';
  bool get _isOwner => widget.pack.isOwner(_currentUserId);

  Future<void> _handleSaveToVault() async {
    setState(() => _isSavingToVault = true);

    try {
      final academic = ref.read(academicWorkspaceProvider);
      final wsId = academic.activeWorkspace?.id;
      if (wsId == null) {
        throw Exception('Please set up an active workspace first.');
      }

      final repo = ref.read(sharingRepositoryProvider);
      await repo.saveStudyPackToVault(
        pack: widget.pack,
        currentUserId: _currentUserId,
        workspaceId: wsId,
        academicPeriodId: academic.activePeriod?.id,
      );

      ref.read(vaultProvider.notifier).loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved all ${widget.pack.items.length} materials into your personal Vault!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e is SharingOfflineException
            ? e.message
            : 'Could not save study pack to your Vault. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingToVault = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.pack;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Study Pack', style: AppTypography.subtitle.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Study Pack',
            onPressed: () {
              ShareMaterialDialog.show(
                context: context,
                resourceId: pack.id,
                resourceTitle: 'Study Pack: ${pack.name}',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pack Banner
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.card,
                      border: AppBorders.allStandard,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                borderRadius: AppRadius.chip,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.folder_zip_outlined, size: 14, color: Color(0xFF8B5CF6)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${pack.items.length} Materials',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(pack.name, style: AppTypography.title.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'Created by ${pack.displayOwner}',
                          style: AppTypography.caption.copyWith(color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                        ),
                        if (pack.description?.isNotEmpty == true) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            pack.description!,
                            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryLight,
                                foregroundColor: Colors.white,
                                shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                              ),
                              icon: const Icon(Icons.share_rounded, size: 16),
                              label: const Text('Share Pack'),
                              onPressed: () {
                                ShareMaterialDialog.show(
                                  context: context,
                                  resourceId: pack.id,
                                  resourceTitle: 'Study Pack: ${pack.name}',
                                );
                              },
                            ),
                            if (!_isOwner)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.surfaceSecondary,
                                  foregroundColor: AppColors.textPrimary,
                                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                                ),
                                icon: const Icon(Icons.save_alt_rounded, size: 16),
                                label: Text(_isSavingToVault ? 'Saving...' : 'Save Study Pack to My Vault'),
                                onPressed: _isSavingToVault ? null : _handleSaveToVault,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Curated Materials',
                    style: AppTypography.subtitle.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (pack.items.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('This study pack contains no materials.', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    )
                  else
                    Card(
                      color: AppColors.surface,
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pack.items.length,
                        separatorBuilder: (_, _) => const AppDivider(),
                        itemBuilder: (ctx, index) {
                          final item = pack.items[index];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.12),
                              child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                            ),
                            title: Text(item.materialTitle, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                            subtitle: Text(item.materialType, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                            trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                            onTap: () {
                              context.push('/material/${item.materialId}');
                            },
                          );
                        },
                      ),
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
