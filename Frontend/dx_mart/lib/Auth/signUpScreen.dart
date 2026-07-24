import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../CustomWidgets/customButton.dart';
import '../CustomWidgets/customTextFiledWidgets.dart';
import '../CustomWidgets/custom_text.dart';
import '../core/supabase.dart';
import '../data/auth_repository.dart';
import '../utils/colors.dart';
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
          backgroundColor: AppColors.primaryColor,
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


                      CustomText(text: "Your Name",fontSize: 12.sp,),
                      SizedBox(height: 7.h,),

                      CustomTextField(
                          controller: nameController,
                          keyboardType: TextInputType.text,
                          preFixIcon: 'assets/svg/user.svg',
                          hintText: "Rohan Kumar"),

                      SizedBox(height: 17.h,),

                      CustomText(text: "Mobile Number",fontSize: 12.sp,),
                      SizedBox(height: 7.h,),

                      CustomTextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          preFixIcon: 'assets/svg/phone.svg',
                          hintText: "9876543210"),


                      SizedBox(height: 20.h,),

                      CustomButton(text: 'Sign Up',  onPressed: (){
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
                      ),

                    ],
                  ),
                ),




                SizedBox(height: 15.h,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Already have an account?',style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14.sp,
                      color: AppColors.primaryTextColor,
                    ),),

                    SizedBox(width: 6.w,),
                    InkWell(
                      child: Text('Login',style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                        color: AppColors.primaryColor, // High contrast green
                      ),),
                      onTap: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>LoginScreen()));
                      },
                    ),

                  ],
                )



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
