import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_space.dart';
import 'app_type.dart';
import 'brand_palette.dart';

/// The application theme.
///
/// The app previously had, in full:
///
/// ```dart
/// theme: ThemeData(
///   colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryColor, ...),
///   textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
///   useMaterial3: true,
/// ),
/// ```
///
/// — no app-bar theme, no button themes, no input theme, no card theme, no
/// divider, snackbar, dialog, radio or chip theme. Every widget was styled by
/// hand at its call site, which is how the codebase ended up with eight
/// different primary buttons and three different text fields.
///
/// Two further problems with the old block, both fixed here:
///
///  * `Theme.of(context)` was called on the `ScreenUtilInit` builder context —
///    i.e. *above* the `MaterialApp` — so the text theme being merged was the
///    ambient fallback, not this app's.
///  * `ColorScheme.fromSeed` **tonally re-derives** every colour you give it.
///    Passing the brand green as a seed does not mean Material will use the
///    brand green; it means Material will use its own approximation. Since the
///    brand values here are exact, the scheme is declared explicitly instead.
class AppTheme {
  const AppTheme._();

  /// Status-bar / navigation-bar styling for a light screen.
  static const SystemUiOverlayStyle lightOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: BrandPalette.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  /// For screens whose header is the navy surface.
  static const SystemUiOverlayStyle darkOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: BrandPalette.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static ColorScheme get _scheme => const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primarySurface,
        onPrimaryContainer: BrandPalette.green800,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondarySurface,
        onSecondaryContainer: BrandPalette.navy800,
        tertiary: AppColors.discount,
        onTertiary: AppColors.onDiscount,
        error: AppColors.danger,
        onError: BrandPalette.white,
        errorContainer: AppColors.dangerSurface,
        onErrorContainer: BrandPalette.dangerBase,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerLowest: BrandPalette.white,
        surfaceContainerLow: AppColors.background,
        surfaceContainer: BrandPalette.neutral100,
        surfaceContainerHigh: BrandPalette.neutral200,
        outline: AppColors.borderStrong,
        outlineVariant: AppColors.border,
      );

  static ThemeData get light {
    final scheme = _scheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.surface,
      dividerColor: AppColors.border,
      textTheme: AppText.textTheme(ThemeData.light().textTheme),
      primaryTextTheme: AppText.textTheme(ThemeData.light().textTheme),

      // Ripples are clipped to the control rather than painted behind an
      // opaque box. Almost every hand-rolled button in the old code wrapped an
      // InkWell *around* a decorated Container, so the ripple was invisible and
      // no primary CTA in the app had press feedback.
      splashFactory: InkRipple.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: lightOverlay,
        titleTextStyle: AppText.h2(),
        iconTheme: const IconThemeData(color: AppColors.icon, size: 24),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        titleTextStyle: AppText.h2(),
        contentTextStyle: AppText.bodyM(color: AppColors.textSecondary),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.disabledSurface,
          disabledForegroundColor: AppColors.onDisabled,
          minimumSize: Size.fromHeight(AppSpace.h(AppSpace.buttonHeight)),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: AppText.button(),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.onDisabled,
          minimumSize: Size.fromHeight(AppSpace.h(AppSpace.buttonHeight)),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          textStyle: AppText.button(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.onDisabled,
          textStyle: AppText.button(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: AppSpace.symmetric(horizontal: AppSpace.base, vertical: AppSpace.md),
        hintStyle: AppText.bodyM(color: AppColors.textTertiary),
        labelStyle: AppText.label(color: AppColors.textSecondary),
        errorStyle: AppText.caption(color: AppColors.danger),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        // A visible focus ring. The address form's fields used
        // `BorderSide.none` for every state, so they never showed focus or
        // validation at all.
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        contentTextStyle: AppText.bodyM(color: AppColors.onSurfaceDark),
        actionTextColor: BrandPalette.green300,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        insetPadding: AppSpace.all(AppSpace.base),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceSunken,
        circularTrackColor: Colors.transparent,
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.borderStrong,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.onPrimary),
        side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceSunken,
        selectedColor: AppColors.primarySurface,
        side: const BorderSide(color: AppColors.border),
        labelStyle: AppText.label(),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xsAll),
        padding: AppSpace.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textTertiary,
        labelStyle: AppText.label(color: AppColors.primary),
        unselectedLabelStyle: AppText.label(color: AppColors.textTertiary),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.border,
      ),

      iconTheme: const IconThemeData(color: AppColors.icon, size: 24),

      listTileTheme: ListTileThemeData(
        iconColor: AppColors.icon,
        titleTextStyle: AppText.bodyL(),
        subtitleTextStyle: AppText.bodyS(color: AppColors.textSecondary),
        contentPadding: AppSpace.symmetric(horizontal: AppSpace.base),
      ),
    );
  }
}
