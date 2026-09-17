import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/features/auth/domain/entities/auth_user.dart';
import 'package:study_vault/features/auth/domain/repositories/auth_repository.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:study_vault/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:study_vault/features/onboarding/presentation/screens/purpose_selection_screen.dart';
import 'package:study_vault/features/onboarding/presentation/screens/college_setup_screen.dart';
import 'package:study_vault/features/onboarding/presentation/screens/college_subjects_screen.dart';
import 'package:study_vault/features/onboarding/presentation/screens/personal_learning_screen.dart';
import 'package:study_vault/features/onboarding/presentation/screens/onboarding_complete_screen.dart';
import 'package:study_vault/features/onboarding/presentation/widgets/onboarding_scaffold.dart';

class MockAuthRepository implements AuthRepository {
  AuthUser? _user;

  MockAuthRepository({AuthUser? initialUser}) : _user = initialUser;

  @override
  AuthUser? getCurrentUser() => _user;

  @override
  Future<void> signIn({required String email, required String password}) async {
    _user = AuthUser(id: 'test-user', email: email, fullName: 'Test User');
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _user = AuthUser(id: 'test-user', email: email, fullName: fullName);
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }

  @override
  Future<void> resetPassword({required String email}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Onboarding Domain Models & Serialization Tests', () {
    test('OnboardingPurpose string parsing and id getter', () {
      expect(OnboardingPurpose.fromId('college'), OnboardingPurpose.college);
      expect(OnboardingPurpose.fromId('school'), OnboardingPurpose.school);
      expect(OnboardingPurpose.fromId('personal_learning'), OnboardingPurpose.personalLearning);
      expect(OnboardingPurpose.fromId('unknown'), OnboardingPurpose.personalLearning);

      expect(OnboardingPurpose.college.id, 'college');
      expect(OnboardingPurpose.school.id, 'school');
      expect(OnboardingPurpose.personalLearning.id, 'personal_learning');
    });

    test('OnboardingStatus string parsing and serialization', () {
      expect(OnboardingStatus.fromString('NOT_STARTED'), OnboardingStatus.notStarted);
      expect(OnboardingStatus.fromString('IN_PROGRESS'), OnboardingStatus.inProgress);
      expect(OnboardingStatus.fromString('COMPLETED'), OnboardingStatus.completed);
      expect(OnboardingStatus.fromString('invalid'), OnboardingStatus.notStarted);

      expect(OnboardingStatus.notStarted.toSerializedString(), 'NOT_STARTED');
      expect(OnboardingStatus.inProgress.toSerializedString(), 'IN_PROGRESS');
      expect(OnboardingStatus.completed.toSerializedString(), 'COMPLETED');
    });

    test('CollegeSetupData JSON round-trip serialization', () {
      const data = CollegeSetupData(
        institutionName: 'MIT',
        degree: 'B.Tech',
        branch: 'Computer Science',
        academicYear: '2026-27',
        semester: 'Semester 5',
        subjects: ['Algorithms', 'DBMS', 'Operating Systems'],
      );

      final json = data.toJson();
      final restored = CollegeSetupData.fromJson(json);

      expect(restored.institutionName, 'MIT');
      expect(restored.degree, 'B.Tech');
      expect(restored.branch, 'Computer Science');
      expect(restored.academicYear, '2026-27');
      expect(restored.semester, 'Semester 5');
      expect(restored.subjects, ['Algorithms', 'DBMS', 'Operating Systems']);
    });

    test('SchoolSetupData JSON round-trip serialization', () {
      const data = SchoolSetupData(
        schoolName: 'Delhi Public School',
        academicYear: '2026-27',
        grade: 'Class 12',
        stream: 'Science',
        subjects: ['Physics', 'Chemistry', 'Maths'],
      );

      final json = data.toJson();
      final restored = SchoolSetupData.fromJson(json);

      expect(restored.schoolName, 'Delhi Public School');
      expect(restored.academicYear, '2026-27');
      expect(restored.grade, 'Class 12');
      expect(restored.stream, 'Science');
      expect(restored.subjects, ['Physics', 'Chemistry', 'Maths']);
    });

    test('PersonalLearningData JSON round-trip serialization', () {
      const data = PersonalLearningData(
        topics: ['Rust', 'Flutter', 'System Design'],
      );

      final json = data.toJson();
      final restored = PersonalLearningData.fromJson(json);

      expect(restored.topics, ['Rust', 'Flutter', 'System Design']);
    });

    test('OnboardingState backward compatibility getters work accurately', () {
      const state = OnboardingState(
        status: OnboardingStatus.completed,
        selectedPurposes: {OnboardingPurpose.college, OnboardingPurpose.personalLearning},
        collegeData: CollegeSetupData(
          degree: 'B.Tech',
          branch: 'CSE',
          academicYear: '3rd Year',
          semester: 'Semester 6',
          subjects: ['OS', 'Networks'],
        ),
        personalLearningData: PersonalLearningData(
          topics: ['Machine Learning'],
        ),
      );

      expect(state.hasCompletedOnboarding, true);
      expect(state.isCollegeSelected, true);
      expect(state.isSchoolSelected, false);
      expect(state.isPersonalLearningSelected, true);
      expect(state.course, 'B.Tech CSE');
      expect(state.studyGoal, 'Semester 6');
      expect(state.subjects, ['OS', 'Networks', 'Machine Learning']);
    });
  });

  group('OnboardingNotifier Business Logic Tests (Flows A–D, G, H)', () {
    late ProviderContainer container;
    late OnboardingRepository repository;

    setUp(() {
      repository = OnboardingRepository();
      container = ProviderContainer(
        overrides: [
          onboardingRepositoryProvider.overrideWithValue(repository),
          authRepositoryProvider.overrideWithValue(MockAuthRepository(
            initialUser: AuthUser(id: 'u1', email: 'user@vault.edu', fullName: 'Vault Student'),
          )),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Flow A — College User Complete Flow', () async {
      final notifier = container.read(onboardingProvider.notifier);

      // 1. Select College Purpose
      notifier.togglePurpose(OnboardingPurpose.college);
      expect(container.read(onboardingProvider).selectedPurposes, {OnboardingPurpose.college});
      expect(container.read(onboardingProvider).isCollegeSelected, true);

      // 2. Set College Academic Structure
      notifier.setCollegeDetails(
        institutionName: 'Stanford University',
        degree: 'B.S.',
        branch: 'Computer Science',
        academicYear: 'Junior Year',
        semester: 'Fall Semester',
      );

      final collegeData = container.read(onboardingProvider).collegeData;
      expect(collegeData, isNotNull);
      expect(collegeData!.degree, 'B.S.');
      expect(collegeData.branch, 'Computer Science');
      expect(collegeData.semester, 'Fall Semester');

      // 3. Add 5 Subjects
      final subjectsToAdd = [
        'Data Structures',
        'Algorithms',
        'Computer Systems',
        'Database Systems',
        'Artificial Intelligence',
      ];
      for (final s in subjectsToAdd) {
        final added = notifier.addSubject(purpose: OnboardingPurpose.college, subjectName: s);
        expect(added, true);
      }

      expect(container.read(onboardingProvider).collegeData!.subjects.length, 5);
      expect(container.read(onboardingProvider).collegeData!.subjects, subjectsToAdd);

      // 4. Complete Onboarding
      await notifier.completeOnboarding();
      expect(container.read(onboardingProvider).status, OnboardingStatus.completed);
      expect(container.read(onboardingProvider).hasCompletedOnboarding, true);
    });

    test('Flow B — School User Complete Flow', () async {
      final notifier = container.read(onboardingProvider.notifier);

      // 1. Select School Purpose
      notifier.togglePurpose(OnboardingPurpose.school);
      expect(container.read(onboardingProvider).isSchoolSelected, true);

      // 2. Set School Details
      notifier.setSchoolDetails(
        schoolName: 'St. Xavier High School',
        academicYear: '2026-27',
        grade: 'Class 11',
        stream: 'Commerce with Maths',
      );

      final school = container.read(onboardingProvider).schoolData;
      expect(school, isNotNull);
      expect(school!.grade, 'Class 11');
      expect(school.stream, 'Commerce with Maths');

      // 3. Add 5 Subjects
      final schoolSubjects = ['Accountancy', 'Business Studies', 'Economics', 'Mathematics', 'English'];
      for (final s in schoolSubjects) {
        final ok = notifier.addSubject(purpose: OnboardingPurpose.school, subjectName: s);
        expect(ok, true);
      }

      expect(container.read(onboardingProvider).schoolData!.subjects.length, 5);

      // 4. Complete
      await notifier.completeOnboarding();
      expect(container.read(onboardingProvider).status, OnboardingStatus.completed);
    });

    test('Flow C — Personal Learning User Flow', () async {
      final notifier = container.read(onboardingProvider.notifier);

      // 1. Select Personal Learning
      notifier.togglePurpose(OnboardingPurpose.personalLearning);
      expect(container.read(onboardingProvider).isPersonalLearningSelected, true);

      // 2. Add Topics (no academic degrees or semesters)
      final topics = ['Flutter Development', 'System Design', 'Go Programming'];
      for (final t in topics) {
        final ok = notifier.addTopic(t);
        expect(ok, true);
      }

      final plData = container.read(onboardingProvider).personalLearningData;
      expect(plData, isNotNull);
      expect(plData!.topics, topics);
      expect(container.read(onboardingProvider).collegeData, isNull);
      expect(container.read(onboardingProvider).schoolData, isNull);

      // 3. Complete
      await notifier.completeOnboarding();
      expect(container.read(onboardingProvider).status, OnboardingStatus.completed);
    });

    test('Flow D — Multiple Purpose User Flow (College + Personal Learning)', () async {
      final notifier = container.read(onboardingProvider.notifier);

      // Select both College and Personal Learning
      notifier.togglePurpose(OnboardingPurpose.college);
      notifier.togglePurpose(OnboardingPurpose.personalLearning);

      expect(container.read(onboardingProvider).isCollegeSelected, true);
      expect(container.read(onboardingProvider).isPersonalLearningSelected, true);

      // Configure College
      notifier.setCollegeDetails(
        degree: 'B.Tech',
        branch: 'IT',
        academicYear: '4th Year',
        semester: 'Semester 7',
      );
      notifier.addSubject(purpose: OnboardingPurpose.college, subjectName: 'Cloud Computing');
      notifier.addSubject(purpose: OnboardingPurpose.college, subjectName: 'Information Security');

      // Configure Personal Learning
      notifier.addTopic('Photography');
      notifier.addTopic('Spanish Language');

      // Strict separation verification: College subjects and Personal topics must not mix
      final collegeSubs = container.read(onboardingProvider).collegeData!.subjects;
      final personalTopics = container.read(onboardingProvider).personalLearningData!.topics;

      expect(collegeSubs, ['Cloud Computing', 'Information Security']);
      expect(personalTopics, ['Photography', 'Spanish Language']);

      // Ensure no crossover
      expect(collegeSubs.contains('Photography'), false);
      expect(personalTopics.contains('Cloud Computing'), false);
    });

    test('Flow G — Back Navigation Preserves Entered Data', () {
      final notifier = container.read(onboardingProvider.notifier);

      // Purpose
      notifier.togglePurpose(OnboardingPurpose.college);
      notifier.setStep(OnboardingStep.setup);

      // Setup
      notifier.setCollegeDetails(
        institutionName: 'IIT Bombay',
        degree: 'B.Tech',
        branch: 'Electrical',
        academicYear: '2nd Year',
        semester: 'Semester 3',
      );
      notifier.setStep(OnboardingStep.subjects);

      // Subjects
      notifier.addSubject(purpose: OnboardingPurpose.college, subjectName: 'Signals & Systems');

      // Navigate back to Setup
      notifier.setStep(OnboardingStep.setup);
      final currentCollege = container.read(onboardingProvider).collegeData;
      expect(currentCollege?.degree, 'B.Tech');
      expect(currentCollege?.branch, 'Electrical');
      expect(currentCollege?.semester, 'Semester 3');
      expect(currentCollege?.institutionName, 'IIT Bombay');

      // Navigate back to Purpose
      notifier.setStep(OnboardingStep.purpose);
      expect(container.read(onboardingProvider).selectedPurposes, {OnboardingPurpose.college});
      // Subjects still preserved
      expect(container.read(onboardingProvider).collegeData?.subjects, ['Signals & Systems']);
    });

    test('Flow H — Subject Management Edge Cases & Duplicate Prevention', () {
      final notifier = container.read(onboardingProvider.notifier);

      notifier.togglePurpose(OnboardingPurpose.college);
      notifier.setCollegeDetails(
        degree: 'B.Sc',
        branch: 'Physics',
        academicYear: '1st Year',
        semester: 'Semester 1',
      );

      // 1. Add valid subject
      expect(notifier.addSubject(purpose: OnboardingPurpose.college, subjectName: 'Mechanics'), true);

      // 2. Duplicate addition (exact and case-insensitive)
      expect(notifier.addSubject(purpose: OnboardingPurpose.college, subjectName: 'Mechanics'), false);
      expect(container.read(onboardingProvider).errorMessage, contains('already added'));

      expect(notifier.addSubject(purpose: OnboardingPurpose.college, subjectName: 'mechanics'), false);
      expect(container.read(onboardingProvider).errorMessage, contains('already added'));

      // 3. Empty or whitespace-only subject
      expect(notifier.addSubject(purpose: OnboardingPurpose.college, subjectName: '   '), false);

      // 4. Leading/trailing spaces trimmed
      expect(notifier.addSubject(purpose: OnboardingPurpose.college, subjectName: '  Thermodynamics  '), true);
      expect(container.read(onboardingProvider).collegeData!.subjects.contains('Thermodynamics'), true);

      // 5. Duplicate rename
      final renameDuplicate = notifier.renameSubject(
        purpose: OnboardingPurpose.college,
        index: 1, // 'Thermodynamics'
        newName: 'Mechanics',
      );
      expect(renameDuplicate, false);
      expect(container.read(onboardingProvider).errorMessage, contains('already exists'));

      // 6. Valid rename
      final renameValid = notifier.renameSubject(
        purpose: OnboardingPurpose.college,
        index: 1,
        newName: 'Quantum Mechanics',
      );
      expect(renameValid, true);
      expect(container.read(onboardingProvider).collegeData!.subjects[1], 'Quantum Mechanics');

      // 7. Reorder subjects
      notifier.reorderSubjects(
        purpose: OnboardingPurpose.college,
        oldIndex: 0,
        newIndex: 1,
      );
      expect(container.read(onboardingProvider).collegeData!.subjects, [
        'Quantum Mechanics',
        'Mechanics',
      ]);

      // 8. Delete subject
      notifier.removeSubject(purpose: OnboardingPurpose.college, index: 0);
      expect(container.read(onboardingProvider).collegeData!.subjects, ['Mechanics']);

      // 9. Personal Topic duplicate prevention
      notifier.togglePurpose(OnboardingPurpose.personalLearning);
      expect(notifier.addTopic('Python'), true);
      expect(notifier.addTopic('python'), false);
      expect(container.read(onboardingProvider).errorMessage, contains('already added'));
    });
  });

  group('Persistence, Resume & Existing User Safety Tests (Flows E & F)', () {
    test('Flow E — Resume In-Progress Onboarding from Draft', () async {
      final repository = OnboardingRepository();

      // Create draft state at subjects step
      const inProgressState = OnboardingState(
        status: OnboardingStatus.inProgress,
        currentStep: OnboardingStep.subjects,
        selectedPurposes: {OnboardingPurpose.college},
        collegeData: CollegeSetupData(
          institutionName: 'Oxford',
          degree: 'B.A.',
          branch: 'History',
          academicYear: '2nd Year',
          semester: 'Trinity Term',
          subjects: ['Medieval Europe', 'Modern History'],
        ),
      );

      await repository.saveDraft(inProgressState);

      // Reload state simulating app restart
      final loaded = await repository.loadOnboardingState();

      expect(loaded.status, OnboardingStatus.inProgress);
      expect(loaded.currentStep, OnboardingStep.subjects);
      expect(loaded.isCollegeSelected, true);
      expect(loaded.collegeData?.degree, 'B.A.');
      expect(loaded.collegeData?.subjects, ['Medieval Europe', 'Modern History']);
    });

    test('Flow F — Existing User Safety (Already Completed)', () async {
      final repository = OnboardingRepository();

      // Mark legacy or explicit completed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      final loaded = await repository.loadOnboardingState();
      expect(loaded.status, OnboardingStatus.completed);
      expect(loaded.hasCompletedOnboarding, true);
    });

    test('New User starts at notStarted', () async {
      final repository = OnboardingRepository();
      final loaded = await repository.loadOnboardingState();

      expect(loaded.status, OnboardingStatus.notStarted);
      expect(loaded.hasCompletedOnboarding, false);
      expect(loaded.selectedPurposes.isEmpty, true);
    });
  });

  group('Phase 3 Widget Tests', () {
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

    testWidgets('PurposeSelectionScreen renders cards and toggles selection', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: PurposeSelectionScreen(
            onContinue: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and cards
      expect(find.text('What are you organizing?'), findsOneWidget);
      expect(find.text('College'), findsOneWidget);
      expect(find.text('School'), findsOneWidget);
      expect(find.text('Personal Learning'), findsOneWidget);

      // Tap College Card
      await tester.tap(find.text('College'));
      await tester.pumpAndSettle();

      // Tap Continue Button
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('CollegeSetupScreen displays inputs and populates chips', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: CollegeSetupScreen(
            onContinue: () {},
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set up your college workspace'), findsOneWidget);
      expect(find.text('Degree *'), findsOneWidget);
      expect(find.text('Department / Branch *'), findsOneWidget);
      expect(find.text('Current Semester *'), findsOneWidget);

      // Tap a suggestion chip (e.g. 'B.Tech')
      final chipFinder = find.text('B.Tech');
      if (chipFinder.evaluate().isNotEmpty) {
        await tester.tap(chipFinder);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('CollegeSubjectsScreen renders semester and empty state', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: CollegeSubjectsScreen(
            onContinue: () {},
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add your subjects'), findsOneWidget);
      expect(find.text('Add Subject'), findsOneWidget);
    });

    testWidgets('PersonalLearningScreen renders topic suggestions', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: PersonalLearningScreen(
            onContinue: () {},
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('What are you learning?'), findsOneWidget);
      expect(find.text('Popular learning areas'), findsOneWidget);
      expect(find.text('Python'), findsOneWidget);
      expect(find.text('Flutter'), findsOneWidget);
    });

    testWidgets('OnboardingCompleteScreen renders completion headline and Continue CTA', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: OnboardingCompleteScreen(
            onFinish: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your Study Vault is ready'), findsOneWidget);
      expect(find.text('Your learning workspace has been created.'), findsOneWidget);
      expect(find.text('Continue to Study Vault'), findsOneWidget);
    });

    testWidgets('OnboardingScaffold renders 4-step progress indicators', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScaffold(
            currentStep: OnboardingStep.setup,
            child: const Text('Scaffold Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('01 Purpose'), findsOneWidget);
      expect(find.text('02 Setup'), findsOneWidget);
      expect(find.text('03 Subjects'), findsOneWidget);
      expect(find.text('04 Done'), findsOneWidget);
      expect(find.text('Scaffold Content'), findsOneWidget);
    });
  });
}
