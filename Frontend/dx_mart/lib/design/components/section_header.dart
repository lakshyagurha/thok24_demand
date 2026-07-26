import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_radius.dart';
import '../app_space.dart';
import '../app_type.dart';

/// A section title with an optional subtitle and an optional "see all".
///
/// The app's four home sections were previously `16.sp bold` `Text` widgets
/// with no rule, no eyebrow, no affordance and no top padding — their spacing
/// came from a `SizedBox` at the call site, so each header sat closer to the
/// content below it than to the rail above. They did not read as headers.
///
/// The accent bar on the left is what makes this scan as a section rather than
/// as a bold sentence, and the trailing chevron gives the section somewhere to
/// go — the reference apps that do this best (Flipkart Grocery, BigBasket) all
/// pair a title with a subtitle and a visible way in.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.seeAllLabel = 'See all',
    this.accent = AppColors.primary,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final String seeAllLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.w(AppSpace.gutter),
        AppSpace.h(AppSpace.xl),
        AppSpace.w(AppSpace.gutter),
        AppSpace.h(AppSpace.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: AppSpace.w(4),
            height: AppSpace.h(20),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: AppRadius.all(2),
            ),
          ),
          AppSpace.gapW(AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.h2(), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  SizedBox(height: AppSpace.h(2)),
                  Text(
                    subtitle!,
                    style: AppText.caption(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            InkWell(
              onTap: onSeeAll,
              borderRadius: AppRadius.pillAll,
              child: Padding(
                padding: AppSpace.symmetric(
                  horizontal: AppSpace.md,
                  vertical: AppSpace.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(seeAllLabel, style: AppText.label(color: AppColors.primary)),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
