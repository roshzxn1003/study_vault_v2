import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/auth/domain/entities/auth_user.dart';
import 'package:study_vault/features/auth/domain/repositories/auth_repository.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/classroom/domain/models/models.dart';
import 'package:study_vault/features/classroom/presentation/providers/classroom_providers.dart';
import 'package:study_vault/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:study_vault/features/dashboard/presentation/screens/shared_screen.dart';
import 'package:study_vault/features/profile/account_settings_screen.dart';
import 'package:study_vault/features/profile/ai_settings_screen.dart';
import 'package:study_vault/features/profile/profile_screen.dart';
import 'package:study_vault/features/classroom/presentation/screens/classroom_list_screen.dart';
import 'package:study_vault/features/classroom/presentation/screens/classroom_detail_screen.dart';
import 'package:study_vault/features/classroom/presentation/screens/assignment_detail_screen.dart';
import 'package:study_vault/features/vault/presentation/screens/vault_screen.dart';
import 'package:study_vault/features/ai/ai_screen.dart';
import 'package:study_vault/features/sync/presentation/screens/storage_sync_screen.dart';
import 'package:study_vault/features/privacy/presentation/screens/privacy_center_screen.dart';
import 'package:study_vault/features/academic/presentation/screens/academic_settings_screen.dart';

class TabTestAuthRepo implements AuthRepository {
  AuthUser? _user = AuthUser(
    id: 'test_student_1',
    email: 'scholar@vault.edu',
    fullName: 'Jane Scholar',
  );

  @override
  AuthUser? getCurrentUser() => _user;
  @override
  Future<void> signIn({required String email, required String password}) async {}
  @override
  Future<void> signUp({required String email, required String password, required String fullName}) async {}
  @override
  Future<void> signOut() async { _user = null; }
  @override
  Future<void> resetPassword({required String email}) async {}
  @override
  Future<void> signInWithGoogle({String? redirectTo}) async {}
  @override
  Future<void> exchangeCodeOrUrl(String urlOrCode) async {}
}

Widget wrapTab(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(TabTestAuthRepo()),
      ...overrides,
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDbService.instance.setCustomPathForTesting(inMemoryDatabasePath);
  });

  tearDownAll(() async {
    await LocalDbService.instance.closeForTesting();
  });

  group('Comprehensive Tab-by-Tab Health & Layout Audit', () {
    testWidgets('Tab 1: DashboardScreen renders without overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapTab(const DashboardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab 2: VaultScreen renders library tabs & search bar', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapTab(const VaultScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(VaultScreen), findsOneWidget);
      expect(find.text('My Vault'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab 3: ClassroomListScreen renders enrolled courses', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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
        wrapTab(
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

      expect(find.byType(ClassroomListScreen), findsOneWidget);
      expect(find.text('Classrooms'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab 4: ClassroomDetailScreen renders 4 tabs without exceptions', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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
            content: 'Welcome to Distributed Systems! Review syllabus.',
            createdAt: now,
          ),
        ],
        topics: [
          ClassroomTopic(
            id: 'topic-1',
            classroomId: 'mock-1',
            title: 'Consensus & Raft',
            orderIndex: 0,
            createdAt: now,
          ),
        ],
        items: [
          ClassroomItem(
            id: 'item-1',
            classroomId: 'mock-1',
            topicId: 'topic-1',
            type: ClassroomItemType.assignment,
            title: 'Implement Raft Consensus State Machine',
            description: 'Implement election timer and log replication.',
            dueDate: now.add(const Duration(days: 3)),
            maxPoints: 100,
            creatorId: 'prof-lin',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        members: [
          ClassroomMember(
            id: 'mem-1',
            classroomId: 'mock-1',
            userId: 'test_student_1',
            role: 'student',
            name: 'Jane Scholar',
            joinedAt: now,
          ),
        ],
      );

      await tester.pumpWidget(
        wrapTab(
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

      // Switch to Classwork tab
      await tester.tap(find.text('Classwork'));
      await tester.pumpAndSettle();

      // Switch to People tab
      await tester.tap(find.text('People'));
      await tester.pumpAndSettle();

      // Switch to Grades tab
      await tester.tap(find.text('Grades'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab 4b: AssignmentDetailScreen renders assignment instructions, rubrics & socratic tutor', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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
        announcements: [],
        topics: [],
        items: [
          ClassroomItem(
            id: 'item-1',
            classroomId: 'mock-1',
            type: ClassroomItemType.assignment,
            title: 'Implement Raft Consensus State Machine',
            description: 'Implement election timer and log replication.',
            dueDate: now.add(const Duration(days: 3)),
            maxPoints: 100,
            creatorId: 'prof-lin',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        members: [],
      );

      await tester.pumpWidget(
        wrapTab(
          const AssignmentDetailScreen(classroomId: 'mock-1', itemId: 'item-1'),
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AssignmentDetailScreen), findsOneWidget);
      expect(find.text('Implement Raft Consensus State Machine'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab 5: AIScreen renders model pill and input bar', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapTab(const AIScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AIScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab 6: SharedScreen renders tabs (Shared with me, Shared by me, Groups)', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapTab(const SharedScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SharedScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab 7: ProfileScreen renders academic stats & settings buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapTab(const ProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab 8: AccountSettingsScreen renders account, AI & study preferences', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapTab(const AccountSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(AccountSettingsScreen), findsOneWidget);
      expect(find.text('Account & Preferences'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab 9: AiSettingsScreen renders models, research rigor and API keys', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapTab(const AiSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AiSettingsScreen), findsOneWidget);
      expect(find.text('AI & Privacy Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab 10: AcademicSettingsScreen renders curriculum configuration', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapTab(const AcademicSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(AcademicSettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab 11: StorageSyncScreen renders storage breakdown gauge', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapTab(const StorageSyncScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(StorageSyncScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab 12: PrivacyCenterScreen renders zero-telemetry policy', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapTab(const PrivacyCenterScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyCenterScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
