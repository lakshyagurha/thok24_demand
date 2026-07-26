import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../design/app_colors.dart';
import '../design/app_space.dart';
import '../design/app_type.dart';
import '../design/components/app_button.dart';
import '../design/components/app_text_field.dart';
import '../design/components/auth_scaffold.dart';
import '../BottomNav/bottomNavScreen.dart';
import '../LocationScreen/locationScreen.dart';
import '../core/session.dart';
import '../core/supabase.dart';
import '../data/auth_repository.dart';

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
          style: TextStyle(color: AppColors.textPrimary),
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: AppColors.primary,
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
    final canResend = _resendIn <= 0;

    return AuthScaffold(
      title: 'Verify your number',
      subtitle: 'Enter the 6-digit code we sent to +91 ${widget.phone}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: otpController,
            label: 'One-time password',
            hint: '000000',
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            prefixIcon: Icons.lock_outline_rounded,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => verify(),
          ),
          AppSpace.gapH(AppSpace.lg),
          AppButton(
            label: 'Verify & continue',
            loading: isLoading,
            onPressed: isLoading ? null : verify,
          ),
          AppSpace.gapH(AppSpace.base),
          // The countdown is stated rather than implied. Previously the resend
          // control simply sat there inert until the timer elapsed, with no
          // indication of why it was not working.
          Center(
            child: canResend
                ? TextButton(
                    onPressed: isLoading ? null : resend,
                    child: Text(
                      'Resend code',
                      style: AppText.label(color: AppColors.primary),
                    ),
                  )
                : Text(
                    'Resend code in ${_resendIn}s',
                    style: AppText.bodyS(color: AppColors.textTertiary),
                  ),
          ),
        ],
      ),
      footer: Text(
        'Wrong number? Go back to change it.',
        textAlign: TextAlign.center,
        style: AppText.caption(),
      ),
    );
  }
}
