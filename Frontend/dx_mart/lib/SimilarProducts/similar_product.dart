import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../BottomNav/Screens/cartScreen.dart';
import '../CustomWidgets/product_card.dart';
import '../SearchProduct/search_product.dart';
import '../core/supabase.dart';
import '../data/catalog_repository.dart';
import '../design/components/app_header.dart';
import '../design/components/cart_bar.dart';
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
  bool _loading = true;
  bool _failed = false;


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
    setState(() {
      products = [];
      _loading = true;
      _failed = false;
    });

    try {
      final categoryId = int.tryParse(id) ?? 0;
      final result = await const CatalogRepository().productsByCategory(categoryId);
      if (!mounted) return;
      setState(() {
        products = result.map((p) => p.toCardMap()).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('similar products load failed: $e');
      if (!mounted) return;
      // Distinguished from "this category is empty": the previous code set products = []
      // on failure and the build had no else branch at all, so a network error and an
      // empty category both rendered as a blank white screen.
      setState(() {
        products = [];
        _loading = false;
        _failed = true;
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

              // ✅ Products Grid
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (products.isNotEmpty)
                Expanded(child: buildSection(products))
              else
                Expanded(
                  child: _EmptyOrError(
                    failed: _failed,
                    onRetry: () =>
                        fetchAllProductsFromCategory(widget.category_id),
                  ),
                ),
            ],
          ),

        ],
      ),
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cart, _) => CartBar(
          itemCount: cart.getUniqueItemsCount(),
          label: Provider.of<LanguageProvider>(context, listen: false)
              .translate('view_cart'),
          onTap: () {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => CartScreen()));
          },
        ),
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
            AppBackButton(onTap: () => Navigator.pop(context)),
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
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 16.h,
          childAspectRatio: 0.58,
        ),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final product = list[index];
          return ProductCard(
            width: 158.w,
            product: product,
            userId: '',
            onCartUpdated: _refreshCart,
          );
        },
      ),
    );
  }
}

/// Distinguishes "nothing here" from "we could not load it".
///
/// Getting this wrong is not cosmetic for this app's users: a network failure rendered
/// as "no products" tells a shopper the shop is empty when actually their connection
/// dropped, and gives them no reason to try again.
class _EmptyOrError extends StatelessWidget {
  const _EmptyOrError({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failed ? Icons.wifi_off_rounded : Icons.inventory_2_outlined,
            size: 44.sp,
            color: Colors.grey,
          ),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              failed
                  ? lang.translate('network_error_retry')
                  : lang.translate('no_products_found'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
            ),
          ),
          if (failed) ...[
            SizedBox(height: 8.h),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(lang.translate('retry')),
            ),
          ],
        ],
      ),
    );
  }
}
