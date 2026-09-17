import 'package:flutter/material.dart';

/// Supported learning purposes for Study Vault.
enum OnboardingPurpose {
  college,
  school,
  personalLearning;

  String get id {
    switch (this) {
      case OnboardingPurpose.college:
        return 'college';
      case OnboardingPurpose.school:
        return 'school';
      case OnboardingPurpose.personalLearning:
        return 'personal_learning';
    }
  }

  String get title {
    switch (this) {
      case OnboardingPurpose.college:
        return 'College';
      case OnboardingPurpose.school:
        return 'School';
      case OnboardingPurpose.personalLearning:
        return 'Personal Learning';
    }
  }

  String get description {
    switch (this) {
      case OnboardingPurpose.college:
        return 'University subjects, notes, assignments, lab work and study materials.';
      case OnboardingPurpose.school:
        return 'Classes, subjects, homework, notes and study materials.';
      case OnboardingPurpose.personalLearning:
        return 'Courses, programming, skills, projects and independent learning.';
    }
  }

  IconData get icon {
    switch (this) {
      case OnboardingPurpose.college:
        return Icons.school_outlined;
      case OnboardingPurpose.school:
        return Icons.auto_stories_outlined;
      case OnboardingPurpose.personalLearning:
        return Icons.lightbulb_outline_rounded;
    }
  }

  static OnboardingPurpose fromId(String id) {
    switch (id) {
      case 'college':
        return OnboardingPurpose.college;
      case 'school':
        return OnboardingPurpose.school;
      case 'personal_learning':
      case 'personal':
      default:
        return OnboardingPurpose.personalLearning;
    }
  }
}

/// Lifecycle status for first-time user detection.
enum OnboardingStatus {
  notStarted,
  inProgress,
  completed;

  String toSerializedString() {
    switch (this) {
      case OnboardingStatus.notStarted:
        return 'NOT_STARTED';
      case OnboardingStatus.inProgress:
        return 'IN_PROGRESS';
      case OnboardingStatus.completed:
        return 'COMPLETED';
    }
  }

  static OnboardingStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'IN_PROGRESS':
        return OnboardingStatus.inProgress;
      case 'COMPLETED':
        return OnboardingStatus.completed;
      case 'NOT_STARTED':
      default:
        return OnboardingStatus.notStarted;
    }
  }
}

/// Current onboarding step index in the progressive flow.
enum OnboardingStep {
  purpose,
  setup,
  subjects,
  complete;

  int get stepNumber {
    switch (this) {
      case OnboardingStep.purpose:
        return 1;
      case OnboardingStep.setup:
        return 2;
      case OnboardingStep.subjects:
        return 3;
      case OnboardingStep.complete:
        return 4;
    }
  }

  String get label {
    switch (this) {
      case OnboardingStep.purpose:
        return 'Purpose';
      case OnboardingStep.setup:
        return 'Setup';
      case OnboardingStep.subjects:
        return 'Subjects';
      case OnboardingStep.complete:
        return 'Done';
    }
  }

  static OnboardingStep fromString(String? value) {
    switch (value) {
      case 'setup':
        return OnboardingStep.setup;
      case 'subjects':
        return OnboardingStep.subjects;
      case 'complete':
        return OnboardingStep.complete;
      case 'purpose':
      default:
        return OnboardingStep.purpose;
    }
  }
}

/// Structured profile and semester data for college students.
class CollegeSetupData {
  final String? institutionName;
  final String degree;
  final String branch;
  final String academicYear;
  final String semester;
  final List<String> subjects;

  const CollegeSetupData({
    this.institutionName,
    required this.degree,
    required this.branch,
    required this.academicYear,
    required this.semester,
    this.subjects = const [],
  });

  CollegeSetupData copyWith({
    String? institutionName,
    String? degree,
    String? branch,
    String? academicYear,
    String? semester,
    List<String>? subjects,
  }) {
    return CollegeSetupData(
      institutionName: institutionName ?? this.institutionName,
      degree: degree ?? this.degree,
      branch: branch ?? this.branch,
      academicYear: academicYear ?? this.academicYear,
      semester: semester ?? this.semester,
      subjects: subjects ?? this.subjects,
    );
  }

  Map<String, dynamic> toJson() => {
        'institution_name': institutionName,
        'degree': degree,
        'branch': branch,
        'academic_year': academicYear,
        'semester': semester,
        'subjects': subjects,
      };

  factory CollegeSetupData.fromJson(Map<String, dynamic> json) {
    return CollegeSetupData(
      institutionName: json['institution_name'] as String?,
      degree: json['degree'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      academicYear: json['academic_year'] as String? ?? '',
      semester: json['semester'] as String? ?? '',
      subjects: (json['subjects'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

/// Structured profile and grade data for school students.
class SchoolSetupData {
  final String? schoolName;
  final String academicYear;
  final String grade;
  final String? stream;
  final List<String> subjects;

  const SchoolSetupData({
    this.schoolName,
    required this.academicYear,
    required this.grade,
    this.stream,
    this.subjects = const [],
  });

  SchoolSetupData copyWith({
    String? schoolName,
    String? academicYear,
    String? grade,
    String? stream,
    List<String>? subjects,
  }) {
    return SchoolSetupData(
      schoolName: schoolName ?? this.schoolName,
      academicYear: academicYear ?? this.academicYear,
      grade: grade ?? this.grade,
      stream: stream ?? this.stream,
      subjects: subjects ?? this.subjects,
    );
  }

  Map<String, dynamic> toJson() => {
        'school_name': schoolName,
        'academic_year': academicYear,
        'grade': grade,
        'stream': stream,
        'subjects': subjects,
      };

  factory SchoolSetupData.fromJson(Map<String, dynamic> json) {
    return SchoolSetupData(
      schoolName: json['school_name'] as String?,
      academicYear: json['academic_year'] as String? ?? '',
      grade: json['grade'] as String? ?? '',
      stream: json['stream'] as String?,
      subjects: (json['subjects'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

/// Topics and skill spaces for personal learning users.
class PersonalLearningData {
  final List<String> topics;

  const PersonalLearningData({
    this.topics = const [],
  });

  PersonalLearningData copyWith({
    List<String>? topics,
  }) {
    return PersonalLearningData(
      topics: topics ?? this.topics,
    );
  }

  Map<String, dynamic> toJson() => {
        'topics': topics,
      };

  factory PersonalLearningData.fromJson(Map<String, dynamic> json) {
    return PersonalLearningData(
      topics: (json['topics'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
