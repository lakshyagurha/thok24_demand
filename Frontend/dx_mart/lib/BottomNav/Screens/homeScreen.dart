import 'dart:convert';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../CategoryViewScreen/categoryViewScreen.dart';
import '../../CustomWidgets/product_card.dart';
import '../../LocationScreen/locationScreen.dart';
import '../../SearchProduct/search_product.dart';
import '../../utils/api_constants.dart';
import '../../utils/colors.dart';
import 'cartScreen.dart';
import 'profileScreen.dart';
import 'package:provider/provider.dart';
import '../../CustomWidgets/cart_provider.dart';
import '../../utils/language_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Scroll controller for detecting scroll direction
  final ScrollController _scrollController = ScrollController();
  bool _showStickySearchBar = false;
  double _scrollPosition = 0;

  // Data variables
  String deliveryTime = '15 minutes';
  String district = '';
  String city = '';
  String userName = "";
  String userEmail = "";
  String userId = "";
  bool _isLoading = true;
  List _categoryList = [];
  List _sliderList = [];


  // Category position lists
  List<dynamic> mainFirstCategoryList = [];
  List<dynamic> mainSecondCategoryList = [];
  List<dynamic> mainThirdCategoryList = [];
  List<dynamic> mainFourthCategoryList = [];

  // Product type lists
  List everydayEssentialsList = [];
  List bestSellingList = [];
  List hotDealsList = [];
  List exclusiveOffersList = [];
  List newlyLaunchList = [];
  List readyToEatList = [];
  List<Map<String, dynamic>> cartList = [];
  String _lastFetchedLang = '';

  // Banner images
  String? bannerImage;
  String? discount_bannerImage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    // initState will trigger _loadAllData on first build dependency setup
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final activeLang = Provider.of<LanguageProvider>(context).currentLanguage;
    if (_lastFetchedLang != activeLang) {
      _lastFetchedLang = activeLang;
      _loadAllData();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final double currentScroll = _scrollController.offset;

    // Show sticky search bar when scrolling down beyond a certain point
    if (currentScroll > 100 && currentScroll > _scrollPosition) {
      if (!_showStickySearchBar) {
        setState(() {
          _showStickySearchBar = true;
        });
      }
    }
    // Hide sticky search bar when scrolling up or at the top
    else if (currentScroll <= 100 || currentScroll < _scrollPosition) {
      if (_showStickySearchBar) {
        setState(() {
          _showStickySearchBar = false;
        });
      }
    }

    _scrollPosition = currentScroll;
  }

  Future<void> _loadAllData() async {
    _lastFetchedLang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        // Basic user data
        fetchUserData(),
        fetchDeliveryTime(),
        loadLocation(),
        fetchUserData(),

        // Categories and banners
        _fetchCategories(),


        _fetchSlider(),


        // Products
        loadAllTypes(),
      ]);
    } catch (e) {
      _showSnackBar("Error loading data: $e", AppColors.errorColor);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }



  Future<void> fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('user_email');
    if (email != null) {
      setState(() => userEmail = email);
      await fetchUserDetails(email);
    }
  }

  Future<void> fetchUserDetails(String email) async {
    final url = Uri.parse(ApiConstants.BASE_URL + "auth/get_user.php?email=$email");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["status"] == "success") {
          setState(() {
            userName = data["user"]["name"];
            userId = data["user"]["id"];
            fetchCartQuantity(userId);
          });
        }

      }
    } catch (e) {
      debugPrint("Error fetching user details: $e");
    }
  }

  /// ✅ Cart quantity fetch
  Future<void> fetchCartQuantity(String id) async {
    if (id.isEmpty) return;
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.refreshCartData(id);
      setState(() {
        cartList = cartProvider.getCartItemsAsList(id);
      });
    } catch (e) {
      setState(() {
        cartList = [];
      });
    }
  }



  Future<void> loadLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      district = prefs.getString('selected_district_name') ?? 'Not Set';
      city = prefs.getString('selected_city_name') ?? 'Not Set';
    });
  }

  Future<void> fetchDeliveryTime() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.DELIVERY_TIME));
      final data = json.decode(response.body);
      if (data['success']) {
        setState(() => deliveryTime = data['data']['time']);
      }
    } catch (e) {
      setState(() => deliveryTime = 'Error fetching time');
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
      final response = await http.get(Uri.parse("${ApiConstants.MAIN_VIEW_CATEGORY}?lang=$lang"));
      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);
        setState(() {
          _categoryList = decoded.where((category) {
            final name = (category['name'] ?? '').toString().toLowerCase();
            return !name.contains('electronic') && 
                   !name.contains('appliance') && 
                   !name.contains('fashion') && 
                   !name.contains('clothing') &&
                   !name.contains('wear');
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
    }
  }




  Future<void> loadAllTypes() async {
    await Future.wait([
      fetchProductsByType('Everyday Essentials'),
      fetchProductsByType('Best Selling'),
      fetchProductsByType('Hot Deals'),
    ]);
  }


  Future<void> fetchProductsByType(String type) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
    final url = Uri.parse("${ApiConstants.VIEW_PRODUCT_BY_TYPE}?type=$type&page=1&limit=10&lang=$lang");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success']) {
          setState(() {
            switch (type) {
              case 'Everyday Essentials':
                everydayEssentialsList = body['products'];
                break;
              case 'Best Selling':
                bestSellingList = body['products'];
                break;
              case 'Hot Deals':
                hotDealsList = body['products'];
                break;

            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching $type products: $e");
    }
  }




  Future<void> _fetchSlider() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.VIEW_SLIDER));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() => _sliderList = jsonResponse['data']['offer_banners']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching slider: $e");
    }
  }


  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shaded Header Section (Calming Sage Green Gradient)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(bottom: 20.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFD2E5DC), // Calm Eucalyptus/Sage Green
                        Color(0xFFEAF2EE), // Soothing Light Sage/Mint
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24.r),
                      bottomRight: Radius.circular(24.r),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 10.h, left: 16.w, right: 16.w),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Delivery time with lightning bolt (Zepto style)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.flash_on,
                                    color: Color(0xFF0F4E34),
                                    size: 20.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    deliveryTime,
                                    style: GoogleFonts.roboto(
                                      color: Color(0xFF0F4E34),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18.sp,
                                    ),
                                  ),
                                ],
                              ),
                              Spacer(),

                              // Profile Icon Button
                              InkWell(
                                onTap: (){
                                  Navigator.push(context, MaterialPageRoute(builder: (context)=>ProfileScreen()));
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20.r),
                                    border: Border.all(color: Color(0xFFC2D9CD), width: 1.0),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        userName.length > 10 ? userName.substring(0, 10) : userName + "!",
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.roboto(
                                          fontSize: 11.sp, 
                                          fontWeight: FontWeight.bold, 
                                          color: Color(0xFF0F4E34),
                                        ),
                                      ),
                                      SizedBox(width: 4.w),
                                      SvgPicture.asset(
                                        'assets/svg/h_profile.svg',
                                        width: 14.w,
                                        height: 14.h,
                                        color: Color(0xFF0F4E34),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Location/Address Row (clean inline style like Zepto)
                        Padding(
                          padding: EdgeInsets.only(top: 6.h, left: 16.w, right: 16.w),
                          child: InkWell(
                            onTap: (){
                              Navigator.push(context, MaterialPageRoute(builder: (context)=>LocationScreen()));
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${Provider.of<LanguageProvider>(context).translate('deliver_to')} - ",
                                  style: GoogleFonts.roboto(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF0F4E34).withOpacity(0.7),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    "$district, $city",
                                    style: GoogleFonts.roboto(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F4E34),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 2.w),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 16.sp,
                                  color: Color(0xFF0F4E34),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 14.h),

                        // Search Container
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: InkWell(
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (context)=>SearchProduct()));
                            },
                            child: Container(
                              width: double.infinity,
                              height: 38.h,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: Color(0xFFC2D9CD), width: 1.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12.w),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search, size: 20.sp, color: Color(0xFF0F4E34)),
                                    SizedBox(width: 8.w),
                                    Text(
                                      Provider.of<LanguageProvider>(context).translate('search_placeholder'),
                                      style: GoogleFonts.roboto(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    Spacer(),
                                    Icon(Icons.mic, size: 18.sp, color: Color(0xFF0F4E34)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        if (_sliderList.isNotEmpty) ...[
                          SizedBox(height: 16.h),
                          // Slider / Carousel
                          CarouselSlider(
                            options: CarouselOptions(
                              height: 130.h,
                              autoPlay: true,
                              enlargeCenterPage: false,
                              viewportFraction: 0.85,
                              aspectRatio: 16 / 9,
                              autoPlayInterval: Duration(seconds: 4),
                              enableInfiniteScroll: true,
                              scrollPhysics: BouncingScrollPhysics(),
                            ),
                            items: _sliderList.map((item) {
                              return Builder(
                                builder: (BuildContext context) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                    child: InkWell(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16.r),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.06),
                                              blurRadius: 8,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16.r),
                                          child: Image.network(
                                            ApiConstants.BASE_URL + 'banner_api/' + item['banner_image'],
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 130.h,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: Colors.grey.shade200,
                                              child: Icon(Icons.error, color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                      ),
                                      onTap: (){
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CategoryViewScreen(
                                              categoryId: int.tryParse(item['category_id'].toString()) ?? 0,
                                              categoryName: item['category_name']?.toString() ?? 'Category',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        ],

                        SizedBox(height: 16.h),

                        // Curated Promo Mini Cards
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildPromoCard(
                                title: "Farm Fresh",
                                subtitle: "Up to 40% OFF",
                                tag: "VEGGIES & FRUITS",
                                startColor: Color(0xFFE2F0D9),
                                endColor: Color(0xFFC5E0B4),
                                textColor: Color(0xFF385723),
                                categoryKeyword: "fruit",
                              ),
                              _buildPromoCard(
                                title: "Dairy Hub",
                                subtitle: "Flat 15% OFF",
                                tag: "MILK & BREAD",
                                startColor: Color(0xFFFFF2CC),
                                endColor: Color(0xFFFCE4D6),
                                textColor: Color(0xFF7F6000),
                                categoryKeyword: "dairy",
                              ),
                              _buildPromoCard(
                                title: "Saver Deals",
                                subtitle: "Min 20% OFF",
                                tag: "GROCERY ESSENTIALS",
                                startColor: Color(0xFFFCE4D6),
                                endColor: Color(0xFFF8CBAD),
                                textColor: Color(0xFFC65911),
                                categoryKeyword: "atta",
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Shop by Category section
                Padding(
                  padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 20.h, bottom: 12.h),
                  child: Text(
                    Provider.of<LanguageProvider>(context).translate('categories'),
                    style: GoogleFonts.roboto(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827), // Neutral 900
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12.h,
                      crossAxisSpacing: 10.w,
                      childAspectRatio: 0.60,
                    ),
                    itemCount: _categoryList.length > 8 ? 8 : _categoryList.length,
                    itemBuilder: (context, index) {
                      final item = _categoryList[index];
                      return GestureDetector(
                        onTap: (){
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CategoryViewScreen(
                                categoryId: int.tryParse(item['id'].toString()) ?? 0,
                                categoryName: item['name']?.toString() ?? 'Category',
                              ),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 64.w,
                              height: 64.w,
                              decoration: BoxDecoration(
                                color: Color(0xFFF3F7F5), // Calming off-white/pale mint background
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(color: Color(0xFFE8F1EC), width: 1.0),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(6.w),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10.r),
                                  child: Image.network(
                                    ApiConstants.BASE_URL + "main_category/${item['image']}",
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported, color: Color(0xFF1B6E4A)),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 6.h),
                            SizedBox(
                              width: 72.w,
                              child: Text(
                                item['name'] ?? '',
                                style: GoogleFonts.roboto(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Products
                SizedBox(height: 20.h),

                // Everyday Essentials
                if (everydayEssentialsList.isNotEmpty)
                  buildSection('Everyday Essentials', everydayEssentialsList),

                // Best Selling
                if (bestSellingList.isNotEmpty) ...[
                  SizedBox(height: 20.h),
                  buildSection('Best Selling', bestSellingList),
                ],

                // Hot Deals
                if (hotDealsList.isNotEmpty) ...[
                  SizedBox(height: 20.h),
                  buildSection('Hot Deals', hotDealsList),
                ],
                SizedBox(height: 100.h),
              ],
            ),
          ),

          // Sticky Search Bar
          AnimatedPositioned(
            duration: Duration(milliseconds: 400),
            top: _showStickySearchBar ? 0 : -87.h,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(left: 16.w,right: 16.w,top: 35.h,bottom: 16.w),
              decoration: BoxDecoration(
                color: Color(0xFFD2E5DC), // matching our calming sage green header
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20)
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context)=>SearchProduct()));
                },
                child: Container(
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Color(0xFFC2D9CD), width: 1.0),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 20.sp, color: Color(0xFF0F4E34)),
                        SizedBox(width: 8.w),
                        Text(Provider.of<LanguageProvider>(context).translate('search_placeholder'), style: GoogleFonts.roboto(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0F4E34).withOpacity(0.8),
                        )),
                        Spacer(),
                        Icon(Icons.mic, size: 18.sp, color: Color(0xFF0F4E34)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              final uniqueItemsCount = cartProvider.getUniqueItemsCount(userId);
              final hasItems = uniqueItemsCount > 0;

              return AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.slowMiddle,
                bottom: hasItems ? 20.h : -60.h,
                left: 20.w, // Wider pill for better visual presence & touch target
                right: 20.w,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: hasItems ? 1.0 : 0.0,
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => CartScreen()));
                    },
                    child: Container(
                      height: 48.h, // Increased from 38.h for premium feel and accessible tap size
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(16.r), // Modern rounded rectangle
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Row(
                          children: [
                            Container(
                              width: 28.w,
                              height: 28.w,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2), // Dim white badge background
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Center(
                                child: Text(
                                  uniqueItemsCount.toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.sp,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Flexible(
                              child: Text(
                                Provider.of<LanguageProvider>(context).translate('view_cart'),
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            const Icon(Icons.arrow_forward_ios_outlined, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          )
        ],
      ),
    );
  }



  Widget _buildPromoCard({
    required String title,
    required String subtitle,
    required String tag,
    required Color startColor,
    required Color endColor,
    required Color textColor,
    required String categoryKeyword,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          final category = _categoryList.firstWhere(
            (c) => (c['name'] ?? '').toString().toLowerCase().contains(categoryKeyword.toLowerCase()),
            orElse: () => null,
          );
          if (category != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryViewScreen(
                  categoryId: int.tryParse(category['id'].toString()) ?? 0,
                  categoryName: category['name']?.toString() ?? 'Category',
                ),
              ),
            );
          }
        },
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
          height: 95.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [startColor, endColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: textColor.withOpacity(0.06),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.roboto(
                    fontSize: 7.5.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.roboto(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.roboto(
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w600,
                      color: textColor.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSection(String title, List<dynamic> list) {
    final langProvider = Provider.of<LanguageProvider>(context);
    String displayTitle = title;
    if (title == 'Everyday Essentials') {
      displayTitle = langProvider.translate('everyday_essentials');
    } else if (title == 'Best Selling') {
      displayTitle = langProvider.translate('best_selling');
    } else if (title == 'Hot Deals') {
      displayTitle = langProvider.translate('hot_deals');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 10.h),
          child: Text(
            displayTitle,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
        ),
        SizedBox(
          height: 220.w,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            padding: EdgeInsets.only(left: 16.w, right: 8.w),
            itemBuilder: (context, index) {
              final product = list[index];
              return Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: SizedBox(
                  width: 120.w,
                  child: ProductCard(
                    product: product,
                    userId: userId,
                    onCartUpdated: () {
                      fetchCartQuantity(userId);
                    },
                    onCategoryBack: () {
                      setState(() {
                        fetchCartQuantity(userId);
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }


}