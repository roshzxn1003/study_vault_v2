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

/// Floating layered glassmorphism navigation bar for Study Vault.
/// Detached from screen edges, pill-shaped, with frosted glass elevation,
/// subtle ambient purple glow, and interactive central action.
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
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 32,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.20),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF161626).withValues(alpha: 0.65),
                  const Color(0xFF0F0F1A).withValues(alpha: 0.65),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                            width: isNarrow ? 46 : 50,
                            height: isNarrow ? 46 : 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF8B5CF6),
                                  Color(0xFF6366F1),
                                  Color(0xFF4F46E5),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.50),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.30),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.40),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 28,
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
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? LinearGradient(
                                        colors: [
                                          const Color(0xFF8B5CF6).withValues(alpha: 0.32),
                                          const Color(0xFF6366F1).withValues(alpha: 0.20),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(16),
                                border: isSelected
                                    ? Border.all(
                                        color: const Color(0xFFA78BFA).withValues(alpha: 0.40),
                                        width: 1,
                                      )
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.22),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: isNarrow ? 20 : 22,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary.withValues(alpha: 0.85),
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
                                      ? Colors.white
                                      : AppColors.textSecondary.withValues(alpha: 0.80),
                                  letterSpacing: isSelected ? 0.2 : 0,
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
