import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';

/// Settings screen for configuring institutional profile, degrees, and academic parameters.
class AcademicSettingsScreen extends ConsumerStatefulWidget {
  const AcademicSettingsScreen({super.key});

  @override
  ConsumerState<AcademicSettingsScreen> createState() =>
      _AcademicSettingsScreenState();
}

class _AcademicSettingsScreenState extends ConsumerState<AcademicSettingsScreen> {
  late final TextEditingController _institutionController;
  late final TextEditingController _degreeController;
  late final TextEditingController _branchController;
  late final TextEditingController _streamController;
  bool _isSaving = false;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    final state = ref.read(academicWorkspaceProvider);
    final profile = state.academicProfile;
    _institutionController = TextEditingController(
        text: profile?['institution_name'] as String? ?? '');
    _degreeController =
        TextEditingController(text: profile?['degree'] as String? ?? '');
    _branchController =
        TextEditingController(text: profile?['branch'] as String? ?? '');
    _streamController =
        TextEditingController(text: profile?['stream'] as String? ?? '');
  }

  @override
  void dispose() {
    _institutionController.dispose();
    _degreeController.dispose();
    _branchController.dispose();
    _streamController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _successMessage = null;
    });

    final notifier = ref.read(academicWorkspaceProvider.notifier);
    final ok = await notifier.updateProfile(
      institutionName: _institutionController.text.trim(),
      degree: _degreeController.text.trim(),
      branch: _branchController.text.trim(),
      stream: _streamController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (ok) {
          _successMessage = 'Academic profile updated successfully.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(academicWorkspaceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        title: 'Academic Settings',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.card,
                border: AppBorders.allStandard,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: AppRadius.brMd,
                      border: AppBorders.allStandard,
                    ),
                    child: const Icon(Icons.badge_outlined,
                        size: 20, color: AppColors.primaryLight),
                  ),
                  AppSpacing.h12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Academic Profile', style: AppTypography.title),
                        Text(
                          'Configure institutional details and current academic cycle.',
                          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            AppSpacing.v20,

            // Success feedback
            if (_successMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: AppRadius.brMd,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: AppColors.primaryLight, size: 18),
                    AppSpacing.h8,
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.primaryLight),
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.v16,
            ],

            // Form Fields
            if (state.isCollege) ...[
              AppTextField(
                label: 'Institution / University',
                hint: 'e.g. Stanford University, MIT',
                controller: _institutionController,
              ),
              AppSpacing.v16,
              AppTextField(
                label: 'Degree',
                hint: 'e.g. B.E / B.Tech, B.Sc',
                controller: _degreeController,
              ),
              AppSpacing.v16,
              AppTextField(
                label: 'Department / Major',
                hint: 'e.g. Computer Science Engineering',
                controller: _branchController,
              ),
              AppSpacing.v16,
            ] else if (state.isSchool) ...[
              AppTextField(
                label: 'School Name',
                hint: 'e.g. St. Xavier High School',
                controller: _institutionController,
              ),
              AppSpacing.v16,
              AppTextField(
                label: 'Stream (optional)',
                hint: 'e.g. Science, Commerce, Arts',
                controller: _streamController,
              ),
              AppSpacing.v16,
            ],

            // Current Semester Info Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: AppRadius.brMd,
                border: AppBorders.allStandard,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Current Active Semester', style: AppTypography.label),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySubtle,
                          borderRadius: AppRadius.brSm,
                        ),
                        child: Text(
                          state.currentPeriod?.name ?? 'Semester 1',
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            letterSpacing: 0.8,
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.v8,
                  Text(
                    'To advance to the next semester or view previous semesters, use the Academic Workspace switcher or history page.',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            AppSpacing.v24,

            AppButton.primary(
              text: 'Save Changes',
              isLoading: _isSaving,
              onPressed: _handleSave,
            ),
          ],
        ),
      ),
    );
  }
}
