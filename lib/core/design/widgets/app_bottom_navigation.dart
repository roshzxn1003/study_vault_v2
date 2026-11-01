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

/// Precision floating navigation bar for Study Vault adhering to Appllama Anti-slop Laws.
/// - Restrained obsidian surface with specular hairline border.
/// - Diffuse black ambient shadow (no neon purple halos).
/// - 0.96 scale touch feedback on central action with haptic punctuation.
/// - Tabular labels and crisp single-accent selection indicator.
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
      height: AppDimensions.bottomNavHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.bottomNavHeight / 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 28,
            spreadRadius: 0,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.bottomNavHeight / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xE6141418), // 90% opacity obsidian zinc
              borderRadius: BorderRadius.circular(AppDimensions.bottomNavHeight / 2),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1.0,
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
                      child: _CentralActionButton(
                        isNarrow: isNarrow,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          if (onAddTap != null) {
                            onAddTap!();
                          } else {
                            onTap(index);
                          }
                        },
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
                      splashColor: AppColors.primary.withValues(alpha: 0.12),
                      highlightColor: AppColors.primary.withValues(alpha: 0.05),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: AppAnimations.fast,
                              curve: AppAnimations.appleEaseOut,
                              padding: EdgeInsets.symmetric(
                                horizontal: isNarrow ? 10 : 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primarySubtle
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: isSelected
                                    ? Border.all(
                                        color: AppColors.primaryLight.withValues(alpha: 0.35),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: isNarrow ? 20 : 22,
                                color: isSelected
                                    ? AppColors.primaryLight
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                fontSize: isNarrow ? 9.5 : 10.5,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
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

class _CentralActionButton extends StatefulWidget {
  final bool isNarrow;
  final VoidCallback onTap;

  const _CentralActionButton({
    required this.isNarrow,
    required this.onTap,
  });

  @override
  State<_CentralActionButton> createState() => _CentralActionButtonState();
}

class _CentralActionButtonState extends State<_CentralActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.isNarrow ? 46.0 : 48.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? AppAnimations.buttonPressScale : 1.0,
        duration: AppAnimations.press,
        curve: AppAnimations.appleEaseOut,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            size: 26,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
