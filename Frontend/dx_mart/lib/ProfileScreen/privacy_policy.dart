import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/colors.dart';

class PrivacyPolicy extends StatefulWidget {
  const PrivacyPolicy({super.key});

  @override
  State<PrivacyPolicy> createState() => _PrivacyPolicyState();
}

class _PrivacyPolicyState extends State<PrivacyPolicy> {
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
                          child: Icon(Icons.arrow_back_ios,color: AppColors.iconColor, size: 15.sp),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    "Privacy Policy",
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
                    "Privacy Policy – DxMart",
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    "DxMart respects your privacy and is committed to protecting your personal information. By using our app and services, you agree to the terms mentioned in this Privacy Policy.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("1️⃣ Information We Collect", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• Name, phone number, address, and payment details\n"
                        "• Order history and app usage to provide better service",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("2️⃣ How We Use It", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• To deliver orders quickly and accurately\n"
                        "• To improve app performance and customer support\n"
                        "• To send order updates, offers, and promotions (you can opt out anytime)",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("3️⃣ Data Security", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• We use secure systems and encryption to protect your data\n"
                        "• Your information will never be sold to third parties",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("4️⃣ Your Rights", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• You can update or delete your information anytime by contacting our support team",
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
