class Exam {
  final String id;
  final String userId;
  final String name;
  final DateTime examDate;
  final DateTime createdAt;

  Exam({
    required this.id,
    required this.userId,
    required this.name,
    required this.examDate,
    required this.createdAt,
  });

  factory Exam.fromMap(Map<String, dynamic> map) {
    return Exam(
      id: map['id'],
      userId: map['user_id'],
      name: map['name'],
      examDate: DateTime.parse(map['exam_date']),
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'exam_date': examDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
