import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../Auth/loginScreen.dart';
import '../BottomNav/bottomNavScreen.dart';
import '../LocationScreen/locationScreen.dart';
import '../core/supabase.dart';
import '../design/app_colors.dart';
import '../design/app_gradients.dart';
import '../design/app_space.dart';
import '../design/app_theme.dart';
import '../design/app_type.dart';
import '../design/components/brand_lockup.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  late final Animation<double> _fade;
  late final Animation<double> _rise;

  /// Held so it can be cancelled: an uncancelled Timer keeps this State alive after the
  /// route is gone.
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();

    // Status Bar & Navigation Bar Settings
    SystemChrome.setSystemUIOverlayStyle(AppTheme.lightOverlay);

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
    _rise = Tween<double>(begin: 16, end: 0)
        .animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic));
    _intro.forward();

    // 1400ms rather than 1000: the intro runs 650ms, and cutting a motion off
    // mid-flight reads as a stutter rather than as speed.
    _splashTimer = Timer(const Duration(milliseconds: 1400), checkLogin);
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _intro.dispose();
    super.dispose();
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
    // Previously: a single `Image.asset` centred inside a `Row` with one child,
    // on a flat white background, sized `180.w x 180.h` — a square asset given
    // two different scale axes, so its box was non-square on most devices.
    // No wordmark, no tagline, no motion, and no indication anything was
    // happening. It is the first thing every user sees.
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.heroSoft),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              AnimatedBuilder(
                animation: _intro,
                builder: (context, child) => Opacity(
                  opacity: _fade.value,
                  child: Transform.translate(
                    offset: Offset(0, _rise.value),
                    child: child,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandLockup(
                      size: BrandLockupSize.lg,
                      withMark: true,
                    ),
                    AppSpace.gapH(AppSpace.md),
                    Text(
                      'Rozana ki zaroorat, sabse kam daam par',
                      textAlign: TextAlign.center,
                      style: AppText.bodyM(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              // A quiet progress cue. A splash with no indicator is
              // indistinguishable from a frozen one on a slow cold start.
              SizedBox(
                width: AppSpace.w(28),
                height: AppSpace.w(28),
                child: const CircularProgressIndicator(strokeWidth: 2.5),
              ),
              AppSpace.gapH(AppSpace.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
