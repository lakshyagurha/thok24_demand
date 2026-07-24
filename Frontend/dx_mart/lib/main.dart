import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'CustomWidgets/cart_provider.dart';
import 'SplashScreen/splashScreen.dart';
import 'core/supabase.dart';
import 'utils/colors.dart';
import 'utils/language_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restores any persisted session before the first frame, so screens can rely on
  // Db.isSignedIn instead of re-identifying the user from stored email on every route.
  await Db.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    // ❌ Firebase related code removed
  }

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
            home: SplashScreen(),
          ),
        );
      },
    );
  }
}
