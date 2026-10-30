import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/classroom_repository.dart';
import '../../domain/models/models.dart';

final classroomRepositoryProvider = Provider<ClassroomRepository>((ref) {
  return ClassroomRepository();
});

class ClassroomListNotifier extends StateNotifier<AsyncValue<List<Classroom>>> {
  final ClassroomRepository _repository;

  ClassroomListNotifier(this._repository, {bool autoLoad = true}) : super(const AsyncValue.loading()) {
    if (autoLoad) {
      loadClassrooms();
    }
  }

  Future<void> loadClassrooms({String? userId}) async {
    try {
      if (mounted) state = const AsyncValue.loading();
      final list = await _repository.fetchClassrooms(userId: userId);
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<Classroom?> createClassroom({
    required String name,
    String? section,
    String? subject,
    String? room,
    String? description,
    String bannerTheme = 'indigo',
    required String creatorId,
    required String creatorName,
  }) async {
    try {
      final created = await _repository.createClassroom(
        name: name,
        section: section,
        subject: subject,
        room: room,
        description: description,
        bannerTheme: bannerTheme,
        creatorId: creatorId,
        creatorName: creatorName,
      );
      await loadClassrooms();
      return created;
    } catch (e) {
      return null;
    }
  }

  Future<Classroom?> joinClassroomWithCode({
    required String code,
    required String studentId,
    required String studentName,
    String? email,
  }) async {
    try {
      final joined = await _repository.joinClassroomWithCode(
        code: code,
        studentId: studentId,
        studentName: studentName,
        email: email,
      );
      if (joined != null) {
        await loadClassrooms();
      }
      return joined;
    } catch (e) {
      return null;
    }
  }
}

final classroomListProvider =
    StateNotifierProvider<ClassroomListNotifier, AsyncValue<List<Classroom>>>((ref) {
  final repo = ref.watch(classroomRepositoryProvider);
  return ClassroomListNotifier(repo);
});

class ClassroomDetailState {
  final Classroom classroom;
  final List<ClassroomTopic> topics;
  final List<ClassroomItem> items;
  final List<ClassroomAnnouncement> announcements;
  final List<ClassroomMember> members;
  final List<ClassroomSubmission> submissions;
  final int selectedTabIndex; // 0: Stream, 1: Classwork, 2: People, 3: Grades
  final String? selectedTopicId;

  const ClassroomDetailState({
    required this.classroom,
    this.topics = const [],
    this.items = const [],
    this.announcements = const [],
    this.members = const [],
    this.submissions = const [],
    this.selectedTabIndex = 0,
    this.selectedTopicId,
  });

  ClassroomDetailState copyWith({
    Classroom? classroom,
    List<ClassroomTopic>? topics,
    List<ClassroomItem>? items,
    List<ClassroomAnnouncement>? announcements,
    List<ClassroomMember>? members,
    List<ClassroomSubmission>? submissions,
    int? selectedTabIndex,
    String? selectedTopicId,
    bool clearSelectedTopic = false,
  }) {
    return ClassroomDetailState(
      classroom: classroom ?? this.classroom,
      topics: topics ?? this.topics,
      items: items ?? this.items,
      announcements: announcements ?? this.announcements,
      members: members ?? this.members,
      submissions: submissions ?? this.submissions,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      selectedTopicId: clearSelectedTopic ? null : (selectedTopicId ?? this.selectedTopicId),
    );
  }
}

class ClassroomDetailNotifier extends StateNotifier<AsyncValue<ClassroomDetailState>> {
  final ClassroomRepository _repository;
  final String _classroomId;
  final Uuid _uuid = const Uuid();

  ClassroomDetailNotifier(this._repository, this._classroomId, {bool autoLoad = true})
      : super(const AsyncValue.loading()) {
    if (autoLoad) {
      loadDetails();
    }
  }

  Future<void> loadDetails() async {
    try {
      if (mounted) state = const AsyncValue.loading();
      final classroom = await _repository.getClassroomById(_classroomId);
      if (!mounted) return;
      if (classroom == null) {
        state = AsyncValue.error('Classroom not found', StackTrace.current);
        return;
      }

      final topics = await _repository.fetchClassroomTopics(_classroomId);
      final items = await _repository.fetchClassroomItems(_classroomId);
      final announcements = await _repository.fetchClassroomAnnouncements(_classroomId);
      final members = await _repository.fetchClassroomMembers(_classroomId);
      final submissions = await _repository.fetchClassroomSubmissions(_classroomId);

      if (mounted) {
        state = AsyncValue.data(ClassroomDetailState(
          classroom: classroom,
          topics: topics,
          items: items,
          announcements: announcements,
          members: members,
          submissions: submissions,
        ));
      }
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  void setTab(int tabIndex) {
    state.whenData((current) {
      state = AsyncValue.data(current.copyWith(selectedTabIndex: tabIndex));
    });
  }

  void filterByTopic(String? topicId) {
    state.whenData((current) {
      state = AsyncValue.data(
        current.copyWith(
          selectedTopicId: topicId,
          clearSelectedTopic: topicId == null,
        ),
      );
    });
  }

  Future<bool> postAnnouncement({
    required String authorId,
    required String authorName,
    required String content,
    bool isPinned = false,
  }) async {
    try {
      final ann = ClassroomAnnouncement(
        id: _uuid.v4(),
        classroomId: _classroomId,
        authorId: authorId,
        authorName: authorName,
        content: content,
        isPinned: isPinned,
        createdAt: DateTime.now(),
      );
      await _repository.postAnnouncement(ann);
      await loadDetails();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> createItem({
    required ClassroomItemType type,
    required String title,
    required String description,
    String? topicId,
    DateTime? dueDate,
    int maxPoints = 100,
    List<RubricCriterion> rubric = const [],
    required String creatorId,
  }) async {
    try {
      final now = DateTime.now();
      final item = ClassroomItem(
        id: _uuid.v4(),
        classroomId: _classroomId,
        topicId: topicId,
        type: type,
        title: title,
        description: description,
        dueDate: dueDate,
        maxPoints: maxPoints,
        rubric: rubric,
        creatorId: creatorId,
        createdAt: now,
        updatedAt: now,
      );
      await _repository.createClassroomItem(item);
      await loadDetails();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> submitAssignment({
    required String itemId,
    required String studentId,
    required String studentName,
    String? studentEmail,
    required String content,
    List<String> attachedMaterialIds = const [],
  }) async {
    try {
      final sub = ClassroomSubmission(
        id: _uuid.v4(),
        classroomId: _classroomId,
        itemId: itemId,
        studentId: studentId,
        studentName: studentName,
        studentEmail: studentEmail,
        status: SubmissionStatus.turnedIn,
        submittedAt: DateTime.now(),
        content: content,
        attachedMaterialIds: attachedMaterialIds,
      );
      await _repository.submitAssignment(sub);
      await loadDetails();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> gradeSubmission({
    required String submissionId,
    required double grade,
    required String feedback,
  }) async {
    try {
      await _repository.gradeSubmission(
        submissionId: submissionId,
        grade: grade,
        feedback: feedback,
      );
      await loadDetails();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final classroomDetailProvider = StateNotifierProvider.family<ClassroomDetailNotifier,
    AsyncValue<ClassroomDetailState>, String>((ref, classroomId) {
  final repo = ref.watch(classroomRepositoryProvider);
  return ClassroomDetailNotifier(repo, classroomId);
});
