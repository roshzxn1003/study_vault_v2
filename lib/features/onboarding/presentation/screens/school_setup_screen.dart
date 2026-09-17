import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:study_vault/features/onboarding/presentation/widgets/onboarding_scaffold.dart';

/// Screen 2B: School workspace setup (Academic Year, Class/Grade, Stream).
class SchoolSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const SchoolSetupScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  ConsumerState<SchoolSetupScreen> createState() => _SchoolSetupScreenState();
}

class _SchoolSetupScreenState extends ConsumerState<SchoolSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _schoolNameController;
  late final TextEditingController _yearController;
  late final TextEditingController _classController;
  late final TextEditingController _streamController;

  static const List<String> _suggestedClasses = [
    'Class 9',
    'Class 10',
    'Class 11',
    'Class 12',
  ];

  static const List<String> _suggestedStreams = [
    'Science (PCM)',
    'Science (PCB)',
    'Commerce',
    'Humanities / Arts',
  ];

  @override
  void initState() {
    super.initState();
    final existing = ref.read(onboardingProvider).schoolData;
    _schoolNameController = TextEditingController(text: existing?.schoolName ?? '');
    _yearController = TextEditingController(text: existing?.academicYear ?? '2026–27');
    _classController = TextEditingController(text: existing?.grade ?? 'Class 12');
    _streamController = TextEditingController(text: existing?.stream ?? '');
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _yearController.dispose();
    _classController.dispose();
    _streamController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    ref.read(onboardingProvider.notifier).clearError();
    if (!_formKey.currentState!.validate()) return;

    final success = ref.read(onboardingProvider.notifier).setSchoolDetails(
          academicYear: _yearController.text,
          grade: _classController.text,
          stream: _streamController.text,
          schoolName: _schoolNameController.text,
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
              'Set up your school workspace',
              textAlign: TextAlign.center,
              style: AppTypography.display.copyWith(
                fontSize: 26,
                letterSpacing: -0.6,
              ),
            ),
            AppSpacing.v8,
            Text(
              'Enter your grade and academic year to organize classes, notes, and homework.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),

            AppSpacing.v24,

            // Academic Year
            AppTextField(
              label: 'Academic Year *',
              hint: 'e.g. 2026–27',
              controller: _yearController,
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Academic year is required' : null,
            ),

            AppSpacing.v20,

            // Class / Grade + suggestions
            AppTextField(
              label: 'Class / Grade *',
              hint: 'e.g. Class 12',
              controller: _classController,
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Class/Grade is required' : null,
            ),
            AppSpacing.v8,
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _suggestedClasses.map((cls) {
                final isSelected = _classController.text == cls;
                return AppChip(
                  label: cls,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() => _classController.text = cls);
                  },
                );
              }).toList(),
            ),

            AppSpacing.v20,

            // Stream / Group (Optional) + suggestions
            AppTextField(
              label: 'Stream / Group (Optional)',
              hint: 'e.g. Science or Commerce',
              controller: _streamController,
            ),
            AppSpacing.v8,
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _suggestedStreams.map((st) {
                  final isSelected = _streamController.text == st;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: AppChip(
                      label: st,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() => _streamController.text = st);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            AppSpacing.v20,

            // School Name (Optional)
            AppTextField(
              label: 'School Name (Optional)',
              hint: 'e.g. St. Xavier’s High School',
              controller: _schoolNameController,
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
