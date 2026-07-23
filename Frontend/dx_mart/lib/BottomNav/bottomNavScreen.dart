import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/colors.dart';
import '../BolKeOrder/bol_ke_order_screen.dart';
import 'Screens/categoryScreen.dart';
import 'Screens/homeScreen.dart';
import 'Screens/order_screen.dart';
import 'Screens/wishlist_screen.dart';

class BottomNavScreen extends StatefulWidget {
  const BottomNavScreen({super.key});

  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    HomeScreen(),
    CategoryScreen(),
    const BolKeOrderScreen(), // Central Voice tab
    OrderScreen(),
    WishlistScreen(),
  ];

  final List<String> _iconPaths = [
    'assets/svg/home.svg',
    'assets/svg/category_aa.svg',
    '', // Custom rendered voice mic icon
    'assets/svg/order.svg',
    'assets/svg/wishlist.svg',
  ];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Transparent to blend seamlessly with our gradient
      statusBarIconBrightness: Brightness.dark, // Dark icons for high readability on light sage background
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  Widget _buildNavIcon(String asset, int index) {
    if (index == 2) {
      // Custom microphone widget for Bol Ke Order
      return Container(
        padding: EdgeInsets.all(3.r),
        decoration: BoxDecoration(
          color: _currentIndex == index 
              ? AppColors.secondaryColor 
              : AppColors.primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.mic,
          size: 16.sp,
          color: _currentIndex == index
              ? AppColors.primaryColor
              : Colors.grey.shade700,
        ),
      );
    }

    return SvgPicture.asset(
      asset,
      color: _currentIndex == index
          ? AppColors.primaryColor // Brand Green active tint
          : Colors.grey.shade600,
      width: 20.w,
      height: 20.h,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Stack(
        children: [
          Container(
            height: 55.h,
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              border: Border(
                top: BorderSide(
                  color: Color(0xFFE5E7EB), // Premium thin border
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                _buildBottomButton(0),
                _buildBottomButton(1),
                _buildBottomButton(2),
                _buildBottomButton(3),
                _buildBottomButton(4),
              ],
            ),
          ),

          // Animated Indicator with transition (Brand Green)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            left: _calculateIndicatorPosition(),
            child: Container(
              width: 44.w,
              height: 2.5.h,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(10.r),
                  bottomRight: Radius.circular(10.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateIndicatorPosition() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double indicatorWidth = 44.w;
    final double itemWidth = screenWidth / 5;

    return (_currentIndex * itemWidth) + (itemWidth / 2) - (indicatorWidth / 2);
  }

  Widget _buildBottomButton(int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 4.h), // Clean spacing to fit text labels
          color: Colors.transparent, // Ensures clickable area
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildNavIcon(_iconPaths[index], index),
              SizedBox(height: 2.h),
              Text(
                _getLabel(index),
                style: GoogleFonts.roboto(
                  fontSize: 8.5.sp,
                  fontWeight: _currentIndex == index ? FontWeight.bold : FontWeight.w500,
                  color: _currentIndex == index
                      ? AppColors.primaryColor // Brand Green text
                      : Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Text labels mapping
  String _getLabel(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Category';
      case 2:
        return 'Bol Ke Order';
      case 3:
        return 'Orders';
      case 4:
        return 'Wishlist';
      default:
        return '';
    }
  }
}