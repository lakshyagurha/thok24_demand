import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../BottomNav/Screens/cartScreen.dart';
import '../CustomWidgets/product_card.dart';
import '../SearchProduct/search_product.dart';
import '../core/supabase.dart';
import '../data/catalog_repository.dart';
import '../utils/colors.dart';
import 'package:provider/provider.dart';
import '../CustomWidgets/cart_provider.dart';
import '../utils/language_provider.dart';

class SimilarProduct extends StatefulWidget {
  final String category_id;
  final String category_name;

  SimilarProduct({
    required this.category_id,
    required this.category_name,
  });

  @override
  State<SimilarProduct> createState() => _SimilarProductState();
}

class _SimilarProductState extends State<SimilarProduct> {
  List products = [];
  List<Map<String, dynamic>> cartList = [];


  @override
  void initState() {
    super.initState();
    _refreshCart();
    fetchAllProductsFromCategory(widget.category_id);
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

  /// Products fetch. Localisation is applied in the widgets via the model's
  /// localizedName(), so the language no longer travels to the server as a query param.
  Future<void> fetchAllProductsFromCategory(String id) async {
    setState(() => products = []);

    try {
      final categoryId = int.tryParse(id) ?? 0;
      final result = await const CatalogRepository().productsByCategory(categoryId);
      if (!mounted) return;
      setState(() => products = result.map((p) => p.toCardMap()).toList());
    } catch (e) {
      if (mounted) setState(() => products = []);
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

              // ✅ Products Grid
              // TODO(tranche-F): no loading or empty branch here — while the fetch is in
              // flight, and on any error, the user sees a blank white screen. Needs a
              // spinner, an empty state and a retry affordance.
              if (products.isNotEmpty)
                Expanded(child: buildSection(products)),
            ],
          ),

          // ✅ Floating Cart Button (Only show if cart is not empty)
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              final uniqueItemsCount = cartProvider.getUniqueItemsCount();
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
      child: Padding(
        padding:  EdgeInsets.only(top: 10.h),
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
              Provider.of<LanguageProvider>(context).translate('similar_products'),
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryTextColor
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
            userId: '',
            onCartUpdated: _refreshCart,
          );
        },
      ),
    );
  }
}
