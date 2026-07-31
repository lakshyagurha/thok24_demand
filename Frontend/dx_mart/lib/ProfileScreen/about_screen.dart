import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../design/components/app_header.dart';
import '../utils/colors.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),

          // Header
          Container(
            width: double.infinity,
            height: 60.h,
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: Offset(0, 4.h),
                  blurRadius: 6.r,
                  spreadRadius: 1.r,
                ),
              ],
            ),
            child: Padding(
              padding:  EdgeInsets.only(top: 10.h),
              child: Row(
                children: [
                  SizedBox(width: 16.w),
                  AppBackButton(onTap: () => Navigator.pop(context)),
                  SizedBox(width: 16.w),
                  Text(
                    "About",
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20.h),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome to DxMart",
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    "DxMart is Kadapa’s very own 10-minute grocery delivery app. We began with a simple mission: to make daily essentials available faster, fresher, and at fair prices — right at your doorstep.",
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.hintTextColor,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    "From fresh fruits and vegetables to snacks, dairy, and household items, everything you need is just a tap away. No long waits, no compromise on quality — only quick and reliable service.",
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.hintTextColor,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    "Our dark stores in Kadapa are built to pick, pack, and dispatch your orders within minutes. This ensures lightning-fast delivery while maintaining freshness and quality in every order.",
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.hintTextColor,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 15.h),
                  Center(
                    child: Text(
                      "Mana Kadapa, Mana App – DxMart\nFast. Fresh. At Your Doorstep.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryTextColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
