import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/colors.dart';

class TermsCondition extends StatefulWidget {
  const TermsCondition({super.key});

  @override
  State<TermsCondition> createState() => _TermsConditionState();
}

class _TermsConditionState extends State<TermsCondition> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 17.h),

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
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 25.h,
                      width: 28.w,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(left: 7.w),
                          child: Icon(Icons.arrow_back_ios, color: AppColors.iconColor, size: 15.sp),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    "Terms & Conditions",
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 18.h),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Terms & Conditions – DxMart",
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    "Welcome to DxMart. By using our app and services, you agree to follow the Terms & Conditions mentioned below. Please read them carefully.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("1️⃣ Use of App", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• You agree to provide accurate details.\n"
                        "• You must not misuse the platform in any way.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("2️⃣ Orders & Pricing", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• Prices may change depending on availability and offers.\n"
                        "• Orders are subject to product stock and availability.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("3️⃣ Payments", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• We accept UPI, cards, wallets, and cash on delivery.\n"
                        "• Failed transactions will be auto-refunded to the original source.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("4️⃣ Cancellations & Refunds", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• Orders can be cancelled before dispatch.\n"
                        "• Perishable goods (fruits, vegetables, dairy) are not eligible for return unless damaged or incorrect.\n"
                        "• Refunds will be processed within 5–7 working days.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("5️⃣ Liability", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• DxMart is not responsible for delays due to weather, traffic, or technical issues.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("6️⃣ Governing Law", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• These terms are governed by the laws of India.",
                    style: sectionText(),
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

  TextStyle sectionTitle() {
    return TextStyle(
      fontSize: 16.sp,
      fontWeight: FontWeight.w700,
      color: AppColors.primaryTextColor,
    );
  }

  TextStyle sectionText() {
    return TextStyle(
      fontSize: 14.sp,
      color: AppColors.hintTextColor,
      height: 1.5,
    );
  }
}
