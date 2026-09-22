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
      final horizontalMargin = isNarrow ? 12.0 : 20.0;
      final floatingBottomMargin = bottomPadding > 0 ? bottomPadding + 6.0 : 16.0;
      const navBarHeight = 64.0;

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

            // 3. True Floating Bottom Navigation Bar (floats above page content)
            if (!isKeyboardOpen)
              Positioned(
                left: horizontalMargin,
                right: horizontalMargin,
                bottom: floatingBottomMargin,
                child: customBottomBar ??
                    AppBottomNavigation(
                      currentIndex: navigationIndex!,
                      onTap: onNavigationChanged!,
                      onAddTap: onAddTap,
                      items: navigationItems,
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
          // Sidebar / Rail
          Container(
            width: isDesktop
                ? AppDimensions.sidebarWidth
                : AppDimensions.navRailWidth,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(right: AppBorders.standard),
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
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: AppRadius.brSm,
                            border: AppBorders.allStandard,
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            size: 20,
                            color: AppColors.primaryLight,
                          ),
                        ),
                        if (isDesktop) ...[
                          AppSpacing.h12,
                          const Text(
                            'Study Vault',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 1),
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
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Material(
                              color: isSelected
                                  ? AppColors.surfaceSecondary
                                  : Colors.transparent,
                              borderRadius: AppRadius.brMd,
                              child: InkWell(
                                onTap: () => onNavigationChanged!(index),
                                borderRadius: AppRadius.brMd,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    border: isSelected
                                        ? const Border(left: AppBorders.focus)
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
                                            ? AppColors.primaryLight
                                            : AppColors.textSecondary,
                                      ),
                                      AppSpacing.h12,
                                      Text(
                                        item.label,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: isSelected
                                              ? AppColors.textPrimary
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
          Expanded(child: body),
        ],
      ),
    );
  }
}
