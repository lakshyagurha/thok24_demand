import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

import '../BottomNav/bottomNavScreen.dart';
import '../CustomWidgets/customButton.dart';
import '../CustomWidgets/customTextFiledWidgets.dart';
import '../CustomWidgets/custom_text.dart';
import '../LocationScreen/locationScreen.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';
import 'loginScreen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {

  bool _isPasswordVisible = false;
  bool isLoading = false;

  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  String? validateFields() {
    if (nameController.text.trim().isEmpty) {
      return "Please Enter Name";
    }
    if (emailController.text.trim().isEmpty) {
      return "Please Enter Email";
    }
    if (passwordController.text.trim().isEmpty) {
      return "Please Enter Password";
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

  Future<void> signup() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.SIGNUP),
        body: {
          "name": nameController.text,
          "email": emailController.text,
          "password": passwordController.text,
          "date_time": DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now()),
        },
      );

      final data = json.decode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data["message"]),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.primaryColor,
        ),
      );

      if (data["status"] == "success") {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', emailController.text);

        nameController.clear();
        emailController.clear();
        passwordController.clear();

        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>LocationScreen()));
      }
    } catch (e) {
      _showSnackBar('Something went wrong. Try again.');
    } finally {
      setState(() {
        isLoading = false;
      });
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
      body: SingleChildScrollView(
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

                  CustomText(text: "Email Address",fontSize: 12.sp,),
                  SizedBox(height: 7.h,),

                  CustomTextField(
                      controller: emailController,
                      keyboardType: TextInputType.text,
                      preFixIcon: 'assets/svg/email.svg',
                      hintText: "example@gmail.com"),


                  SizedBox(height: 17.h,),
                  CustomText(text: "Password",fontSize: 12.sp,),

                  SizedBox(height: 7.h,),

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


                  SizedBox(height: 20.h,),

                  CustomButton(text: 'Sign Up',  onPressed: (){

                    handleSubmit();
                  }),

                  SizedBox(height: 10.h,),



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
