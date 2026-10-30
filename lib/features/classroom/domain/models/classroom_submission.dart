import 'dart:convert';

enum SubmissionStatus { assigned, turnedIn, graded, missing }

class ClassroomSubmission {
  final String id;
  final String classroomId;
  final String itemId;
  final String studentId;
  final String studentName;
  final String? studentEmail;
  final SubmissionStatus status;
  final DateTime? submittedAt;
  final String content; // Text response, markdown or summary
  final List<String> attachedMaterialIds;
  final double? grade;
  final String? teacherFeedback;
  final double? aiSuggestedScore;
  final String? aiFeedbackDraft;
  final Map<String, double> rubricScores;
  final DateTime? gradedAt;

  const ClassroomSubmission({
    required this.id,
    required this.classroomId,
    required this.itemId,
    required this.studentId,
    required this.studentName,
    this.studentEmail,
    this.status = SubmissionStatus.assigned,
    this.submittedAt,
    this.content = '',
    this.attachedMaterialIds = const [],
    this.grade,
    this.teacherFeedback,
    this.aiSuggestedScore,
    this.aiFeedbackDraft,
    this.rubricScores = const {},
    this.gradedAt,
  });

  bool get isTurnedIn => status == SubmissionStatus.turnedIn || status == SubmissionStatus.graded;
  bool get isGraded => status == SubmissionStatus.graded;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'classroom_id': classroomId,
      'item_id': itemId,
      'student_id': studentId,
      'student_name': studentName,
      'student_email': studentEmail,
      'status': status.name,
      'submitted_at': submittedAt?.toIso8601String(),
      'content': content,
      'attached_material_ids': jsonEncode(attachedMaterialIds),
      'grade': grade,
      'teacher_feedback': teacherFeedback,
      'ai_suggested_score': aiSuggestedScore,
      'ai_feedback_draft': aiFeedbackDraft,
      'rubric_scores_json': jsonEncode(rubricScores),
      'graded_at': gradedAt?.toIso8601String(),
    };
  }

  factory ClassroomSubmission.fromMap(Map<String, dynamic> map) {
    Map<String, double> parsedScores = {};
    if (map['rubric_scores_json'] != null) {
      try {
        final decoded = jsonDecode(map['rubric_scores_json'] as String);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            parsedScores[k.toString()] = (v as num).toDouble();
          });
        }
      } catch (_) {}
    }

    List<String> parsedAttachments = [];
    if (map['attached_material_ids'] != null) {
      try {
        final decoded = jsonDecode(map['attached_material_ids'] as String);
        if (decoded is List) {
          parsedAttachments = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    SubmissionStatus parsedStatus = SubmissionStatus.assigned;
    final statusStr = map['status'] as String?;
    if (statusStr != null) {
      for (final val in SubmissionStatus.values) {
        if (val.name == statusStr) {
          parsedStatus = val;
          break;
        }
      }
    }

    return ClassroomSubmission(
      id: map['id'] as String,
      classroomId: map['classroom_id'] as String,
      itemId: map['item_id'] as String,
      studentId: map['student_id'] as String,
      studentName: map['student_name'] as String? ?? 'Student',
      studentEmail: map['student_email'] as String?,
      status: parsedStatus,
      submittedAt: map['submitted_at'] != null
          ? DateTime.tryParse(map['submitted_at'] as String)
          : null,
      content: map['content'] as String? ?? '',
      attachedMaterialIds: parsedAttachments,
      grade: (map['grade'] as num?)?.toDouble(),
      teacherFeedback: map['teacher_feedback'] as String?,
      aiSuggestedScore: (map['ai_suggested_score'] as num?)?.toDouble(),
      aiFeedbackDraft: map['ai_feedback_draft'] as String?,
      rubricScores: parsedScores,
      gradedAt: map['graded_at'] != null
          ? DateTime.tryParse(map['graded_at'] as String)
          : null,
    );
  }
}
