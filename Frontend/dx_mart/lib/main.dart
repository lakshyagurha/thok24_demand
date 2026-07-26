import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'CustomWidgets/cart_provider.dart';
import 'CustomWidgets/wishlist_provider.dart';
import 'SplashScreen/splashScreen.dart';
import 'core/session.dart';
import 'core/supabase.dart';
import 'design/app_colors.dart';
import 'design/app_space.dart';
import 'design/app_theme.dart';
import 'design/app_type.dart';
import 'utils/language_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Restores any persisted session before the first frame, so screens can rely on
    // Db.isSignedIn instead of re-identifying the user from stored email on every route.
    await Db.init();
  } catch (e) {
    // Unguarded, this killed the isolate before runApp: a missing --dart-define or a
    // Supabase init failure showed the user a blank window with no explanation and no
    // way forward.
    debugPrint('Supabase init failed: $e');
    runApp(_StartupFailureApp(message: '$e'));
    return;
  }
  runApp(const MyApp());
}

/// Shown instead of a black screen when the app cannot reach its own configuration.
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    // Wrapped in ScreenUtilInit and given the real theme: this used to be a
    // second, themeless MaterialApp, so the one screen a user sees when the app
    // is broken was also the one screen that looked like a different app.
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      builder: (context, child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'DxMart',
        theme: AppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: AppSpace.all(AppSpace.xl),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: AppColors.iconMuted,
                  ),
                  AppSpace.gapH(AppSpace.base),
                  Text(
                    'DxMart could not start',
                    textAlign: TextAlign.center,
                    style: AppText.h2(),
                  ),
                  AppSpace.gapH(AppSpace.sm),
                  Text(
                    'Please close the app and open it again. If this keeps happening, '
                    'contact support.',
                    textAlign: TextAlign.center,
                    style: AppText.bodyM(color: AppColors.textSecondary),
                  ),
                  AppSpace.gapH(AppSpace.base),
                  // Only useful to whoever is debugging a build; harmless to a shopper.
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppText.caption(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      // `splitScreenMode` was true. It exists so ScreenUtil can account for a
      // device actually being in Android/iOS split-screen or multi-window
      // mode, which this app does not support and never checks for. Left on,
      // it is a documented flutter_screenutil footgun: its split-screen
      // detection heuristic misfires on some real devices — certain OEM
      // skins, aspect ratios and Android versions — and the app renders into
      // only part of the screen with the remainder left blank, which matches
      // exactly what was reported ("splash screen shows in half screen") and
      // could not be reproduced on the emulator, since the heuristic is
      // device-dependent. Default is false; nothing else in this app reads
      // or needs it.
      builder: (context, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CartProvider()),
            // One shared set of wishlisted product ids. ProductCard used to query
            // membership per card, so a grid cost one request per product.
            ChangeNotifierProvider(create: (_) => WishlistProvider()),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: appNavigatorKey,
            title: 'DxMart',
            theme: AppTheme.light,
            // Sits above every route so an expiring or revoked session is noticed
            // wherever the user happens to be, not only on the Profile screen.
            home: SessionWatcher(child: SplashScreen()),
          ),
        );
      },
    );
  }
}
