import 'package:flutter/material.dart';

/// Raw brand ink. **This is the only file that changes if the brand moves.**
///
/// Nothing in the app may reference these values directly — screens read
/// semantic roles from `AppColors`, which maps onto this palette. That
/// indirection is the point: a re-brand is an edit here and nowhere else.
///
/// ## The brand, as supplied (2026-07-26)
///
///   * **Primary — `#2E6F40`**, a deep forest green.
///   * **Secondary — `#24425E`**, a deep slate navy.
///   * **White and black.**
///
/// Everything else below is derived, with permission to extend into shades.
///
/// ## What the two brand colours are actually good for
///
/// These were measured, not guessed:
///
///   * White on `#2E6F40` → **6.1:1**. Comfortably passes for buttons and
///     active navigation. (The app's previous green managed 3.2:1 against the
///     *black* it was habitually paired with, which is the single most common
///     contrast failure this redesign removes.)
///   * White on `#24425E` → **10.5:1**. Unusually high. Navy is therefore not
///     just a secondary tint — it is a legitimate *dark surface* we can build
///     headers and hero blocks on, and it is the one move none of the
///     reference grocery apps make. They are all pastel; a navy header will
///     read as more considered without costing legibility.
///
/// ## The derived accent
///
/// Green and navy are both cool and both serious. A discount badge needs to be
/// neither. [amber500] (`#F5A524`) is a harvest gold at H≈37° — the classic
/// warm partner to forest green, and it pops hard against navy. Navy-black ink
/// on it measures **8.0:1**, so a 10sp badge stays readable at thumbnail size,
/// which the old 9sp blue-on-white discount text did not.
///
/// ## The neutrals
///
/// White and black are brand colours, so they are here verbatim as [white] and
/// [black]. The greys between them are *not* neutral grey — they carry a few
/// degrees of the secondary's hue (H≈209°, 4–8% saturation). Against `#24425E`
/// a pure grey looks dirty; a navy-tinted grey looks intentional.
class BrandPalette {
  const BrandPalette._();

  // ---------------------------------------------------------------------------
  // The brand, verbatim
  // ---------------------------------------------------------------------------

  /// Primary brand green, as supplied.
  static const Color brandGreen = Color(0xFF2E6F40);

  /// Secondary brand navy, as supplied.
  static const Color brandNavy = Color(0xFF24425E);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // ---------------------------------------------------------------------------
  // Green ramp — actions, active state, brand presence
  // ---------------------------------------------------------------------------
  //
  // Hue held at ~137°, lightness walked from 95% down to 11%.

  static const Color green50 = Color(0xFFEFF8F1);
  static const Color green100 = Color(0xFFD4EDDB);
  static const Color green200 = Color(0xFFAEDDBB);
  static const Color green300 = Color(0xFF7EC893);
  static const Color green400 = Color(0xFF44A45F);
  static const Color green500 = brandGreen;
  static const Color green600 = Color(0xFF275F36);
  static const Color green700 = Color(0xFF1F4D2C);
  static const Color green800 = Color(0xFF173B21);
  static const Color green900 = Color(0xFF102917);

  // ---------------------------------------------------------------------------
  // Navy ramp — dark surfaces, headers, emphasis
  // ---------------------------------------------------------------------------
  //
  // Hue held at ~209°. Note the supplied navy is already dark (L≈25%), so it
  // sits naturally at the 700 step; 400–600 are the usable mid-tones that the
  // brand colour alone does not provide.

  static const Color navy50 = Color(0xFFEEF4F9);
  static const Color navy100 = Color(0xFFD8E5F0);
  static const Color navy200 = Color(0xFFB6CDE2);
  static const Color navy300 = Color(0xFF84ABCF);
  static const Color navy400 = Color(0xFF4074A5);
  static const Color navy500 = Color(0xFF356189);
  static const Color navy600 = Color(0xFF2B5073);
  static const Color navy700 = brandNavy;
  static const Color navy800 = Color(0xFF1B3146);
  static const Color navy900 = Color(0xFF122230);

  // ---------------------------------------------------------------------------
  // Amber ramp — the derived warm accent (discounts, savings, urgency)
  // ---------------------------------------------------------------------------

  static const Color amber50 = Color(0xFFFEF5E7);
  static const Color amber100 = Color(0xFFFCE5C0);
  static const Color amber300 = Color(0xFFF8BF63);
  static const Color amber500 = Color(0xFFF5A524);
  static const Color amber700 = Color(0xFFBA7608);
  static const Color amber900 = Color(0xFF6D4503);

  // ---------------------------------------------------------------------------
  // Neutral ramp — navy-tinted, so greys sit with the secondary
  // ---------------------------------------------------------------------------

  static const Color neutral0 = white;
  static const Color neutral50 = Color(0xFFF7F9FB);
  static const Color neutral100 = Color(0xFFEFF2F6);
  static const Color neutral200 = Color(0xFFE1E6ED);
  static const Color neutral300 = Color(0xFFCBD3DE);
  static const Color neutral400 = Color(0xFF9BA7B8);

  /// Tuned to `#66748A` rather than a mathematically even step: the even value
  /// measured 4.25:1 on white, just under the 4.5:1 floor for body text. This
  /// is 4.75:1.
  static const Color neutral500 = Color(0xFF66748A);
  static const Color neutral600 = Color(0xFF4F5D70);
  static const Color neutral700 = Color(0xFF3A4657);
  static const Color neutral800 = Color(0xFF26303E);
  static const Color neutral900 = Color(0xFF121A24);

  // ---------------------------------------------------------------------------
  // Status hues
  // ---------------------------------------------------------------------------
  //
  // Success is deliberately *not* the brand green. In a green-branded shop
  // every primary button is already green; if confirmations are that same green
  // then "this is an action" and "this worked" stop reading apart. Success sits
  // brighter and cooler.

  static const Color successSurface = Color(0xFFE4F6EA);
  static const Color successBorder = Color(0xFFAEE0C1);
  static const Color successBase = Color(0xFF12874A);

  static const Color warningSurface = amber50;
  static const Color warningBorder = amber100;
  static const Color warningBase = amber700;

  static const Color dangerSurface = Color(0xFFFDECEC);
  static const Color dangerBorder = Color(0xFFF5C2C2);
  static const Color dangerBase = Color(0xFFC5342B);

  static const Color infoSurface = navy50;
  static const Color infoBorder = navy200;
  static const Color infoBase = navy500;
}
