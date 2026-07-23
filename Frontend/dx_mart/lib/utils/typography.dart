import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTextStyles {
  // Headings
  static TextStyle h1({Color color = AppColors.primaryTextColor}) => GoogleFonts.poppins(
        fontSize: 24.sp,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: color,
      );

  static TextStyle h2({Color color = AppColors.primaryTextColor}) => GoogleFonts.poppins(
        fontSize: 20.sp,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: color,
      );

  static TextStyle h3({Color color = AppColors.primaryTextColor}) => GoogleFonts.poppins(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color,
      );

  // Body
  static TextStyle bodyLarge({Color color = AppColors.primaryTextColor}) => GoogleFonts.poppins(
        fontSize: 16.sp,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  static TextStyle bodyMedium({Color color = AppColors.primaryTextColor}) => GoogleFonts.poppins(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );

  static TextStyle bodySmall({Color color = AppColors.primaryTextColor}) => GoogleFonts.poppins(
        fontSize: 12.sp,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: color,
      );

  // Labels
  static TextStyle labelLarge({Color color = AppColors.primaryTextColor}) => GoogleFonts.poppins(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color,
      );

  static TextStyle labelMedium({Color color = AppColors.primaryTextColor}) => GoogleFonts.poppins(
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color,
      );

  static TextStyle labelSmall({Color color = AppColors.primaryTextColor}) => GoogleFonts.poppins(
        fontSize: 10.sp,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: color,
      );

  // Button text
  static TextStyle buttonText({Color color = AppColors.secondaryTextColor}) => GoogleFonts.poppins(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: color,
      );
}
