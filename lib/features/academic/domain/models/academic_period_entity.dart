/// Type of academic period.
enum AcademicPeriodType {
  semester,
  classGrade;

  String toSerializedString() {
    switch (this) {
      case AcademicPeriodType.semester:
        return 'semester';
      case AcademicPeriodType.classGrade:
        return 'class';
    }
  }

  static AcademicPeriodType fromString(String? val) {
    if (val == 'class' || val == 'classGrade') {
      return AcademicPeriodType.classGrade;
    }
    return AcademicPeriodType.semester;
  }
}

/// Represents an individual semester (College) or class grade (School).
/// Can be marked as Current or Previous/Archived.
class AcademicPeriodEntity {
  final String id;
  final String workspaceId;
  final String academicYearId;
  final String userId;
  final String name;
  final AcademicPeriodType periodType;
  final bool isCurrent;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AcademicPeriodEntity({
    required this.id,
    required this.workspaceId,
    required this.academicYearId,
    required this.userId,
    required this.name,
    this.periodType = AcademicPeriodType.semester,
    this.isCurrent = false,
    required this.createdAt,
    required this.updatedAt,
  });

  AcademicPeriodEntity copyWith({
    String? id,
    String? workspaceId,
    String? academicYearId,
    String? userId,
    String? name,
    AcademicPeriodType? periodType,
    bool? isCurrent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AcademicPeriodEntity(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      academicYearId: academicYearId ?? this.academicYearId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      periodType: periodType ?? this.periodType,
      isCurrent: isCurrent ?? this.isCurrent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'academic_year_id': academicYearId,
        'user_id': userId,
        'name': name,
        'period_type': periodType.toSerializedString(),
        'is_current': isCurrent ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory AcademicPeriodEntity.fromJson(Map<String, dynamic> map) {
    return AcademicPeriodEntity(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String,
      academicYearId: map['academic_year_id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      periodType: AcademicPeriodType.fromString(map['period_type'] as String?),
      isCurrent: (map['is_current'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
