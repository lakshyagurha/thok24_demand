import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/colors.dart';
import '../utils/typography.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const double borderRadiusValue = 12.0;
    
    return Container(
      width: double.infinity,
      height: 48.h, // Accessible touch target size
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: BorderRadius.circular(borderRadiusValue.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadiusValue.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadiusValue.r),
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: AppTextStyles.buttonText(color: AppColors.secondaryTextColor),
            ),
          ),
        ),
      ),
    );
  }
}
