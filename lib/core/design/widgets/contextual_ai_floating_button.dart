import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';

/// Custom FAB location ensuring buttons float safely above the floating glass bottom navigation bar.
class FloatingAboveNavLocation extends FloatingActionButtonLocation {
  final double bottomClearance;
  const FloatingAboveNavLocation({this.bottomClearance = 124.0});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.floatingActionButtonSize.width -
        18.0;
    final double fabY = scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        bottomClearance;
    return Offset(fabX, fabY);
  }
}

/// Contextual Floating AI Button for Study Vault.
///
/// Automatically grounds AI study sessions into the active context:
/// - Dashboard: General study companion & exam readiness.
/// - Subject: Specific subject grounding & syllabus review.
/// - Material / Document: Grounded to the specific file & page.
/// - Folder: Grounded to all notes and files in that folder.
class ContextualAiFloatingButton extends StatelessWidget {
  final String? subject;
  final String? materialId;
  final String? materialTitle;
  final String? folderId;
  final String? folderName;
  final String? initialQuery;
  final String? tooltip;
  final Object? heroTag;
  final double? bottomOffset;
  final VoidCallback? onTap;

  const ContextualAiFloatingButton({
    super.key,
    this.subject,
    this.materialId,
    this.materialTitle,
    this.folderId,
    this.folderName,
    this.initialQuery,
    this.tooltip,
    this.heroTag,
    this.bottomOffset,
    this.onTap,
  });

  String _computedTooltip() {
    if (tooltip != null) return tooltip!;
    if (materialTitle != null && materialTitle!.trim().isNotEmpty) {
      return 'Ask AI about "${materialTitle!.trim()}"';
    }
    if (subject != null && subject!.trim().isNotEmpty) {
      return 'Ask AI about ${subject!.trim()}';
    }
    if (folderName != null && folderName!.trim().isNotEmpty) {
      return 'Ask AI about folder "${folderName!.trim()}"';
    }
    return 'Ask Study Vault AI';
  }

  void _handleTap(BuildContext context) {
    HapticFeedback.lightImpact();
    if (onTap != null) {
      onTap!();
      return;
    }

    final params = <String, String>{};
    if (subject != null && subject!.trim().isNotEmpty) {
      params['subject'] = subject!.trim();
    }
    if (materialId != null && materialId!.trim().isNotEmpty) {
      params['materialId'] = materialId!.trim();
    }
    if (materialTitle != null && materialTitle!.trim().isNotEmpty) {
      params['materialTitle'] = materialTitle!.trim();
    }
    if (folderId != null && folderId!.trim().isNotEmpty) {
      params['folderId'] = folderId!.trim();
    }
    if (folderName != null && folderName!.trim().isNotEmpty) {
      params['folderName'] = folderName!.trim();
    }
    if (initialQuery != null && initialQuery!.trim().isNotEmpty) {
      params['query'] = initialQuery!.trim();
    }

    final targetUri = Uri(
      path: '/ai',
      queryParameters: params.isNotEmpty ? params : null,
    );
    context.push(targetUri.toString());
  }

  @override
  Widget build(BuildContext context) {
    // Hide when keyboard is actively visible so it doesn't obstruct typing
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }

    final hasContext = (subject != null && subject!.trim().isNotEmpty) ||
        (materialId != null && materialId!.trim().isNotEmpty) ||
        (folderName != null && folderName!.trim().isNotEmpty);

    final buttonWidget = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8B5CF6), // Royal Purple
            Color(0xFF6366F1), // Electric Indigo
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.40),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          onTap: () => _handleTap(context),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              if (hasContext)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.emerald,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final fab = heroTag != null
        ? Hero(
            tag: heroTag!,
            child: Tooltip(
              message: _computedTooltip(),
              child: buttonWidget,
            ),
          )
        : Tooltip(
            message: _computedTooltip(),
            child: buttonWidget,
          );

    if (bottomOffset != null && bottomOffset! > 0) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottomOffset!),
        child: fab,
      );
    }

    return fab;
  }
}
