import 'package:study_vault/features/academic/domain/models/models.dart';
import 'package:study_vault/features/dashboard/domain/models/dashboard_models.dart';
import 'package:study_vault/features/onboarding/domain/models/onboarding_models.dart';

/// State representation for the personalized Study Vault Dashboard.
class DashboardState {
  final AcademicWorkspace? activeWorkspace;
  final List<AcademicWorkspace> workspaces;
  final AcademicPeriodEntity? currentPeriod;
  final AcademicPeriodEntity? selectedPeriod;
  final List<AcademicYearWithPeriods> history;
  final Map<String, dynamic>? academicProfile;
  final List<SubjectWithCount> subjects;
  final List<PersonalTopicEntity> personalTopics;
  final List<DashboardRecentMaterial> recentMaterials;
  final List<DashboardInboxItem> inboxItems;
  final int inboxTotalCount;
  final String? userFullName;
  final bool isLoading;
  final String? errorMessage;

  const DashboardState({
    this.activeWorkspace,
    this.workspaces = const [],
    this.currentPeriod,
    this.selectedPeriod,
    this.history = const [],
    this.academicProfile,
    this.subjects = const [],
    this.personalTopics = const [],
    this.recentMaterials = const [],
    this.inboxItems = const [],
    this.inboxTotalCount = 0,
    this.userFullName,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isCollege => activeWorkspace?.purpose == OnboardingPurpose.college;
  bool get isSchool => activeWorkspace?.purpose == OnboardingPurpose.school;
  bool get isPersonalLearning =>
      activeWorkspace?.purpose == OnboardingPurpose.personalLearning;

  /// True when the user is viewing the active/current period, false if browsing historical archive.
  bool get isViewingCurrentPeriod {
    if (currentPeriod == null || selectedPeriod == null) return true;
    return selectedPeriod!.id == currentPeriod!.id;
  }

  bool get isViewingHistoricalPeriod => !isViewingCurrentPeriod;

  String get currentPeriodName => currentPeriod?.name ?? 'Current Period';
  String get selectedPeriodName => selectedPeriod?.name ?? currentPeriodName;

  /// Time-of-day greeting adhering to Section 13 specs.
  String get greeting {
    final hour = DateTime.now().hour;
    final String timeGreeting;
    if (hour < 12) {
      timeGreeting = 'Good morning';
    } else if (hour < 17) {
      timeGreeting = 'Good afternoon';
    } else {
      timeGreeting = 'Good evening';
    }

    if (userFullName != null && userFullName!.trim().isNotEmpty) {
      final firstName = userFullName!.trim().split(' ').first;
      return '$timeGreeting, $firstName';
    }
    return timeGreeting;
  }

  /// Primary academic identity line (e.g. "B.E Computer Science Engineering", "Class 12 • Science", "My Learning").
  String get academicIdentityTitle {
    if (isCollege) {
      final deg = academicProfile?['degree'] as String? ?? '';
      final branch = academicProfile?['branch'] as String? ?? '';
      if (deg.isNotEmpty && branch.isNotEmpty) return '$deg $branch';
      if (deg.isNotEmpty) return deg;
      return activeWorkspace?.name ?? 'College Workspace';
    }
    if (isSchool) {
      final grade = academicProfile?['semester_or_class'] as String? ?? '';
      final stream = academicProfile?['stream'] as String? ?? '';
      if (grade.isNotEmpty && stream.isNotEmpty) return '$grade • $stream';
      if (grade.isNotEmpty) return grade;
      return activeWorkspace?.name ?? 'School Workspace';
    }
    return activeWorkspace?.name ?? 'My Learning';
  }

  /// Secondary academic line (e.g. "2026–27 • Semester 3", "2026–27", "Independent Study & Skills").
  String get academicSubtitle {
    if (isCollege) {
      final year = (academicProfile?['academic_year'] as String?)?.trim() ?? '2026–27';
      final period = selectedPeriodName;
      return '$year • $period';
    }
    if (isSchool) {
      final year = (academicProfile?['academic_year'] as String?)?.trim() ?? '2026–27';
      return year;
    }
    return 'Independent Study & Skills';
  }

  DashboardState copyWith({
    AcademicWorkspace? activeWorkspace,
    List<AcademicWorkspace>? workspaces,
    AcademicPeriodEntity? currentPeriod,
    AcademicPeriodEntity? selectedPeriod,
    List<AcademicYearWithPeriods>? history,
    Map<String, dynamic>? academicProfile,
    List<SubjectWithCount>? subjects,
    List<PersonalTopicEntity>? personalTopics,
    List<DashboardRecentMaterial>? recentMaterials,
    List<DashboardInboxItem>? inboxItems,
    int? inboxTotalCount,
    String? userFullName,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardState(
      activeWorkspace: activeWorkspace ?? this.activeWorkspace,
      workspaces: workspaces ?? this.workspaces,
      currentPeriod: currentPeriod ?? this.currentPeriod,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      history: history ?? this.history,
      academicProfile: academicProfile ?? this.academicProfile,
      subjects: subjects ?? this.subjects,
      personalTopics: personalTopics ?? this.personalTopics,
      recentMaterials: recentMaterials ?? this.recentMaterials,
      inboxItems: inboxItems ?? this.inboxItems,
      inboxTotalCount: inboxTotalCount ?? this.inboxTotalCount,
      userFullName: userFullName ?? this.userFullName,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
