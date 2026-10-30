class Classroom {
  final String id;
  final String name;
  final String? section;
  final String? subject;
  final String? room;
  final String code; // 6-char alphanumeric, e.g., 'SV-9X7K'
  final String? description;
  final String bannerTheme; // 'indigo', 'emerald', 'amber', 'rose', 'sky'
  final String creatorId;
  final String creatorName;
  final String? creatorAvatar;
  final String? academicSubjectId;
  final int studentCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Classroom({
    required this.id,
    required this.name,
    this.section,
    this.subject,
    this.room,
    required this.code,
    this.description,
    this.bannerTheme = 'indigo',
    required this.creatorId,
    required this.creatorName,
    this.creatorAvatar,
    this.academicSubjectId,
    this.studentCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool isOwner(String currentUserId) => creatorId == currentUserId;

  Classroom copyWith({
    String? id,
    String? name,
    String? section,
    String? subject,
    String? room,
    String? code,
    String? description,
    String? bannerTheme,
    String? creatorId,
    String? creatorName,
    String? creatorAvatar,
    String? academicSubjectId,
    int? studentCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Classroom(
      id: id ?? this.id,
      name: name ?? this.name,
      section: section ?? this.section,
      subject: subject ?? this.subject,
      room: room ?? this.room,
      code: code ?? this.code,
      description: description ?? this.description,
      bannerTheme: bannerTheme ?? this.bannerTheme,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      creatorAvatar: creatorAvatar ?? this.creatorAvatar,
      academicSubjectId: academicSubjectId ?? this.academicSubjectId,
      studentCount: studentCount ?? this.studentCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'section': section,
      'subject': subject,
      'room': room,
      'code': code,
      'description': description,
      'banner_theme': bannerTheme,
      'creator_id': creatorId,
      'creator_name': creatorName,
      'creator_avatar': creatorAvatar,
      'academic_subject_id': academicSubjectId,
      'student_count': studentCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Classroom.fromMap(Map<String, dynamic> map) {
    return Classroom(
      id: map['id'] as String,
      name: map['name'] as String,
      section: map['section'] as String?,
      subject: map['subject'] as String?,
      room: map['room'] as String?,
      code: map['code'] as String? ?? 'SV-DEMO',
      description: map['description'] as String?,
      bannerTheme: map['banner_theme'] as String? ?? 'indigo',
      creatorId: map['creator_id'] as String? ?? '',
      creatorName: map['creator_name'] as String? ?? 'Instructor',
      creatorAvatar: map['creator_avatar'] as String?,
      academicSubjectId: map['academic_subject_id'] as String?,
      studentCount: (map['student_count'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
