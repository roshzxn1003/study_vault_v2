class ClassroomAnnouncement {
  final String id;
  final String classroomId;
  final String authorId;
  final String authorName;
  final String authorRole; // 'teacher', 'student'
  final String content;
  final bool isPinned;
  final DateTime createdAt;

  const ClassroomAnnouncement({
    required this.id,
    required this.classroomId,
    required this.authorId,
    required this.authorName,
    this.authorRole = 'teacher',
    required this.content,
    this.isPinned = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'classroom_id': classroomId,
      'author_id': authorId,
      'author_name': authorName,
      'author_role': authorRole,
      'content': content,
      'is_pinned': isPinned ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ClassroomAnnouncement.fromMap(Map<String, dynamic> map) {
    return ClassroomAnnouncement(
      id: map['id'] as String,
      classroomId: map['classroom_id'] as String,
      authorId: map['author_id'] as String? ?? '',
      authorName: map['author_name'] as String? ?? 'Instructor',
      authorRole: map['author_role'] as String? ?? 'teacher',
      content: map['content'] as String? ?? '',
      isPinned: (map['is_pinned'] as num?)?.toInt() == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ClassroomTopic {
  final String id;
  final String classroomId;
  final String title;
  final int orderIndex;
  final DateTime createdAt;

  const ClassroomTopic({
    required this.id,
    required this.classroomId,
    required this.title,
    this.orderIndex = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'classroom_id': classroomId,
      'title': title,
      'order_index': orderIndex,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ClassroomTopic.fromMap(Map<String, dynamic> map) {
    return ClassroomTopic(
      id: map['id'] as String,
      classroomId: map['classroom_id'] as String,
      title: map['title'] as String? ?? 'General',
      orderIndex: (map['order_index'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ClassroomMember {
  final String id;
  final String classroomId;
  final String userId;
  final String role; // 'teacher', 'student'
  final String name;
  final String? email;
  final DateTime joinedAt;

  const ClassroomMember({
    required this.id,
    required this.classroomId,
    required this.userId,
    required this.role,
    required this.name,
    this.email,
    required this.joinedAt,
  });

  bool get isTeacher => role == 'teacher' || role == 'co_teacher';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'classroom_id': classroomId,
      'user_id': userId,
      'role': role,
      'name': name,
      'email': email,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  factory ClassroomMember.fromMap(Map<String, dynamic> map) {
    return ClassroomMember(
      id: map['id'] as String,
      classroomId: map['classroom_id'] as String,
      userId: map['user_id'] as String? ?? '',
      role: map['role'] as String? ?? 'student',
      name: map['name'] as String? ?? 'Student',
      email: map['email'] as String?,
      joinedAt: map['joined_at'] != null
          ? DateTime.tryParse(map['joined_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
