import 'package:flutter/material.dart';
import 'package:study_vault/core/design/design_system.dart';

/// Keyboard-safe, responsive container for authentication screens.
/// Enforces a maximum readable width (440px) on tablets and desktops.
class AuthScreenContainer extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final double maxWidth;

  const AuthScreenContainer({
    super.key,
    required this.child,
    this.appBar,
    this.maxWidth = 440,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 360;
    final horizontalPadding = isCompact ? AppSpacing.md : AppSpacing.lg;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: AppSpacing.lg,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

