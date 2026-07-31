import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../app_colors.dart';
import '../app_radius.dart';
import '../app_space.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Loading placeholders.
///
/// `shimmer: ^3.0.0` has been a declared dependency of this app for its whole
/// life and was never once imported. Every load state was a bare centred
/// `CircularProgressIndicator` on an otherwise empty screen, and the shared
/// `ProductImage` placeholder was `#FFFFFF` **on a white card** — so a grid
/// waiting on images rendered as genuinely blank space. The captured Category
/// tab showed two full rows of labels floating in nothing.
///
/// A skeleton says "this is arriving". A blank screen says "this is broken".
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius,
  });

  final double width;
  final double height;
  final BorderRadius? radius;

  /// Wraps any arrangement of [AppSkeleton] boxes in a single shimmer sweep, so
  /// a whole screen pulses together rather than each box animating on its own.
  static Widget sweep({required Widget child}) => Shimmer.fromColors(
        baseColor: AppColors.surfaceSunken,
        highlightColor: AppColors.surface,
        period: const Duration(milliseconds: 1200),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: radius ?? AppRadius.smAll,
      ),
    );
  }
}

/// The skeleton of a single product card, matched to the real card's geometry
/// so nothing jumps when the data lands.
///
/// The real [ProductCard] survives a tight `GridView` cell (its height set by
/// `childAspectRatio`, not its own declared height) via a `FittedBox` that
/// shrinks its text block. This skeleton has no such text to shrink, so
/// instead it sizes the image block to whatever height is actually on offer
/// — via [LayoutBuilder], not a `width`-derived square — and gives the fixed,
/// small text-line block priority. A caller passing a tight height (any grid)
/// or a generous one (the horizontal rail below, at a fixed 250.h) both just
/// work, rather than this overflowing whenever a caller's aspect ratio left
/// less headroom than a square image plus three text lines needs.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key, this.width});

  final double? width;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = width ?? constraints.maxWidth.clamp(1.0, 150.w);
        final textBlockHeight = AppSpace.h(AppSpace.sm) +
            AppSpace.h(12) +
            AppSpace.h(AppSpace.sm) +
            AppSpace.h(12) +
            AppSpace.h(6) +
            AppSpace.h(12);
        final availableHeight =
            constraints.hasBoundedHeight ? constraints.maxHeight : w + textBlockHeight;
        final imageHeight = (availableHeight - textBlockHeight).clamp(0.0, w);

        return SizedBox(
          width: w,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSkeleton(width: w, height: imageHeight, radius: AppRadius.mdAll),
              SizedBox(height: AppSpace.h(AppSpace.sm)),
              AppSkeleton(width: w * 0.45, height: AppSpace.h(12)),
              SizedBox(height: AppSpace.h(AppSpace.sm)),
              AppSkeleton(width: w * 0.9, height: AppSpace.h(12)),
              SizedBox(height: AppSpace.h(6)),
              AppSkeleton(width: w * 0.6, height: AppSpace.h(12)),
            ],
          ),
        );
      },
    );
  }
}

/// A horizontal rail of product skeletons.
class ProductRailSkeleton extends StatelessWidget {
  const ProductRailSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton.sweep(
      child: SizedBox(
        height: 250.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: AppSpace.symmetric(horizontal: AppSpace.gutter),
          itemCount: count,
          separatorBuilder: (_, __) => AppSpace.gapW(AppSpace.md),
          itemBuilder: (_, __) => const ProductCardSkeleton(),
        ),
      ),
    );
  }
}
