import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../Auth/loginScreen.dart';
import '../BottomNav/bottomNavScreen.dart';
import '../LocationScreen/locationScreen.dart';
import '../core/supabase.dart';
import '../utils/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    // Status Bar & Navigation Bar Settings
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));



    Timer(Duration (seconds: 1), (){
      //
      checkLogin();

    });

  }

  /// `Db.init()` has already run in main(), so a persisted Supabase session is restored
  /// by this point. Whether the user is signed in comes from that session — not from an
  /// email left in SharedPreferences, which any process could have written and which
  /// proved nothing about the account.
  Future<void> checkLogin() async {
    if (!Db.isSignedIn) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
      return;
    }

    // Location is a display preference, not identity, so it stays in SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    final String? district = prefs.getString('selected_district_name');
    final String? city = prefs.getString('selected_city_name');

    if (!mounted) return;

    if (district == null || city == null || district.isEmpty || city.isEmpty) {
      // Location not selected yet
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LocationScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BottomNavScreen()),
      );
    }
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Image.asset('assets/images/logo.png',
              width: 180.w,height: 180.h,),


          ],
        ),
      ),
    );
  }
}
