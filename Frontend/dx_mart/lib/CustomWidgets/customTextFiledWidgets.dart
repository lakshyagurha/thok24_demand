import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../utils/colors.dart';
import '../utils/typography.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isObscure;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final String? preFixIcon;
  final String? Function(String?)? validator;
  final bool enabled;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.isObscure = false,
    required this.keyboardType,
    this.suffixIcon,
    this.preFixIcon,
    this.validator,
    this.enabled = true,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isObscure,
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      style: AppTextStyles.bodyMedium(color: AppColors.primaryTextColor),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: AppTextStyles.bodyMedium(color: AppColors.neutral500),
        suffixIcon: widget.suffixIcon != null
            ? IconTheme(
                data: const IconThemeData(color: AppColors.neutral500),
                child: widget.suffixIcon!,
              )
            : null,
        prefixIcon: widget.preFixIcon != null
            ? Padding(
                padding: EdgeInsets.all(12.w),
                child: SizedBox(
                  height: 18.w,
                  width: 18.w,
                  child: SvgPicture.asset(
                    widget.preFixIcon!,
                    color: AppColors.primaryColor,
                  ),
                ),
              )
            : null,
        fillColor: AppColors.gray, // Neutral 50 light surface background
        filled: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 12.h,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.neutral200, width: 1.0),
          borderRadius: BorderRadius.all(Radius.circular(10.r)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5),
          borderRadius: BorderRadius.all(Radius.circular(10.r)),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.errorColor, width: 1.0),
          borderRadius: BorderRadius.all(Radius.circular(10.r)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.errorColor, width: 1.5),
          borderRadius: BorderRadius.all(Radius.circular(10.r)),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.neutral200, width: 0.5),
          borderRadius: BorderRadius.all(Radius.circular(10.r)),
        ),
      ),
      validator: widget.validator,
    );
  }
}
