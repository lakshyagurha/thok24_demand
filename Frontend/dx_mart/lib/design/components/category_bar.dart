import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../CustomWidgets/product_image.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_space.dart';
import '../app_type.dart';

/// A horizontal category selector that sits directly under the header.
///
/// Every serious grocery app in this market has one — Zepto, BigBasket, DMart
/// Ready and Flipkart Grocery all put a scrollable category rail immediately
/// below the search bar, because it is the fastest route from "I opened the
/// app" to "I am looking at food". DxMart had nothing of the kind: the only way
/// into a category was to scroll past the banner to a grid that was silently
/// capped at eight, or to leave home entirely for the Category tab.
///
/// Each entry carries its real product photo rather than an icon. That is the
/// BigBasket execution and it is the right one here — a shopper recognises the
/// Red Label pack far faster than they read the words "Tea, Coffee & More",
/// which matters when half the audience is reading their second language.
class CategoryBar extends StatelessWidget {
  const CategoryBar({
    super.key,
    required this.items,
    required this.onSelected,
    this.selectedId,
  });

  final List<CategoryBarItem> items;
  final ValueChanged<CategoryBarItem> onSelected;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.only(top: AppSpace.h(AppSpace.md), bottom: AppSpace.h(AppSpace.sm)),
      child: SizedBox(
        height: 92.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: AppSpace.symmetric(horizontal: AppSpace.gutter),
          itemCount: items.length,
          separatorBuilder: (_, __) => AppSpace.gapW(AppSpace.md),
          itemBuilder: (context, i) {
            final item = items[i];
            final selected = item.id == selectedId;

            return InkWell(
              onTap: () => onSelected(item),
              borderRadius: AppRadius.mdAll,
              child: SizedBox(
                width: 64.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56.w,
                      height: 56.w,
                      padding: EdgeInsets.all(AppSpace.w(6)),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primarySurface
                            : AppColors.surfaceSunken,
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(
                          color: selected ? AppColors.primary : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ProductImage(
                        path: item.image,
                        width: 44.w,
                        height: 44.w,
                        errorIcon: Icons.category_outlined,
                      ),
                    ),
                    SizedBox(height: AppSpace.h(6)),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: selected
                          ? AppText.labelS(color: AppColors.primary)
                          : AppText.caption(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          },
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
