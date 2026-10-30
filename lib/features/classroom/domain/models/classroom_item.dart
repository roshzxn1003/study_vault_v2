import 'dart:convert';

enum ClassroomItemType { assignment, material, quiz, question }

class RubricCriterion {
  final String title;
  final String description;
  final int maxPoints;

  const RubricCriterion({
    required this.title,
    required this.description,
    required this.maxPoints,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'max_points': maxPoints,
    };
  }

  factory RubricCriterion.fromMap(Map<String, dynamic> map) {
    return RubricCriterion(
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      maxPoints: (map['max_points'] as num?)?.toInt() ?? 10,
    );
  }
}

class ClassroomItem {
  final String id;
  final String classroomId;
  final String? topicId;
  final ClassroomItemType type;
  final String title;
  final String description;
  final DateTime? dueDate;
  final int maxPoints;
  final List<RubricCriterion> rubric;
  final List<String> attachmentIds; // Vault material IDs
  final String creatorId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClassroomItem({
    required this.id,
    required this.classroomId,
    this.topicId,
    required this.type,
    required this.title,
    required this.description,
    this.dueDate,
    this.maxPoints = 100,
    this.rubric = const [],
    this.attachmentIds = const [],
    required this.creatorId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAssignment => type == ClassroomItemType.assignment;
  bool get isMaterial => type == ClassroomItemType.material;
  bool get isQuiz => type == ClassroomItemType.quiz;
  bool get isQuestion => type == ClassroomItemType.question;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'classroom_id': classroomId,
      'topic_id': topicId,
      'type': type.name,
      'title': title,
      'description': description,
      'due_date': dueDate?.toIso8601String(),
      'max_points': maxPoints,
      'rubric_json': jsonEncode(rubric.map((r) => r.toMap()).toList()),
      'attachment_ids': jsonEncode(attachmentIds),
      'creator_id': creatorId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ClassroomItem.fromMap(Map<String, dynamic> map) {
    List<RubricCriterion> parsedRubric = [];
    if (map['rubric_json'] != null) {
      try {
        final decoded = jsonDecode(map['rubric_json'] as String);
        if (decoded is List) {
          parsedRubric = decoded
              .map((item) => RubricCriterion.fromMap(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
      } catch (_) {}
    }

    List<String> parsedAttachments = [];
    if (map['attachment_ids'] != null) {
      try {
        final decoded = jsonDecode(map['attachment_ids'] as String);
        if (decoded is List) {
          parsedAttachments = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    ClassroomItemType parsedType = ClassroomItemType.assignment;
    final typeStr = map['type'] as String?;
    if (typeStr != null) {
      for (final val in ClassroomItemType.values) {
        if (val.name == typeStr) {
          parsedType = val;
          break;
        }
      }
    }

    return ClassroomItem(
      id: map['id'] as String,
      classroomId: map['classroom_id'] as String,
      topicId: map['topic_id'] as String?,
      type: parsedType,
      title: map['title'] as String? ?? 'Untitled',
      description: map['description'] as String? ?? '',
      dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date'] as String) : null,
      maxPoints: (map['max_points'] as num?)?.toInt() ?? 100,
      rubric: parsedRubric,
      attachmentIds: parsedAttachments,
      creatorId: map['creator_id'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
