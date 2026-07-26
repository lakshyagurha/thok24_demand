import 'package:flutter/widgets.dart';

import 'brand_palette.dart';

/// Gradients.
///
/// Flat fills of a dark brand colour read as heavy and, at large sizes, cheap —
/// a solid navy hero swamped the page. The apps this category is measured
/// against (Zepto, Blinkit, BigBasket) all do the same two things instead:
///
///  1. **The big surface is a light tint of the brand, not the brand at full
///     strength.** The hero is a pale wash that fades into the page, so the
///     page feels open and the content — not the chrome — carries the colour.
///  2. **Small surfaces get a gradient rather than a flat fill**, which is what
///     stops a coloured card looking like a rectangle of paint.
///
/// So: [heroSoft] for the big areas, and the saturated gradients for the small
/// ones that need to pop against them.
class AppGradients {
  const AppGradients._();

  /// The home hero. A pale brand mint that dissolves into the page background,
  /// so the header has presence without becoming a wall.
  static const LinearGradient heroSoft = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFC7E9D5),
      Color(0xFFE4F3EA),
      BrandPalette.neutral50,
    ],
    stops: [0.0, 0.55, 1.0],
  );

  /// A softer wash for secondary screens — category browse, search — that
  /// should feel related to home without repeating it.
  static const LinearGradient surfaceSoft = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      BrandPalette.green50,
      BrandPalette.neutral50,
    ],
  );

  /// Primary action / brand card.
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3C8A52), BrandPalette.green600],
  );

  /// The secondary navy, kept for small blocks where it earns contrast rather
  /// than as a full-bleed surface.
  static const LinearGradient secondary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF33608A), BrandPalette.navy700],
  );

  /// Discounts and savings.
  static const LinearGradient warm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF9B84A), Color(0xFFDE8E05)],
  );

  /// A neutral tile wash, used behind catalogue photography whose own
  /// background is an off-white or cream. A pure white tile leaves those photos
  /// sitting in a visible box; a warm-neutral tile absorbs them.
  static const LinearGradient tile = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFDF7), Color(0xFFF4F7F5)],
  );
}
