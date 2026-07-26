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
import 'loginScreen.dart';
import 'otpScreen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {

  final AuthRepository _auth = const AuthRepository();

  bool isLoading = false;

  TextEditingController nameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  String? validateFields() {
    if (nameController.text.trim().isEmpty) {
      return "Please Enter Name";
    }
    if (phoneController.text.trim().isEmpty) {
      return "Please Enter Mobile Number";
    }
    if (!AuthRepository.isValidIndianMobile(phoneController.text)) {
      return "Please Enter a valid 10 digit Mobile Number";
    }
    return null;
  }

  void showError(String message) {
    // See the note in loginScreen: this runs after an await, so the element may be gone.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle()),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// There is no separate signup call any more: `sendOtp` registers a new number and
  /// signs in an existing one. The name is carried to the OTP step and written to the
  /// profile once the session exists.
  Future<void> signup() async {
    setState(() {
      isLoading = true;
    });

    final phone = phoneController.text.trim();
    final name = nameController.text.trim();

    try {
      await _auth.sendOtp(phone);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP sent to ${AuthRepository.normalisePhone(phone)}'),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.primary,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpScreen(phone: phone, name: name),
        ),
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
      signup();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'We only need a name and a mobile number to get you started.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account?',
            style: AppText.bodyM(color: AppColors.textSecondary),
          ),
          AppSpace.gapW(AppSpace.xs),
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: AppSpace.all(AppSpace.xs),
              child: Text(
                'Sign In',
                style: AppText.label(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: nameController,
            label: 'Full name',
            hint: 'Lakshya Jain',
            keyboardType: TextInputType.name,
            prefixIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          AppSpace.gapH(AppSpace.base),
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
