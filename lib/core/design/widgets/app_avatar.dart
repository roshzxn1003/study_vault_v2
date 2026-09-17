import 'package:flutter/material.dart';
import '../tokens/tokens.dart';

/// Clean academic avatar displaying user initials or image with fallback.
class AppAvatar extends StatelessWidget {
  final String? name;
  final String? imageUrl;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isCircular;

  const AppAvatar({
    super.key,
    this.name,
    this.imageUrl,
    this.size = 36.0,
    this.backgroundColor,
    this.foregroundColor,
    this.isCircular = true,
  });

  String get _initials {
    if (name == null || name!.trim().isEmpty) return '?';
    final parts = name!.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.surfaceSecondary;
    final fg = foregroundColor ?? AppColors.textPrimary;
    final radius = isCircular ? BorderRadius.circular(size / 2) : AppRadius.brMd;

    Widget content;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      content = Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallback(fg),
      );
    } else {
      content = _buildFallback(fg);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: AppBorders.allStandard,
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(child: content),
    );
  }

  Widget _buildFallback(Color fg) {
    return Text(
      _initials,
      style: TextStyle(
        fontSize: size * 0.38,
        fontWeight: FontWeight.w600,
        color: fg,
        letterSpacing: -0.5,
      ),
    );
  }
}
