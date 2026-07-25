import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../CustomWidgets/customButton.dart';
import '../CustomWidgets/customTextFiledWidgets.dart';
import '../CustomWidgets/custom_text.dart';
import '../LocationScreen/locationScreen.dart';
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

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      showError('Please enter a valid email');
      return;
    }
    if (password.length < 6) {
      showError('Password must be at least 6 characters');
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
          _goHome();
        } else {
          // This project has "Confirm email" on, so signUp sends a link instead of a
          // session. Flip to the login tab rather than leaving the user stuck.
          showMessage('Check $email to confirm your account, then log in below.');
          setState(() => isSignUp = false);
        }
      } else {
        await _auth.signInWithEmail(email: email, password: password);
        if (!mounted) return;
        _goHome();
      }
    } on DataException catch (e) {
      showError(e.message);
    } catch (e) {
      showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LocationScreen()),
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
