/// Represents a hierarchical folder in the Vault or within an academic subject.
class VaultFolder {
  final String id;
  final String userId;
  final String? workspaceId;
  final String? academicPeriodId;
  final String? subjectId;
  final String name;
  final String? parentId;
  final int orderIndex;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int materialCount;
  final int subfolderCount;

  const VaultFolder({
    required this.id,
    required this.userId,
    this.workspaceId,
    this.academicPeriodId,
    this.subjectId,
    required this.name,
    this.parentId,
    this.orderIndex = 0,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
    this.materialCount = 0,
    this.subfolderCount = 0,
  });

  bool get isRoot => parentId == null || parentId!.isEmpty;
  bool get hasContents => materialCount > 0 || subfolderCount > 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'workspace_id': workspaceId,
      'academic_period_id': academicPeriodId,
      'subject_id': subjectId,
      'name': name,
      'parent_id': parentId,
      'order_index': orderIndex,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory VaultFolder.fromMap(Map<String, dynamic> map, {int materialCount = 0, int subfolderCount = 0}) {
    return VaultFolder(
      id: map['id'] as String,
      userId: map['user_id'] as String? ?? 'guest',
      workspaceId: map['workspace_id'] as String?,
      academicPeriodId: map['academic_period_id'] as String?,
      subjectId: map['subject_id'] as String?,
      name: map['name'] as String,
      parentId: map['parent_id'] as String?,
      orderIndex: (map['order_index'] as num?)?.toInt() ?? 0,
      isArchived: (map['is_archived'] as num?)?.toInt() == 1,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
      materialCount: materialCount,
      subfolderCount: subfolderCount,
    );
  }

  VaultFolder copyWith({
    String? id,
    String? userId,
    String? workspaceId,
    String? academicPeriodId,
    String? subjectId,
    String? name,
    String? parentId,
    int? orderIndex,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? materialCount,
    int? subfolderCount,
  }) {
    return VaultFolder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      workspaceId: workspaceId ?? this.workspaceId,
      academicPeriodId: academicPeriodId ?? this.academicPeriodId,
      subjectId: subjectId ?? this.subjectId,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      orderIndex: orderIndex ?? this.orderIndex,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      materialCount: materialCount ?? this.materialCount,
      subfolderCount: subfolderCount ?? this.subfolderCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultFolder &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
