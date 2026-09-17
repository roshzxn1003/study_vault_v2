import 'onboarding_models.dart';

/// Complete state container for user onboarding.
class OnboardingState {
  final OnboardingStatus status;
  final bool isLoaded;
  final Set<OnboardingPurpose> selectedPurposes;
  final CollegeSetupData? collegeData;
  final SchoolSetupData? schoolData;
  final PersonalLearningData? personalLearningData;
  final OnboardingStep currentStep;
  final bool isLoading;
  final String? errorMessage;

  const OnboardingState({
    this.status = OnboardingStatus.notStarted,
    this.isLoaded = false,
    this.selectedPurposes = const {},
    this.collegeData,
    this.schoolData,
    this.personalLearningData,
    this.currentStep = OnboardingStep.purpose,
    this.isLoading = false,
    this.errorMessage,
  });

  // Backward compatibility getters for Phase 0/1/2 components
  bool get hasCompletedOnboarding => status == OnboardingStatus.completed;

  String? get course {
    if (collegeData != null) {
      final deg = collegeData!.degree.trim();
      final branch = collegeData!.branch.trim();
      return '$deg $branch'.trim();
    }
    if (schoolData != null) {
      return schoolData!.grade.trim();
    }
    if (personalLearningData != null && personalLearningData!.topics.isNotEmpty) {
      return personalLearningData!.topics.first;
    }
    return null;
  }

  String? get studyGoal {
    if (collegeData != null) return collegeData!.semester;
    if (schoolData != null) return schoolData!.grade;
    return 'Personal Learning';
  }

  List<String> get subjects {
    final list = <String>[];
    if (collegeData != null) list.addAll(collegeData!.subjects);
    if (schoolData != null) list.addAll(schoolData!.subjects);
    if (personalLearningData != null) list.addAll(personalLearningData!.topics);
    return list;
  }

  bool get hasSelectedPurposes => selectedPurposes.isNotEmpty;

  bool get isCollegeSelected => selectedPurposes.contains(OnboardingPurpose.college);
  bool get isSchoolSelected => selectedPurposes.contains(OnboardingPurpose.school);
  bool get isPersonalLearningSelected =>
      selectedPurposes.contains(OnboardingPurpose.personalLearning);

  OnboardingState copyWith({
    OnboardingStatus? status,
    bool? isLoaded,
    Set<OnboardingPurpose>? selectedPurposes,
    CollegeSetupData? collegeData,
    SchoolSetupData? schoolData,
    PersonalLearningData? personalLearningData,
    OnboardingStep? currentStep,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OnboardingState(
      status: status ?? this.status,
      isLoaded: isLoaded ?? this.isLoaded,
      selectedPurposes: selectedPurposes ?? this.selectedPurposes,
      collegeData: collegeData ?? this.collegeData,
      schoolData: schoolData ?? this.schoolData,
      personalLearningData: personalLearningData ?? this.personalLearningData,
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status.toSerializedString(),
        'selected_purposes': selectedPurposes.map((e) => e.id).toList(),
        'college_data': collegeData?.toJson(),
        'school_data': schoolData?.toJson(),
        'personal_learning_data': personalLearningData?.toJson(),
        'current_step': currentStep.name,
      };

  factory OnboardingState.fromJson(Map<String, dynamic> json) {
    final rawPurposes = (json['selected_purposes'] as List<dynamic>?)
            ?.map((e) => OnboardingPurpose.fromId(e.toString()))
            .toSet() ??
        {};

    return OnboardingState(
      status: OnboardingStatus.fromString(json['status'] as String?),
      isLoaded: true,
      selectedPurposes: rawPurposes,
      collegeData: json['college_data'] != null
          ? CollegeSetupData.fromJson(json['college_data'] as Map<String, dynamic>)
          : null,
      schoolData: json['school_data'] != null
          ? SchoolSetupData.fromJson(json['school_data'] as Map<String, dynamic>)
          : null,
      personalLearningData: json['personal_learning_data'] != null
          ? PersonalLearningData.fromJson(
              json['personal_learning_data'] as Map<String, dynamic>)
          : null,
      currentStep: OnboardingStep.fromString(json['current_step'] as String?),
    );
  }
}
