import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/tokens.dart';

/// Navigation item model representing a Study Vault core destination.
class AppNavigationItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int? badgeCount;
  final bool isCentralAction;

  const AppNavigationItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badgeCount,
    this.isCentralAction = false,
  });

  /// The 5 core primary destinations for Study Vault:
  /// 1. Home, 2. Library, 3. Add, 4. Shared, 5. Profile
  static const List<AppNavigationItem> defaultItems = [
    AppNavigationItem(
      label: 'Home',
      icon: AppIcons.home,
      activeIcon: AppIcons.homeActive,
    ),
    AppNavigationItem(
      label: 'Library',
      icon: AppIcons.library_,
      activeIcon: AppIcons.libraryActive,
    ),
    AppNavigationItem(
      label: 'Add',
      icon: Icons.add_rounded,
      activeIcon: Icons.add_rounded,
      isCentralAction: true,
    ),
    AppNavigationItem(
      label: 'Shared',
      icon: AppIcons.shared,
      activeIcon: AppIcons.sharedActive,
    ),
    AppNavigationItem(
      label: 'Profile',
      icon: AppIcons.profile,
      activeIcon: AppIcons.profileActive,
    ),
  ];
}

/// True floating academic navigation bar for Study Vault.
/// Detached from screen edges, pill-shaped, with frosted glass elevation.
class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onAddTap;
  final List<AppNavigationItem> items;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onAddTap,
    this.items = AppNavigationItem.defaultItems,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 360;

    return Container(
      height: 66,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(33),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(33),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(33),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.85),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = currentIndex == index && !item.isCentralAction;

                if (item.isCentralAction) {
                  return Expanded(
                    child: Center(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            if (onAddTap != null) {
                              onAddTap!();
                            } else {
                              onTap(index);
                            }
                          },
                          borderRadius: BorderRadius.circular(24),
                          splashColor: Colors.white.withValues(alpha: 0.3),
                          highlightColor: Colors.white.withValues(alpha: 0.15),
                          child: Container(
                            width: isNarrow ? 42 : 46,
                            height: isNarrow ? 42 : 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  Color(0xFF4F46E5),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.45),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1.2,
                              ),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 26,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTap(index);
                      },
                      borderRadius: BorderRadius.circular(24),
                      splashColor: AppColors.primary.withValues(alpha: 0.15),
                      highlightColor: AppColors.primary.withValues(alpha: 0.08),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(
                                horizontal: isNarrow ? 10 : 14,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.18)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: isNarrow ? 20 : 22,
                                color: isSelected
                                    ? AppColors.primaryLight
                                    : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  fontSize: isNarrow ? 9.5 : 10.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.primaryLight
                                      : AppColors.textMuted,
                                  letterSpacing: isSelected ? 0.1 : 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
