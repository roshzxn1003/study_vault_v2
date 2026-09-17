/// Represents a learning topic or skill in a Personal Learning workspace.
/// Independent of degrees, semesters, or academic years.
class PersonalTopicEntity {
  final String id;
  final String workspaceId;
  final String userId;
  final String name;
  final String? description;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersonalTopicEntity({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.name,
    this.description,
    this.orderIndex = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  PersonalTopicEntity copyWith({
    String? id,
    String? workspaceId,
    String? userId,
    String? name,
    String? description,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PersonalTopicEntity(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'user_id': userId,
        'name': name,
        'description': description,
        'order_index': orderIndex,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory PersonalTopicEntity.fromJson(Map<String, dynamic> map) {
    return PersonalTopicEntity(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String,
      userId: map['user_id'] as String? ?? 'guest',
      name: map['name'] as String,
      description: map['description'] as String?,
      orderIndex: (map['order_index'] as int?) ?? 0,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
