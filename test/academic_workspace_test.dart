import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/features/academic/data/repositories/academic_workspace_repository.dart';
import 'package:study_vault/features/academic/domain/models/models.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';
import 'package:study_vault/features/academic/presentation/screens/academic_workspace_screen.dart';
import 'package:study_vault/features/academic/presentation/screens/academic_history_screen.dart';
import 'package:study_vault/features/academic/presentation/widgets/semester_transition_dialog.dart';
import 'package:study_vault/features/academic/presentation/widgets/subject_edit_dialog.dart';
import 'package:study_vault/features/auth/domain/entities/auth_user.dart';
import 'package:study_vault/features/auth/domain/repositories/auth_repository.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/onboarding/domain/models/onboarding_models.dart';

class FakeAuthRepository implements AuthRepository {
  AuthUser? _currentUser;

  FakeAuthRepository({AuthUser? initialUser})
      : _currentUser = initialUser ??
            AuthUser(id: 'user_1', email: 'student@vault.edu', fullName: 'Vault Student');

  @override
  AuthUser? getCurrentUser() => _currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    _currentUser = AuthUser(id: 'user_1', email: email, fullName: 'Vault Student');
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _currentUser = AuthUser(id: 'user_1', email: email, fullName: fullName);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Future<void> resetPassword({required String email}) async {}
}

/// In-memory Fake implementation of AcademicWorkspaceRepository for deterministic unit testing.
class FakeAcademicWorkspaceRepository implements AcademicWorkspaceRepository {
  final List<AcademicWorkspace> _workspaces = [];
  final Map<String, Map<String, dynamic>> _profiles = {};
  final List<AcademicYearEntity> _years = [];
  final List<AcademicPeriodEntity> _periods = [];
  final List<AcademicSubjectEntity> _subjects = [];
  final List<PersonalTopicEntity> _topics = [];

  int _idCounter = 1;
  String _genId(String prefix) => '${prefix}_${_idCounter++}';

  @override
  Future<void> ensureInitialized({required String userId}) async {
    if (_workspaces.where((w) => w.userId == userId).isEmpty) {
      final ws = AcademicWorkspace(
        id: _genId('ws'),
        userId: userId,
        name: 'College Workspace',
        purpose: OnboardingPurpose.college,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _workspaces.add(ws);
    }
  }

  @override
  Future<List<AcademicWorkspace>> getWorkspaces(String userId) async {
    return _workspaces.where((w) => w.userId == userId).toList();
  }

  @override
  Future<AcademicWorkspace> createWorkspace({
    required String userId,
    required String name,
    required OnboardingPurpose purpose,
  }) async {
    final ws = AcademicWorkspace(
      id: _genId('ws'),
      userId: userId,
      name: name,
      purpose: purpose,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _workspaces.add(ws);
    return ws;
  }

  @override
  Future<Map<String, dynamic>?> getAcademicStructure(String workspaceId) async {
    return _profiles[workspaceId];
  }

  void seedProfile(String workspaceId, Map<String, dynamic> profile) {
    _profiles[workspaceId] = profile;
  }

  @override
  Future<void> updateAcademicProfile({
    required String structureId,
    String? institutionName,
    String? degree,
    String? branch,
    String? stream,
  }) async {
    for (final entry in _profiles.entries) {
      if (entry.value['id'] == structureId) {
        if (institutionName != null) entry.value['institution_name'] = institutionName;
        if (degree != null) entry.value['degree'] = degree;
        if (branch != null) entry.value['branch'] = branch;
        if (stream != null) entry.value['stream'] = stream;
        break;
      }
    }
  }

  @override
  Future<List<AcademicYearEntity>> getAcademicYears(String workspaceId) async {
    return _years.where((y) => y.workspaceId == workspaceId).toList();
  }

  @override
  Future<AcademicYearEntity> createAcademicYear({
    required String workspaceId,
    required String userId,
    required String yearName,
    bool isCurrent = false,
  }) async {
    final existing = _years.where((y) => y.workspaceId == workspaceId && y.yearName == yearName);
    if (existing.isNotEmpty) return existing.first;

    final yr = AcademicYearEntity(
      id: _genId('yr'),
      workspaceId: workspaceId,
      userId: userId,
      yearName: yearName,
      isCurrent: isCurrent,
      createdAt: DateTime.now(),
    );
    _years.add(yr);
    return yr;
  }

  @override
  Future<List<AcademicPeriodEntity>> getPeriodsForYear(String academicYearId) async {
    return _periods.where((p) => p.academicYearId == academicYearId).toList();
  }

  @override
  Future<AcademicPeriodEntity?> getCurrentPeriod(String workspaceId) async {
    final list = _periods.where((p) => p.workspaceId == workspaceId && p.isCurrent);
    return list.isNotEmpty ? list.first : null;
  }

  @override
  Future<AcademicPeriodEntity?> getPeriodById(String periodId) async {
    final list = _periods.where((p) => p.id == periodId);
    return list.isNotEmpty ? list.first : null;
  }

  @override
  Future<List<AcademicYearWithPeriods>> getAcademicHistory(String workspaceId) async {
    final years = await getAcademicYears(workspaceId);
    final history = <AcademicYearWithPeriods>[];

    for (final y in years) {
      final periods = await getPeriodsForYear(y.id);
      final periodsWithCount = periods.map((p) {
        final count = _subjects.where((s) => s.academicPeriodId == p.id && !s.isArchived).length;
        return AcademicPeriodWithCount(period: p, subjectCount: count);
      }).toList();
      history.add(AcademicYearWithPeriods(year: y, periods: periodsWithCount));
    }
    return history;
  }

  @override
  Future<AcademicPeriodEntity> startNewPeriod({
    required String workspaceId,
    required String userId,
    required String academicYearId,
    required String newPeriodName,
    AcademicPeriodType periodType = AcademicPeriodType.semester,
    List<String>? subjectsToCopy,
  }) async {
    final trimmed = newPeriodName.trim();
    final duplicate = _periods.any(
      (p) => p.academicYearId == academicYearId && p.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) {
      throw ArgumentError('Academic period "$trimmed" already exists in this academic year.');
    }

    // 1. Mark existing periods as previous
    for (int i = 0; i < _periods.length; i++) {
      if (_periods[i].workspaceId == workspaceId) {
        _periods[i] = _periods[i].copyWith(isCurrent: false);
      }
    }

    // 2. Insert new period
    final newPeriod = AcademicPeriodEntity(
      id: _genId('period'),
      workspaceId: workspaceId,
      academicYearId: academicYearId,
      userId: userId,
      name: trimmed,
      periodType: periodType,
      isCurrent: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _periods.add(newPeriod);

    // 3. Optional copy creates separate new records
    if (subjectsToCopy != null) {
      for (int i = 0; i < subjectsToCopy.length; i++) {
        final name = subjectsToCopy[i].trim();
        _subjects.add(AcademicSubjectEntity(
          id: _genId('sub'),
          academicPeriodId: newPeriod.id,
          userId: userId,
          name: name,
          orderIndex: i,
          isArchived: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }

    return newPeriod;
  }

  @override
  Future<void> switchCurrentPeriod({
    required String workspaceId,
    required String targetPeriodId,
  }) async {
    for (int i = 0; i < _periods.length; i++) {
      if (_periods[i].workspaceId == workspaceId) {
        final isTarget = _periods[i].id == targetPeriodId;
        _periods[i] = _periods[i].copyWith(isCurrent: isTarget);
      }
    }
  }

  @override
  Future<List<AcademicSubjectEntity>> getSubjectsForPeriod(String periodId) async {
    final list = _subjects.where((s) => s.academicPeriodId == periodId && !s.isArchived).toList();
    list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return list;
  }

  @override
  Future<AcademicSubjectEntity> addSubject({
    required String periodId,
    required String userId,
    required String name,
    String? code,
    String? description,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Subject name cannot be empty.');

    // Duplicate check in this period only
    final duplicate = _subjects.any(
      (s) => s.academicPeriodId == periodId && s.name.toLowerCase() == trimmed.toLowerCase() && !s.isArchived,
    );
    if (duplicate) {
      throw ArgumentError('Subject "$trimmed" already exists in this semester.');
    }

    final currentSubs = _subjects.where((s) => s.academicPeriodId == periodId && !s.isArchived);
    final nextOrder = currentSubs.isEmpty ? 0 : currentSubs.map((s) => s.orderIndex).reduce((a, b) => a > b ? a : b) + 1;

    final subject = AcademicSubjectEntity(
      id: _genId('sub'),
      academicPeriodId: periodId,
      userId: userId,
      name: trimmed,
      code: code,
      description: description,
      orderIndex: nextOrder,
      isArchived: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _subjects.add(subject);
    return subject;
  }

  @override
  Future<void> renameSubject({
    required String subjectId,
    required String newName,
    String? code,
    String? description,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw ArgumentError('Subject name cannot be empty.');

    final index = _subjects.indexWhere((s) => s.id == subjectId);
    if (index == -1) throw ArgumentError('Subject not found.');

    final current = _subjects[index];
    final duplicate = _subjects.any(
      (s) => s.academicPeriodId == current.academicPeriodId && s.id != subjectId && s.name.toLowerCase() == trimmed.toLowerCase() && !s.isArchived,
    );
    if (duplicate) {
      throw ArgumentError('Subject "$trimmed" already exists in this semester.');
    }

    _subjects[index] = current.copyWith(
      name: trimmed,
      code: code,
      description: description,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> removeSubject(String subjectId) async {
    final index = _subjects.indexWhere((s) => s.id == subjectId);
    if (index != -1) {
      _subjects[index] = _subjects[index].copyWith(isArchived: true);
    }
  }

  @override
  Future<void> reorderSubjects({
    required String periodId,
    required List<String> orderedSubjectIds,
  }) async {
    for (int i = 0; i < orderedSubjectIds.length; i++) {
      final idx = _subjects.indexWhere((s) => s.id == orderedSubjectIds[i]);
      if (idx != -1) {
        _subjects[idx] = _subjects[idx].copyWith(orderIndex: i);
      }
    }
  }

  @override
  Future<List<PersonalTopicEntity>> getPersonalTopics(String workspaceId) async {
    final list = _topics.where((t) => t.workspaceId == workspaceId).toList();
    list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return list;
  }

  @override
  Future<PersonalTopicEntity> addPersonalTopic({
    required String workspaceId,
    required String userId,
    required String name,
    String? description,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Topic name cannot be empty.');

    final duplicate = _topics.any(
      (t) => t.workspaceId == workspaceId && t.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) throw ArgumentError('Topic "$trimmed" already added.');

    final topic = PersonalTopicEntity(
      id: _genId('topic'),
      workspaceId: workspaceId,
      userId: userId,
      name: trimmed,
      description: description,
      orderIndex: _topics.length,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _topics.add(topic);
    return topic;
  }

  @override
  Future<void> renamePersonalTopic({
    required String topicId,
    required String newName,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw ArgumentError('Topic name cannot be empty.');

    final idx = _topics.indexWhere((t) => t.id == topicId);
    if (idx == -1) throw ArgumentError('Topic not found.');

    final current = _topics[idx];
    final duplicate = _topics.any(
      (t) => t.workspaceId == current.workspaceId && t.id != topicId && t.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) throw ArgumentError('Topic "$trimmed" already exists.');

    _topics[idx] = current.copyWith(name: trimmed, updatedAt: DateTime.now());
  }

  @override
  Future<void> removePersonalTopic(String topicId) async {
    _topics.removeWhere((t) => t.id == topicId);
  }

  @override
  Future<void> reorderPersonalTopics({
    required String workspaceId,
    required List<String> orderedTopicIds,
  }) async {
    for (int i = 0; i < orderedTopicIds.length; i++) {
      final idx = _topics.indexWhere((t) => t.id == orderedTopicIds[i]);
      if (idx != -1) {
        _topics[idx] = _topics[idx].copyWith(orderIndex: i);
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Academic Workspace Scenarios (A through J)', () {
    late FakeAcademicWorkspaceRepository fakeRepo;
    late FakeAuthRepository fakeAuth;
    late ProviderContainer container;

    setUp(() async {
      fakeRepo = FakeAcademicWorkspaceRepository();
      fakeAuth = FakeAuthRepository();

      container = ProviderContainer(
        overrides: [
          academicWorkspaceRepositoryProvider.overrideWithValue(fakeRepo),
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
      );

      // Initialize base workspace
      final notifier = container.read(academicWorkspaceProvider.notifier);
      await notifier.init();
    });

    tearDown(() {
      container.dispose();
    });

    test('Scenario A — College Setup & Persistence', () async {
      final notifier = container.read(academicWorkspaceProvider.notifier);
      final ws = container.read(academicWorkspaceProvider).activeWorkspace!;

      fakeRepo.seedProfile(ws.id, {
        'id': 'struct_1',
        'workspace_id': ws.id,
        'institution_name': 'MIT',
        'degree': 'B.E',
        'branch': 'CSE',
        'semester_or_class': 'Semester 3',
      });

      final yr = await fakeRepo.createAcademicYear(
        workspaceId: ws.id,
        userId: 'user_1',
        yearName: '2026–27',
        isCurrent: true,
      );

      final period = await fakeRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 3',
      );

      // Add 4 subjects
      await fakeRepo.addSubject(periodId: period.id, userId: 'user_1', name: 'Operating Systems');
      await fakeRepo.addSubject(periodId: period.id, userId: 'user_1', name: 'DBMS');
      await fakeRepo.addSubject(periodId: period.id, userId: 'user_1', name: 'Computer Networks');
      await fakeRepo.addSubject(periodId: period.id, userId: 'user_1', name: 'Mathematics');

      // Re-initialize (simulating app restart)
      await notifier.init();

      final state = container.read(academicWorkspaceProvider);
      expect(state.degreeOrClassTitle, 'B.E CSE');
      expect(state.currentPeriod?.name, 'Semester 3');
      expect(state.subjects.length, 4);
      expect(state.subjects.map((s) => s.name).toList(), [
        'Operating Systems',
        'DBMS',
        'Computer Networks',
        'Mathematics',
      ]);
    });

    test('Scenario B — New Semester (Safe Progression: Semester 4 = Current, Semester 3 = Previous)', () async {
      final notifier = container.read(academicWorkspaceProvider.notifier);
      final ws = container.read(academicWorkspaceProvider).activeWorkspace!;

      final yr = await fakeRepo.createAcademicYear(
        workspaceId: ws.id,
        userId: 'user_1',
        yearName: '2026–27',
        isCurrent: true,
      );

      await fakeRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 3',
      );

      await notifier.init();
      expect(container.read(academicWorkspaceProvider).currentPeriod?.name, 'Semester 3');

      // Transition to Semester 4
      final ok = await notifier.startNewSemester(newSemesterName: 'Semester 4');
      expect(ok, true);

      final state = container.read(academicWorkspaceProvider);
      expect(state.currentPeriod?.name, 'Semester 4');
      expect(state.isViewingCurrentPeriod, true);

      // Verify Semester 3 is now Previous
      final history = state.history;
      expect(history.isNotEmpty, true);
      final periods = history.first.periods.map((p) => p.period).toList();

      final oldSem3 = periods.firstWhere((p) => p.name == 'Semester 3');
      expect(oldSem3.isCurrent, false);

      final curSem4 = periods.firstWhere((p) => p.name == 'Semester 4');
      expect(curSem4.isCurrent, true);
    });

    test('Scenario C — History (Open Semester 3 and Verify It Remains Unchanged)', () async {
      final notifier = container.read(academicWorkspaceProvider.notifier);
      final ws = container.read(academicWorkspaceProvider).activeWorkspace!;

      final yr = await fakeRepo.createAcademicYear(
        workspaceId: ws.id,
        userId: 'user_1',
        yearName: '2026–27',
        isCurrent: true,
      );

      final sem3 = await fakeRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 3',
      );
      await fakeRepo.addSubject(periodId: sem3.id, userId: 'user_1', name: 'Operating Systems');

      // Start Semester 4
      await fakeRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 4',
      );

      await notifier.init();

      // Open previous Semester 3
      await notifier.selectPeriod(sem3.id);

      final state = container.read(academicWorkspaceProvider);
      expect(state.selectedPeriod?.name, 'Semester 3');
      expect(state.isViewingCurrentPeriod, false); // Viewing archived
      expect(state.subjects.length, 1);
      expect(state.subjects.first.name, 'Operating Systems');
    });

    test('Scenario D — Copy Subjects into New Semester Creates New Records', () async {
      final notifier = container.read(academicWorkspaceProvider.notifier);
      final ws = container.read(academicWorkspaceProvider).activeWorkspace!;

      final yr = await fakeRepo.createAcademicYear(
        workspaceId: ws.id,
        userId: 'user_1',
        yearName: '2026–27',
        isCurrent: true,
      );

      final sem3 = await fakeRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 3',
      );
      await fakeRepo.addSubject(periodId: sem3.id, userId: 'user_1', name: 'DBMS');
      await fakeRepo.addSubject(periodId: sem3.id, userId: 'user_1', name: 'Mathematics');

      await notifier.init();

      // Create Semester 4 with copy of DBMS only
      final ok = await notifier.startNewSemester(
        newSemesterName: 'Semester 4',
        subjectsToCopy: ['DBMS'],
      );
      expect(ok, true);

      // Verify Semester 4 has DBMS
      final sem4Subjects = container.read(academicWorkspaceProvider).subjects;
      expect(sem4Subjects.length, 1);
      expect(sem4Subjects.first.name, 'DBMS');

      // Switch back to Semester 3 and verify its records were untouched
      await notifier.selectPeriod(sem3.id);
      final sem3Subjects = container.read(academicWorkspaceProvider).subjects;
      expect(sem3Subjects.length, 2);
      expect(sem3Subjects.map((s) => s.name).toList(), ['DBMS', 'Mathematics']);

      // Ensure distinct subject IDs (new record was created, not moved)
      expect(sem4Subjects.first.id != sem3Subjects.first.id, true);
    });

    test('Scenario E — Duplicate Subject in Same Semester is Prevented', () async {
      final notifier = container.read(academicWorkspaceProvider.notifier);
      final ws = container.read(academicWorkspaceProvider).activeWorkspace!;

      final yr = await fakeRepo.createAcademicYear(
        workspaceId: ws.id,
        userId: 'user_1',
        yearName: '2026–27',
        isCurrent: true,
      );

      await fakeRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 3',
      );
      await notifier.init();

      // 1. Add DBMS
      final ok1 = await notifier.addSubject(name: 'DBMS');
      expect(ok1, true);

      // 2. Try adding DBMS again (same period)
      final ok2 = await notifier.addSubject(name: 'DBMS');
      expect(ok2, false);
      expect(container.read(academicWorkspaceProvider).errorMessage, contains('already exists'));

      // 3. Case-insensitive duplicate check
      final ok3 = await notifier.addSubject(name: 'dbms');
      expect(ok3, false);
      expect(container.read(academicWorkspaceProvider).errorMessage, contains('already exists'));
    });

    test('Scenario F — Same Subject Name in Different Semesters is Allowed', () async {
      final notifier = container.read(academicWorkspaceProvider.notifier);
      final ws = container.read(academicWorkspaceProvider).activeWorkspace!;

      final yr = await fakeRepo.createAcademicYear(
        workspaceId: ws.id,
        userId: 'user_1',
        yearName: '2026–27',
        isCurrent: true,
      );

      final sem3 = await fakeRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 3',
      );
      await fakeRepo.addSubject(periodId: sem3.id, userId: 'user_1', name: 'DBMS');

      await fakeRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 4',
      );

      await notifier.init();
      // Add DBMS to Semester 4 as well
      final ok = await notifier.addSubject(name: 'DBMS');
      expect(ok, true);

      expect(container.read(academicWorkspaceProvider).subjects.any((s) => s.name == 'DBMS'), true);
    });

    test('Scenario G — Multiple Workspaces (College & Personal Learning are Isolated)', () async {
      final notifier = container.read(academicWorkspaceProvider.notifier);

      // Create Personal Learning workspace
      final personalWs = await fakeRepo.createWorkspace(
        userId: 'user_1',
        name: 'Personal Learning',
        purpose: OnboardingPurpose.personalLearning,
      );

      await fakeRepo.addPersonalTopic(
        workspaceId: personalWs.id,
        userId: 'user_1',
        name: 'Python',
      );

      await notifier.init();

      // Switch to Personal Learning
      await notifier.selectWorkspace(personalWs.id);

      final state = container.read(academicWorkspaceProvider);
      expect(state.isPersonalLearning, true);
      expect(state.personalTopics.length, 1);
      expect(state.personalTopics.first.name, 'Python');
      // College subjects should not appear in personal topics
      expect(state.subjects.isEmpty, true);
    });

    test('Scenario H — School Workspace Hierarchy', () async {
      final notifier = container.read(academicWorkspaceProvider.notifier);

      final schoolWs = await fakeRepo.createWorkspace(
        userId: 'user_1',
        name: 'High School',
        purpose: OnboardingPurpose.school,
      );

      fakeRepo.seedProfile(schoolWs.id, {
        'id': 'struct_school',
        'workspace_id': schoolWs.id,
        'semester_or_class': 'Class 12',
        'stream': 'Science',
      });

      final yr = await fakeRepo.createAcademicYear(
        workspaceId: schoolWs.id,
        userId: 'user_1',
        yearName: '2026–27',
        isCurrent: true,
      );

      final period = await fakeRepo.startNewPeriod(
        workspaceId: schoolWs.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Class 12',
        periodType: AcademicPeriodType.classGrade,
      );

      await fakeRepo.addSubject(periodId: period.id, userId: 'user_1', name: 'Physics');
      await fakeRepo.addSubject(periodId: period.id, userId: 'user_1', name: 'Chemistry');

      await notifier.selectWorkspace(schoolWs.id);

      final state = container.read(academicWorkspaceProvider);
      expect(state.isSchool, true);
      expect(state.degreeOrClassTitle, 'Class 12 • Science');
      expect(state.subjects.length, 2);
    });

    test('Scenario I — Personal Learning Topics (No Academic Periods Forced)', () async {
      final notifier = container.read(academicWorkspaceProvider.notifier);

      final personalWs = await fakeRepo.createWorkspace(
        userId: 'user_1',
        name: 'Personal Skills',
        purpose: OnboardingPurpose.personalLearning,
      );

      await notifier.selectWorkspace(personalWs.id);

      // Add topics
      await notifier.addPersonalTopic('Flutter');
      await notifier.addPersonalTopic('Rust');
      await notifier.addPersonalTopic('Git');

      final state = container.read(academicWorkspaceProvider);
      expect(state.isPersonalLearning, true);
      expect(state.personalTopics.map((t) => t.name).toList(), ['Flutter', 'Rust', 'Git']);
      // Verify no academic year or semester concepts are required
      expect(state.currentPeriod, isNull);
      expect(state.academicYears.isEmpty, true);
    });

    test('Scenario J — Session Signout & Signin Preserves Workspaces', () async {
      final notifier = container.read(academicWorkspaceProvider.notifier);
      await notifier.init();

      // Sign out
      await fakeAuth.signOut();

      // Sign back in
      await fakeAuth.signIn(email: 'student@vault.edu', password: 'password123');
      await notifier.init();

      final state = container.read(academicWorkspaceProvider);
      expect(state.workspaces.isNotEmpty, true);
      expect(state.activeWorkspace?.userId, 'user_1');
    });
  });

  group('Phase 4 Widget Tests', () {
    Widget buildTestWidget({
      required Widget child,
      List<Override> overrides = const [],
    }) {
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.background,
          ),
          home: child,
        ),
      );
    }

    testWidgets('AcademicWorkspaceScreen renders active degree, period, and action buttons', (tester) async {
      final fakeRepo = FakeAcademicWorkspaceRepository();
      final ws = AcademicWorkspace(
        id: 'ws_college',
        userId: 'user_1',
        name: 'College',
        purpose: OnboardingPurpose.college,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      fakeRepo._workspaces.add(ws);
      fakeRepo.seedProfile('ws_college', {
        'id': 'struct_1',
        'degree': 'B.E',
        'branch': 'Computer Science Engineering',
      });

      final yr = await fakeRepo.createAcademicYear(
        workspaceId: 'ws_college',
        userId: 'user_1',
        yearName: '2026–27',
        isCurrent: true,
      );

      final period = await fakeRepo.startNewPeriod(
        workspaceId: 'ws_college',
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 3',
      );

      await fakeRepo.addSubject(periodId: period.id, userId: 'user_1', name: 'Operating Systems');

      await tester.pumpWidget(
        buildTestWidget(
          child: const AcademicWorkspaceScreen(),
          overrides: [
            academicWorkspaceRepositoryProvider.overrideWithValue(fakeRepo),
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Academic Workspace'), findsOneWidget);
      expect(find.text('B.E Computer Science Engineering'), findsOneWidget);
      expect(find.text('Semester 3'), findsOneWidget);
      expect(find.text('CURRENT'), findsOneWidget);
      expect(find.text('Operating Systems'), findsOneWidget);
      expect(find.text('Add Subject'), findsOneWidget);
      expect(find.text('Start Next'), findsOneWidget);
    });

    testWidgets('AcademicHistoryScreen renders chronological periods with badges', (tester) async {
      final fakeRepo = FakeAcademicWorkspaceRepository();
      final ws = AcademicWorkspace(
        id: 'ws_hist',
        userId: 'user_1',
        name: 'College',
        purpose: OnboardingPurpose.college,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      fakeRepo._workspaces.add(ws);

      final yr = await fakeRepo.createAcademicYear(
        workspaceId: 'ws_hist',
        userId: 'user_1',
        yearName: '2026–27',
        isCurrent: true,
      );

      await fakeRepo.startNewPeriod(
        workspaceId: 'ws_hist',
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 4',
      );

      await tester.pumpWidget(
        buildTestWidget(
          child: const AcademicHistoryScreen(),
          overrides: [
            academicWorkspaceRepositoryProvider.overrideWithValue(fakeRepo),
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Academic History & Archive'), findsOneWidget);
      expect(find.text('2026–27'), findsOneWidget);
      expect(find.text('Semester 4'), findsOneWidget);
      expect(find.text('CURRENT'), findsOneWidget);
    });

    testWidgets('SemesterTransitionDialog renders safety notice and period input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SemesterTransitionDialog(
              currentPeriodName: 'Semester 3',
              suggestedNextPeriodName: 'Semester 4',
              previousSubjectNames: const ['DBMS', 'Operating Systems'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Semester 4?'), findsOneWidget);
      expect(find.textContaining('Your Semester 3 workspace will remain fully available'), findsOneWidget);
      expect(find.text('Copy subjects from Semester 3?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('SubjectEditDialog validates empty subject name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubjectEditDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Subject'), findsNWidgets(2));
      expect(find.text('Subject Name *'), findsOneWidget);

      // Tap Add Subject without typing
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Subject').first);
      await tester.pumpAndSettle();

      expect(find.text('Subject name is required.'), findsOneWidget);
    });
  });
}
