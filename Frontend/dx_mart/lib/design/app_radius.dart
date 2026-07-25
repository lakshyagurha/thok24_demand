import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The corner-radius scale.
///
/// The app previously used 18 distinct radii — 3, 4, 5, 6, 7, 8, 9, 10, 12, 16,
/// 18, 20, 22, 24, 25, 30, 50, 100 — sometimes three of them inside a single
/// card. Several "circular" controls were built as `circular(100)` on a
/// non-square box, which produces a stadium, not a circle: the search and
/// wishlist back buttons were 25×28 ellipses with the glyph hand-nudged by
/// `EdgeInsets.only(left: 7.w)` to fake optical centring.
///
/// Five steps. Use [circle] for round things rather than a large radius on a
/// box you hope is square.
class AppRadius {
  const AppRadius._();

  /// Badges, small chips, discount tags.
  static const double xs = 6;

  /// Buttons, inputs, segmented controls.
  static const double sm = 8;

  /// Cards, tiles, images.
  static const double md = 12;

  /// Bottom sheets, dialogs, large feature cards.
  static const double lg = 16;

  /// Fully rounded — pills and stadium buttons.
  static const double pill = 999;

  static BorderRadius get xsAll => BorderRadius.circular(xs.r);
  static BorderRadius get smAll => BorderRadius.circular(sm.r);
  static BorderRadius get mdAll => BorderRadius.circular(md.r);
  static BorderRadius get lgAll => BorderRadius.circular(lg.r);
  static BorderRadius get pillAll => BorderRadius.circular(pill);

  /// Rounded on the top edge only — bottom sheets.
  static BorderRadius get sheet => BorderRadius.vertical(top: Radius.circular(lg.r));

  /// A genuinely circular clip, for use with an explicitly square box.
  static const BoxShape circle = BoxShape.circle;

  static BorderRadius all(double step) => BorderRadius.circular(step.r);
}
