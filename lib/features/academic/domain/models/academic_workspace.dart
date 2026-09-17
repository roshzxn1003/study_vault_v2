import 'package:study_vault/features/onboarding/domain/models/onboarding_models.dart';

/// Representation of a distinct study workspace (e.g. College, School, Personal Learning).
class AcademicWorkspace {
  final String id;
  final String userId;
  final String name;
  final OnboardingPurpose purpose;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AcademicWorkspace({
    required this.id,
    required this.userId,
    required this.name,
    required this.purpose,
    required this.createdAt,
    required this.updatedAt,
  });

  AcademicWorkspace copyWith({
    String? id,
    String? userId,
    String? name,
    OnboardingPurpose? purpose,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AcademicWorkspace(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      purpose: purpose ?? this.purpose,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'purpose': purpose.id,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory AcademicWorkspace.fromJson(Map<String, dynamic> map) {
    return AcademicWorkspace(
      id: map['id'] as String,
      userId: map['user_id'] as String? ?? 'guest',
      name: map['name'] as String? ?? 'My Study Vault',
      purpose: OnboardingPurpose.fromId(map['purpose'] as String? ?? 'college'),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
