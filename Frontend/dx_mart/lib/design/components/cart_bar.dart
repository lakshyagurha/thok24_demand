import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_elevation.dart';
import '../app_radius.dart';
import '../app_space.dart';
import '../app_type.dart';

/// The one cart bar.
///
/// This widget replaces four copy-pasted "View Cart" pills — in
/// `search_product`, `similar_product`, `wishlist_screen` and
/// `product_details_screen` — which had diverged in every single property:
/// label colour (black in three of them, on a dark green fill, about 3.2:1),
/// badge size, badge text style, chevron size and bottom offset.
///
/// Two structural fixes over the pills it replaces:
///
///  * **It is docked, not floating.** The old pills were `Positioned` over the
///    content, so on home they covered the product row beneath them and on the
///    product page they sat on top of the variant selector. Callers put this in
///    `bottomNavigationBar`, or reserve [AppSpace.cartBarReserve] at the foot of
///    their scroll view, so it always has its own space.
///  * **It is not a fixed 200dp.** The pills were pinned `left: 80.w, right:
///    80.w` regardless of what the label said, which is why the product page
///    rendered the truncated string "View ...".
///
/// [savings] is shown when there is something to show. DMart Ready puts the
/// saved figure next to the total and it is the strongest conversion element in
/// the whole reference set — and this app already computes the number, it just
/// never displayed it here.
class CartBar extends StatelessWidget {
  const CartBar({
    super.key,
    required this.itemCount,
    required this.onTap,
    this.total,
    this.savings,
    this.label = 'View Cart',
  });

  final int itemCount;
  final VoidCallback onTap;
  final double? total;
  final double? savings;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) return const SizedBox.shrink();

    final hasSavings = savings != null && savings! > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppElevation.raisedUp,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: AppSpace.symmetric(
            horizontal: AppSpace.gutter,
            vertical: AppSpace.md,
          ),
          child: Material(
            color: AppColors.primary,
            borderRadius: AppRadius.mdAll,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: AppSpace.symmetric(
                  horizontal: AppSpace.base,
                  vertical: AppSpace.md,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: AppSpace.symmetric(
                        horizontal: AppSpace.sm,
                        vertical: AppSpace.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.overlayOnPrimary,
                        borderRadius: AppRadius.xsAll,
                      ),
                      child: Text(
                        '$itemCount',
                        style: AppText.label(color: AppColors.onPrimary),
                      ),
                    ),
                    AppSpace.gapW(AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            total != null
                                ? '₹${total!.toStringAsFixed(0)}'
                                : '$itemCount ${itemCount == 1 ? "item" : "items"}',
                            style: AppText.priceL(color: AppColors.onPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasSavings)
                            Text(
                              'You save ₹${savings!.toStringAsFixed(0)}',
                              style: AppText.caption(color: AppColors.onPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    AppSpace.gapW(AppSpace.sm),
                    Flexible(
                      child: Text(
                        label,
                        style: AppText.button(color: AppColors.onPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: AppColors.onPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
