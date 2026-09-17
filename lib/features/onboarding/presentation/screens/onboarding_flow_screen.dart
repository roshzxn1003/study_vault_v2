import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'purpose_selection_screen.dart';
import 'college_setup_screen.dart';
import 'school_setup_screen.dart';
import 'college_subjects_screen.dart';
import 'school_subjects_screen.dart';
import 'personal_learning_screen.dart';
import 'onboarding_complete_screen.dart';

enum _SubStage {
  purpose,
  collegeSetup,
  schoolSetup,
  collegeSubjects,
  schoolSubjects,
  personalLearning,
  complete,
}

/// Master onboarding coordinator orchestrating multi-purpose progression,
/// back navigation, and resume behavior.
class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  _SubStage _currentSubStage = _SubStage.purpose;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeSubStage();
    });
  }

  void _resumeSubStage() {
    final state = ref.read(onboardingProvider);
    if (!state.hasSelectedPurposes) {
      setState(() => _currentSubStage = _SubStage.purpose);
      return;
    }

    switch (state.currentStep) {
      case OnboardingStep.purpose:
        setState(() => _currentSubStage = _SubStage.purpose);
        break;
      case OnboardingStep.setup:
        if (state.isCollegeSelected && state.collegeData == null) {
          setState(() => _currentSubStage = _SubStage.collegeSetup);
        } else if (state.isSchoolSelected && state.schoolData == null) {
          setState(() => _currentSubStage = _SubStage.schoolSetup);
        } else if (state.isCollegeSelected) {
          setState(() => _currentSubStage = _SubStage.collegeSetup);
        } else if (state.isSchoolSelected) {
          setState(() => _currentSubStage = _SubStage.schoolSetup);
        } else {
          setState(() => _currentSubStage = _SubStage.personalLearning);
        }
        break;
      case OnboardingStep.subjects:
        if (state.isCollegeSelected && (state.collegeData?.subjects.isEmpty ?? true)) {
          setState(() => _currentSubStage = _SubStage.collegeSubjects);
        } else if (state.isSchoolSelected && (state.schoolData?.subjects.isEmpty ?? true)) {
          setState(() => _currentSubStage = _SubStage.schoolSubjects);
        } else if (state.isPersonalLearningSelected) {
          setState(() => _currentSubStage = _SubStage.personalLearning);
        } else {
          setState(() => _currentSubStage = _SubStage.complete);
        }
        break;
      case OnboardingStep.complete:
        setState(() => _currentSubStage = _SubStage.complete);
        break;
    }
  }

  // --- Forward Transitions ---

  void _afterPurpose() {
    final state = ref.read(onboardingProvider);
    if (state.isCollegeSelected) {
      ref.read(onboardingProvider.notifier).setStep(OnboardingStep.setup);
      setState(() => _currentSubStage = _SubStage.collegeSetup);
    } else if (state.isSchoolSelected) {
      ref.read(onboardingProvider.notifier).setStep(OnboardingStep.setup);
      setState(() => _currentSubStage = _SubStage.schoolSetup);
    } else if (state.isPersonalLearningSelected) {
      ref.read(onboardingProvider.notifier).setStep(OnboardingStep.subjects);
      setState(() => _currentSubStage = _SubStage.personalLearning);
    }
  }

  void _afterCollegeSetup() {
    final state = ref.read(onboardingProvider);
    if (state.isSchoolSelected && state.schoolData == null) {
      setState(() => _currentSubStage = _SubStage.schoolSetup);
    } else {
      ref.read(onboardingProvider.notifier).setStep(OnboardingStep.subjects);
      setState(() => _currentSubStage = _SubStage.collegeSubjects);
    }
  }

  void _afterSchoolSetup() {
    final state = ref.read(onboardingProvider);
    ref.read(onboardingProvider.notifier).setStep(OnboardingStep.subjects);
    if (state.isCollegeSelected) {
      setState(() => _currentSubStage = _SubStage.collegeSubjects);
    } else {
      setState(() => _currentSubStage = _SubStage.schoolSubjects);
    }
  }

  void _afterCollegeSubjects() {
    final state = ref.read(onboardingProvider);
    if (state.isSchoolSelected) {
      setState(() => _currentSubStage = _SubStage.schoolSubjects);
    } else if (state.isPersonalLearningSelected) {
      setState(() => _currentSubStage = _SubStage.personalLearning);
    } else {
      ref.read(onboardingProvider.notifier).setStep(OnboardingStep.complete);
      setState(() => _currentSubStage = _SubStage.complete);
    }
  }

  void _afterSchoolSubjects() {
    final state = ref.read(onboardingProvider);
    if (state.isPersonalLearningSelected) {
      setState(() => _currentSubStage = _SubStage.personalLearning);
    } else {
      ref.read(onboardingProvider.notifier).setStep(OnboardingStep.complete);
      setState(() => _currentSubStage = _SubStage.complete);
    }
  }

  void _afterPersonalLearning() {
    ref.read(onboardingProvider.notifier).setStep(OnboardingStep.complete);
    setState(() => _currentSubStage = _SubStage.complete);
  }

  // --- Backward Transitions ---

  void _backToPurpose() {
    ref.read(onboardingProvider.notifier).setStep(OnboardingStep.purpose);
    setState(() => _currentSubStage = _SubStage.purpose);
  }

  void _backToCollegeSetup() {
    ref.read(onboardingProvider.notifier).setStep(OnboardingStep.setup);
    setState(() => _currentSubStage = _SubStage.collegeSetup);
  }

  void _backToSchoolSetup() {
    ref.read(onboardingProvider.notifier).setStep(OnboardingStep.setup);
    setState(() => _currentSubStage = _SubStage.schoolSetup);
  }

  void _backToCollegeSubjects() {
    ref.read(onboardingProvider.notifier).setStep(OnboardingStep.subjects);
    setState(() => _currentSubStage = _SubStage.collegeSubjects);
  }

  void _backToSchoolSubjects() {
    ref.read(onboardingProvider.notifier).setStep(OnboardingStep.subjects);
    setState(() => _currentSubStage = _SubStage.schoolSubjects);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);

    switch (_currentSubStage) {
      case _SubStage.purpose:
        return PurposeSelectionScreen(
          onContinue: _afterPurpose,
        );

      case _SubStage.collegeSetup:
        return CollegeSetupScreen(
          onContinue: _afterCollegeSetup,
          onBack: _backToPurpose,
        );

      case _SubStage.schoolSetup:
        return SchoolSetupScreen(
          onContinue: _afterSchoolSetup,
          onBack: state.isCollegeSelected ? _backToCollegeSetup : _backToPurpose,
        );

      case _SubStage.collegeSubjects:
        return CollegeSubjectsScreen(
          onContinue: _afterCollegeSubjects,
          onBack: _backToCollegeSetup,
        );

      case _SubStage.schoolSubjects:
        return SchoolSubjectsScreen(
          onContinue: _afterSchoolSubjects,
          onBack: state.isCollegeSelected
              ? _backToCollegeSubjects
              : _backToSchoolSetup,
        );

      case _SubStage.personalLearning:
        return PersonalLearningScreen(
          onContinue: _afterPersonalLearning,
          onBack: state.isSchoolSelected
              ? _backToSchoolSubjects
              : (state.isCollegeSelected ? _backToCollegeSubjects : _backToPurpose),
        );

      case _SubStage.complete:
        return OnboardingCompleteScreen(
          onFinish: () {
            context.go('/home');
          },
        );
    }
  }
}
