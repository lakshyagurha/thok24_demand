import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../CustomWidgets/product_card.dart';
import '../../utils/api_constants.dart';
import '../../utils/colors.dart';
import '../bottomNavScreen.dart';
import 'cartScreen.dart';
import 'package:provider/provider.dart';
import '../../CustomWidgets/cart_provider.dart';
import '../../utils/language_provider.dart';


class WishlistScreen extends StatefulWidget {


  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {

  List<dynamic> wishlistProducts = [];
  bool isLoading = true;
  bool isRefreshing = false;
  String userEmail = "";
  String userName = "";
  String userID = "";
  String _lastFetchedLang = '';

  List<Map<String, dynamic>> cartList = [];

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (userID.isNotEmpty) {
      final activeLang = Provider.of<LanguageProvider>(context).currentLanguage;
      if (_lastFetchedLang != activeLang) {
        _lastFetchedLang = activeLang;
        fetchWishlist(userID);
      }
    }
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
            fetchWishlist(userID);
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

  Future<void> fetchWishlist(String userID) async {
    if (userID.isEmpty) return;

    final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
    _lastFetchedLang = lang;

    setState(() {
      isLoading = true;
    });

    try {
      final url = Uri.parse('${ApiConstants.GET_WISHLIST}?user_id=$userID&lang=$lang');
      final response = await http.get(url);

      print("Wishlist API Response: ${response.body}"); // Debugging

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        print("Parsed data keys: ${data.keys.toList()}"); // Debugging: keys देखें
        print("Products key exists: ${data.containsKey('products')}"); // Debugging
        print("Data type of 'products': ${data['products']?.runtimeType}"); // Debugging

        if (data['success'] == true) {

          if (data['products'] != null && data['products'].isNotEmpty) {
            setState(() {
              wishlistProducts = List<Map<String, dynamic>>.from(data['products']);
            });
            print("Loaded ${wishlistProducts.length} products"); // Debugging
          } else {
            setState(() {
              wishlistProducts = [];
            });
            print("No products found in response"); // Debugging
          }
        } else {
          setState(() {
            wishlistProducts = [];
          });
          print("API returned success: false"); // Debugging
        }
      } else {
        print("API error status code: ${response.statusCode}"); // Debugging
        setState(() {
          wishlistProducts = [];
        });
      }
    } catch (e) {
      print('Error fetching wishlist: $e');
      setState(() {
        wishlistProducts = [];
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }



  Future<void> removeFromWishlist(String productId) async {
    try {
      final url = Uri.parse(ApiConstants.REMOVE_FROM_WISHLIST);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userID,
          'product_id': productId,
        }),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        // ✅ सिर्फ local list update करो, दोबारा full fetch की ज़रूरत नहीं
        setState(() {
          wishlistProducts.removeWhere((item) => item['product_id'].toString() == productId);
        });
      }
    } catch (e) {
      print('Error removing from wishlist: $e');
    }
  }

  Future<void> _refreshWishlist() async {
    setState(() {
      isRefreshing = true;
    });
    await fetchWishlist(userID);
    setState(() {
      isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: AppColors.backgroundColor,

      body: Stack(
        children: [
          userID.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 50.sp, color: Colors.grey),
                SizedBox(height: 16.h),
                Text(
                  'Please login to view your wishlist',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: _refreshWishlist,
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : wishlistProducts.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [


                  Icon(Icons.favorite_border, size: 50.sp, color: Colors.grey),
                  SizedBox(height: 16.h),
                  Text(
                    'Your wishlist is empty',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],

              ),
            )


                : Column(
              children: [


                SizedBox(height: 17.h,),
                Container(
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
                  child: Padding(
                    padding:  EdgeInsets.only(top: 10.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(width: 16.w),
                        InkWell(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context)=>BottomNavScreen()));
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
                                child: Icon(Icons.arrow_back_ios, size: 15.sp,color: AppColors.iconColor,),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Text(
                          "Wishlist",
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Spacer(),

                        SizedBox(width: 16.w),
                      ],
                    ),
                  ),
                ),


                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.all(12.w),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16.w,
                      mainAxisSpacing: 16.h,
                      childAspectRatio: 0.42,
                    ),
                    itemCount: wishlistProducts.length,
                    itemBuilder: (context, index) {
                      final product = wishlistProducts[index];
                      return ProductCard(
                        product: product,
                        userId: userID,
                        onCartUpdated: () {
                          fetchCartQuantity(userID); // ✅ Real-time update
                        },
                        onWishlistUpdated: (){
                          fetchWishlist(userID);
                        },

                        onCategoryBack: (){
                          setState(() {
                            fetchCartQuantity(userID);
                          });
                        },
                      );
                    },
                  ),
                )

              ],
            ),
          ),


          // ✅ Floating Cart Button (Only show if cartList is not empty)
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              final uniqueItemsCount = cartProvider.getUniqueItemsCount(userID);
              final hasItems = uniqueItemsCount > 0;

              return AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.slowMiddle,
                bottom: hasItems ? 20.h : -100.h, // Hide below screen
                left: 80.w,
                right: 80.w,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: hasItems ? 1.0 : 0.0, // Fade in/out
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => CartScreen()));
                    },
                    child: Container(
                      height: 38.h,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor, // Brand Green
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
                                  color: AppColors.primaryTextColor,
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

}