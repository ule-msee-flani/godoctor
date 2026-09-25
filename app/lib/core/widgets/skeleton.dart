import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// A single shimmering placeholder block.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.white,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Card-shaped list skeleton that mirrors the icon-tile + two-line-text rows
/// used by the patient history/search lists, so the layout doesn't jump when
/// real data arrives. Replaces the bare spinner on list screens.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 6, this.padding});

  final int itemCount;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding ?? const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => const _SkeletonRow(),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Skeleton(width: 46, height: 46, radius: 14),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Skeleton(width: 150, height: 14),
                  SizedBox(height: 8),
                  Skeleton(width: 96, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
