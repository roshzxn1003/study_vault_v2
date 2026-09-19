import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_vault/features/academic/data/repositories/academic_workspace_repository.dart';
import 'package:study_vault/features/academic/domain/models/models.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';
import 'package:study_vault/features/auth/domain/entities/auth_user.dart';
import 'package:study_vault/features/auth/domain/repositories/auth_repository.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:study_vault/features/dashboard/domain/models/dashboard_models.dart';
import 'package:study_vault/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:study_vault/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:study_vault/features/dashboard/presentation/screens/subject_detail_screen.dart';
import 'package:study_vault/features/dashboard/presentation/screens/inbox_screen.dart';
import 'package:study_vault/features/dashboard/presentation/widgets/historical_period_banner.dart';
import 'package:study_vault/features/dashboard/presentation/widgets/subject_card.dart';
import 'package:study_vault/features/onboarding/domain/models/onboarding_models.dart';
import 'package:study_vault/features/vault/data/repositories/vault_repository.dart';
import 'package:study_vault/features/inbox/presentation/providers/inbox_provider.dart';

class FakeAuthRepository implements AuthRepository {
  AuthUser? _currentUser;

  FakeAuthRepository({AuthUser? initialUser})
      : _currentUser = initialUser ??
            AuthUser(id: 'user_1', email: 'arun@vault.edu', fullName: 'Arun Kumar');

  @override
  AuthUser? getCurrentUser() => _currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    _currentUser = AuthUser(id: 'user_1', email: email, fullName: 'Arun Kumar');
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

  @override
  Future<void> signInWithGoogle({String? redirectTo}) async {}
}

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
    if (isCurrent) {
      for (int i = 0; i < _years.length; i++) {
        if (_years[i].workspaceId == workspaceId) {
          _years[i] = _years[i].copyWith(isCurrent: false);
        }
      }
    }
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

    for (int i = 0; i < _periods.length; i++) {
      if (_periods[i].workspaceId == workspaceId) {
        _periods[i] = _periods[i].copyWith(isCurrent: false);
      }
    }

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
    String? description,
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

class FakeDashboardRepository implements DashboardRepository {
  final Map<String, int> _counts = {};
  final List<DashboardRecentMaterial> _recent = [];
  final List<DashboardInboxItem> _inbox = [];

  void setSubjectCount(String subjectId, int count) {
    _counts[subjectId] = count;
  }

  void addRecentMaterial(DashboardRecentMaterial material) {
    _recent.add(material);
  }

  void addInboxItem(DashboardInboxItem item) {
    _inbox.add(item);
  }

  @override
  Future<Map<String, int>> getSubjectMaterialCounts(List<String> subjectIds) async {
    final result = <String, int>{};
    for (final id in subjectIds) {
      result[id] = _counts[id] ?? 0;
    }
    return result;
  }

  @override
  Future<List<DashboardRecentMaterial>> getRecentMaterials({required String userId, int limit = 5}) async {
    return _recent.take(limit).toList();
  }

  @override
  Future<({List<DashboardInboxItem> items, int totalCount})> getInboxPreview({required String userId, int limit = 4}) async {
    return (items: _inbox.take(limit).toList(), totalCount: _inbox.length);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 5 Navigation & Scenario Unit Tests (1 through 15)', () {
    late FakeAuthRepository fakeAuth;
    late FakeAcademicWorkspaceRepository fakeAcademicRepo;
    late FakeDashboardRepository fakeDashboardRepo;
    late ProviderContainer container;

    setUp(() async {
      fakeAuth = FakeAuthRepository();
      fakeAcademicRepo = FakeAcademicWorkspaceRepository();
      fakeDashboardRepo = FakeDashboardRepository();

      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          academicWorkspaceRepositoryProvider.overrideWithValue(fakeAcademicRepo),
          dashboardRepositoryProvider.overrideWithValue(fakeDashboardRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('1 & 4. College dashboard loads and shows correct college context', () async {
      final ws = await fakeAcademicRepo.createWorkspace(
        userId: 'user_1',
        name: 'College',
        purpose: OnboardingPurpose.college,
      );

      fakeAcademicRepo.seedProfile(ws.id, {
        'id': 'struct_1',
        'institution_name': 'IIT Bombay',
        'degree': 'B.E',
        'branch': 'Computer Science Engineering',
        'academic_year': '2026–27',
      });

      final yr = await fakeAcademicRepo.createAcademicYear(
        workspaceId: ws.id,
        userId: 'user_1',
        yearName: '2026–27',
        isCurrent: true,
      );

      final sem3 = await fakeAcademicRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 3',
      );

      await fakeAcademicRepo.addSubject(periodId: sem3.id, userId: 'user_1', name: 'Operating Systems');
      await fakeAcademicRepo.addSubject(periodId: sem3.id, userId: 'user_1', name: 'DBMS');

      final notifier = container.read(dashboardProvider.notifier);
      await notifier.init();

      final state = container.read(dashboardProvider);
      expect(state.isCollege, true);
      expect(state.academicIdentityTitle, 'B.E Computer Science Engineering');
      expect(state.academicSubtitle, '2026–27 • Semester 3');
      expect(state.greeting, contains('Arun'));
    });

    test('2 & 5. Correct semester subjects appear in established order', () async {
      final ws = await fakeAcademicRepo.createWorkspace(
        userId: 'user_1',
        name: 'College',
        purpose: OnboardingPurpose.college,
      );

      final yr = await fakeAcademicRepo.createAcademicYear(
        workspaceId: ws.id,
        userId: 'user_1',
        yearName: '2026–27',
        isCurrent: true,
      );

      final sem3 = await fakeAcademicRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 3',
      );

      await fakeAcademicRepo.addSubject(periodId: sem3.id, userId: 'user_1', name: 'Operating Systems');
      await fakeAcademicRepo.addSubject(periodId: sem3.id, userId: 'user_1', name: 'DBMS');
      await fakeAcademicRepo.addSubject(periodId: sem3.id, userId: 'user_1', name: 'Computer Networks');
      await fakeAcademicRepo.addSubject(periodId: sem3.id, userId: 'user_1', name: 'Mathematics');

      final notifier = container.read(dashboardProvider.notifier);
      await notifier.init();

      final state = container.read(dashboardProvider);
      final names = state.subjects.map((s) => s.subject.name).toList();
      expect(names, ['Operating Systems', 'DBMS', 'Computer Networks', 'Mathematics']);
    });

    test('3, 6 & 7. Switching viewed semester updates subjects without changing current semester', () async {
      final ws = await fakeAcademicRepo.createWorkspace(
        userId: 'user_1',
        name: 'College',
        purpose: OnboardingPurpose.college,
      );

      final yr = await fakeAcademicRepo.createAcademicYear(
        workspaceId: ws.id,
        userId: 'user_1',
        yearName: '2026–27',
        isCurrent: true,
      );

      // Previous Semester 2
      final sem2 = await fakeAcademicRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 2',
      );
      await fakeAcademicRepo.addSubject(periodId: sem2.id, userId: 'user_1', name: 'Data Structures');

      // Current Semester 3
      final sem3 = await fakeAcademicRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 3',
      );
      await fakeAcademicRepo.addSubject(periodId: sem3.id, userId: 'user_1', name: 'Operating Systems');

      final notifier = container.read(dashboardProvider.notifier);
      await notifier.init();

      // Initially viewing current Semester 3
      expect(container.read(dashboardProvider).selectedPeriodName, 'Semester 3');
      expect(container.read(dashboardProvider).isViewingCurrentPeriod, true);
      expect(container.read(dashboardProvider).isViewingHistoricalPeriod, false);
      expect(container.read(dashboardProvider).subjects.map((s) => s.subject.name).toList(), ['Operating Systems']);

      // Switch view to historical Semester 2
      await notifier.selectPeriod(sem2.id);

      final state2 = container.read(dashboardProvider);
      expect(state2.selectedPeriodName, 'Semester 2');
      expect(state2.isViewingCurrentPeriod, false);
      expect(state2.isViewingHistoricalPeriod, true);
      expect(state2.subjects.map((s) => s.subject.name).toList(), ['Data Structures']);

      // Verify that the actual current period in DB remains Semester 3
      final currentInDb = await fakeAcademicRepo.getCurrentPeriod(ws.id);
      expect(currentInDb?.name, 'Semester 3');
    });

    test('8. Multiple workspace switching works cleanly (College <-> Personal Learning)', () async {
      final collegeWs = await fakeAcademicRepo.createWorkspace(
        userId: 'user_1',
        name: 'College Vault',
        purpose: OnboardingPurpose.college,
      );

      final personalWs = await fakeAcademicRepo.createWorkspace(
        userId: 'user_1',
        name: 'My Skills',
        purpose: OnboardingPurpose.personalLearning,
      );

      await fakeAcademicRepo.addPersonalTopic(
        workspaceId: personalWs.id,
        userId: 'user_1',
        name: 'Flutter Development',
      );

      final notifier = container.read(dashboardProvider.notifier);
      await notifier.init();

      // Switch to Personal Learning
      await notifier.selectWorkspace(personalWs.id);
      var state = container.read(dashboardProvider);
      expect(state.isPersonalLearning, true);
      expect(state.academicIdentityTitle, 'My Skills');
      expect(state.personalTopics.map((t) => t.name).toList(), ['Flutter Development']);

      // Switch back to College
      await notifier.selectWorkspace(collegeWs.id);
      state = container.read(dashboardProvider);
      expect(state.isCollege, true);
    });

    test('9. School dashboard shows class context (no degree or semester terms)', () async {
      final schoolWs = await fakeAcademicRepo.createWorkspace(
        userId: 'user_1',
        name: 'DPS School',
        purpose: OnboardingPurpose.school,
      );

      fakeAcademicRepo.seedProfile(schoolWs.id, {
        'id': 'struct_school',
        'institution_name': 'Delhi Public School',
        'semester_or_class': 'Class 12',
        'stream': 'Science',
        'academic_year': '2026–27',
      });

      final yr = await fakeAcademicRepo.createAcademicYear(
        workspaceId: schoolWs.id,
        userId: 'user_1',
        yearName: '2026–27',
        isCurrent: true,
      );

      final class12 = await fakeAcademicRepo.startNewPeriod(
        workspaceId: schoolWs.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Class 12',
        periodType: AcademicPeriodType.classGrade,
      );

      await fakeAcademicRepo.addSubject(periodId: class12.id, userId: 'user_1', name: 'Physics');
      await fakeAcademicRepo.addSubject(periodId: class12.id, userId: 'user_1', name: 'Chemistry');

      final notifier = container.read(dashboardProvider.notifier);
      await notifier.selectWorkspace(schoolWs.id);

      final state = container.read(dashboardProvider);
      expect(state.isSchool, true);
      expect(state.academicIdentityTitle, 'Class 12 • Science');
      expect(state.academicSubtitle, '2026–27');
      expect(state.subjects.map((s) => s.subject.name).toList(), ['Physics', 'Chemistry']);
    });

    test('10. Personal Learning shows topics and independent learning identity', () async {
      final personalWs = await fakeAcademicRepo.createWorkspace(
        userId: 'user_1',
        name: 'My Learning',
        purpose: OnboardingPurpose.personalLearning,
      );

      await fakeAcademicRepo.addPersonalTopic(workspaceId: personalWs.id, userId: 'user_1', name: 'Python');
      await fakeAcademicRepo.addPersonalTopic(workspaceId: personalWs.id, userId: 'user_1', name: 'Rust');

      final notifier = container.read(dashboardProvider.notifier);
      await notifier.selectWorkspace(personalWs.id);

      final state = container.read(dashboardProvider);
      expect(state.isPersonalLearning, true);
      expect(state.academicIdentityTitle, 'My Learning');
      expect(state.academicSubtitle, 'Independent Study & Skills');
      expect(state.personalTopics.map((t) => t.name).toList(), ['Python', 'Rust']);
    });

    test('13. Empty states work cleanly when no subjects exist', () async {
      final ws = await fakeAcademicRepo.createWorkspace(
        userId: 'user_1',
        name: 'Empty College',
        purpose: OnboardingPurpose.college,
      );

      final yr = await fakeAcademicRepo.createAcademicYear(
        workspaceId: ws.id,
        userId: 'user_1',
        yearName: '2026–27',
        isCurrent: true,
      );

      await fakeAcademicRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 1',
      );

      final notifier = container.read(dashboardProvider.notifier);
      await notifier.selectWorkspace(ws.id);

      final state = container.read(dashboardProvider);
      expect(state.subjects.isEmpty, true);
    });

    test('Real material counts are mapped per subject without fake numbers', () async {
      final ws = await fakeAcademicRepo.createWorkspace(
        userId: 'user_1',
        name: 'College',
        purpose: OnboardingPurpose.college,
      );

      final yr = await fakeAcademicRepo.createAcademicYear(
        workspaceId: ws.id,
        userId: 'user_1',
        yearName: '2026–27',
        isCurrent: true,
      );

      final sem1 = await fakeAcademicRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 1',
      );

      final s1 = await fakeAcademicRepo.addSubject(periodId: sem1.id, userId: 'user_1', name: 'OS');
      final s2 = await fakeAcademicRepo.addSubject(periodId: sem1.id, userId: 'user_1', name: 'DBMS');

      fakeDashboardRepo.setSubjectCount(s1.id, 12);
      fakeDashboardRepo.setSubjectCount(s2.id, 0);

      final notifier = container.read(dashboardProvider.notifier);
      await notifier.selectWorkspace(ws.id);

      final state = container.read(dashboardProvider);
      final osWithCount = state.subjects.firstWhere((s) => s.subject.id == s1.id);
      final dbmsWithCount = state.subjects.firstWhere((s) => s.subject.id == s2.id);

      expect(osWithCount.materialCount, 12);
      expect(osWithCount.materialCountLabel, '12 materials');
      expect(dbmsWithCount.materialCount, 0);
      expect(dbmsWithCount.materialCountLabel, 'No materials yet');
    });

    test('Recent materials and inbox preview data are loaded into dashboard state', () async {
      final now = DateTime.now();
      fakeDashboardRepo.addRecentMaterial(DashboardRecentMaterial(
        id: 'mat_1',
        title: 'OS Unit 3 Notes',
        type: 'PDF',
        subjectName: 'Operating Systems',
        createdAt: now.subtract(const Duration(hours: 2)),
      ));

      fakeDashboardRepo.addInboxItem(DashboardInboxItem(
        id: 'inb_1',
        title: 'Pending Syllabus.pdf',
        type: 'PDF',
        createdAt: now,
      ));

      final notifier = container.read(dashboardProvider.notifier);
      await notifier.init();

      final state = container.read(dashboardProvider);
      expect(state.recentMaterials.length, 1);
      expect(state.recentMaterials.first.title, 'OS Unit 3 Notes');
      expect(state.recentMaterials.first.formattedSubtitle, contains('PDF • Operating Systems • 2h ago'));

      expect(state.inboxItems.length, 1);
      expect(state.inboxItems.first.title, 'Pending Syllabus.pdf');
      expect(state.inboxTotalCount, 1);
    });

    test('14 & 15. Signout & Signin preserves dashboard workspace data', () async {
      final notifier = container.read(dashboardProvider.notifier);
      await notifier.init();

      // Sign out
      await fakeAuth.signOut();
      // Sign in
      await fakeAuth.signIn(email: 'arun@vault.edu', password: 'password123');

      await notifier.refresh();
      final state = container.read(dashboardProvider);
      expect(state.workspaces.isNotEmpty, true);
    });
  });

  group('Phase 5 Widget Tests', () {
    late FakeAuthRepository fakeAuth;
    late FakeAcademicWorkspaceRepository fakeAcademicRepo;
    late FakeDashboardRepository fakeDashboardRepo;

    setUp(() async {
      fakeAuth = FakeAuthRepository();
      fakeAcademicRepo = FakeAcademicWorkspaceRepository();
      fakeDashboardRepo = FakeDashboardRepository();

      final ws = await fakeAcademicRepo.createWorkspace(
        userId: 'user_1',
        name: 'College',
        purpose: OnboardingPurpose.college,
      );

      fakeAcademicRepo.seedProfile(ws.id, {
        'id': 'struct_1',
        'institution_name': 'MIT',
        'degree': 'B.E',
        'branch': 'Computer Science Engineering',
        'academic_year': '2026–27',
      });

      final yr = await fakeAcademicRepo.createAcademicYear(
        workspaceId: ws.id,
        userId: 'user_1',
        yearName: '2026–27',
        isCurrent: true,
      );

      final sem3 = await fakeAcademicRepo.startNewPeriod(
        workspaceId: ws.id,
        userId: 'user_1',
        academicYearId: yr.id,
        newPeriodName: 'Semester 3',
      );

      await fakeAcademicRepo.addSubject(periodId: sem3.id, userId: 'user_1', name: 'Operating Systems', code: 'CS-301');
      await fakeAcademicRepo.addSubject(periodId: sem3.id, userId: 'user_1', name: 'Database Systems');
    });

    testWidgets('DashboardScreen renders college academic identity, search bar, and subjects', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            academicWorkspaceRepositoryProvider.overrideWithValue(fakeAcademicRepo),
            dashboardRepositoryProvider.overrideWithValue(fakeDashboardRepo),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('B.E Computer Science Engineering'), findsOneWidget);
      expect(find.text('Search notes, PDFs, subjects...'), findsOneWidget);
      expect(find.text('Subjects'), findsOneWidget);
      expect(find.text('Operating Systems'), findsOneWidget);
      expect(find.text('CS-301'), findsOneWidget);
      expect(find.text('Database Systems'), findsOneWidget);
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
    });

    testWidgets('HistoricalPeriodBanner renders when browsing previous semester', (tester) async {
      bool switched = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoricalPeriodBanner(
              periodName: 'Semester 2',
              currentPeriodName: 'Semester 3',
              onSwitchToCurrent: () => switched = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ARCHIVE VIEW • PREVIOUS TERM'), findsOneWidget);
      expect(find.textContaining('Viewing Semester 2'), findsOneWidget);
      expect(find.text('Back to Current'), findsOneWidget);

      await tester.tap(find.text('Back to Current'));
      expect(switched, true);
    });

    testWidgets('SubjectCard renders name, code chip, and material count', (tester) async {
      bool tapped = false;
      final subject = AcademicSubjectEntity(
        id: 's_1',
        userId: 'user_1',
        name: 'Computer Networks',
        code: 'CS-304',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final subjectWithCount = SubjectWithCount(
        subject: subject,
        materialCount: 7,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubjectCard(
              subjectWithCount: subjectWithCount,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Computer Networks'), findsOneWidget);
      expect(find.text('CS-304'), findsOneWidget);
      expect(find.text('7 materials'), findsOneWidget);

      await tester.tap(find.text('Computer Networks'));
      expect(tapped, true);
    });

    testWidgets('SubjectDetailScreen renders subject context and materials area', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          academicWorkspaceRepositoryProvider.overrideWithValue(fakeAcademicRepo),
          dashboardRepositoryProvider.overrideWithValue(fakeDashboardRepo),
        ],
      );
      await container.read(dashboardProvider.notifier).init();
      final targetSubject = container.read(dashboardProvider).subjects.first.subject;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SubjectDetailScreen(subjectId: targetSubject.id),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(targetSubject.name), findsWidgets);
      if (targetSubject.code != null) {
        expect(find.text(targetSubject.code!), findsOneWidget);
      }
      expect(find.text('+ New Folder'), findsOneWidget);
    });

    testWidgets('InboxScreen renders header and clear state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inboxProvider.overrideWith(
              (ref) => InboxNotifier(VaultRepository(), ref)
                ..state = const InboxState(items: [], isLoading: false),
            ),
          ],
          child: const MaterialApp(
            home: InboxScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text("You're all caught up."), findsOneWidget);
    });
  });
}
