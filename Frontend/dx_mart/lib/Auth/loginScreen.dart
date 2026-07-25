import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../CustomWidgets/customButton.dart';
import '../CustomWidgets/customTextFiledWidgets.dart';
import '../CustomWidgets/custom_text.dart';
import '../core/supabase.dart';
import '../data/auth_repository.dart';
import '../utils/colors.dart';
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
            style: TextStyle(color: AppColors.primaryTextColor),
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.primaryColor,
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
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:  [

                SizedBox(height: 80.h,),

                Image.asset('assets/images/logo.png',
                  width: 180.w,height: 110.h,),



                SizedBox(height: 40.h,),

                Padding(
                  padding:  EdgeInsets.only(left: 20.w,right: 20.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [


                      CustomText(text: "Mobile Number",fontSize: 12.sp,),
                      SizedBox(height: 7.h,),

                      CustomTextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          preFixIcon: 'assets/svg/phone.svg',
                          hintText: "9876543210"),


                      SizedBox(height: 20.h,),

                      CustomButton(text: 'Send OTP',  onPressed: (){
                        if (isLoading) return;
                        handleSubmit();
                      }),

                      SizedBox(height: 10.h,),

                      Center(
                        child: CustomText(
                          text: "We will send you a one time password on this number",
                          color: AppColors.neutral500,
                          fontWeight: FontWeight.w400,
                          fontSize: 12.sp,
                        ),
                      )
                    ],
                  ),
                ),




                SizedBox(height: 15.h,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Don’t have an account?',style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14.sp,
                      color: AppColors.primaryTextColor,
                    ),),

                    SizedBox(width: 6.w,),
                    InkWell(
                      child: Text('Sign Up',style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                        color: AppColors.primaryColor, // High contrast green
                      ),),
                      onTap: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>SignUpScreen()));
                      },
                    ),

                  ],
                ),

                SizedBox(height: 12.h,),
                Center(
                  child: InkWell(
                    child: CustomText(
                      text: 'Or continue with email',
                      color: AppColors.neutral500,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.sp,
                    ),
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>const EmailAuthScreen()));
                    },
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
