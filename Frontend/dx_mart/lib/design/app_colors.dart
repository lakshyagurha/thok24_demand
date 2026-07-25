import 'package:flutter/material.dart';

import 'brand_palette.dart';

/// Semantic colour roles. **Screens reference only this class.**
///
/// Every name describes a *job* ("the ink that goes on a primary button")
/// rather than a hue, so a re-brand is a change in [BrandPalette] and nothing
/// else.
///
/// ## Three rules this file exists to enforce
///
/// 1. **[onPrimary] and [onSecondary] are always white.** The old palette
///    exposed `iconColor` and `primaryTextColor`, both literally `#000000`, and
///    a dozen screens used them as the foreground *on the green brand colour* —
///    about 3.2:1, well under the 4.5:1 floor. There is deliberately no
///    "black on primary" token here, so that bug cannot be re-expressed.
///
/// 2. **One neutral ramp.** The app previously mixed a cool `neutral*` scale
///    with Material's warmer `Colors.grey.*` (414 uses) for identical roles.
///
/// 3. **One discount treatment.** The app had four — blue text, a yellow corner
///    tab that rendered even at 0%, a peach pill, and a green ribbon. There is
///    now exactly one pair: [discount] / [onDiscount].
class AppColors {
  const AppColors._();

  // ---------------------------------------------------------------------------
  // Primary — green. Actions, active navigation, selection.
  // ---------------------------------------------------------------------------

  static const Color primary = BrandPalette.green500;
  static const Color primaryPressed = BrandPalette.green600;

  /// A tint that reads as "primary" without being a button: selected rows,
  /// icon chips, the active category rail item.
  static const Color primarySurface = BrandPalette.green50;
  static const Color primaryBorder = BrandPalette.green200;

  /// Ink on [primary]. White, always — 6.1:1. See rule 1.
  static const Color onPrimary = BrandPalette.white;

  // ---------------------------------------------------------------------------
  // Secondary — navy. Dark surfaces, headers, structural emphasis.
  // ---------------------------------------------------------------------------

  static const Color secondary = BrandPalette.navy700;
  static const Color secondaryPressed = BrandPalette.navy800;
  static const Color secondarySurface = BrandPalette.navy50;
  static const Color secondaryBorder = BrandPalette.navy200;

  /// Ink on [secondary]. White — 10.5:1.
  static const Color onSecondary = BrandPalette.white;

  /// A full dark surface: the home hero band, a night-mode header, the splash.
  ///
  /// Worth using deliberately. Every competitor in this category is pastel; a
  /// navy hero is the cheapest available point of difference and it costs
  /// nothing in legibility.
  static const Color surfaceDark = BrandPalette.navy700;
  static const Color surfaceDarker = BrandPalette.navy900;
  static const Color onSurfaceDark = BrandPalette.white;

  /// Muted ink on a dark surface — subtitles inside the hero band.
  static const Color onSurfaceDarkMuted = BrandPalette.navy200;

  // ---------------------------------------------------------------------------
  // Discount & savings — the derived amber
  // ---------------------------------------------------------------------------

  /// The one discount highlight. Navy-black on amber measures 8.0:1, so a
  /// 10sp badge survives at thumbnail size.
  static const Color discount = BrandPalette.amber500;
  static const Color onDiscount = BrandPalette.navy900;

  /// A quieter amber wash, for "you saved" strips where a solid block shouts.
  static const Color discountSurface = BrandPalette.amber50;
  static const Color discountBorder = BrandPalette.amber100;
  static const Color discountText = BrandPalette.amber700;

  /// Savings confirmation in bills and cart bars — green, because at that point
  /// it is a result rather than an offer.
  static const Color savingsSurface = BrandPalette.successSurface;
  static const Color savingsText = BrandPalette.successBase;

  // ---------------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------------

  /// The page behind everything.
  static const Color background = BrandPalette.neutral50;

  /// Cards, sheets, bars — anything that should lift off [background].
  ///
  /// Deliberately a different value from [background]. Previously cards were
  /// white on white-backed screens with no border and no shadow, so they had no
  /// figure–ground separation at all.
  static const Color surface = BrandPalette.white;

  /// A recessed surface: image wells, skeletons, disabled fills.
  static const Color surfaceSunken = BrandPalette.neutral100;

  static const Color border = BrandPalette.neutral200;
  static const Color borderStrong = BrandPalette.neutral300;

  static Color get scrim => BrandPalette.navy900.withValues(alpha: 0.55);

  // ---------------------------------------------------------------------------
  // Text & icons
  // ---------------------------------------------------------------------------

  /// Primary reading text. Not pure black: `#121A24` carries a trace of the
  /// secondary's hue so body copy sits with the navy instead of fighting it.
  /// Still 17.7:1 on white.
  static const Color textPrimary = BrandPalette.neutral900;

  /// Subtitles and metadata.
  static const Color textSecondary = BrandPalette.neutral600;

  /// De-emphasised: pack sizes, MRP, captions, placeholders. 4.75:1 on white.
  static const Color textTertiary = BrandPalette.neutral500;

  static const Color textInverse = BrandPalette.white;
  static const Color textDisabled = BrandPalette.neutral400;

  /// Text that carries brand weight without being a button — section eyebrows,
  /// the wordmark lockup.
  static const Color textBrand = BrandPalette.green600;

  static const Color icon = BrandPalette.neutral700;
  static const Color iconMuted = BrandPalette.neutral400;
  static const Color iconInverse = BrandPalette.white;

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  static const Color success = BrandPalette.successBase;
  static const Color successSurface = BrandPalette.successSurface;
  static const Color successBorder = BrandPalette.successBorder;

  static const Color warning = BrandPalette.warningBase;
  static const Color warningSurface = BrandPalette.warningSurface;
  static const Color warningBorder = BrandPalette.warningBorder;

  static const Color danger = BrandPalette.dangerBase;
  static const Color dangerSurface = BrandPalette.dangerSurface;
  static const Color dangerBorder = BrandPalette.dangerBorder;

  static const Color info = BrandPalette.infoBase;
  static const Color infoSurface = BrandPalette.infoSurface;
  static const Color infoBorder = BrandPalette.infoBorder;

  /// Ink on any `*Surface` status block above.
  static const Color onStatusSurface = BrandPalette.neutral900;

  // ---------------------------------------------------------------------------
  // Control states
  // ---------------------------------------------------------------------------

  /// A disabled fill. Previously raw `Colors.grey`, which read as "broken"
  /// rather than "not yet".
  static const Color disabledSurface = BrandPalette.neutral200;
  static const Color onDisabled = BrandPalette.neutral500;

  static Color get overlayOnPrimary =>
      BrandPalette.white.withValues(alpha: 0.16);

  static Color get overlayOnSurface =>
      BrandPalette.neutral900.withValues(alpha: 0.06);
}
