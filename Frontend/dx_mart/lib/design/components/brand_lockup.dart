import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../app_space.dart';
import '../app_type.dart';
import '../brand_palette.dart';

/// The DxMart wordmark.
///
/// Two-tone, following the logo itself: green mark, warm wordmark. Amber is the
/// **700** step rather than the base — `#F5A524` measures under 2:1 on a light
/// surface, which is fine for a badge fill and not for type.
///
/// Extracted because the app had no brand presence anywhere after the splash
/// screen, and the fix is only worth anything if the same lockup appears on
/// every screen that needs one.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.size = BrandLockupSize.md,
    this.withMark = false,
    this.onDark = false,
  });

  final BrandLockupSize size;

  /// Show the cart mark above the wordmark. For splash and auth, where the app
  /// is introducing itself rather than labelling a screen.
  final bool withMark;

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final style = switch (size) {
      BrandLockupSize.sm => AppText.h2,
      BrandLockupSize.md => AppText.h1,
      BrandLockupSize.lg => AppText.display,
    };

    final markSize = switch (size) {
      BrandLockupSize.sm => 40.w,
      BrandLockupSize.md => 64.w,
      BrandLockupSize.lg => 96.w,
    };

    final wordmark = RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Dx',
            style: style(
              color: onDark ? BrandPalette.white : BrandPalette.green700,
            ),
          ),
          TextSpan(
            text: 'Mart',
            style: style(
              color: onDark ? BrandPalette.amber300 : BrandPalette.amber700,
            ),
          ),
        ],
      ),
    );

    if (!withMark) return wordmark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: markSize * 2.4,
          height: markSize,
          fit: BoxFit.contain,
        ),
        AppSpace.gapH(AppSpace.sm),
      ],
    );
  }
}

enum BrandLockupSize { sm, md, lg }
