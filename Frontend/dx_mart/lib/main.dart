import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'CustomWidgets/cart_provider.dart';
import 'SplashScreen/splashScreen.dart';
import 'core/session.dart';
import 'core/supabase.dart';
import 'utils/colors.dart';
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'DxMart could not start',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please close the app and open it again. If this keeps happening, '
                  'contact support.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                // Only useful to whoever is debugging a build; harmless to a shopper.
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
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
      splitScreenMode: true,
      builder: (context, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CartProvider()),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: appNavigatorKey,
            title: 'Dx Mart',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primaryColor,
                primary: AppColors.primaryColor,
                secondary: AppColors.secondaryColor,
              ),
              textTheme: GoogleFonts.poppinsTextTheme(
                Theme.of(context).textTheme,
              ),
              useMaterial3: true,
            ),
            // Sits above every route so an expiring or revoked session is noticed
            // wherever the user happens to be, not only on the Profile screen.
            home: SessionWatcher(child: SplashScreen()),
          ),
        );
      },
    );
  }
}
