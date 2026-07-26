import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../app_colors.dart';
import '../app_gradients.dart';
import '../app_radius.dart';
import '../app_space.dart';
import '../app_type.dart';

enum PriceSize { card, line, hero }

/// Selling price, MRP and discount, rendered one way.
///
/// The app previously had six divergent price layouts — the gap between price
/// and MRP was 4, 5, 6 or 8dp depending on the screen, the strikethrough grey
/// was `neutral400`, `Colors.grey` or `Colors.grey.shade500` (two different
/// hues, adjacent), and the discount was blue text, a yellow corner tab, a
/// peach pill or a green ribbon. The grand total's emphasis actually *fell* as
/// the shopper got closer to paying: 17sp in the cart, 16sp at checkout, 14sp
/// on the summary.
class PriceBlock extends StatelessWidget {
  const PriceBlock({
    super.key,
    required this.sellingPrice,
    this.mrp,
    this.size = PriceSize.card,
    this.showDiscount = false,
    this.highlighted = false,
  });

  final double sellingPrice;
  final double? mrp;
  final PriceSize size;

  /// Renders the percentage inline. Off by default because on a product card
  /// the discount belongs on the image as a [DiscountBadge], not in the text.
  final bool showDiscount;

  /// Wrap the price in a warm plate, with the MRP struck through beside it.
  ///
  /// This is the Flipkart Grocery treatment, and it works for a reason: a plain
  /// price and a plain strikethrough are two pieces of text the eye has to
  /// compare, whereas a highlighted plate reads as "this is the deal" before
  /// you have parsed either number. On a shelf of twelve cards that difference
  /// is the whole scan.
  ///
  /// Only for the card. On the detail page and in the cart the price is already
  /// the largest thing on screen and does not need a plate to win.
  final bool highlighted;

  bool get _hasMrp => mrp != null && mrp! > sellingPrice;

  int get discountPercentage =>
      _hasMrp ? (((mrp! - sellingPrice) / mrp!) * 100).round() : 0;

  @override
  Widget build(BuildContext context) {
    final priceStyle = switch (size) {
      PriceSize.card => AppText.priceM(),
      PriceSize.line => AppText.priceL(),
      PriceSize.hero => AppText.priceHero(),
    };

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('₹${sellingPrice.toStringAsFixed(0)}', style: priceStyle),
        if (_hasMrp) ...[
          AppSpace.gapW(AppSpace.xs),
          Flexible(
            child: Text(
              '₹${mrp!.toStringAsFixed(0)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.mrp(),
            ),
          ),
        ],
        if (showDiscount && discountPercentage > 0) ...[
          AppSpace.gapW(AppSpace.sm),
          DiscountBadge(percentage: discountPercentage, compact: true),
        ],
      ],
    );

    if (!highlighted) return row;

    return Container(
      padding: AppSpace.symmetric(horizontal: AppSpace.sm, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.discountSurface,
        borderRadius: AppRadius.xsAll,
        border: Border.all(color: AppColors.discountBorder),
      ),
      child: row,
    );
  }
}

/// The single discount treatment.
///
/// Amber, because the brand's green and navy are both cool and serious and a
/// discount needs to be neither. Navy-black on it measures 8.0:1, so it stays
/// readable at the 10sp used on a thumbnail — which the previous 9sp blue
/// `#2563EB` text on white did not.
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({
    super.key,
    required this.percentage,
    this.compact = false,
    this.corner = false,
  });

  final int percentage;

  /// A pill, for use inline beside a price.
  final bool compact;

  /// A corner tab, for use on the top-left of a product image.
  final bool corner;

  @override
  Widget build(BuildContext context) {
    if (percentage <= 0) return const SizedBox.shrink();

    return Container(
      padding: AppSpace.symmetric(
        horizontal: compact ? AppSpace.xs : AppSpace.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        gradient: AppGradients.warm,
        borderRadius: corner
            ? BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md.r),
                bottomRight: Radius.circular(AppRadius.md.r),
              )
            : AppRadius.xsAll,
      ),
      child: Text(
        '$percentage% OFF',
        style: AppText.overline(color: AppColors.onDiscount),
      ),
    );
  }
}
