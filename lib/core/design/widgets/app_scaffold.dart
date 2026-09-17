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
    this.navigationItems = AppNavigationItem.defaultItems,
    this.customBottomBar,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final hasNav = navigationIndex != null && onNavigationChanged != null;

    if (isMobile || !hasNav) {
      return Scaffold(
        backgroundColor: backgroundColor ?? AppColors.background,
        appBar: topBar,
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: customBottomBar ??
            (hasNav && isMobile
                ? AppBottomNavigation(
                    currentIndex: navigationIndex!,
                    onTap: onNavigationChanged!,
                    items: navigationItems,
                  )
                : null),
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
