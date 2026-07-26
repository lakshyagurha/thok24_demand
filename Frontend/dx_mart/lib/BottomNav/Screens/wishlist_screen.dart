import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../CustomWidgets/product_card.dart';
import '../../core/supabase.dart';
import '../../data/cart_repository.dart';
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
  String _lastFetchedLang = '';

  List<Map<String, dynamic>> cartList = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Db.isSignedIn) {
      final activeLang = Provider.of<LanguageProvider>(context).currentLanguage;
      if (_lastFetchedLang != activeLang) {
        _lastFetchedLang = activeLang;
        fetchWishlist();
      }
    }
  }

  /// Loads the screen for the signed-in user. There is no id to look up: the old
  /// version read an email from SharedPreferences, called get_user.php to turn it into
  /// an integer id, and then sent that id back to every other endpoint.
  Future<void> _load() async {
    if (!Db.isSignedIn) return;
    await _refreshCart();
    await fetchWishlist();
  }

  /// Cart sync. RLS scopes this to the signed-in user, so there is no id to pass.
  Future<void> _refreshCart() async {
    if (!Db.isSignedIn) return;
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.refreshCartData();
      if (!mounted) return;
      setState(() => cartList = cartProvider.getCartItemsAsList());
    } catch (e) {
      if (mounted) setState(() => cartList = []);
    }
  }

  Future<void> fetchWishlist() async {
    if (!Db.isSignedIn) return;

    _lastFetchedLang =
        Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
    setState(() => isLoading = true);

    try {
      // No user_id and no lang in the request. RLS scopes the rows to the caller, and
      // localisation happens in the widgets via the model's localizedName().
      final products = await const WishlistRepository().items();
      if (!mounted) return;
      setState(() {
        wishlistProducts = products
            .map((p) => {...p.toCardMap(), 'product_id': p.id})
            .toList();
      });
    } catch (e) {
      debugPrint('Error fetching wishlist: $e');
      if (mounted) setState(() => wishlistProducts = []);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }



  Future<void> removeFromWishlist(String productId) async {
    try {
      await const WishlistRepository().remove(int.tryParse(productId) ?? 0);
      if (!mounted) return;
      setState(() {
        wishlistProducts
            .removeWhere((item) => item['product_id'].toString() == productId);
      });
    } catch (e) {
      debugPrint('Error removing from wishlist: $e');
    }
  }

  Future<void> _refreshWishlist() async {
    setState(() {
      isRefreshing = true;
    });
    await fetchWishlist();
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
          !Db.isSignedIn
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
                      crossAxisCount: 2,
                      crossAxisSpacing: 12.w,
                      mainAxisSpacing: 16.h,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: wishlistProducts.length,
                    itemBuilder: (context, index) {
                      final product = wishlistProducts[index];
                      return ProductCard(
                        width: 158.w,
                        product: product,
                        userId: '',
                        onCartUpdated: _refreshCart,
                        onWishlistUpdated: fetchWishlist,
                        onCategoryBack: _refreshCart,
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
              final uniqueItemsCount = cartProvider.getUniqueItemsCount();
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