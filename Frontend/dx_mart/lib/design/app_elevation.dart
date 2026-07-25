import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Depth, in three steps.
///
/// The app previously hand-authored about ten unrelated shadow recipes —
/// `black@0.02/blur 8`, `black@0.03/blur 4`, `black@0.05/blur 5`,
/// `black@0.06/blur 8`, `black@0.1/blur 6/spread 1`, `black@0.15/blur 8`,
/// `primary@0.2/blur 8`, `primary@0.3/blur 12` — plus one shadow with
/// `blurRadius: 0.1`, which is invisible. Two structurally identical headers
/// used entirely different treatments (one a drop shadow, one a 1px border).
///
/// None of the old blur radii or offsets were scaled with `flutter_screenutil`,
/// so shadows stayed a fixed physical size while everything around them grew.
/// These are unscaled too — deliberately. A shadow is an optical effect, not a
/// layout measurement, and scaling it makes large screens look smudged.
class AppElevation {
  const AppElevation._();

  /// No shadow at all — a 1px border does the separating.
  ///
  /// This is the default for cards. Borders survive on any background and never
  /// muddy at low contrast, which matters here because most surfaces are white
  /// or near-white.
  static const List<BoxShadow> flat = <BoxShadow>[];

  /// Something that floats just above the page: docked bars, sticky headers,
  /// the cart bar, FABs.
  static List<BoxShadow> get raised => <BoxShadow>[
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// The same, thrown upward — for bars docked to the bottom of the screen,
  /// where the light should read as coming from the content above.
  static List<BoxShadow> get raisedUp => <BoxShadow>[
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, -2),
        ),
      ];

  /// Modals, bottom sheets, dialogs — anything over a scrim.
  static List<BoxShadow> get overlay => <BoxShadow>[
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.10),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}
