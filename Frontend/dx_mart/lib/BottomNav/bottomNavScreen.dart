import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/colors.dart';
import '../BolKeOrder/bol_ke_order_screen.dart';
import '../design/haptics.dart';
import 'Screens/categoryScreen.dart';
import 'Screens/homeScreen.dart';
import 'Screens/order_screen.dart';
import 'Screens/wishlist_screen.dart';

class BottomNavScreen extends StatefulWidget {
  const BottomNavScreen({super.key});

  /// Index of the Categories tab, for [openTab].
  static const int categoriesTab = 1;

  /// Lets a child screen move the shell to another tab.
  ///
  /// Home's "All" tile belongs on the Categories *tab*, not on a pushed copy of it:
  /// pushing would stack a second categories screen over the shell, hide the bottom
  /// bar, and leave the user with a back arrow where the nav should be. A notifier
  /// rather than an InheritedWidget because the caller is inside an IndexedStack
  /// child and only ever needs to write.
  static final ValueNotifier<int?> openTab = ValueNotifier<int?>(null);

  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int _currentIndex = 0;

  /// Tabs are built the first time they are opened, not at launch.
  ///
  /// `IndexedStack` builds **every** child immediately, so a cold start used to fire
  /// HomeScreen's six-way `Future.wait`, CategoryScreen's fetch, BolKeOrder's history,
  /// OrderScreen's order list and WishlistScreen's load all at once — a dozen-plus
  /// requests before the user had touched anything, on the connection where it matters
  /// most, and five subtrees resident forever on a 1 GB device.
  ///
  /// IndexedStack is still what renders them, so a tab that HAS been visited keeps its
  /// scroll position and state; unvisited ones are just an empty box until first use.
  final Set<int> _visited = {0};

  Widget _screenAt(int index) => switch (index) {
        0 => HomeScreen(),
        1 => CategoryScreen(),
        3 => OrderScreen(),
        4 => WishlistScreen(),
        _ => const SizedBox.shrink(),
      };

  final List<String> _iconPaths = [
    'assets/svg/home.svg',
    'assets/svg/category_aa.svg',
    '', // Custom rendered voice mic icon — Bol Ke Order chat action
    'assets/svg/order.svg',
    'assets/svg/wishlist.svg',
  ];

  @override
  void initState() {
    super.initState();
    BottomNavScreen.openTab.addListener(_onOpenTabRequested);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Transparent to blend seamlessly with our gradient
      statusBarIconBrightness: Brightness.dark, // Dark icons for high readability on light sage background
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  void _onOpenTabRequested() {
    final target = BottomNavScreen.openTab.value;
    if (target == null || !mounted) return;
    BottomNavScreen.openTab.value = null; // one-shot
    if (target == 2) {
      _openChatScreen();
      return;
    }
    setState(() {
      _currentIndex = target;
      _visited.add(target);
    });
  }

  void _openChatScreen() {
    AppHaptics.tap();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BolKeOrderScreen()),
    );
  }

  @override
  void dispose() {
    BottomNavScreen.openTab.removeListener(_onOpenTabRequested);
    super.dispose();
  }

  Widget _buildNavIcon(String asset, int index) {
    if (index == 2) {
      // Custom microphone action button for Bol Ke Order full-screen chat
      return Container(
        padding: EdgeInsets.all(4.r),
        decoration: BoxDecoration(
          color: AppColors.secondaryColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.mic,
          size: 18.sp,
          color: AppColors.primaryColor,
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
        children: List.generate(
          5,
          (i) => _visited.contains(i)
              ? _screenAt(i)
              : const SizedBox.shrink(),
        ),
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
          if (index == 2) {
            _openChatScreen();
            return;
          }
          setState(() {
            _visited.add(index);
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