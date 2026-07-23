import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/bot_service.dart';
import '../../utils/colors.dart';

class RamuBhaiAvatar extends StatefulWidget {
  final RamuBhaiState state;
  final String speechBubbleText;

  const RamuBhaiAvatar({
    Key? key,
    required this.state,
    required this.speechBubbleText,
  }) : super(key: key);

  @override
  State<RamuBhaiAvatar> createState() => _RamuBhaiAvatarState();
}

class _RamuBhaiAvatarState extends State<RamuBhaiAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant RamuBhaiAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == RamuBhaiState.listening) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 2.h),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Avatar (compact, 50w)
          Stack(
            alignment: Alignment.center,
            children: [
              // Listening pulse animation
              if (widget.state == RamuBhaiState.listening)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 48.w * _pulseAnimation.value,
                      height: 48.w * _pulseAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryColor.withOpacity(0.15),
                      ),
                    );
                  },
                ),
              
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.state == RamuBhaiState.listening
                        ? AppColors.secondaryColor
                        : AppColors.primaryColor,
                    width: 2.0.w,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 3,
                      offset: const Offset(0, 1.5),
                    )
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/ramu_bhai.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade300,
                        child: Icon(Icons.person, size: 24.sp, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ),

              // Thinking overlay indicator
              if (widget.state == RamuBhaiState.thinking)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(2.r),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 2),
                      ],
                    ),
                    child: SizedBox(
                      width: 12.w,
                      height: 12.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                ),

              // Thumbs up sticker
              if (widget.state == RamuBhaiState.thumbsUp)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(2.r),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 2),
                      ],
                    ),
                    child: Text(
                      '👍',
                      style: TextStyle(fontSize: 10.sp),
                    ),
                  ),
                ),
            ],
          ),
          
          SizedBox(width: 8.w),
          
          // 2. Chat bubble
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.neutral50,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                widget.speechBubbleText,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  height: 1.25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
