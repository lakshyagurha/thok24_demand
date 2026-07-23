import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

import '../CustomWidgets/customButton.dart';
import '../CustomWidgets/customTextFiledWidgets.dart';
import '../CustomWidgets/custom_text.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';

class ForgetPassword extends StatefulWidget {
  const ForgetPassword({super.key});

  @override
  State<ForgetPassword> createState() => _ForgetPasswordState();
}

class _ForgetPasswordState extends State<ForgetPassword> {
  final emailController = TextEditingController();
  final otpController = TextEditingController();
  final passwordController = TextEditingController();
  bool otpSent = false;
  bool otpVerified = false;
  bool isLoading = false;
  bool _isPasswordVisible = false;

  Future<void> sendOTP() async {
    setState(() => isLoading = true);

    final response = await http.post(
      Uri.parse(ApiConstants.FORGET_PASSWORD),
      body: {"email": emailController.text},
    );

    final data = json.decode(response.body);

    setState(() => isLoading = false);

    if (data["status"] == "success") {
      setState(() => otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data["message"]),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data["message"] ?? "Something went wrong"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> verifyOTP() async {
    setState(() => isLoading = true);

    final response = await http.post(
      Uri.parse(ApiConstants.OTP_VERYFLY),
      body: {
        "email": emailController.text,
        "otp": otpController.text,
      },
    );

    final data = json.decode(response.body);
    setState(() => isLoading = false);

    if (data["status"] == "success") {
      setState(() => otpVerified = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data["message"]),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data["message"] ?? "Invalid OTP or something went wrong"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> resetPassword() async {
    setState(() => isLoading = true);

    final response = await http.post(
      Uri.parse(ApiConstants.RESET_PASSWORD),
      body: {
        "email": emailController.text,
        "new_password": passwordController.text,
      },
    );

    final data = json.decode(response.body);
    setState(() => isLoading = false);

    if (data["status"] == "success") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data["message"]),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data["message"] ?? "Something went wrong"),
          backgroundColor: Colors.red,
        ),
      );
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

                Image.asset('assets/images/logo.png',
                    width: 180.w, height: 110.h),

                SizedBox(height: 40.h),

                Padding(
                  padding: EdgeInsets.only(left: 20.w, right: 20.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email Field
                      CustomText(text: "Email Address", fontSize: 12.sp),
                      SizedBox(height: 7.h),

                      CustomTextField(
                        controller: emailController,
                        keyboardType: TextInputType.text,
                        preFixIcon: 'assets/svg/email.svg',
                        hintText: "example@gmail.com",
                      ),

                      SizedBox(height: 17.h),

                      // Show OTP field only when OTP is sent
                      if (otpSent && !otpVerified) ...[
                        CustomText(text: "OTP", fontSize: 12.sp),
                        SizedBox(height: 7.h),

                        CustomTextField(
                          controller: otpController,
                          hintText: "Enter OTP",
                          keyboardType: TextInputType.number,
                          preFixIcon: 'assets/svg/otp.svg', // Add OTP icon if available
                        ),
                        SizedBox(height: 17.h),
                      ]

                      // Show Password field only when OTP is verified
                      else if (otpVerified) ...[
                        CustomText(text: "New Password", fontSize: 12.sp),
                        SizedBox(height: 7.h),

                        CustomTextField(
                          controller: passwordController,
                          hintText: "********",
                          keyboardType: TextInputType.text,
                          preFixIcon: 'assets/svg/password.svg',
                          isObscure: !_isPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: AppColors.primaryColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        SizedBox(height: 20.h),
                      ],

                      // Button based on current state
                      CustomButton(
                        text: !otpSent
                            ? 'Send OTP'
                            : (!otpVerified ? 'Verify OTP' : 'Reset Password'),
                        onPressed: () {
                          if (isLoading) return;

                          if (!otpSent) {
                            sendOTP();
                          } else if (otpSent && !otpVerified) {
                            verifyOTP();
                          } else if (otpVerified) {
                            resetPassword();
                          }
                        },
                      ),

                      SizedBox(height: 10.h),

                      // Back to Login Option
                      Center(
                        child: InkWell(
                          child: CustomText(
                            text: "Back to Login",
                            color: AppColors.secondaryColor,
                            fontWeight: FontWeight.w400,
                            fontSize: 14.sp,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                          },
                        ),
                      )
                    ],
                  ),
                ),

                SizedBox(height: 15.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Don\'t have an account?',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14.sp,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    InkWell(
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.sp,
                          color: AppColors.secondaryColor,
                        ),
                      ),
                      onTap: () {
                        // Navigate to SignUpScreen
                        // Navigator.push(context, MaterialPageRoute(builder: (context)=>SignUpScreen()));
                      },
                    ),
                  ],
                )
              ],
            ),
          ),

          // Loading Overlay
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