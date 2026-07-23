import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../CustomWidgets/customButton.dart';
import '../CustomWidgets/customTextFiledWidgets.dart';
import '../CustomWidgets/custom_text.dart';
import '../LocationScreen/locationScreen.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';
import 'forgetPassword.dart';
import 'signUpScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  bool _isPasswordVisible = false;
  bool isLoading = false;
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();


  String? validateFields() {
    if (emailController.text.trim().isEmpty) {
      return "Please Enter Email";
    }
    if (passwordController.text.trim().isEmpty) {
      return "Please Enter Email";
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



  Future<void> login() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.LOGIN),
        body: {
          "email": emailController.text,
          "password": passwordController.text,

        },
      );

      final data = json.decode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data["message"],style: TextStyle(color: AppColors.primaryTextColor),),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.primaryColor,
        ),
      );

      if (data["status"] == "success") {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', emailController.text);

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
      login();
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
                 
                  CustomButton(text: 'Login',  onPressed: (){

                    handleSubmit();
                  }),
        
                  SizedBox(height: 10.h,),
                  
                  Center(child: InkWell(
                    child: CustomText(text: "Forget Password",color: AppColors.primaryColor, // High contrast green
                    fontWeight: FontWeight.w500,fontSize: 14.sp,),
                  onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>ForgetPassword()));
                  },
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

