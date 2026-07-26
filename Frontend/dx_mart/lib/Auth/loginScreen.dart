import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../design/app_colors.dart';
import '../design/app_space.dart';
import '../design/app_type.dart';
import '../design/components/app_button.dart';
import '../design/components/app_text_field.dart';
import '../design/components/auth_scaffold.dart';
import '../core/supabase.dart';
import '../data/auth_repository.dart';
import 'emailAuthScreen.dart';
import 'otpScreen.dart';
import 'signUpScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final AuthRepository _auth = const AuthRepository();

  bool isLoading = false;
  TextEditingController phoneController = TextEditingController();

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  String? validateFields() {
    if (phoneController.text.trim().isEmpty) {
      return "Please Enter Mobile Number";
    }
    if (!AuthRepository.isValidIndianMobile(phoneController.text)) {
      return "Please Enter a valid 10 digit Mobile Number";
    }

    return null;
  }

  void showError(String message) {
    // Called from catch blocks after an await; without this, backing out during the
    // network call throws on a defunct element. otpScreen and emailAuthScreen already
    // guarded theirs.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle()),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }



  /// Sends the OTP and moves to the verification step. There is no password any more,
  /// and nothing about the user is written to SharedPreferences — the Supabase session
  /// created on the OTP screen is the only source of identity.
  Future<void> login() async {
    setState(() {
      isLoading = true;
    });

    final phone = phoneController.text.trim();

    try {
      await _auth.sendOtp(phone);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'OTP sent to ${AuthRepository.normalisePhone(phone)}',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.primary,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OtpScreen(phone: phone)),
      );
    } on DataException catch (e) {
      showError(e.message);
    } catch (e) {
      _showSnackBar('Something went wrong. Try again.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void handleSubmit() {
    final error = validateFields();
    if (error != null) {
      showError(error);
    } else {
      login();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Was: a bare Column on white — an 80h top gap, a 180x110 logo, a label, a
    // field, a button, and three separate links, with no card, no title and no
    // sense of what the screen was asking for. The loading state was a
    // full-screen black@0.5 scrim over a spinner, which is a lot of ceremony
    // for "we are sending an SMS".
    return AuthScaffold(
      showBack: false,
      title: 'Welcome back',
      subtitle: 'Sign in with your mobile number to start ordering.',
      footer: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Don\u2019t have an account?',
                style: AppText.bodyM(color: AppColors.textSecondary),
              ),
              AppSpace.gapW(AppSpace.xs),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SignUpScreen()),
                ),
                child: Padding(
                  padding: AppSpace.symmetric(
                    horizontal: AppSpace.xs,
                    vertical: AppSpace.xs,
                  ),
                  child: Text(
                    'Sign Up',
                    style: AppText.label(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          AppSpace.gapH(AppSpace.sm),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmailAuthScreen()),
            ),
            child: Text(
              'Or continue with email',
              style: AppText.label(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: phoneController,
            label: 'Mobile number',
            hint: '9876543210',
            helper: 'We will send a one-time password to this number.',
            keyboardType: TextInputType.phone,
            maxLength: 10,
            prefixIcon: Icons.phone_outlined,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => handleSubmit(),
          ),
          AppSpace.gapH(AppSpace.lg),
          // The button owns its own loading state now, so the screen no longer
          // throws a full-screen scrim over itself to say "working".
          AppButton(
            label: 'Send OTP',
            loading: isLoading,
            onPressed: isLoading ? null : handleSubmit,
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}
