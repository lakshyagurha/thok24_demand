import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_colors.dart';

/// The type scale, in Mukta.
///
/// ## Why Mukta
///
/// The app rendered everything in Poppins, which has **no Devanagari glyphs at
/// all**. Every Hindi string therefore fell back to whatever the device
/// happened to supply — a different typeface on every handset, and a visible
/// break between the two languages on any screen that mixed them. For a
/// Hindi-first product that is an identity failure, not a nitpick.
///
/// Mukta is one superfamily covering Latin *and* Devanagari, drawn together, so
/// `Fortune Kachi Ghani` and `फॉर्च्यून कच्ची घानी` share a voice. It also has a
/// tall x-height, which is what keeps 11–13sp label text legible on the cheap,
/// low-density screens this app is actually used on.
///
/// ## Why the line heights look generous
///
/// Devanagari stacks matras above *and* below the baseline, so a `height` tuned
/// for Latin clips them. Body styles here sit at 1.45–1.5 rather than the
/// 1.2–1.35 the old `AppTextStyles` used. This costs a little vertical space and
/// is the difference between Hindi rendering correctly and Hindi rendering
/// chopped.
///
/// ## Scale discipline
///
/// The app previously used **22 distinct font sizes** including 7, 7.5, 8, 8.5,
/// 9, 9.5, 10.5, 11.5, 12.5 and 13.5 — half-point steps that no one chose on
/// purpose — against a token file that was referenced **three times** in the
/// entire codebase while 344 raw `TextStyle(...)` objects were built inline.
///
/// This is 16 named roles with a hard floor of **10sp**. Weights are restricted
/// to w400/w500/w600/w700; `w800`, `w900` and the `bold`-vs-`w700` double
/// spelling are gone.
class AppText {
  const AppText._();

  /// Line height for running text. Sized for Devanagari, see above.
  static const double _bodyLeading = 1.5;
  static const double _tightLeading = 1.3;
  static const double _headingLeading = 1.25;

  /// The bundled family name, as declared in `pubspec.yaml`.
  ///
  /// Deliberately not `GoogleFonts.mukta()`: that package fetches the font from
  /// a CDN on first use, so a shopper opening the app for the first time on a
  /// weak connection would see fallback type on the one screen that has to make
  /// a first impression. The TTFs ship in `assets/fonts/`.
  static const String family = 'Mukta';

  static TextStyle _base({
    required double size,
    required FontWeight weight,
    required double height,
    Color? color,
    double? letterSpacing,
    TextDecoration? decoration,
  }) =>
      TextStyle(
        fontFamily: family,
        fontSize: size.sp,
        fontWeight: weight,
        height: height,
        color: color ?? AppColors.textPrimary,
        letterSpacing: letterSpacing,
        decoration: decoration,
      );

  // ---------------------------------------------------------------------------
  // Headings
  // ---------------------------------------------------------------------------

  /// Hero numerals: the cart total, the delivery promise.
  static TextStyle display({Color? color}) =>
      _base(size: 26, weight: FontWeight.w700, height: 1.15, color: color);

  /// Screen titles.
  static TextStyle h1({Color? color}) =>
      _base(size: 20, weight: FontWeight.w700, height: _headingLeading, color: color);

  /// Section headers. Previously this rank was rendered at 16, 17, 18 *and* 20
  /// on four different screens, in two different typefaces.
  static TextStyle h2({Color? color}) =>
      _base(size: 17, weight: FontWeight.w700, height: _headingLeading, color: color);

  /// Card titles and product names.
  static TextStyle h3({Color? color}) =>
      _base(size: 15, weight: FontWeight.w600, height: _tightLeading, color: color);

  // ---------------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------------

  static TextStyle bodyL({Color? color}) =>
      _base(size: 15, weight: FontWeight.w400, height: _bodyLeading, color: color);

  /// The default. If you are unsure, this one.
  static TextStyle bodyM({Color? color}) =>
      _base(size: 13, weight: FontWeight.w400, height: _bodyLeading, color: color);

  static TextStyle bodyS({Color? color}) =>
      _base(size: 12, weight: FontWeight.w400, height: 1.45, color: color);

  // ---------------------------------------------------------------------------
  // Labels
  // ---------------------------------------------------------------------------

  static TextStyle label({Color? color}) =>
      _base(size: 12, weight: FontWeight.w600, height: _tightLeading, color: color);

  static TextStyle labelS({Color? color}) =>
      _base(size: 11, weight: FontWeight.w600, height: _tightLeading, color: color);

  static TextStyle caption({Color? color}) => _base(
        size: 11,
        weight: FontWeight.w400,
        height: _tightLeading,
        color: color ?? AppColors.textTertiary,
      );

  /// Badges and eyebrows. The floor of the scale.
  static TextStyle overline({Color? color}) => _base(
        size: 10,
        weight: FontWeight.w700,
        height: 1.2,
        color: color,
        letterSpacing: 0.4,
      );

  /// Button text. Sized to sit on a 48dp control without crowding it.
  static TextStyle button({Color? color}) => _base(
        size: 15,
        weight: FontWeight.w700,
        height: 1.2,
        color: color ?? AppColors.onPrimary,
      );

  static TextStyle buttonCompact({Color? color}) => _base(
        size: 13,
        weight: FontWeight.w700,
        height: 1.2,
        color: color ?? AppColors.onPrimary,
      );

  // ---------------------------------------------------------------------------
  // Price
  // ---------------------------------------------------------------------------
  //
  // Price had six divergent treatments across the app, and the emphasis on the
  // grand total actually *decreased* as the customer got closer to paying:
  // 17sp in the cart, 16sp at checkout, 14sp on the summary. These four roles
  // replace all of it, and the hierarchy now runs the right way.

  /// Product detail.
  static TextStyle priceHero({Color? color}) =>
      _base(size: 22, weight: FontWeight.w700, height: 1.15, color: color);

  /// Cart lines and sticky bars.
  static TextStyle priceL({Color? color}) =>
      _base(size: 16, weight: FontWeight.w700, height: 1.2, color: color);

  /// Product cards.
  static TextStyle priceM({Color? color}) =>
      _base(size: 14, weight: FontWeight.w700, height: 1.2, color: color);

  /// The struck-through MRP. Never competes with the live price.
  static TextStyle mrp({Color? color}) => _base(
        size: 12,
        weight: FontWeight.w400,
        height: 1.2,
        color: color ?? AppColors.textTertiary,
        decoration: TextDecoration.lineThrough,
      );

  /// The discount figure.
  static TextStyle discount({Color? color}) => _base(
        size: 11,
        weight: FontWeight.w700,
        height: 1.2,
        color: color ?? AppColors.onDiscount,
      );

  // ---------------------------------------------------------------------------
  // Material integration
  // ---------------------------------------------------------------------------

  /// Mukta mapped onto Material's `TextTheme`, so any widget we do not style
  /// explicitly still inherits the right family rather than falling back to
  /// Roboto.
  ///
  /// This is what carries the new typeface across the ~344 screens that build
  /// bare `TextStyle(fontSize: …)` objects without naming a family: they merge
  /// against `DefaultTextStyle`, which resolves from here.
  static TextTheme textTheme(TextTheme base) => base.apply(
        fontFamily: family,
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      );
}
