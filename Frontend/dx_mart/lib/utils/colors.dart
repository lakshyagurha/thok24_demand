import 'package:flutter/material.dart';

import '../design/brand_palette.dart';

/// **Deprecated compatibility shim. Do not add to this file.**
///
/// New code imports `design/app_colors.dart` and uses semantic roles
/// (`AppColors.primary`, `AppColors.textSecondary`, …).
///
/// This class survives only because ~525 references to it are spread across
/// screens that have not been migrated yet. Every member below is now an alias
/// onto [BrandPalette], so the brand colours supplied on 2026-07-26
/// (`#2E6F40` primary, `#24425E` secondary) take effect across the entire app
/// immediately, without editing forty screens at once. Screens migrate off this
/// file one at a time, and it is deleted when the last one does.
///
/// ## Two things this shim deliberately does *not* fix
///
/// 1. [primaryTextColor] and [iconColor] were both literally `#000000`, and a
///    dozen screens use them as the foreground **on the green brand colour** —
///    roughly 3.2:1, well under the 4.5:1 floor. Repointing them here cannot fix
///    that, because the same two tokens are also used as ordinary text on white,
///    where they are correct. Those call sites need `AppColors.onPrimary`, which
///    is a per-screen change.
///
/// 2. The duplicate pairs below (`lineColor` == `borderColor`, `gray` ==
///    `neutral50`, `DisountPriceColor` == `hintTextColor`, `searchBorderHome` ==
///    `primaryColor`) are preserved as duplicates on purpose. Collapsing them
///    here would change which screens compile; they disappear with the file.
class AppColors {
  // Base
  static const Color backgroundColor = BrandPalette.white;
  static const Color primaryColor = BrandPalette.green500;

  /// Was the accent yellow that no screen ever referenced; now the derived
  /// amber that carries discounts and savings.
  static const Color secondaryColor = BrandPalette.amber500;

  /// The brand secondary navy. Newly available to unmigrated screens.
  static const Color navyColor = BrandPalette.navy700;

  // Text
  static const Color primaryTextColor = BrandPalette.neutral900;
  static const Color secondaryTextColor = BrandPalette.white;

  // UI accents
  static const Color ratingColor = BrandPalette.amber500;
  static const Color iconColor = BrandPalette.neutral700;
  static const Color hintTextColor = BrandPalette.neutral500;
  static const Color borderColor = BrandPalette.neutral200;
  static const Color gray = BrandPalette.neutral50;

  // Legacy aliases
  static const Color searchBorderHome = BrandPalette.green500;
  static const Color errorColor = BrandPalette.dangerBase;
  static const Color DisountPriceColor = BrandPalette.neutral500;
  static const Color lineColor = BrandPalette.neutral200;
  static const Color successColor = BrandPalette.successBase;
  static const Color warningColor = BrandPalette.warningBase;

  // Primary ramp
  static const Color primary50 = BrandPalette.green50;
  static const Color primary100 = BrandPalette.green100;
  static const Color primary200 = BrandPalette.green200;
  static const Color primary300 = BrandPalette.green300;
  static const Color primary400 = BrandPalette.green400;
  static const Color primary500 = BrandPalette.green500;
  static const Color primary600 = BrandPalette.green600;
  static const Color primary700 = BrandPalette.green700;
  static const Color primary800 = BrandPalette.green800;
  static const Color primary900 = BrandPalette.green900;

  // Neutral ramp
  static const Color neutral50 = BrandPalette.neutral50;
  static const Color neutral100 = BrandPalette.neutral100;
  static const Color neutral200 = BrandPalette.neutral200;
  static const Color neutral300 = BrandPalette.neutral300;
  static const Color neutral400 = BrandPalette.neutral400;
  static const Color neutral500 = BrandPalette.neutral500;
  static const Color neutral600 = BrandPalette.neutral600;
  static const Color neutral700 = BrandPalette.neutral700;
  static const Color neutral800 = BrandPalette.neutral800;
  static const Color neutral900 = BrandPalette.neutral900;

  // Status
  static const Color success50 = BrandPalette.successSurface;
  static const Color success100 = BrandPalette.successBorder;
  static const Color success500 = BrandPalette.successBase;

  static const Color error50 = BrandPalette.dangerSurface;
  static const Color error100 = BrandPalette.dangerBorder;
  static const Color error500 = BrandPalette.dangerBase;

  static const Color warning50 = BrandPalette.warningSurface;
  static const Color warning100 = BrandPalette.warningBorder;
  static const Color warning500 = BrandPalette.warningBase;
}
