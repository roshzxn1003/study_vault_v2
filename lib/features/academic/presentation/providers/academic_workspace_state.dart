import 'package:study_vault/features/academic/domain/models/models.dart';
import 'package:study_vault/features/onboarding/domain/models/onboarding_models.dart';

/// State representation for Academic Workspace and Period management.
class AcademicWorkspaceState {
  final List<AcademicWorkspace> workspaces;
  final AcademicWorkspace? activeWorkspace;
  final Map<String, dynamic>? academicProfile;
  final List<AcademicYearEntity> academicYears;
  final AcademicPeriodEntity? currentPeriod;
  final AcademicPeriodEntity? selectedPeriod;
  final List<AcademicSubjectEntity> subjects;
  final List<PersonalTopicEntity> personalTopics;
  final List<AcademicYearWithPeriods> history;
  final bool isLoading;
  final String? errorMessage;

  const AcademicWorkspaceState({
    this.workspaces = const [],
    this.activeWorkspace,
    this.academicProfile,
    this.academicYears = const [],
    this.currentPeriod,
    this.selectedPeriod,
    this.subjects = const [],
    this.personalTopics = const [],
    this.history = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  /// Whether the user is viewing the live current period (vs an archived/previous period).
  bool get isViewingCurrentPeriod {
    if (currentPeriod == null || selectedPeriod == null) return true;
    return selectedPeriod!.id == currentPeriod!.id;
  }

  bool get isCollege => activeWorkspace?.purpose == OnboardingPurpose.college;
  bool get isSchool => activeWorkspace?.purpose == OnboardingPurpose.school;
  bool get isPersonalLearning =>
      activeWorkspace?.purpose == OnboardingPurpose.personalLearning;

  String get degreeOrClassTitle {
    if (isCollege) {
      final deg = academicProfile?['degree'] as String? ?? '';
      final branch = academicProfile?['branch'] as String? ?? '';
      if (deg.isNotEmpty && branch.isNotEmpty) return '$deg $branch';
      if (deg.isNotEmpty) return deg;
      return 'College Workspace';
    }
    if (isSchool) {
      final grade = academicProfile?['semester_or_class'] as String? ?? '';
      final stream = academicProfile?['stream'] as String? ?? '';
      if (grade.isNotEmpty && stream.isNotEmpty) return '$grade • $stream';
      if (grade.isNotEmpty) return grade;
      return 'School Workspace';
    }
    return activeWorkspace?.name ?? 'Personal Learning';
  }

  String get institutionName {
    return academicProfile?['institution_name'] as String? ?? '';
  }

  AcademicWorkspaceState copyWith({
    List<AcademicWorkspace>? workspaces,
    AcademicWorkspace? activeWorkspace,
    Map<String, dynamic>? academicProfile,
    List<AcademicYearEntity>? academicYears,
    AcademicPeriodEntity? currentPeriod,
    AcademicPeriodEntity? selectedPeriod,
    List<AcademicSubjectEntity>? subjects,
    List<PersonalTopicEntity>? personalTopics,
    List<AcademicYearWithPeriods>? history,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AcademicWorkspaceState(
      workspaces: workspaces ?? this.workspaces,
      activeWorkspace: activeWorkspace ?? this.activeWorkspace,
      academicProfile: academicProfile ?? this.academicProfile,
      academicYears: academicYears ?? this.academicYears,
      currentPeriod: currentPeriod ?? this.currentPeriod,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      subjects: subjects ?? this.subjects,
      personalTopics: personalTopics ?? this.personalTopics,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
