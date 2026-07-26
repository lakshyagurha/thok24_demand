import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../CustomWidgets/product_image.dart';
import '../app_colors.dart';
import '../app_gradients.dart';
import '../app_radius.dart';
import '../app_space.dart';
import '../app_type.dart';

/// The horizontal category selector that sits under the hero.
///
/// Every serious grocery app in this market has one — Zepto, BigBasket, DMart
/// Ready and Flipkart Grocery all put a scrollable category rail immediately
/// below the search bar, because it is the fastest route from "I opened the
/// app" to "I am looking at food".
///
/// Each entry carries its real product photo rather than an icon. That is the
/// BigBasket execution and it is right here: a shopper recognises the Red Label
/// pack faster than they read "Tea, Coffee & More", which matters when half the
/// audience is reading their second language.
///
/// ## What changed after seeing it on a device
///
/// The first version pinned to the very top of the viewport with no safe-area
/// inset, so once the hero scrolled away the clock and signal icons sat on top
/// of the thumbnails. It also had no edge of its own — a white row against a
/// near-white page, floating with nothing to separate it from the content it
/// was overlapping. Both are fixed: the host paints the status-bar strip, and
/// the bar carries a hairline so it reads as a surface above the content rather
/// than a gap in it.
class CategoryBar extends StatelessWidget {
  const CategoryBar({
    super.key,
    required this.items,
    required this.onSelected,
    this.onViewAll,
    this.selectedId,
  });

  final List<CategoryBarItem> items;
  final ValueChanged<CategoryBarItem> onSelected;

  /// Trailing "All" tile. Home no longer carries a separate category grid — the
  /// bar and that grid were the same twelve categories rendered twice a few
  /// hundred pixels apart — so this is the way through to the full list.
  final VoidCallback? onViewAll;

  final int? selectedId;

  static const double _tile = 58;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.symmetric(vertical: AppSpace.h(AppSpace.md)),
      child: SizedBox(
        height: 92.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: AppSpace.symmetric(horizontal: AppSpace.gutter),
          itemCount: items.length + (onViewAll != null ? 1 : 0),
          separatorBuilder: (_, _) => AppSpace.gapW(AppSpace.base),
          itemBuilder: (context, i) {
            if (i == items.length) return _viewAllTile();
            final item = items[i];
            return _tileFor(item, item.id == selectedId);
          },
        ),
      ),
    );
  }

  Widget _tileFor(CategoryBarItem item, bool selected) {
    return InkWell(
      onTap: () => onSelected(item),
      borderRadius: AppRadius.mdAll,
      child: SizedBox(
        width: 66.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Filled edge to edge: the catalogue artwork carries its own cream
            // background, which inside a padded tile reads as a stray yellow
            // square rather than as the tile itself.
            Container(
              width: _tile.w,
              height: _tile.w,
              decoration: BoxDecoration(
                gradient: selected ? null : AppGradients.tile,
                color: selected ? AppColors.primarySurface : null,
                borderRadius: AppRadius.mdAll,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: AppRadius.mdAll,
                child: ProductImage(
                  path: item.image,
                  width: _tile.w,
                  height: _tile.w,
                  fit: BoxFit.cover,
                  errorIcon: Icons.category_outlined,
                ),
              ),
            ),
            AppSpace.gapH(AppSpace.xs),
            Expanded(
              child: Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: selected
                    ? AppText.overline(color: AppColors.primary)
                    : AppText.caption(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewAllTile() {
    return InkWell(
      onTap: onViewAll,
      borderRadius: AppRadius.mdAll,
      child: SizedBox(
        width: 66.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _tile.w,
              height: _tile.w,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                size: 22,
                color: AppColors.primary,
              ),
            ),
            AppSpace.gapH(AppSpace.xs),
            Expanded(
              child: Text(
                'All',
                textAlign: TextAlign.center,
                style: AppText.overline(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryBarItem {
  const CategoryBarItem({
    required this.id,
    required this.label,
    required this.image,
  });

  final int id;
  final String label;
  final String? image;
}
