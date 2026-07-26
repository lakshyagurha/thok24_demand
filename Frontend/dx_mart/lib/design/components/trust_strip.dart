import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_radius.dart';
import '../app_space.dart';
import '../app_type.dart';

/// The three reasons to trust a shop you have not bought from before.
///
/// Lifted from Meesho, which does this better than anything else in the
/// reference set: a first-time buyer in a tier-3 town is not weighing our
/// design, they are weighing whether the money is safe. Three short promises
/// directly under the search bar answer that before the first scroll.
///
/// Every claim here must be one we actually keep — COD is the launch payment
/// method, and the return policy already ships in the app.
class TrustStrip extends StatelessWidget {
  const TrustStrip({super.key, required this.items});

  final List<TrustItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: AppSpace.symmetric(horizontal: AppSpace.gutter),
      padding: AppSpace.symmetric(vertical: AppSpace.md, horizontal: AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: AppSpace.h(28),
                color: AppColors.border,
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(items[i].icon, size: 20, color: items[i].tint),
                  SizedBox(height: AppSpace.h(6)),
                  Text(
                    items[i].label,
                    textAlign: TextAlign.center,
                    style: AppText.labelS(color: AppColors.textSecondary),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TrustItem {
  const TrustItem({required this.icon, required this.label, required this.tint});

  final IconData icon;
  final String label;
  final Color tint;
}
