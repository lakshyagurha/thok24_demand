import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The spacing scale.
///
/// The app previously used ~24 distinct gap values — 1, 3, 5, 6, 7, 9, 13, 15,
/// 17, 25 all appeared alongside 4/8/12/16/24, and the page gutter was 12, 14,
/// 16 or 20 depending on which screen you were on. Nothing lined up across
/// screens because nothing was ever the same number twice.
///
/// This is a 4pt scale. If a design needs a value that is not here, the design
/// is wrong, not the scale.
///
/// ## Axis discipline
///
/// `flutter_screenutil` scales width and height independently. The old code
/// declared vertical spacing with the *width* factor in ~25 places (18 of them
/// in `profileScreen.dart` alone), so vertical rhythm drifted from horizontal
/// on any device whose aspect ratio differed from the 360×690 baseline.
///
/// Use [h] for vertical gaps, [w] for horizontal gaps, and the [gapH]/[gapW]
/// helpers where a `SizedBox` is wanted — they pick the correct axis for you.
class AppSpace {
  const AppSpace._();

  // Raw scale steps, in design pixels at the 360×690 baseline.
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;

  /// The one horizontal page gutter. Every screen, every list, every card row.
  static const double gutter = base;

  /// Scaled for a vertical measurement.
  static double h(double step) => step.h;

  /// Scaled for a horizontal measurement.
  static double w(double step) => step.w;

  /// A vertical gap. `AppSpace.gapH(AppSpace.base)`.
  static Widget gapH(double step) => SizedBox(height: step.h);

  /// A horizontal gap. `AppSpace.gapW(AppSpace.sm)`.
  static Widget gapW(double step) => SizedBox(width: step.w);

  // ---------------------------------------------------------------------------
  // Ready-made insets
  // ---------------------------------------------------------------------------

  /// Standard horizontal page padding.
  static EdgeInsets get page => EdgeInsets.symmetric(horizontal: gutter.w);

  /// Padding inside a card.
  static EdgeInsets get card =>
      EdgeInsets.symmetric(horizontal: base.w, vertical: base.h);

  /// Padding inside a compact card or list row.
  static EdgeInsets get cardCompact =>
      EdgeInsets.symmetric(horizontal: md.w, vertical: md.h);

  /// Symmetric inset from the scale.
  static EdgeInsets all(double step) =>
      EdgeInsets.symmetric(horizontal: step.w, vertical: step.h);

  static EdgeInsets symmetric({double horizontal = 0, double vertical = 0}) =>
      EdgeInsets.symmetric(horizontal: horizontal.w, vertical: vertical.h);

  static EdgeInsets only({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) =>
      EdgeInsets.only(
        left: left.w,
        top: top.h,
        right: right.w,
        bottom: bottom.h,
      );

  // ---------------------------------------------------------------------------
  // Layout constants
  // ---------------------------------------------------------------------------

  /// Minimum interactive target. Material's floor is 48dp; 44 is the practical
  /// minimum and what we hold icon-only controls to. The old wishlist heart was
  /// a bare 14dp glyph and the cart stepper's +/- was about 30×28.
  static const double minTapTarget = 44;

  /// Height of a standard primary button. Previously 27, 34, 38, 39, 45 and 48
  /// were all in use for the same control.
  static const double buttonHeight = 48;
  static const double buttonHeightCompact = 36;

  /// Height of a screen header, excluding the status bar inset.
  static const double headerHeight = 56;

  /// Bottom inset a scroll view must reserve when the docked cart bar is
  /// visible, so content is never hidden beneath it.
  static const double cartBarReserve = 88;
}
