import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../BottomNav/Screens/cartScreen.dart';
import '../CustomWidgets/product_card.dart';
import '../SearchProduct/search_product.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';
import 'package:provider/provider.dart';
import '../CustomWidgets/cart_provider.dart';
import '../utils/language_provider.dart';

class BrandViewScreen extends StatefulWidget {
  final String brandName;
  const BrandViewScreen({super.key, required this.brandName});

  @override
  State<BrandViewScreen> createState() => _BrandViewScreenState();
}

class _BrandViewScreenState extends State<BrandViewScreen> {
  List allProducts = []; // pura products
  List filteredProducts = []; // brand filter ke baad products
  bool _isLoadingProducts = false;
  List<Map<String, dynamic>> cartList = [];

  String userEmail = "";
  String userName = "";
  String userID = "";

  @override
  void initState() {
    super.initState();
    fetchProducts(); // ek hi api call

    fetchUserData();

  }

  Future<void> fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('user_email');
    if (email != null) {
      setState(() => userEmail = email);
      fetchUserDetails(email);
    }
  }

  Future<void> fetchUserDetails(String email) async {
    final url = Uri.parse(ApiConstants.BASE_URL+"auth/get_user.php?email=$email");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["status"] == "success") {

          setState(() {
            userName = data["user"]["name"];
            userID = data["user"]["id"];
            fetchCartQuantity(userID);
          });
        }
      }
    } catch (e) {
      print("Error fetching user details: $e");
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

  Future<void> fetchProducts() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
    var response = await http.get(Uri.parse("${ApiConstants.VIEW_ALL_PRODUCTS}?lang=$lang"));
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      setState(() {
        allProducts = data["products"];
        filteredProducts = allProducts
            .where((p) => p["brand_name"]?.toString() == widget.brandName)
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: 20.h),

              // ✅ Top AppBar
              buildAppBar(),

              SizedBox(height: 20.h),

              // ✅ Products Grid OR Empty Message
              Expanded(
                child: filteredProducts.isNotEmpty
                    ? buildSection(filteredProducts)
                    : Center(
                  child: Text(
                    Provider.of<LanguageProvider>(context).translate('no_products_found_brand'),
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.hintTextColor,
                    ),textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),


          // ✅ Floating Cart Button (Only show if cart is not empty)
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              final uniqueItemsCount = cartProvider.getUniqueItemsCount(userID);
              final hasItems = uniqueItemsCount > 0;

              return AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.slowMiddle,
                bottom: hasItems ? 40.h : -100.h, // Hide below screen
                left: 80.w,
                right: 80.w,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: hasItems ? 1.0 : 0.0, // Fade in/out
                  child: InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>CartScreen()));
                    },
                    child: Container(
                      height: 38.h,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(30.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.gray,
                                borderRadius: BorderRadius.circular(50.r),
                              ),
                              child: Center(
                                child: Text(
                                  uniqueItemsCount.toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Flexible(
                              child: Text(
                                Provider.of<LanguageProvider>(context).translate('view_cart'),
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.iconColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_forward_ios_outlined, color: AppColors.iconColor, size: 16.sp),
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

  /// ✅ Top AppBar extracted for clarity
  Widget buildAppBar() {
    return Container(
      width: double.infinity,
      height: 60.h,
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: Offset(0, 4),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 16.w),
          InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            child: Container(
              height: 25.h,
              width: 28.w,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: BorderRadius.circular(100),
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
            widget.brandName.toString(),
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          Spacer(),
          InkWell(
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => SearchProduct()));
            },
            child: Container(
              height: 25.h,
              width: 28.w,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(left: 1.w),
                  child: Icon(Icons.search,color: AppColors.iconColor, size: 15.sp),
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
        ],
      ),
    );
  }


  /// ✅ Grid Section
  Widget buildSection(List<dynamic> list) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16.w,
          mainAxisSpacing: 16.h,
          childAspectRatio: 0.42,
        ),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final product = list[index];
          return ProductCard(
            product: product,
            userId: userID,
            onCartUpdated: () {
              fetchCartQuantity(userID); // ✅ Real-time update
            },
          );
        },
      ),
    );
  }
}
