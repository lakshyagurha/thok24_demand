import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../BottomNav/bottomNavScreen.dart';
import '../CustomWidgets/customButton.dart';
import '../CustomWidgets/customTextFiledWidgets.dart';
import '../utils/colors.dart';
import '../utils/language_provider.dart';

/// First-run "where are you" step.
///
/// Was a manual district -> area dropdown backed by public.district / public.city. That
/// table is leftover generic seed data (Ranchi/Hazaribag/Chatra), not THOK24's actual
/// pilot area (Sagar/Khurai/Bina) -- and two of its three districts have zero cities, so
/// picking either one left "Your Area" permanently empty with no way to proceed. Nothing
/// downstream enforces serviceability against this table (splashScreen.dart's own comment
/// calls it "a display preference, not identity"), so there is no correctness reason to
/// keep it: this replaces it with the device's actual location via GPS, with a manual
/// text fallback for denied permission / indoor / emulator testing.
///
/// Writes the same SharedPreferences keys the old screen did
/// (selected_district_name, selected_city_name), so splashScreen.dart and
/// homeScreen.dart need no changes.
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  bool isLoading = false;
  bool showManualEntry = false;
  String? errorMessage;

  final areaController = TextEditingController();
  final cityController = TextEditingController();

  @override
  void dispose() {
    areaController.dispose();
    cityController.dispose();
    super.dispose();
  }

  Future<void> saveAndContinue({
    required String district,
    required String city,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_district_name', district);
    await prefs.setString('selected_city_name', city);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => BottomNavScreen()),
    );
  }

  /// Shows a recoverable problem and reveals the manual entry fields.
  ///
  /// Guarded, because everything that calls it runs after an await — and
  /// `Geolocator.getCurrentPosition` has a 15-SECOND time limit, which is a long window
  /// for the user to have backed out of this screen. Every one of these setState calls
  /// was previously unguarded.
  void _failSoftly(String message) {
    if (!mounted) return;
    setState(() {
      errorMessage = message;
      showManualEntry = true;
    });
  }

  Future<void> useCurrentLocation() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _failSoftly('Location is turned off. Enable it in your phone settings, '
            'or enter your area manually below.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _failSoftly(permission == LocationPermission.deniedForever
            ? 'Location permission is blocked. Enable it from app settings, '
                'or enter your area manually below.'
            : 'Location permission was denied. Enter your area manually below.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) {
        _failSoftly("Couldn't work out your area from GPS. "
            'Enter it manually below.');
        return;
      }

      final p = placemarks.first;
      // locality is usually the city/town; subLocality is the neighbourhood, used only
      // when locality is blank (some rural areas geocode that way).
      final city = (p.locality?.isNotEmpty ?? false)
          ? p.locality!
          : (p.subLocality ?? '');
      // subAdministrativeArea is the district in India; administrativeArea (state) is
      // the fallback so this never comes back empty on a coarse geocode.
      final district = (p.subAdministrativeArea?.isNotEmpty ?? false)
          ? p.subAdministrativeArea!
          : (p.administrativeArea ?? '');

      if (city.isEmpty && district.isEmpty) {
        _failSoftly("Couldn't work out your area from GPS. "
            'Enter it manually below.');
        return;
      }

      await saveAndContinue(
        district: district.isEmpty ? city : district,
        city: city.isEmpty ? district : city,
      );
    } catch (e) {
      debugPrint('Location detection failed: $e');
      _failSoftly('Something went wrong getting your location. '
          'Enter your area manually below.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> submitManual() async {
    final city = cityController.text.trim();
    final district = areaController.text.trim();
    if (city.isEmpty) {
      setState(() => errorMessage = 'Please enter your city/town');
      return;
    }
    await saveAndContinue(
      district: district.isEmpty ? city : district,
      city: city,
    );
  }

  @override
  Widget build(BuildContext context) {
    // This is the FIRST screen a new user sees and it was 100% hardcoded English, in an
    // app whose whole premise is Hindi-first.
    final lang = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 60.h),
              Center(
                child: Image.asset(
                  'assets/images/location.png',
                  width: 180.w,
                  height: 120.h,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 20.h),
              Center(
                child: Text(
                  lang.translate('select_your_location'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 20.sp,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Center(
                child: Text(
                  lang.translate('location_subtitle'),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12.sp,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 36.h),

              CustomButton(
                text: isLoading
                    ? lang.translate('detecting_location')
                    : lang.translate('use_current_location'),
                onPressed: () {
                  if (isLoading) return;
                  useCurrentLocation();
                },
              ),

              if (errorMessage != null) ...[
                SizedBox(height: 12.h),
                Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red.shade400, fontSize: 12.sp),
                ),
              ],

              if (!showManualEntry) ...[
                SizedBox(height: 16.h),
                Center(
                  child: InkWell(
                    onTap: isLoading
                        ? null
                        : () => setState(() => showManualEntry = true),
                    child: Text(
                      lang.translate('enter_location_manually'),
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ),
              ],

              if (showManualEntry) ...[
                SizedBox(height: 24.h),
                Text(
                  lang.translate('city_town'),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14.sp,
                    color: AppColors.primaryTextColor,
                  ),
                ),
                SizedBox(height: 8.h),
                CustomTextField(
                  controller: cityController,
                  keyboardType: TextInputType.text,
                  hintText: 'e.g. Sagar',
                ),
                SizedBox(height: 16.h),
                Text(
                  lang.translate('district_optional'),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14.sp,
                    color: AppColors.primaryTextColor,
                  ),
                ),
                SizedBox(height: 8.h),
                CustomTextField(
                  controller: areaController,
                  keyboardType: TextInputType.text,
                  hintText: 'e.g. Sagar',
                ),
                SizedBox(height: 20.h),
                CustomButton(
                  text: lang.translate('continue_btn'),
                  onPressed: () {
                    if (isLoading) return;
                    submitManual();
                  },
                ),
              ],

              SizedBox(height: 30.h),
            ],
          ),
        ),
      ),
    );
  }
}
