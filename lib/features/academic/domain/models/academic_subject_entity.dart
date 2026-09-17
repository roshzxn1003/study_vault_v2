/// Represents a course or subject belonging to a specific academic period.
class AcademicSubjectEntity {
  final String id;
  final String? academicPeriodId;
  final String? academicStructureId;
  final String userId;
  final String name;
  final String? code;
  final String? description;
  final int orderIndex;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AcademicSubjectEntity({
    required this.id,
    this.academicPeriodId,
    this.academicStructureId,
    required this.userId,
    required this.name,
    this.code,
    this.description,
    this.orderIndex = 0,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  AcademicSubjectEntity copyWith({
    String? id,
    String? academicPeriodId,
    String? academicStructureId,
    String? userId,
    String? name,
    String? code,
    String? description,
    int? orderIndex,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AcademicSubjectEntity(
      id: id ?? this.id,
      academicPeriodId: academicPeriodId ?? this.academicPeriodId,
      academicStructureId: academicStructureId ?? this.academicStructureId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'academic_period_id': academicPeriodId,
        'academic_structure_id': academicStructureId,
        'user_id': userId,
        'name': name,
        'code': code,
        'description': description,
        'order_index': orderIndex,
        'is_archived': isArchived ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory AcademicSubjectEntity.fromJson(Map<String, dynamic> map) {
    return AcademicSubjectEntity(
      id: map['id'] as String,
      academicPeriodId: map['academic_period_id'] as String?,
      academicStructureId: map['academic_structure_id'] as String?,
      userId: map['user_id'] as String? ?? 'guest',
      name: map['name'] as String,
      code: map['code'] as String?,
      description: map['description'] as String?,
      orderIndex: (map['order_index'] as int?) ?? 0,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
