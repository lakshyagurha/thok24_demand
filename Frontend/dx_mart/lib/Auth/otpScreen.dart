import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../CustomWidgets/customButton.dart';
import '../CustomWidgets/customTextFiledWidgets.dart';
import '../CustomWidgets/custom_text.dart';
import '../BottomNav/bottomNavScreen.dart';
import '../LocationScreen/locationScreen.dart';
import '../core/session.dart';
import '../core/supabase.dart';
import '../data/auth_repository.dart';
import '../utils/colors.dart';

/// OTP entry step shared by login and sign up.
///
/// [phone] is the number the code was sent to. [name] is only supplied by the sign up
/// flow — it is written to the profile once the session exists, because there is no
/// separate signup endpoint any more: `sendOtp` both registers and signs in.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone, this.name});

  final String phone;
  final String? name;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final AuthRepository _auth = const AuthRepository();
  final TextEditingController otpController = TextEditingController();

  bool isLoading = false;
  int _resendIn = 30;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    otpController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendIn <= 1) {
        timer.cancel();
        setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn -= 1);
      }
    });
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle()),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: AppColors.primaryTextColor),
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: AppColors.primaryColor,
      ),
    );
  }

  Future<void> verify() async {
    final code = otpController.text.trim();
    // The field is labelled "6 digit OTP" but only emptiness was checked, so a partial
    // code was sent to the server and came back as a generic failure.
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      showError("Please enter the 6 digit OTP");
      return;
    }

    setState(() => isLoading = true);

    try {
      // Verifying establishes the Supabase session. Nothing about the user is written
      // to SharedPreferences — the session is the only source of identity.
      await _auth.verifyOtp(
        phone: widget.phone,
        token: code,
        name: widget.name,
      );

      otpController.clear();
      // Skip the location picker if this device has already chosen a delivery area —
      // splash already did this, so signing in used to be the only path that forced a
      // returning user back through GPS.
      final needsLocation = !await hasChosenDeliveryArea();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) =>
              needsLocation ? LocationScreen() : BottomNavScreen(),
        ),
        (route) => false,
      );
    } on DataException catch (e) {
      showError(e.message);
    } catch (e) {
      showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> resend() async {
    if (_resendIn > 0 || isLoading) return;

    setState(() => isLoading = true);
    try {
      await _auth.sendOtp(widget.phone);
      showMessage('OTP sent again to ${widget.phone}');
      _startResendCountdown();
    } on DataException catch (e) {
      showError(e.message);
    } catch (e) {
      showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 80.h),

                Image.asset(
                  'assets/images/logo.png',
                  width: 180.w,
                  height: 110.h,
                ),

                SizedBox(height: 40.h),

                Padding(
                  padding: EdgeInsets.only(left: 20.w, right: 20.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(
                        text: "Enter the OTP sent to ${widget.phone}",
                        fontSize: 12.sp,
                      ),
                      SizedBox(height: 7.h),

                      CustomTextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        preFixIcon: 'assets/svg/password.svg',
                        hintText: "6 digit OTP",
                      ),

                      SizedBox(height: 20.h),

                      CustomButton(
                        text: 'Verify',
                        onPressed: () {
                          if (isLoading) return;
                          verify();
                        },
                      ),

                      SizedBox(height: 10.h),

                      Center(
                        child: InkWell(
                          child: CustomText(
                            text: _resendIn > 0
                                ? "Resend OTP in ${_resendIn}s"
                                : "Resend OTP",
                            color: _resendIn > 0
                                ? AppColors.neutral500
                                : AppColors.primaryColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 14.sp,
                          ),
                          onTap: resend,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 15.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Wrong number?',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14.sp,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    InkWell(
                      child: Text(
                        'Change',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.sp,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primaryColor),
              ),
            ),
        ],
      ),
    );
  }
}
