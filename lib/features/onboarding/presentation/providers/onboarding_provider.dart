import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingState {
  final bool isLoaded;
  final bool hasCompletedOnboarding;
  final String? course;
  final List<String> subjects;
  final String? studyGoal;

  OnboardingState({
    this.isLoaded = false,
    this.hasCompletedOnboarding = false,
    this.course,
    this.subjects = const [],
    this.studyGoal,
  });

  OnboardingState copyWith({
    bool? isLoaded,
    bool? hasCompletedOnboarding,
    String? course,
    List<String>? subjects,
    String? studyGoal,
  }) {
    return OnboardingState(
      isLoaded: isLoaded ?? this.isLoaded,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      course: course ?? this.course,
      subjects: subjects ?? this.subjects,
      studyGoal: studyGoal ?? this.studyGoal,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(OnboardingState()) {
    _loadOnboardingStatus();
  }

  Future<void> _loadOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_completed') ?? false;
    state = state.copyWith(hasCompletedOnboarding: completed, isLoaded: true);
  }

  Future<void> completeOnboarding({
    String? course,
    List<String>? subjects,
    String? studyGoal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    state = state.copyWith(
      hasCompletedOnboarding: true,
      course: course,
      subjects: subjects,
      studyGoal: studyGoal,
      isLoaded: true,
    );
    
    // In a real app, we would save these to the user_preferences table in Supabase here.
  }
}

final onboardingProvider = StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});
