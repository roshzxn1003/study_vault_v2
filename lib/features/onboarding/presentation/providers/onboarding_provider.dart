import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:study_vault/features/onboarding/domain/models/onboarding_models.dart';
import 'package:study_vault/features/onboarding/domain/models/onboarding_state.dart';

export 'package:study_vault/features/onboarding/domain/models/onboarding_models.dart';
export 'package:study_vault/features/onboarding/domain/models/onboarding_state.dart';

/// Provider for the Onboarding Repository.
final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository();
});

/// Riverpod Notifier managing all onboarding state transitions, drafts, and persistence.
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final OnboardingRepository _repository;
  final Ref _ref;

  OnboardingNotifier(this._repository, this._ref) : super(const OnboardingState()) {
    _init();
  }

  Future<void> _init() async {
    final loadedState = await _repository.loadOnboardingState();
    if (mounted) {
      state = loadedState;
    }
  }

  /// Toggles a purpose selection (College, School, Personal Learning).
  void togglePurpose(OnboardingPurpose purpose) {
    final updated = Set<OnboardingPurpose>.from(state.selectedPurposes);
    if (updated.contains(purpose)) {
      updated.remove(purpose);
    } else {
      updated.add(purpose);
    }

    state = state.copyWith(
      selectedPurposes: updated,
      status: OnboardingStatus.inProgress,
      clearError: true,
    );
    _persistDraft();
  }

  /// Sets college workspace attributes.
  bool setCollegeDetails({
    required String degree,
    required String branch,
    required String academicYear,
    required String semester,
    String? institutionName,
  }) {
    if (degree.trim().isEmpty ||
        branch.trim().isEmpty ||
        academicYear.trim().isEmpty ||
        semester.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Please fill in all required college details.');
      return false;
    }

    final currentData = state.collegeData;
    final updated = CollegeSetupData(
      degree: degree.trim(),
      branch: branch.trim(),
      academicYear: academicYear.trim(),
      semester: semester.trim(),
      institutionName: institutionName?.trim().isEmpty == true ? null : institutionName?.trim(),
      subjects: currentData?.subjects ?? const [],
    );

    state = state.copyWith(
      collegeData: updated,
      status: OnboardingStatus.inProgress,
      clearError: true,
    );
    _persistDraft();
    return true;
  }

  /// Sets school workspace attributes.
  bool setSchoolDetails({
    required String academicYear,
    required String grade,
    String? stream,
    String? schoolName,
  }) {
    if (academicYear.trim().isEmpty || grade.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Please fill in academic year and class/grade.');
      return false;
    }

    final currentData = state.schoolData;
    final updated = SchoolSetupData(
      academicYear: academicYear.trim(),
      grade: grade.trim(),
      stream: stream?.trim().isEmpty == true ? null : stream?.trim(),
      schoolName: schoolName?.trim().isEmpty == true ? null : schoolName?.trim(),
      subjects: currentData?.subjects ?? const [],
    );

    state = state.copyWith(
      schoolData: updated,
      status: OnboardingStatus.inProgress,
      clearError: true,
    );
    _persistDraft();
    return true;
  }

  /// Adds a subject to either College or School purpose with duplicate check.
  bool addSubject({
    required OnboardingPurpose purpose,
    required String subjectName,
  }) {
    final trimmed = subjectName.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(errorMessage: 'Subject name cannot be empty.');
      return false;
    }

    if (purpose == OnboardingPurpose.college) {
      final currentSubjects = List<String>.from(state.collegeData?.subjects ?? []);
      final duplicate = currentSubjects.any((s) => s.toLowerCase() == trimmed.toLowerCase());
      if (duplicate) {
        state = state.copyWith(errorMessage: 'Subject "$trimmed" already added.');
        return false;
      }

      currentSubjects.add(trimmed);
      final updatedCollege = (state.collegeData ??
              const CollegeSetupData(
                degree: '',
                branch: '',
                academicYear: '',
                semester: '',
              ))
          .copyWith(subjects: currentSubjects);

      state = state.copyWith(
        collegeData: updatedCollege,
        status: OnboardingStatus.inProgress,
        clearError: true,
      );
      _persistDraft();
      return true;
    } else if (purpose == OnboardingPurpose.school) {
      final currentSubjects = List<String>.from(state.schoolData?.subjects ?? []);
      final duplicate = currentSubjects.any((s) => s.toLowerCase() == trimmed.toLowerCase());
      if (duplicate) {
        state = state.copyWith(errorMessage: 'Subject "$trimmed" already added.');
        return false;
      }

      currentSubjects.add(trimmed);
      final updatedSchool = (state.schoolData ??
              const SchoolSetupData(
                academicYear: '',
                grade: '',
              ))
          .copyWith(subjects: currentSubjects);

      state = state.copyWith(
        schoolData: updatedSchool,
        status: OnboardingStatus.inProgress,
        clearError: true,
      );
      _persistDraft();
      return true;
    }

    return false;
  }

  /// Renames a subject with duplicate check.
  bool renameSubject({
    required OnboardingPurpose purpose,
    required int index,
    required String newName,
  }) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;

    if (purpose == OnboardingPurpose.college && state.collegeData != null) {
      final list = List<String>.from(state.collegeData!.subjects);
      if (index < 0 || index >= list.length) return false;

      // Duplicate check excluding self
      for (int i = 0; i < list.length; i++) {
        if (i != index && list[i].toLowerCase() == trimmed.toLowerCase()) {
          state = state.copyWith(errorMessage: 'Subject "$trimmed" already exists.');
          return false;
        }
      }

      list[index] = trimmed;
      state = state.copyWith(
        collegeData: state.collegeData!.copyWith(subjects: list),
        clearError: true,
      );
      _persistDraft();
      return true;
    } else if (purpose == OnboardingPurpose.school && state.schoolData != null) {
      final list = List<String>.from(state.schoolData!.subjects);
      if (index < 0 || index >= list.length) return false;

      for (int i = 0; i < list.length; i++) {
        if (i != index && list[i].toLowerCase() == trimmed.toLowerCase()) {
          state = state.copyWith(errorMessage: 'Subject "$trimmed" already exists.');
          return false;
        }
      }

      list[index] = trimmed;
      state = state.copyWith(
        schoolData: state.schoolData!.copyWith(subjects: list),
        clearError: true,
      );
      _persistDraft();
      return true;
    }

    return false;
  }

  /// Removes a subject at [index].
  void removeSubject({
    required OnboardingPurpose purpose,
    required int index,
  }) {
    if (purpose == OnboardingPurpose.college && state.collegeData != null) {
      final list = List<String>.from(state.collegeData!.subjects);
      if (index >= 0 && index < list.length) {
        list.removeAt(index);
        state = state.copyWith(
          collegeData: state.collegeData!.copyWith(subjects: list),
          clearError: true,
        );
        _persistDraft();
      }
    } else if (purpose == OnboardingPurpose.school && state.schoolData != null) {
      final list = List<String>.from(state.schoolData!.subjects);
      if (index >= 0 && index < list.length) {
        list.removeAt(index);
        state = state.copyWith(
          schoolData: state.schoolData!.copyWith(subjects: list),
          clearError: true,
        );
        _persistDraft();
      }
    }
  }

  /// Reorders subjects for drag and drop.
  void reorderSubjects({
    required OnboardingPurpose purpose,
    required int oldIndex,
    required int newIndex,
  }) {
    if (purpose == OnboardingPurpose.college && state.collegeData != null) {
      final list = List<String>.from(state.collegeData!.subjects);
      if (oldIndex < 0 || oldIndex >= list.length || newIndex < 0 || newIndex >= list.length) return;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      state = state.copyWith(collegeData: state.collegeData!.copyWith(subjects: list));
      _persistDraft();
    } else if (purpose == OnboardingPurpose.school && state.schoolData != null) {
      final list = List<String>.from(state.schoolData!.subjects);
      if (oldIndex < 0 || oldIndex >= list.length || newIndex < 0 || newIndex >= list.length) return;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      state = state.copyWith(schoolData: state.schoolData!.copyWith(subjects: list));
      _persistDraft();
    }
  }

  /// Adds a personal learning topic with duplicate check.
  bool addTopic(String topicName) {
    final trimmed = topicName.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(errorMessage: 'Topic name cannot be empty.');
      return false;
    }

    final currentTopics = List<String>.from(state.personalLearningData?.topics ?? []);
    final duplicate = currentTopics.any((t) => t.toLowerCase() == trimmed.toLowerCase());
    if (duplicate) {
      state = state.copyWith(errorMessage: 'Topic "$trimmed" already added.');
      return false;
    }

    currentTopics.add(trimmed);
    final updatedPl = (state.personalLearningData ?? const PersonalLearningData())
        .copyWith(topics: currentTopics);

    state = state.copyWith(
      personalLearningData: updatedPl,
      status: OnboardingStatus.inProgress,
      clearError: true,
    );
    _persistDraft();
    return true;
  }

  /// Removes a personal learning topic.
  void removeTopic(int index) {
    if (state.personalLearningData != null) {
      final list = List<String>.from(state.personalLearningData!.topics);
      if (index >= 0 && index < list.length) {
        list.removeAt(index);
        state = state.copyWith(
          personalLearningData: state.personalLearningData!.copyWith(topics: list),
          clearError: true,
        );
        _persistDraft();
      }
    }
  }

  /// Reorders personal learning topics.
  void reorderTopics(int oldIndex, int newIndex) {
    if (state.personalLearningData != null) {
      final list = List<String>.from(state.personalLearningData!.topics);
      if (oldIndex < 0 || oldIndex >= list.length || newIndex < 0 || newIndex >= list.length) return;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      state = state.copyWith(
        personalLearningData: state.personalLearningData!.copyWith(topics: list),
      );
      _persistDraft();
    }
  }

  /// Navigates to a specific step.
  void setStep(OnboardingStep step) {
    state = state.copyWith(
      currentStep: step,
      status: OnboardingStatus.inProgress,
      clearError: true,
    );
    _persistDraft();
  }

  /// Clears any visible error banner.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Finalizes and commits onboarding workspace to database.
  Future<void> completeOnboarding() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final authRepo = _ref.read(authRepositoryProvider);
      final currentUser = authRepo.getCurrentUser();
      final userId = currentUser?.id ?? 'guest';

      await _repository.completeOnboarding(
        userId: userId,
        state: state,
      );

      state = state.copyWith(
        status: OnboardingStatus.completed,
        isLoading: false,
        isLoaded: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: OnboardingStatus.completed, // complete gracefully in prefs regardless
        isLoading: false,
      );
    }
  }

  /// Backwards-compatible completeOnboarding method for legacy tests or widgets.
  Future<void> completeOnboardingLegacy({
    String? course,
    List<String>? subjects,
    String? studyGoal,
  }) async {
    if (course != null) {
      setCollegeDetails(
        degree: course,
        branch: 'General',
        academicYear: '2026-27',
        semester: studyGoal ?? 'Semester 1',
      );
    }
    if (subjects != null) {
      for (final s in subjects) {
        addSubject(purpose: OnboardingPurpose.college, subjectName: s);
      }
    }
    await completeOnboarding();
  }

  /// Resets onboarding status and wipes draft (useful for testing or sign out).
  Future<void> resetOnboarding() async {
    await _repository.clearDraft();
    state = const OnboardingState(
      status: OnboardingStatus.notStarted,
      isLoaded: true,
    );
  }

  void _persistDraft() {
    _repository.saveDraft(state);
  }
}

/// The main onboarding provider used across the application.
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  final repo = ref.watch(onboardingRepositoryProvider);
  return OnboardingNotifier(repo, ref);
});
