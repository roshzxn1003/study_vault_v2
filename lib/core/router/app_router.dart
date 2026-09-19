import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/subject_detail_screen.dart';
import '../../features/dashboard/presentation/screens/inbox_screen.dart';
import '../../features/dashboard/presentation/screens/shared_screen.dart';
import '../../core/design/widgets/app_scaffold.dart';
import '../../core/design/widgets/add_material_sheet.dart';
import '../../core/theme/app_colors.dart';
import '../../features/home/add_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/ai/ai_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/account_settings_screen.dart';
import '../../features/profile/ai_settings_screen.dart';
import '../../features/gamification/presentation/screens/progress_screen.dart';
import '../../features/vault/presentation/screens/vault_screen.dart';
import '../../features/vault/presentation/screens/material_detail_screen.dart';
import '../../features/import/presentation/screens/import_screen.dart';
import '../../features/folders/folder_details_screen.dart';
import '../../features/notes/create_note_screen.dart';
import '../../features/notes/note_viewer_screen.dart';
import '../../features/files/file_view_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../core/design/preview/design_system_preview_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/academic/presentation/screens/academic_workspace_screen.dart';
import '../../features/academic/presentation/screens/academic_history_screen.dart';
import '../../features/academic/presentation/screens/academic_settings_screen.dart';
import '../../features/exam/presentation/screens/exam_setup_screen.dart';
import '../../features/exam/presentation/screens/exam_plan_screen.dart';
import '../../features/study/presentation/screens/study_topic_screen.dart';
import '../../features/study/presentation/screens/study_tutor_screen.dart';
import '../../features/quiz/presentation/screens/quiz_player_screen.dart';
import '../../features/flashcards/presentation/screens/flashcard_screen.dart';
import '../../features/scan/presentation/screens/scan_screen.dart';
import '../../features/scan/presentation/screens/ocr_review_screen.dart';
import '../../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../../features/privacy/presentation/screens/privacy_center_screen.dart';
import '../../features/sync/presentation/screens/storage_sync_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final onboardingState = ref.watch(onboardingProvider);
  final isGuest = ref.watch(guestModeProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final currentSession = Supabase.instance.client.auth.currentSession;
      final AuthStatus status = authState.value?.status ?? 
          (currentSession != null ? AuthStatus.authenticated : AuthStatus.unauthenticated);
      
      final bool isAuthenticated = (status == AuthStatus.authenticated) || isGuest;
      final bool isSplash = state.matchedLocation == '/splash';
      final bool isDevPage = state.matchedLocation == '/design-preview';
      final bool isAuthPage = state.matchedLocation == '/login' || 
                             state.matchedLocation == '/signup' || 
                             state.matchedLocation == '/forgot-password';
      
      // Protect dev preview routes in production
      if (!kDebugMode && isDevPage) {
        return isAuthenticated ? '/home' : '/login';
      }

      // Let splash and dev preview screens (debug only) run uninterrupted
      if (isSplash || isDevPage) return null;

      if (!isAuthenticated && !isAuthPage) return '/login';
      if (isAuthenticated && isAuthPage && !isGuest) return '/home';
      
      // Check onboarding status
      final bool isOnboardingPage = state.matchedLocation.startsWith('/onboarding');
      if (isAuthenticated && !isGuest && onboardingState.isLoaded) {
        if (!onboardingState.hasCompletedOnboarding && !isOnboardingPage) {
          return '/onboarding';
        }
        if (onboardingState.hasCompletedOnboarding && isOnboardingPage) {
          return '/home';
        }
      }
      
      return null;
    },

    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/design-preview', builder: (context, state) => const DesignSystemPreviewScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/onboarding/setup', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/onboarding/subjects', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/onboarding/complete', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      ShellRoute(
        builder: (context, state, child) => MainNavigationShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/academic', builder: (context, state) => const AcademicWorkspaceScreen()),
          GoRoute(path: '/inbox', builder: (context, state) => const InboxScreen()),
          GoRoute(path: '/vault', builder: (context, state) => const VaultScreen()),
          GoRoute(path: '/folders', redirect: (_, _) => '/vault'),
          GoRoute(path: '/shared', builder: (context, state) => const SharedScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
          GoRoute(path: '/privacy', builder: (context, state) => const PrivacyCenterScreen()),
          GoRoute(path: '/ai', builder: (context, state) => const AIScreen()),
          GoRoute(path: '/ai/settings', builder: (context, state) => const AiSettingsScreen()),
        ],
      ),
      GoRoute(
        path: '/subject/:id',
        builder: (context, state) => SubjectDetailScreen(
          subjectId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/vault/material/:id',
        builder: (context, state) => MaterialDetailScreen(
          materialId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/material/:id',
        builder: (context, state) => MaterialDetailScreen(
          materialId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(path: '/import', builder: (context, state) => const ImportScreen()),
      GoRoute(path: '/add', builder: (context, state) => const AddScreen()),
      GoRoute(path: '/scan', builder: (context, state) => const ScanScreen()),
      GoRoute(path: '/scan/review', builder: (context, state) => const OCRReviewScreen()),
      GoRoute(path: '/folder/:id', builder: (context, state) => FolderDetailsScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/notes/create', builder: (context, state) => const CreateNoteScreen()),
      GoRoute(path: '/notes/:id', builder: (context, state) => NoteViewerScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/files/:id', builder: (context, state) => FileViewScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/settings', builder: (context, state) => const AccountSettingsScreen()),
      GoRoute(path: '/settings/storage-sync', builder: (context, state) => const StorageSyncScreen()),
      GoRoute(path: '/progress', builder: (context, state) => const ProgressScreen()),
      GoRoute(path: '/academic/history', builder: (context, state) => const AcademicHistoryScreen()),
      GoRoute(path: '/academic/settings', builder: (context, state) => const AcademicSettingsScreen()),
      
      // Exam, Study & Flashcards
      GoRoute(path: '/exam/setup', builder: (context, state) => const ExamSetupScreen()),
      GoRoute(path: '/exam/plan', builder: (context, state) => const ExamPlanScreen()),
      GoRoute(path: '/study/:topic', builder: (context, state) => StudyTopicScreen(topic: state.pathParameters['topic']!)),
      GoRoute(path: '/study/learn/:topic', builder: (context, state) => StudyTutorScreen(topic: state.pathParameters['topic']!)),
      GoRoute(path: '/study/quiz/:topic', builder: (context, state) => QuizPlayerScreen(topic: state.pathParameters['topic']!)),
      GoRoute(path: '/study/flashcards/:topic', builder: (context, state) => FlashcardScreen(topic: state.pathParameters['topic']!)),
    ],
  );
});

class MainNavigationShell extends StatelessWidget {
  final Widget child;
  const MainNavigationShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/academic')) return 1;
    if (location.startsWith('/inbox')) return 2;
    if (location.startsWith('/vault') || location.startsWith('/folders')) return 3;
    if (location.startsWith('/shared')) return 4;
    if (location.startsWith('/profile') || location.startsWith('/privacy')) return 5;
    return 0;
  }

  void _onNavigationChanged(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/academic');
        break;
      case 2:
        context.go('/inbox');
        break;
      case 3:
        context.go('/vault');
        break;
      case 4:
        context.go('/shared');
        break;
      case 5:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final showShellFab = selectedIndex != 3 && selectedIndex != 5;

    return AppScaffold(
      body: child,
      navigationIndex: selectedIndex,
      onNavigationChanged: (index) => _onNavigationChanged(context, index),
      floatingActionButton: showShellFab
          ? FloatingActionButton.extended(
              heroTag: 'shell_add_material_fab',
              onPressed: () => AddMaterialSheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Material', style: TextStyle(fontWeight: FontWeight.w600)),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}

