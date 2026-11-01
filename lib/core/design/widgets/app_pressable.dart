import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/tokens.dart';

/// Benchmark interactive touchable container following Appllama Motion & Haptic standards.
/// - Performs tactile 0.97 spring press-in scale on touch-down.
/// - Triggers subtle haptic punctuation (HapticFeedback.lightImpact).
/// - Correctly renders native splash/ripple effects without obscuring them behind opaque child containers.
class AppPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Border? border;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool enableHaptic;
  final Color? splashColor;
  final Color? highlightColor;

  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = AppAnimations.cardPressScale,
    this.borderRadius,
    this.backgroundColor,
    this.border,
    this.shadows,
    this.padding,
    this.margin,
    this.enableHaptic = true,
    this.splashColor,
    this.highlightColor,
  });

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (_isPressed != pressed && mounted) {
      setState(() => _isPressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = widget.borderRadius ?? AppRadius.card;
    final isInteractive = widget.onTap != null || widget.onLongPress != null;

    Widget body = Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: widget.child,
    );

    Widget interactiveContent;
    if (isInteractive) {
      interactiveContent = Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap != null
              ? () {
                  if (widget.enableHaptic) {
                    HapticFeedback.lightImpact();
                  }
                  widget.onTap!();
                }
              : null,
          onLongPress: widget.onLongPress != null
              ? () {
                  if (widget.enableHaptic) {
                    HapticFeedback.mediumImpact();
                  }
                  widget.onLongPress!();
                }
              : null,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          borderRadius: effectiveRadius,
          splashColor: widget.splashColor ?? AppColors.primary.withValues(alpha: 0.12),
          highlightColor: widget.highlightColor ?? AppColors.primary.withValues(alpha: 0.05),
          child: Ink(
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? AppColors.surface,
              borderRadius: effectiveRadius,
              border: widget.border ?? AppBorders.allStandard,
            ),
            child: body,
          ),
        ),
      );
    } else {
      interactiveContent = Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? AppColors.surface,
          borderRadius: effectiveRadius,
          border: widget.border ?? AppBorders.allStandard,
        ),
        child: widget.child,
      );
    }

    Widget result = AnimatedScale(
      scale: _isPressed ? widget.pressedScale : 1.0,
      duration: AppAnimations.press,
      curve: AppAnimations.appleEaseOut,
      child: interactiveContent,
    );

    if (widget.shadows != null && widget.shadows!.isNotEmpty) {
      result = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          boxShadow: widget.shadows,
        ),
        child: result,
      );
    }

    if (widget.margin != null) {
      result = Padding(
        padding: widget.margin!,
        child: result,
      );
    }

    return result;
  }
}
