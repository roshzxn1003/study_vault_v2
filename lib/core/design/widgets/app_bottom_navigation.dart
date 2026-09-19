import 'package:flutter/material.dart';
import '../tokens/tokens.dart';

/// Navigation item model representing a Study Vault core destination.
class AppNavigationItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int? badgeCount;

  const AppNavigationItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badgeCount,
  });

  /// The 6 future core destinations for Study Vault
  static const List<AppNavigationItem> defaultItems = [
    AppNavigationItem(
      label: 'Home',
      icon: AppIcons.home,
      activeIcon: AppIcons.homeActive,
    ),
    AppNavigationItem(
      label: 'Subjects',
      icon: AppIcons.subjects,
      activeIcon: AppIcons.subjectsActive,
    ),
    AppNavigationItem(
      label: 'Inbox',
      icon: AppIcons.inbox,
      activeIcon: AppIcons.inboxActive,
    ),
    AppNavigationItem(
      label: 'Vault',
      icon: AppIcons.vault,
      activeIcon: AppIcons.vaultActive,
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

/// Minimal academic bottom navigation bar for Study Vault.
class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppNavigationItem> items;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items = AppNavigationItem.defaultItems,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: AppBorders.allStandard,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = currentIndex == index;

                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTap(index),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected ? item.activeIcon : item.icon,
                            size: 22,
                            color: isSelected
                                ? AppColors.primaryLight
                                : AppColors.textMuted,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              fontSize: 11,
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primaryLight
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
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
