import 'package:flutter/material.dart';
import '../tokens/tokens.dart';

/// Minimal academic top bar adhering to Study Vault design tokens.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool showBottomBorder;

  const AppTopBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.bottom,
    this.showBottomBorder = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        AppDimensions.topBarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: showBottomBorder
            ? const Border(bottom: AppBorders.standard)
            : null,
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: leading ??
            (canPop
                ? IconButton(
                    icon: const Icon(
                      AppIcons.back,
                      size: AppIcons.md,
                      color: AppColors.textPrimary,
                    ),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : null),
        title: titleWidget ??
            (title != null
                ? Text(
                    title!,
                    style: AppTypography.title,
                  )
                : null),
        actions: actions != null
            ? [
                ...actions!,
                AppSpacing.h8,
              ]
            : null,
        bottom: bottom,
      ),
    );
  }
}
