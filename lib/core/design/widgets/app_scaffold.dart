import 'dart:ui';
import 'package:flutter/material.dart';
import '../tokens/tokens.dart';
import 'app_bottom_navigation.dart';

/// Responsive scaffold supporting adaptive navigation:
/// - Bottom bar on mobile (< 600px)
/// - Navigation rail on tablet (600px - 1024px)
/// - Navigation sidebar on desktop (>= 1024px)
class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? topBar;
  final Widget? floatingActionButton;
  final int? navigationIndex;
  final ValueChanged<int>? onNavigationChanged;
  final VoidCallback? onAddTap;
  final VoidCallback? onAiTap;
  final List<AppNavigationItem> navigationItems;
  final Widget? customBottomBar;
  final Color? backgroundColor;

  const AppScaffold({
    super.key,
    required this.body,
    this.topBar,
    this.floatingActionButton,
    this.navigationIndex,
    this.onNavigationChanged,
    this.onAddTap,
    this.onAiTap,
    this.navigationItems = AppNavigationItem.defaultItems,
    this.customBottomBar,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final hasNav = navigationIndex != null && onNavigationChanged != null;

    if (!hasNav && isMobile) {
      return Scaffold(
        backgroundColor: backgroundColor ?? AppColors.background,
        appBar: topBar,
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: customBottomBar,
      );
    }

    if (isMobile && hasNav) {
      final bottomPadding = MediaQuery.of(context).padding.bottom;
      final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
      final screenWidth = MediaQuery.of(context).size.width;
      final isNarrow = screenWidth < 360;
      final horizontalMargin = isNarrow ? 12.0 : 18.0;
      final floatingBottomMargin = bottomPadding > 0 ? bottomPadding + 8.0 : 20.0;
      const navBarHeight = 68.0;

      return Scaffold(
        backgroundColor: backgroundColor ?? AppColors.background,
        appBar: topBar,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Page Content fills the entire viewport
            Positioned.fill(
              child: body,
            ),

            // 2. Floating Action Button positioned safely above the floating navigation bar
            if (floatingActionButton != null && !isKeyboardOpen)
              Positioned(
                right: 20.0,
                bottom: navBarHeight + floatingBottomMargin + 14.0,
                child: floatingActionButton!,
              ),

            // 3. True Floating Bottom Navigation Bar (floats above page content, centered with max width)
            if (!isKeyboardOpen)
              Positioned(
                left: 0,
                right: 0,
                bottom: floatingBottomMargin,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
                      child: customBottomBar ??
                          AppBottomNavigation(
                            currentIndex: navigationIndex!,
                            onTap: onNavigationChanged!,
                            onAddTap: onAddTap,
                            items: navigationItems,
                          ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Tablet & Desktop: Adaptive Rail / Sidebar
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      appBar: topBar,
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          // Sidebar / Rail with Translucent Frosted Glass Styling
          Container(
            width: isDesktop
                ? AppDimensions.sidebarWidth
                : AppDimensions.navRailWidth,
            decoration: BoxDecoration(
              color: const Color(0xFF0C0C14).withValues(alpha: 0.65),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1.0,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // App Brand Mark
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.lg,
                    ),
                    child: Row(
                      mainAxisAlignment: isDesktop
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF8B5CF6),
                                Color(0xFF6366F1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.30),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        if (isDesktop) ...[
                          AppSpacing.h12,
                          const Text(
                            'Study Vault',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.06),
                    height: 1,
                  ),
                  AppSpacing.v8,

                  // Navigation Links
                  Expanded(
                    child: ListView.builder(
                      itemCount: navigationItems.length,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      itemBuilder: (context, index) {
                        final item = navigationItems[index];
                        final isSelected = navigationIndex == index;

                        if (isDesktop) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Material(
                              color: isSelected
                                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.16)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () => onNavigationChanged!(index),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(
                                            color: const Color(0xFFA78BFA).withValues(alpha: 0.35),
                                            width: 1,
                                          )
                                        : null,
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? item.activeIcon
                                            : item.icon,
                                        size: AppIcons.md,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      ),
                                      AppSpacing.h12,
                                      Text(
                                        item.label,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        } else {
                          // Tablet Rail Icon
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: IconButton(
                              icon: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: AppIcons.md,
                                color: isSelected
                                    ? AppColors.primaryLight
                                    : AppColors.textSecondary,
                              ),
                              tooltip: item.label,
                              onPressed: () => onNavigationChanged!(index),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Screen Content
          Expanded(
            child: Column(
              children: [
                if (topBar == null)
                  ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        height: 58,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0F1A).withValues(alpha: 0.65),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Workspace / Breadcrumb Indicator
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Study Space',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '/',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    _getSectionTitle(navigationIndex),
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),

                            // Dedicated Elegant Top AI Navigation Button
                            if (onAiTap != null) ...[
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  key: const ValueKey('desktop_top_ai_nav_button'),
                                  onTap: onAiTap,
                                  borderRadius: BorderRadius.circular(22),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF8B5CF6).withValues(alpha: 0.90),
                                          const Color(0xFF6366F1).withValues(alpha: 0.85),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.40),
                                          blurRadius: 14,
                                          spreadRadius: 0,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 15,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Ask AI Tutor',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSectionTitle(int? index) {
    if (index == null || index < 0 || index >= navigationItems.length) {
      return 'Overview';
    }
    return navigationItems[index].label;
  }
}
