/// Study Group entity representing collaborative peer groups.
class StudyGroup {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final int memberCount;
  final String? ownerUsername;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyGroup({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.memberCount = 1,
    this.ownerUsername,
    required this.createdAt,
    required this.updatedAt,
  });

  bool isOwner(String userId) => ownerId == userId;

  String get displayOwner => ownerUsername != null ? '@${ownerUsername!.replaceAll('@', '')}' : 'Owner';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'description': description,
      'member_count': memberCount,
      'owner_username': ownerUsername,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StudyGroup.fromMap(Map<String, dynamic> map) {
    return StudyGroup(
      id: map['id']?.toString() ?? '',
      ownerId: map['owner_id']?.toString() ?? '',
      name: (map['name'] as String?)?.trim() ?? 'Untitled Study Group',
      description: map['description'] as String?,
      memberCount: (map['member_count'] as num?)?.toInt() ?? 1,
      ownerUsername: map['owner_username'] as String?,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  StudyGroup copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    int? memberCount,
    String? ownerUsername,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyGroup(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      memberCount: memberCount ?? this.memberCount,
      ownerUsername: ownerUsername ?? this.ownerUsername,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
