import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/personalization_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/add_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/ai/ai_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/account_settings_screen.dart';
import '../../features/gamification/presentation/screens/progress_screen.dart';
import '../../features/folders/folders_screen.dart';
import '../../features/folders/folder_details_screen.dart';
import '../../features/notes/create_note_screen.dart';
import '../../features/notes/note_viewer_screen.dart';
import '../../features/files/file_view_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
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
import '../../features/premium/presentation/screens/premium_screen.dart';
import '../../core/theme/app_colors.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final onboardingState = ref.watch(onboardingProvider);
  final isGuest = ref.watch(guestModeProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final currentSession = Supabase.instance.client.auth.currentSession;
      final AuthStatus status = authState.value?.status ?? 
          (currentSession != null ? AuthStatus.authenticated : AuthStatus.unauthenticated);
      
      final bool isAuthenticated = (status == AuthStatus.authenticated) || isGuest;
      final bool isAuthPage = state.matchedLocation == '/login' || 
                             state.matchedLocation == '/signup' || 
                             state.matchedLocation == '/forgot-password';
      
      if (!isAuthenticated && !isAuthPage) return '/login';
      if (isAuthenticated && isAuthPage && !isGuest) return '/home';
      
      // Check onboarding status
      if (isAuthenticated && !isGuest && onboardingState.isLoaded && !onboardingState.hasCompletedOnboarding && state.matchedLocation != '/onboarding' && state.matchedLocation != '/onboarding/personalize') {
        return '/onboarding';
      }
      
      return null;
    },

    routes: [
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/onboarding/personalize', builder: (context, state) => const PersonalizationScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      ShellRoute(
        builder: (context, state, child) => MainNavigationShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
          GoRoute(path: '/ai', builder: (context, state) => const AIScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          GoRoute(path: '/privacy', builder: (context, state) => const PrivacyCenterScreen()),
          GoRoute(path: '/premium', builder: (context, state) => const PremiumScreen()),
        ],
      ),
      GoRoute(path: '/add', builder: (context, state) => const AddScreen()),
      GoRoute(path: '/scan', builder: (context, state) => const ScanScreen()),
      GoRoute(path: '/scan/review', builder: (context, state) => const OCRReviewScreen()),
      GoRoute(path: '/folders', builder: (context, state) => const FoldersScreen()),
      GoRoute(path: '/folder/:id', builder: (context, state) => FolderDetailsScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/notes/create', builder: (context, state) => const CreateNoteScreen()),
      GoRoute(path: '/notes/:id', builder: (context, state) => NoteViewerScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/files/:id', builder: (context, state) => FileViewScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/settings', builder: (context, state) => const AccountSettingsScreen()),
      GoRoute(path: '/progress', builder: (context, state) => const ProgressScreen()),
      
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/add')) return 2;
    if (location.startsWith('/ai')) return 3;
    if (location.startsWith('/profile') || location.startsWith('/privacy') || location.startsWith('/premium')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: const Border(top: BorderSide(color: AppColors.cardBorder, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(context, index: 0, selectedIndex: selectedIndex, icon: Icons.home_rounded, label: 'Vault', route: '/home'),
              _navItem(context, index: 1, selectedIndex: selectedIndex, icon: Icons.search_rounded, label: 'Search', route: '/search'),
              
              // Center Floating Add Button
              GestureDetector(
                onTap: () => context.push('/add'),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                ),
              ),

              _navItem(context, index: 3, selectedIndex: selectedIndex, icon: Icons.auto_awesome_rounded, label: 'AI Tutor', route: '/ai'),
              _navItem(context, index: 4, selectedIndex: selectedIndex, icon: Icons.person_rounded, label: 'Profile', route: '/profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required int index,
    required int selectedIndex,
    required IconData icon,
    required String label,
    required String route,
  }) {
    final isSelected = index == selectedIndex;

    return InkWell(
      onTap: () {
        if (index == 0) context.go('/home');
        if (index == 1) context.go('/search');
        if (index == 3) context.go('/ai');
        if (index == 4) context.go('/profile');
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primaryLight : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primaryLight : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

