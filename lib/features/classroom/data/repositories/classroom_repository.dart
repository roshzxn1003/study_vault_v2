import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../../../core/database/local_db_service.dart';
import '../../domain/models/models.dart';

class ClassroomRepository {
  final LocalDbService _db;
  final Uuid _uuid = const Uuid();

  ClassroomRepository({LocalDbService? db}) : _db = db ?? LocalDbService.instance;

  String generateClassCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final buffer = StringBuffer('SV-');
    for (int i = 0; i < 4; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  Future<List<Classroom>> fetchClassrooms({String? userId}) async {
    final rows = await _db.getClassrooms(userId: userId);
    return rows.map((r) => Classroom.fromMap(r)).toList();
  }

  Future<Classroom?> getClassroomById(String id) async {
    final row = await _db.getClassroomById(id);
    return row != null ? Classroom.fromMap(row) : null;
  }

  Future<Classroom> createClassroom({
    required String name,
    String? section,
    String? subject,
    String? room,
    String? description,
    String bannerTheme = 'indigo',
    required String creatorId,
    required String creatorName,
    String? creatorAvatar,
  }) async {
    final now = DateTime.now();
    final classroom = Classroom(
      id: _uuid.v4(),
      name: name,
      section: section,
      subject: subject,
      room: room,
      code: generateClassCode(),
      description: description,
      bannerTheme: bannerTheme,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorAvatar: creatorAvatar,
      studentCount: 1,
      createdAt: now,
      updatedAt: now,
    );

    await _db.insertClassroom(classroom.toMap());

    // Automatically add creator as teacher in members
    final member = ClassroomMember(
      id: _uuid.v4(),
      classroomId: classroom.id,
      userId: creatorId,
      role: 'teacher',
      name: creatorName,
      joinedAt: now,
    );
    await _db.insertClassroomMember(member.toMap());

    return classroom;
  }

  Future<Classroom?> joinClassroomWithCode({
    required String code,
    required String studentId,
    required String studentName,
    String? email,
  }) async {
    final row = await _db.getClassroomByCode(code);
    if (row == null) return null;

    final classroom = Classroom.fromMap(row);

    // Insert student into members
    final member = ClassroomMember(
      id: _uuid.v4(),
      classroomId: classroom.id,
      userId: studentId,
      role: 'student',
      name: studentName,
      email: email,
      joinedAt: DateTime.now(),
    );
    await _db.insertClassroomMember(member.toMap());

    // Increment student count
    final updatedClass = classroom.copyWith(
      studentCount: classroom.studentCount + 1,
      updatedAt: DateTime.now(),
    );
    await _db.updateClassroom(updatedClass.id, updatedClass.toMap());

    return updatedClass;
  }

  Future<List<ClassroomTopic>> fetchClassroomTopics(String classroomId) async {
    final rows = await _db.getClassroomTopics(classroomId);
    return rows.map((r) => ClassroomTopic.fromMap(r)).toList();
  }

  Future<ClassroomTopic> createClassroomTopic(String classroomId, String title) async {
    final topic = ClassroomTopic(
      id: _uuid.v4(),
      classroomId: classroomId,
      title: title,
      createdAt: DateTime.now(),
    );
    await _db.insertClassroomTopic(topic.toMap());
    return topic;
  }

  Future<List<ClassroomItem>> fetchClassroomItems(
    String classroomId, {
    String? topicId,
    String? type,
  }) async {
    final rows = await _db.getClassroomItems(
      classroomId,
      topicId: topicId,
      type: type,
    );
    return rows.map((r) => ClassroomItem.fromMap(r)).toList();
  }

  Future<ClassroomItem?> getClassroomItemById(String id) async {
    final row = await _db.getClassroomItemById(id);
    return row != null ? ClassroomItem.fromMap(row) : null;
  }

  Future<ClassroomItem> createClassroomItem(ClassroomItem item) async {
    await _db.insertClassroomItem(item.toMap());
    return item;
  }

  Future<List<ClassroomSubmission>> fetchClassroomSubmissions(
    String classroomId, {
    String? itemId,
    String? studentId,
  }) async {
    final rows = await _db.getClassroomSubmissions(
      classroomId,
      itemId: itemId,
      studentId: studentId,
    );
    return rows.map((r) => ClassroomSubmission.fromMap(r)).toList();
  }

  Future<ClassroomSubmission?> getSubmissionById(String id) async {
    final row = await _db.getSubmissionById(id);
    return row != null ? ClassroomSubmission.fromMap(row) : null;
  }

  Future<void> submitAssignment(ClassroomSubmission submission) async {
    await _db.insertOrUpdateSubmission(submission.toMap());
  }

  Future<void> gradeSubmission({
    required String submissionId,
    required double grade,
    required String feedback,
    Map<String, double>? rubricScores,
  }) async {
    final row = await _db.getSubmissionById(submissionId);
    if (row != null) {
      final existing = ClassroomSubmission.fromMap(row);
      final updated = ClassroomSubmission(
        id: existing.id,
        classroomId: existing.classroomId,
        itemId: existing.itemId,
        studentId: existing.studentId,
        studentName: existing.studentName,
        studentEmail: existing.studentEmail,
        status: SubmissionStatus.graded,
        submittedAt: existing.submittedAt,
        content: existing.content,
        attachedMaterialIds: existing.attachedMaterialIds,
        grade: grade,
        teacherFeedback: feedback,
        aiSuggestedScore: existing.aiSuggestedScore,
        aiFeedbackDraft: existing.aiFeedbackDraft,
        rubricScores: rubricScores ?? existing.rubricScores,
        gradedAt: DateTime.now(),
      );
      await _db.insertOrUpdateSubmission(updated.toMap());
    }
  }

  Future<List<ClassroomAnnouncement>> fetchClassroomAnnouncements(String classroomId) async {
    final rows = await _db.getClassroomAnnouncements(classroomId);
    return rows.map((r) => ClassroomAnnouncement.fromMap(r)).toList();
  }

  Future<ClassroomAnnouncement> postAnnouncement(ClassroomAnnouncement announcement) async {
    await _db.insertClassroomAnnouncement(announcement.toMap());
    return announcement;
  }

  Future<List<ClassroomMember>> fetchClassroomMembers(String classroomId) async {
    final rows = await _db.getClassroomMembers(classroomId);
    return rows.map((r) => ClassroomMember.fromMap(r)).toList();
  }
}
