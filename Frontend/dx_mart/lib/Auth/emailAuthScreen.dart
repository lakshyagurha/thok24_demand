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

/// Email + password sign in / sign up.
///
/// Interim path alongside phone/OTP (loginScreen.dart / otpScreen.dart): while MSG91 (the
/// SMS provider wired in via the Send SMS auth hook) is being configured, this lets the
/// app be tested end to end without an SMS round trip. It does not replace phone/OTP —
/// both create the same kind of Supabase Auth session, and RLS treats them identically.
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final AuthRepository _auth = const AuthRepository();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  bool isSignUp = false;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
        duration: const Duration(seconds: 5),
        backgroundColor: AppColors.primaryColor,
      ),
    );
  }

  /// Rejects the obviously-wrong rather than trying to fully validate an address — a
  /// bare `contains('@')` accepted "@" and "a@b".
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$');

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (!_emailRe.hasMatch(email)) {
      showError('Please enter a valid email');
      return;
    }
    if (password.length < 6) {
      showError('Password must be at least 6 characters');
      return;
    }
    // Only on sign-up: the phone path requires a name, and without this an email
    // account was silently created with a blank one.
    if (isSignUp && nameController.text.trim().isEmpty) {
      showError('Please enter your name');
      return;
    }

    setState(() => isLoading = true);
    try {
      if (isSignUp) {
        final signedInImmediately = await _auth.signUpWithEmail(
          email: email,
          password: password,
          name: nameController.text,
        );
        if (!mounted) return;
        if (signedInImmediately) {
          await _goHome();
        } else {
          // This project has "Confirm email" on, so signUp sends a link instead of a
          // session.
          //
          // Note this is also what an ALREADY-REGISTERED address returns: Supabase's
          // user-enumeration protection makes the two indistinguishable on purpose, and
          // we must not try to tell them apart. So the wording covers both rather than
          // promising an email that may never arrive.
          showMessage(
            'If $email is new, check your inbox to confirm it. '
            'If you already have an account, just log in below.',
          );
          setState(() => isSignUp = false);
        }
      } else {
        await _auth.signInWithEmail(email: email, password: password);
        if (!mounted) return;
        await _goHome();
      }
    } on DataException catch (e) {
      showError(e.message);
    } catch (e) {
      showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Sends a reset link. Always reports the same thing whether or not the address is
  /// registered — saying "no such account" would let anyone test which emails have one.
  Future<void> _forgotPassword() async {
    final email = emailController.text.trim();
    if (!_emailRe.hasMatch(email)) {
      showError('Enter your email above first, then tap Forgot password');
      return;
    }
    setState(() => isLoading = true);
    try {
      await _auth.sendPasswordReset(email);
      showMessage('If $email has an account, a reset link is on its way.');
    } on DataException catch (e) {
      showError(e.message);
    } catch (e) {
      showError('Could not send the reset link. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _goHome() async {
    // Same rule as splash: only ask for a delivery area if this device has not chosen
    // one yet.
    final needsLocation = !await hasChosenDeliveryArea();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => needsLocation ? LocationScreen() : BottomNavScreen(),
      ),
      (route) => false,
    );
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

                SizedBox(height: 30.h),

                Padding(
                  padding: EdgeInsets.only(left: 20.w, right: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(
                        text: isSignUp ? 'Sign Up with Email' : 'Log In with Email',
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      SizedBox(height: 4.h),
                      CustomText(
                        text: 'Interim login while phone OTP is being set up.',
                        color: AppColors.neutral500,
                        fontWeight: FontWeight.w400,
                        fontSize: 12.sp,
                      ),
                      SizedBox(height: 24.h),

                      if (isSignUp) ...[
                        CustomText(text: 'Name', fontSize: 12.sp),
                        SizedBox(height: 7.h),
                        CustomTextField(
                          controller: nameController,
                          keyboardType: TextInputType.name,
                          preFixIcon: 'assets/svg/user.svg',
                          hintText: 'Your name',
                        ),
                        SizedBox(height: 16.h),
                      ],

                      CustomText(text: 'Email', fontSize: 12.sp),
                      SizedBox(height: 7.h),
                      CustomTextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        hintText: 'you@example.com',
                      ),
                      SizedBox(height: 16.h),

                      CustomText(text: 'Password', fontSize: 12.sp),
                      SizedBox(height: 7.h),
                      CustomTextField(
                        controller: passwordController,
                        keyboardType: TextInputType.visiblePassword,
                        isObscure: true,
                        hintText: 'At least 6 characters',
                      ),

                      // Without this an email user who forgot their password had no way
                      // back into the account at all.
                      if (!isSignUp)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: isLoading ? null : _forgotPassword,
                            child: CustomText(
                              text: 'Forgot password?',
                              fontSize: 12.sp,
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      SizedBox(height: 24.h),

                      CustomButton(
                        text: isSignUp ? 'Sign Up' : 'Log In',
                        onPressed: () {
                          if (isLoading) return;
                          submit();
                        },
                      ),

                      SizedBox(height: 16.h),

                      Center(
                        child: InkWell(
                          onTap: isLoading
                              ? null
                              : () => setState(() => isSignUp = !isSignUp),
                          child: CustomText(
                            text: isSignUp
                                ? 'Already have an account? Log In'
                                : "Don't have an account? Sign Up",
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
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
