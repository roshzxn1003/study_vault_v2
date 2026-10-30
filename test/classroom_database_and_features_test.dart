import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/classroom/domain/models/models.dart';
import 'package:study_vault/features/classroom/data/repositories/classroom_repository.dart';
import 'package:study_vault/features/classroom/data/services/classroom_ai_service.dart';
import 'package:study_vault/features/classroom/presentation/providers/classroom_providers.dart';
import 'package:study_vault/features/classroom/presentation/screens/classroom_list_screen.dart';
import 'package:study_vault/features/classroom/presentation/screens/classroom_detail_screen.dart';
import 'package:study_vault/features/dashboard/presentation/widgets/dashboard_classrooms_card.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDbService.instance.setCustomPathForTesting(inMemoryDatabasePath);
  });

  tearDownAll(() async {
    await LocalDbService.instance.closeForTesting();
  });

  group('Google Classroom Domain Models Unit Tests', () {
    test('Classroom model serializes and deserializes accurately', () {
      final now = DateTime.now();
      final classroom = Classroom(
        id: 'cls-1',
        name: 'Distributed Systems',
        section: 'CS-401',
        subject: 'Computer Science',
        room: 'Room 204',
        code: 'SV-TEST',
        description: 'Test description',
        bannerTheme: 'indigo',
        creatorId: 'prof-1',
        creatorName: 'Dr. Lin',
        studentCount: 25,
        createdAt: now,
        updatedAt: now,
      );

      final map = classroom.toMap();
      expect(map['id'], 'cls-1');
      expect(map['code'], 'SV-TEST');

      final fromMap = Classroom.fromMap(map);
      expect(fromMap.id, 'cls-1');
      expect(fromMap.name, 'Distributed Systems');
      expect(fromMap.isOwner('prof-1'), isTrue);
      expect(fromMap.isOwner('student-1'), isFalse);
    });

    test('ClassroomItem model parses rubric criteria and types correctly', () {
      const rubric = [
        RubricCriterion(title: 'Logic', description: 'Correct algorithm', maxPoints: 50),
        RubricCriterion(title: 'Style', description: 'Clean code', maxPoints: 50),
      ];

      final now = DateTime.now();
      final item = ClassroomItem(
        id: 'item-1',
        classroomId: 'cls-1',
        type: ClassroomItemType.assignment,
        title: 'Assignment 1',
        description: 'Implement Raft',
        dueDate: now.add(const Duration(days: 5)),
        maxPoints: 100,
        rubric: rubric,
        creatorId: 'prof-1',
        createdAt: now,
        updatedAt: now,
      );

      expect(item.isAssignment, isTrue);
      expect(item.isMaterial, isFalse);

      final map = item.toMap();
      final restored = ClassroomItem.fromMap(map);
      expect(restored.rubric.length, 2);
      expect(restored.rubric.first.title, 'Logic');
      expect(restored.rubric.first.maxPoints, 50);
    });

    test('ClassroomSubmission tracks turn-in status and grades', () {
      final sub = ClassroomSubmission(
        id: 'sub-1',
        classroomId: 'cls-1',
        itemId: 'item-1',
        studentId: 'stud-1',
        studentName: 'Alex',
        status: SubmissionStatus.turnedIn,
        content: 'Draft solution outline',
        grade: 95.0,
      );

      expect(sub.isTurnedIn, isTrue);
      final map = sub.toMap();
      final restored = ClassroomSubmission.fromMap(map);
      expect(restored.studentName, 'Alex');
      expect(restored.grade, 95.0);
    });
  });

  group('Classroom Repository & SQLite Integration Tests', () {
    late ClassroomRepository repository;

    setUp(() {
      repository = ClassroomRepository();
    });

    test('generateClassCode produces SV- formatted 6-char unique codes', () {
      final code1 = repository.generateClassCode();
      final code2 = repository.generateClassCode();
      expect(code1.startsWith('SV-'), isTrue);
      expect(code1.length, 7);
      expect(code1 != code2, isTrue);
    });

    test('createClassroom inserts class and enrolls teacher automatically', () async {
      final created = await repository.createClassroom(
        name: 'Advanced Algorithms',
        section: 'CS-601',
        creatorId: 'teacher-dan',
        creatorName: 'Prof. Dan',
      );

      expect(created.name, 'Advanced Algorithms');
      expect(created.code.startsWith('SV-'), isTrue);

      final fetched = await repository.getClassroomById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Advanced Algorithms');

      final members = await repository.fetchClassroomMembers(created.id);
      expect(members.any((m) => m.userId == 'teacher-dan' && m.isTeacher), isTrue);
    });

    test('joinClassroomWithCode enrolls student and increments studentCount', () async {
      final classItem = await repository.createClassroom(
        name: 'Computer Networks',
        creatorId: 'prof-net',
        creatorName: 'Dr. Cable',
      );

      final joined = await repository.joinClassroomWithCode(
        code: classItem.code,
        studentId: 'student-roshan',
        studentName: 'Roshan G',
        email: 'roshan@university.edu',
      );

      expect(joined, isNotNull);
      expect(joined!.studentCount, 2);

      final members = await repository.fetchClassroomMembers(classItem.id);
      expect(members.any((m) => m.userId == 'student-roshan' && !m.isTeacher), isTrue);
    });

    test('Classroom item creation and assignment submission cycle', () async {
      final classItem = await repository.createClassroom(
        name: 'Operating Systems',
        creatorId: 'prof-os',
        creatorName: 'Dr. Kern',
      );

      final topic = await repository.createClassroomTopic(classItem.id, 'Unit 1: Kernel Architecture');
      expect(topic.title, 'Unit 1: Kernel Architecture');

      final now = DateTime.now();
      final item = ClassroomItem(
        id: 'assign-os-1',
        classroomId: classItem.id,
        topicId: topic.id,
        type: ClassroomItemType.assignment,
        title: 'Build a Toy Shell',
        description: 'Implement fork, exec, and pipes',
        creatorId: 'prof-os',
        createdAt: now,
        updatedAt: now,
      );
      await repository.createClassroomItem(item);

      final items = await repository.fetchClassroomItems(classItem.id);
      expect(items.any((i) => i.id == 'assign-os-1'), isTrue);

      // Student submits
      final submission = ClassroomSubmission(
        id: 'sub-os-1',
        classroomId: classItem.id,
        itemId: 'assign-os-1',
        studentId: 'stud-1',
        studentName: 'Student Alice',
        content: 'Shell handles fork and pipe chaining cleanly.',
      );
      await repository.submitAssignment(submission);

      final subs = await repository.fetchClassroomSubmissions(classItem.id, itemId: 'assign-os-1');
      expect(subs.length, 1);
      expect(subs.first.studentName, 'Student Alice');

      // Teacher grades
      await repository.gradeSubmission(
        submissionId: 'sub-os-1',
        grade: 98.0,
        feedback: 'Excellent pipeline implementation!',
      );

      final graded = await repository.getSubmissionById('sub-os-1');
      expect(graded, isNotNull);
      expect(graded!.grade, 98.0);
      expect(graded.teacherFeedback, 'Excellent pipeline implementation!');
      expect(graded.isGraded, isTrue);
    });

    test('postAnnouncement records stream update', () async {
      final classItem = await repository.createClassroom(
        name: 'Database Engineering',
        creatorId: 'prof-db',
        creatorName: 'Dr. Codd',
      );

      final ann = ClassroomAnnouncement(
        id: 'ann-db-1',
        classroomId: classItem.id,
        authorId: 'prof-db',
        authorName: 'Dr. Codd',
        content: 'Midterm exam syllabus released.',
        isPinned: true,
        createdAt: DateTime.now(),
      );
      await repository.postAnnouncement(ann);

      final list = await repository.fetchClassroomAnnouncements(classItem.id);
      expect(list.any((a) => a.id == 'ann-db-1' && a.isPinned), isTrue);
    });
  });

  group('Classroom AI Service Unit Tests', () {
    test('getSocraticHint returns conceptual hints without revealing solution', () async {
      final service = ClassroomAiService.instance;
      final hint = await service.getSocraticHint(
        assignmentTitle: 'Raft Consensus',
        assignmentDescription: 'Implement leader election',
        studentQuestion: 'How do I handle split vote situations?',
      );

      expect(hint.isNotEmpty, isTrue);
      expect(hint.contains('Socratic'), isTrue);
    });

    test('checkDraftAgainstRubric provides structured pre-submission review', () async {
      final service = ClassroomAiService.instance;
      final review = await service.checkDraftAgainstRubric(
        assignmentTitle: 'Raft Consensus',
        assignmentDescription: 'Implement leader election',
        rubric: const [
          RubricCriterion(title: 'Quorum', description: 'Majority check', maxPoints: 50),
        ],
        draftContent: 'I added vote counting with N/2 + 1 condition.',
      );

      expect(review.isNotEmpty, isTrue);
      expect(review.contains('Check My Work'), isTrue);
      expect(review.contains('Strengths'), isTrue);
    });
  });

  group('Classroom Widget & Screen Tests', () {
    testWidgets('ClassroomListScreen renders header, join button, and class cards', (tester) async {
      final now = DateTime.now();
      final fakeClasses = [
        Classroom(
          id: 'mock-1',
          name: 'Distributed Systems & Cloud Computing',
          section: 'CS-401 • Fall 2026',
          code: 'SV-DIST',
          creatorId: 'prof-lin',
          creatorName: 'Dr. Sarah Lin (Prof)',
          studentCount: 42,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          const ClassroomListScreen(),
          overrides: [
            classroomListProvider.overrideWith((ref) {
              final notifier = ClassroomListNotifier(
                ref.watch(classroomRepositoryProvider),
                autoLoad: false,
              );
              notifier.state = AsyncValue.data(fakeClasses);
              return notifier;
            }),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Classrooms'), findsOneWidget);
      expect(find.text('Distributed Systems & Cloud Computing'), findsOneWidget);
      expect(find.text('SV-DIST'), findsOneWidget);
      expect(find.text('Dr. Sarah Lin (Prof)'), findsOneWidget);
      expect(find.text('42 Students'), findsOneWidget);
      expect(find.text('Enter Classroom'), findsOneWidget);
    });

    testWidgets('DashboardClassroomsCard renders active courses on Dashboard', (tester) async {
      final now = DateTime.now();
      final fakeClasses = [
        Classroom(
          id: 'mock-1',
          name: 'Distributed Systems & Cloud Computing',
          code: 'SV-DIST',
          creatorId: 'prof-lin',
          creatorName: 'Dr. Sarah Lin (Prof)',
          studentCount: 42,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          const Scaffold(body: DashboardClassroomsCard()),
          overrides: [
            classroomListProvider.overrideWith((ref) {
              final notifier = ClassroomListNotifier(
                ref.watch(classroomRepositoryProvider),
                autoLoad: false,
              );
              notifier.state = AsyncValue.data(fakeClasses);
              return notifier;
            }),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Classrooms'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);
      expect(find.text('Distributed Systems & Cloud Computing'), findsOneWidget);
      expect(find.text('SV-DIST'), findsOneWidget);
    });

    testWidgets('ClassroomDetailScreen renders 4 Google Classroom tabs', (tester) async {
      final now = DateTime.now();
      final fakeClass = Classroom(
        id: 'mock-1',
        name: 'Distributed Systems',
        code: 'SV-DIST',
        creatorId: 'prof-lin',
        creatorName: 'Dr. Sarah Lin',
        createdAt: now,
        updatedAt: now,
      );

      final fakeState = ClassroomDetailState(
        classroom: fakeClass,
        announcements: [
          ClassroomAnnouncement(
            id: 'ann-1',
            classroomId: 'mock-1',
            authorId: 'prof-lin',
            authorName: 'Dr. Sarah Lin',
            content: 'Welcome to Distributed Systems!',
            createdAt: now,
          ),
        ],
        items: [
          ClassroomItem(
            id: 'item-1',
            classroomId: 'mock-1',
            type: ClassroomItemType.assignment,
            title: 'Assignment 1: Raft',
            description: 'Implement Raft protocol',
            creatorId: 'prof-lin',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          const ClassroomDetailScreen(classroomId: 'mock-1'),
          overrides: [
            classroomDetailProvider('mock-1').overrideWith((ref) {
              final notifier = ClassroomDetailNotifier(
                ref.watch(classroomRepositoryProvider),
                'mock-1',
                autoLoad: false,
              );
              notifier.state = AsyncValue.data(fakeState);
              return notifier;
            }),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Stream'), findsOneWidget);
      expect(find.text('Classwork'), findsOneWidget);
      expect(find.text('People'), findsOneWidget);
      expect(find.text('Grades'), findsOneWidget);
      expect(find.text('Welcome to Distributed Systems!'), findsOneWidget);

      // Switch to Classwork Tab
      await tester.tap(find.text('Classwork'));
      await tester.pumpAndSettle();

      expect(find.text('Assignment 1: Raft'), findsOneWidget);
    });
  });
}
