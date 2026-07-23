import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/colors.dart';

class ReturnPolicy extends StatefulWidget {
  const ReturnPolicy({super.key});

  @override
  State<ReturnPolicy> createState() => _ReturnPolicyState();
}

class _ReturnPolicyState extends State<ReturnPolicy> {
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
                    "Shipping Policy",
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
                    "Shipping Policy – DxMart",
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    "At DxMart, we promise fast, reliable, and safe delivery in Kadapa.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("⏱ Delivery Time:", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "Most orders are delivered within 10 minutes of confirmation.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("📍 Service Areas:", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "Currently available across Kadapa city limits.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("💰 Delivery Charges:", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• Free delivery on orders above ₹199.\n"
                        "• For smaller orders, a minimal delivery fee applies.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("⚠ Possible Delays:", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "In rare cases like bad weather, traffic, or stock issues, "
                        "delivery may take longer. We’ll notify you instantly through the app.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("🤝 Contactless Delivery:", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "Available on request for your safety and convenience.",
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
