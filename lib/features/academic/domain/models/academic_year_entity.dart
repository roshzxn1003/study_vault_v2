/// Represents an academic calendar year (e.g. "2026–27", "2025–26").
/// A user can have multiple academic years across their academic career.
class AcademicYearEntity {
  final String id;
  final String workspaceId;
  final String userId;
  final String yearName;
  final bool isCurrent;
  final DateTime createdAt;

  const AcademicYearEntity({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.yearName,
    this.isCurrent = false,
    required this.createdAt,
  });

  AcademicYearEntity copyWith({
    String? id,
    String? workspaceId,
    String? userId,
    String? yearName,
    bool? isCurrent,
    DateTime? createdAt,
  }) {
    return AcademicYearEntity(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      userId: userId ?? this.userId,
      yearName: yearName ?? this.yearName,
      isCurrent: isCurrent ?? this.isCurrent,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'user_id': userId,
        'year_name': yearName,
        'is_current': isCurrent ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory AcademicYearEntity.fromJson(Map<String, dynamic> map) {
    return AcademicYearEntity(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String,
      userId: map['user_id'] as String,
      yearName: map['year_name'] as String,
      isCurrent: (map['is_current'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
