import 'package:flutter/material.dart';
import '../tokens/tokens.dart';

/// Reusable loading states for Study Vault (page, skeleton, and list placeholders).
class AppLoadingState extends StatelessWidget {
  final String? message;

  const AppLoadingState({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
              ),
            ),
            if (message != null) ...[
              AppSpacing.v16,
              Text(
                message!,
                style: AppTypography.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Subtle content placeholder skeleton block for cards and list items.
class AppSkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const AppSkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<AppSkeletonBox> createState() => _AppSkeletonBoxState();
}

class _AppSkeletonBoxState extends State<AppSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated.withValues(alpha: _animation.value),
            borderRadius: widget.borderRadius ?? AppRadius.brMd,
            border: AppBorders.allSubtle,
          ),
        );
      },
    );
  }
}

/// Reusable list skeleton displaying animated shimmer placeholders.
class AppListSkeleton extends StatelessWidget {
  final int count;

  const AppListSkeleton({
    super.key,
    this.count = 4,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: count,
      separatorBuilder: (_, _) => AppSpacing.v12,
      itemBuilder: (_, _) {
        return Container(
          padding: AppSpacing.p16,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: AppBorders.allStandard,
          ),
          child: const Row(
            children: [
              AppSkeletonBox(width: 40, height: 40),
              AppSpacing.h16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonBox(width: 140, height: 14),
                    AppSpacing.v8,
                    AppSkeletonBox(width: 220, height: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shimmer skeleton matching the exact layout hierarchy of the Study Vault Dashboard.
class AppDashboardSkeleton extends StatelessWidget {
  const AppDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Academic Header Skeleton
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(width: 170, height: 22, borderRadius: AppRadius.chip),
                SizedBox(height: AppSpacing.xs),
                AppSkeletonBox(width: 110, height: 12, borderRadius: AppRadius.chip),
              ],
            ),
            AppSkeletonBox(width: 38, height: 38, borderRadius: BorderRadius.all(Radius.circular(19))),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // 2. Search Field Skeleton
        const AppSkeletonBox(width: double.infinity, height: 48, borderRadius: AppRadius.field),
        const SizedBox(height: AppSpacing.md),

        // 3. Quick Action Pills Skeleton
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: List.generate(
              4,
              (i) => const Padding(
                padding: EdgeInsets.only(right: AppSpacing.sm),
                child: AppSkeletonBox(width: 105, height: 40, borderRadius: AppRadius.button),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 4. Subjects Section Header Skeleton
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppSkeletonBox(width: 130, height: 18, borderRadius: AppRadius.chip),
            AppSkeletonBox(width: 60, height: 14, borderRadius: AppRadius.chip),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // 5. Subjects Grid 2x2 Skeleton
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.35,
          ),
          itemCount: 4,
          itemBuilder: (_, _) => Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.card,
              border: AppBorders.allStandard,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppSkeletonBox(width: 50, height: 16, borderRadius: AppRadius.chip),
                AppSkeletonBox(width: 100, height: 16, borderRadius: AppRadius.chip),
                AppSkeletonBox(width: 65, height: 12, borderRadius: AppRadius.chip),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
