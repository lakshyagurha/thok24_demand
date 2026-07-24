import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/supabase.dart';
import 'SplashScreen/splashScreen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restores any persisted admin session before the first frame, so SplashScreen can
  // route on a real session instead of an email left in SharedPreferences.
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
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1366, 768),
      minTextAdapt: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'DxMart',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: const Color(0xFFF8F9FC),
          ),
          home: SplashScreen(),
        );
      },
    );
  }
}
