import 'package:flutter/material.dart';
import 'onboarding_flow_screen.dart';

export 'onboarding_flow_screen.dart';
export 'purpose_selection_screen.dart';
export 'college_setup_screen.dart';
export 'school_setup_screen.dart';
export 'college_subjects_screen.dart';
export 'school_subjects_screen.dart';
export 'personal_learning_screen.dart';
export 'onboarding_complete_screen.dart';

/// Primary entry point for onboarding, rendering the adaptive flow screen.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingFlowScreen();
  }
}
