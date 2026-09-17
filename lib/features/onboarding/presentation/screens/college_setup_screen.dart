import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:study_vault/features/onboarding/presentation/widgets/onboarding_scaffold.dart';

/// Screen 2A: College profile and current semester setup.
class CollegeSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const CollegeSetupScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  ConsumerState<CollegeSetupScreen> createState() => _CollegeSetupScreenState();
}

class _CollegeSetupScreenState extends ConsumerState<CollegeSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _institutionController;
  late final TextEditingController _degreeController;
  late final TextEditingController _branchController;
  late final TextEditingController _yearController;
  late final TextEditingController _semesterController;

  static const List<String> _suggestedSemesters = [
    'Semester 1',
    'Semester 2',
    'Semester 3',
    'Semester 4',
    'Semester 5',
    'Semester 6',
    'Semester 7',
    'Semester 8',
  ];

  static const List<String> _commonDegrees = [
    'B.E / B.Tech',
    'B.Sc',
    'BCA',
    'B.Com',
    'BBA',
    'M.Tech',
    'MBA',
  ];

  @override
  void initState() {
    super.initState();
    final existing = ref.read(onboardingProvider).collegeData;
    _institutionController = TextEditingController(text: existing?.institutionName ?? '');
    _degreeController = TextEditingController(text: existing?.degree ?? '');
    _branchController = TextEditingController(text: existing?.branch ?? '');
    _yearController = TextEditingController(text: existing?.academicYear ?? '2026–27');
    _semesterController = TextEditingController(text: existing?.semester ?? 'Semester 3');
  }

  @override
  void dispose() {
    _institutionController.dispose();
    _degreeController.dispose();
    _branchController.dispose();
    _yearController.dispose();
    _semesterController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    ref.read(onboardingProvider.notifier).clearError();
    if (!_formKey.currentState!.validate()) return;

    final success = ref.read(onboardingProvider.notifier).setCollegeDetails(
          degree: _degreeController.text,
          branch: _branchController.text,
          academicYear: _yearController.text,
          semester: _semesterController.text,
          institutionName: _institutionController.text,
        );

    if (success) {
      widget.onContinue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return OnboardingScaffold(
      currentStep: OnboardingStep.setup,
      onBack: widget.onBack,
      errorMessage: onboarding.errorMessage,
      onDismissError: () => notifier.clearError(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSpacing.v16,

            // Header
            Text(
              'Set up your college workspace',
              textAlign: TextAlign.center,
              style: AppTypography.display.copyWith(
                fontSize: 26,
                letterSpacing: -0.6,
              ),
            ),
            AppSpacing.v8,
            Text(
              'Enter your degree and semester so Study Vault can organize your academic subjects.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),

            AppSpacing.v24,

            // Degree field + suggestions
            AppTextField(
              label: 'Degree *',
              hint: 'e.g. B.E / B.Tech',
              controller: _degreeController,
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Degree is required' : null,
            ),
            AppSpacing.v8,
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _commonDegrees.map((deg) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: AppChip(
                      label: deg,
                      isSelected: _degreeController.text == deg,
                      onTap: () {
                        setState(() => _degreeController.text = deg);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            AppSpacing.v20,

            // Department / Branch
            AppTextField(
              label: 'Department / Branch *',
              hint: 'e.g. Computer Science Engineering',
              controller: _branchController,
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Branch is required' : null,
            ),

            AppSpacing.v20,

            // Academic Year
            AppTextField(
              label: 'Academic Year *',
              hint: 'e.g. 2026–27',
              controller: _yearController,
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Academic year is required' : null,
            ),

            AppSpacing.v20,

            // Current Semester + suggestions
            AppTextField(
              label: 'Current Semester *',
              hint: 'e.g. Semester 3',
              controller: _semesterController,
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Current semester is required' : null,
            ),
            AppSpacing.v8,
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _suggestedSemesters.map((sem) {
                final isSelected = _semesterController.text == sem;
                return AppChip(
                  label: sem,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() => _semesterController.text = sem);
                  },
                );
              }).toList(),
            ),

            AppSpacing.v20,

            // College / Institution Name (Optional)
            AppTextField(
              label: 'College / Institution Name (Optional)',
              hint: 'e.g. Stanford University',
              controller: _institutionController,
            ),

            AppSpacing.v32,

            // Primary Action
            AppButton.primary(
              text: 'Continue',
              onPressed: _handleContinue,
            ),
            AppSpacing.v24,
          ],
        ),
      ),
    );
  }
}
