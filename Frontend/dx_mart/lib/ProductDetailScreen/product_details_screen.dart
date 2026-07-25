import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:provider/provider.dart';
import '../BottomNav/Screens/cartScreen.dart';
import '../CategoryViewScreen/categoryViewScreen.dart';
import '../CustomWidgets/cart_provider.dart';
import '../CustomWidgets/product_card.dart';
import '../SearchProduct/search_product.dart';
import '../SimilarProducts/similar_product.dart';
import '../core/supabase.dart';
import '../data/cart_repository.dart';
import '../data/catalog_repository.dart';
import '../utils/colors.dart';
import '../utils/language_provider.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsScreen({Key? key, required this.product})
      : super(key: key);

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  String userEmail = "";
  String userName = "";
  int selectedVariantIndex = 0;
  final _pageController = PageController();
  bool _showDetails = false;
  String deliveryTime = '17 MIN';
  String CATEGORY_ID = "";
  List<Map<String, dynamic>> _couponList = [];
  List products = [];
  bool isLoading = false;
  List<Map<String, dynamic>> cartList = [];

  // Local mutable product copy — updated on every language change
  late Map<String, dynamic> _localProduct;
  String _lastFetchedLang = '';

  @override
  void initState() {
    super.initState();
    _localProduct = Map<String, dynamic>.from(widget.product);
    fetchCartQuantities();
    // Coerce rather than cast: callers supply this key as an int (`Product.toCardMap`,
    // the voice bot) and as a String elsewhere, and an implicit int -> String cast here
    // threw in initState, killing the whole screen.
    CATEGORY_ID = widget.product['main_category_id']?.toString() ?? '';
    fetchDeliveryTime();
    _fetchCoupons();
    fetchAllProductsFromCategory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final activeLang = Provider.of<LanguageProvider>(context).currentLanguage;
    if (_lastFetchedLang != activeLang) {
      _lastFetchedLang = activeLang;
      _fetchProductDetails(activeLang);
    }
  }

  /// Re-reads the product. All three language variants come back on the row, so the
  /// active language is applied in the widgets rather than sent to the server.
  Future<void> _fetchProductDetails(String lang) async {
    final productId = int.tryParse('${widget.product['id'] ?? ''}') ?? 0;
    if (productId == 0) return;
    try {
      final product = await const CatalogRepository().product(productId);
      if (product == null || !mounted) return;
      setState(() {
        _localProduct = product.toCardMap();
        CATEGORY_ID = product.mainCategoryId.toString();
        final variants = _localProduct['variants'] as List?;
        if (variants != null && selectedVariantIndex >= variants.length) {
          selectedVariantIndex = 0;
        }
      });
    } catch (e) {
      debugPrint('Error re-fetching product: $e');
    }
  }





  /// Cart sync. RLS scopes this to the signed-in user, so there is no id to pass.
  Future<void> fetchCartQuantities() async {
    if (!Db.isSignedIn) return;
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.refreshCartData();
      if (!mounted) return;
      setState(() => cartList = cartProvider.getCartItemsAsList());
    } catch (e) {
      debugPrint('Error fetching cart quantities: $e');
    }
  }

  Future<void> addToCart() async {
    final variant = _localProduct['variants'][selectedVariantIndex];
    final int stock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;

    // 🛑 Stock check
    if (stock <= 0) {
      Fluttertoast.showToast(
        msg: Provider.of<LanguageProvider>(context, listen: false).translate('product_out_of_stock_msg'),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final variantId = variant['id'].toString();
      final productId = _localProduct['id'].toString();

      // The stored PATH, not a built URL: the host is applied at render time.
      final imagePath = (_localProduct['images'] != null &&
              (_localProduct['images'] as List).isNotEmpty)
          ? '${_localProduct['images'][0]}'
          : '';

      await const CartRepository().add(
        productId: int.tryParse(productId) ?? 0,
        variantId: int.tryParse(variantId),
        quantity: 1,
        imagePath: imagePath,
      );

      if (!mounted) return;
      // Re-read rather than guessing the new row id locally.
      await Provider.of<CartProvider>(context, listen: false).refreshCartData();

    } catch (e) {
      debugPrint("Error adding to cart: $e");
      Fluttertoast.showToast(
        msg: "Something went wrong!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> updateQuantity(int newQuantity) async {
    final variant = _localProduct['variants'][selectedVariantIndex];
    final variantId = variant['id'].toString();
    final productId = _localProduct['id'].toString();

    setState(() {
      isLoading = true;
    });

    try {
      // 🟢 Stock check
      final stock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;
      if (newQuantity > stock) {
        Fluttertoast.showToast(
          msg: "Only $stock items available in stock",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: AppColors.errorColor,
          textColor: Colors.white,
        );
        return;
      }

      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      int cartId = cartProvider.getCartId('', productId, variantId);

      // If cartId is 0, try to find it by making a direct API call
      if (cartId == 0) {
        cartId = await _findCartIdDirectly('', productId, variantId);

        if (cartId == 0) {
          print("⚠️ Cart item not found in server either");
          Fluttertoast.showToast(
            msg: "Cart item not found. Please add it again.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
          return;
        }
      }

      // RLS makes another user's row invisible, so this can only affect the caller's.
      await const CartRepository()
          .setQuantity(cartItemId: cartId, quantity: newQuantity);

      if (mounted) {
        cartProvider.updateCartQuantities(
          '',
          productId,
          variantId,
          newQuantity,
          cartId,
        );
      }
    } catch (e) {
      debugPrint('Error updating quantity: $e');
      Fluttertoast.showToast(
        msg: "Network error. Please try again.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Re-syncs from the server and returns the row id, if any. The old version hit a
  /// second endpoint with user_id in the query string to do this.
  Future<int> _findCartIdDirectly(
      String _, String productId, String variantId) async {
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.refreshCartData();
      return cartProvider.getCartId('', productId, variantId);
    } catch (e) {
      debugPrint('Error resolving cart id: $e');
      return 0;
    }
  }



  Future<void> removeFromCart() async {
    final variant = _localProduct['variants'][selectedVariantIndex];
    final variantId = variant['id'].toString();
    final productId = _localProduct['id'].toString();

    setState(() {
      isLoading = true;
    });

    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final cartId = cartProvider.getCartId('', productId, variantId);
      if (cartId == 0) return;

      await const CartRepository().remove(cartId);
      if (mounted) cartProvider.removeCartItem('', productId, variantId);
    } catch (e) {
      debugPrint('Error removing from cart: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchAllProductsFromCategory() async {
    setState(() => products = []);
    try {
      final categoryId = int.tryParse(CATEGORY_ID) ?? 0;
      final result =
          await const CatalogRepository().productsByCategory(categoryId);
      if (!mounted) return;
      setState(() => products = result.map((p) => p.toCardMap()).toList());
    } catch (e) {
      debugPrint("Error fetching products: $e");
      if (mounted) setState(() => products = []);
    }
  }

  /// Only status='Public' coupons are listable; RLS hides private codes so they cannot
  /// be enumerated from a client.
  Future<void> _fetchCoupons() async {
    try {
      final coupons = await const CatalogRepository().publicCoupons();
      if (!mounted) return;
      setState(() {
        _couponList = coupons
            .map((c) => {
                  'id': c.id,
                  'title': c.title,
                  'description': c.description,
                  'code_name': c.codeName,
                  'discount': c.discount,
                  'min_amount': c.minAmount,
                  'expiry_date':
                      c.expiryDate?.toIso8601String().split('T').first,
                  'status': 'Public',
                })
            .toList();
      });
    } catch (e) {
      debugPrint("Error fetching coupons: $e");
    }
  }

  Future<void> fetchDeliveryTime() async {
    try {
      // Was its own endpoint and single-row table; now one app_settings key.
      final settings = await const CatalogRepository().settings();
      final time = settings['delivery_time'];
      if (!mounted) return;
      if (time != null && time.isNotEmpty) setState(() => deliveryTime = time);
    } catch (e) {
      debugPrint('Error fetching delivery time: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    final productId = _localProduct['id'].toString();
    final List variants = _localProduct['variants'] ?? [];
    // Guard: ensure selectedVariantIndex is in bounds after language re-fetch
    if (selectedVariantIndex >= variants.length && variants.isNotEmpty) {
      selectedVariantIndex = 0;
    }
    final variantId = variants.isNotEmpty
        ? variants[selectedVariantIndex]['id'].toString()
        : '';
    final currentQuantity = cartProvider.getQuantity(
      '',
      productId,
      variantId,
    );

    final List images = _localProduct['images'] ?? [];
    final String productName = _localProduct['name'] ?? '';
    final currentVariant = variants.isNotEmpty ? variants[selectedVariantIndex] : {};
    final double price =
        double.tryParse(currentVariant['price']?.toString() ?? '0') ?? 0;
    final int stock =
        int.tryParse(currentVariant['stock']?.toString() ?? '0') ?? 0;
    final double sellingPrice =
        double.tryParse(currentVariant['selling_price']?.toString() ?? '0') ??
            0;
    final int discount =
        price > 0 ? (((price - sellingPrice) / price) * 100).round() : 0;

    final List info = _localProduct['info'] ?? [];
    final List allHighlights = _localProduct['highlights'] ?? [];
    final List highlights = allHighlights
        .where((item) => !(item['attribute'] ?? '')
            .toString()
            .toLowerCase()
            .contains('nutrition'))
        .toList();

    final String subCategoryName = _localProduct['subcategory'] ?? '';
    final String category_id = _localProduct['category_id'] ?? '';
    final String category_name = _localProduct['category'] ?? '';

    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image slider container
                Container(
                  width: double.infinity,
                  height: 330.h,
                  color: Colors.white,
                  child: Stack(
                    children: [
                      // PageView for Images
                      Positioned.fill(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            return Image.network(
                              Db.imageUrl('${images[index]}'),
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade100,
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 50.sp,
                                    color: Colors.grey.shade400,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),

                      // Premium Floating Top Buttons
                      Positioned(
                        top: statusBarHeight > 0 ? statusBarHeight + 6.h : 16.h,
                        left: 16.w,
                        right: 16.w,
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: Container(
                                width: 36.w,
                                height: 36.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade200, width: 1.w),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.arrow_back,
                                    color: Colors.black87,
                                    size: 18.sp,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SearchProduct(),
                                  ),
                                );
                                setState(() {
                                  fetchCartQuantities();
                                });
                              },
                              child: Container(
                                width: 36.w,
                                height: 36.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade200, width: 1.w),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.search,
                                    color: Colors.black87,
                                    size: 18.sp,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Page Indicator
                      if (images.length > 1)
                        Positioned(
                          bottom: 16.h,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: SmoothPageIndicator(
                              controller: _pageController,
                              count: images.length,
                              effect: WormEffect(
                                dotHeight: 6.h,
                                dotWidth: 6.w,
                                activeDotColor: AppColors.primaryColor,
                                dotColor: Colors.grey.shade300,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Highlights Specifications Row
                if (highlights.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  SizedBox(
                    height: 52.h,
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: highlights.length + 1,
                      itemBuilder: (context, index) {
                        if (index == highlights.length) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _showDetails = !_showDetails;
                              });
                            },
                            child: Container(
                              margin: EdgeInsets.only(right: 8.w),
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: const Color(0xFFC8E6C9), width: 1.w),
                              ),
                              child: Center(
                                child: Text(
                                  Provider.of<LanguageProvider>(context).translate('view_details'),
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final item = highlights[index];
                        return Container(
                          margin: EdgeInsets.only(right: 8.w),
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: Colors.grey.shade200, width: 1.w),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item['attribute'] ?? '',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                item['value'] ?? '',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Divider(color: Colors.grey.shade100, height: 24.h, thickness: 1.h),
                ),

                // Core Detail & variant selector
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time and rating tags
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7F6),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flash_on, color: Colors.orange.shade800, size: 12.sp),
                                SizedBox(width: 4.w),
                                Text(
                                  deliveryTime == "1"
                                      ? "CLOSE"
                                      : formatDeliveryTime(deliveryTime).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7F6),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 12.sp),
                                SizedBox(width: 4.w),
                                Text(
                                  '4.6 (1.2k)',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),

                      // Title
                      Text(
                        productName,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          height: 1.25,
                        ),
                      ),
                      SizedBox(height: 4.h),

                      // Weight/Unit
                      Text(
                        currentVariant['name'] ?? '',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 12.h),

                      // Price line
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₹${sellingPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20.sp,
                              color: Colors.black,
                            ),
                          ),
                          if (discount > 0) ...[
                            SizedBox(width: 8.w),
                            Text(
                              '₹${price.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14.sp,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFECE5),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                '$discount% OFF',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: const Color(0xFFFF521B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 20.h),

                      // Variant Select
                      Text(
                        Provider.of<LanguageProvider>(context).translate('select_unit'),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 10.h),

                      SizedBox(
                        height: 70.h,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: variants.length,
                          itemBuilder: (context, index) {
                            final v = variants[index];
                            final isSelected = index == selectedVariantIndex;

                            final double itemPrice =
                                double.tryParse(v['price']?.toString() ?? '0') ?? 0;
                            final double itemSellingPrice =
                                double.tryParse(v['selling_price']?.toString() ?? '0') ?? 0;

                            final int itemDiscount = itemPrice > 0
                                ? (((itemPrice - itemSellingPrice) / itemPrice) * 100).round()
                                : 0;

                            return Padding(
                              padding: EdgeInsets.only(right: 12.w),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    selectedVariantIndex = index;
                                  });
                                },
                                child: Container(
                                  width: 105.w,
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                                    borderRadius: BorderRadius.circular(10.r),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primaryColor : Colors.grey.shade200,
                                      width: 1.5.w,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      if (itemDiscount > 0)
                                        Positioned(
                                          top: 0,
                                          left: 0,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryColor,
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(8.r),
                                                bottomRight: Radius.circular(8.r),
                                              ),
                                            ),
                                            child: Text(
                                              '$itemDiscount% OFF',
                                              style: TextStyle(
                                                color: Colors.black87,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 8.sp,
                                              ),
                                            ),
                                          ),
                                        ),
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left: 10.w,
                                          right: 10.w,
                                          top: itemDiscount > 0 ? 18.h : 8.h,
                                          bottom: 6.h,
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              v['name'],
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 4.h),
                                            Row(
                                              children: [
                                                Text(
                                                  '₹${itemSellingPrice.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    color: Colors.black87,
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                if (itemDiscount > 0) ...[
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    '₹${itemPrice.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade500,
                                                      fontSize: 10.sp,
                                                      decoration: TextDecoration.lineThrough,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Collapsible details container
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey.shade200, width: 1.w),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            final hasDetails = allHighlights.isNotEmpty || info.isNotEmpty;
                            if (hasDetails) {
                              setState(() {
                                _showDetails = !_showDetails;
                              });
                            } else {
                              Fluttertoast.showToast(
                                msg: "No details available for this product",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.grey,
                                textColor: Colors.white,
                              );
                            }
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                            child: Row(
                              children: [
                                Text(
                                  Provider.of<LanguageProvider>(context).translate('product_details'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp,
                                    color: Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  _showDetails
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: Colors.grey.shade600,
                                  size: 20.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showDetails) ...[
                          Padding(
                            padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 16.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Divider(color: Colors.grey.shade100, height: 1.h),
                                SizedBox(height: 12.h),
                                if (allHighlights.isNotEmpty) ...[
                                  Text(
                                    Provider.of<LanguageProvider>(context).translate('highlights'),
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  ...allHighlights.map(
                                    (item) => Padding(
                                      padding: EdgeInsets.only(bottom: 6.h),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 100.w,
                                            child: Text(
                                              '${item['attribute']}',
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              item['value'] ?? '',
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                ],
                                if (info.isNotEmpty) ...[
                                  Text(
                                    Provider.of<LanguageProvider>(context).translate('product_description'),
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  ...info.map(
                                    (item) => Padding(
                                      padding: EdgeInsets.only(bottom: 6.h),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 100.w,
                                            child: Text(
                                              '${item['attribute']}',
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              item['value'] ?? '',
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Explore all items from Brand
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryViewScreen(
                            categoryId: int.tryParse(category_id.toString()),
                            categoryName: category_name,
                          ),
                        ),
                      );
                      setState(() {
                        fetchCartQuantities();
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.grey.shade200, width: 1.w),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36.h,
                            height: 36.h,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(color: Colors.grey.shade200, width: 1.w),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: Center(
                                child: Image.network(
                                  Db.imageUrl(
                                      '${_localProduct['images'][0]}'),
                                  width: 30.w,
                                  height: 30.h,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      Icon(Icons.store, size: 20.sp, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Provider.of<LanguageProvider>(context).currentLanguage == 'hi'
                                      ? "${subCategoryName} के सभी आइटम देखें"
                                      : Provider.of<LanguageProvider>(context).currentLanguage == 'hn'
                                          ? "${subCategoryName} ke saare items explore karein"
                                          : "Explore all ${subCategoryName}'s Items",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  Provider.of<LanguageProvider>(context).translate('find_similar_items'),
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_right, color: Colors.grey.shade400, size: 20.sp),
                        ],
                      ),
                    ),
                  ),
                ),

                // Replacement Guarantee
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey.shade200, width: 1.w),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36.h,
                          height: 36.h,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(Icons.verified_user_outlined,
                                color: AppColors.primaryColor, size: 18.sp),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Provider.of<LanguageProvider>(context).translate('replacement_guarantee'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.sp,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                Provider.of<LanguageProvider>(context).translate('easy_replacement'),
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_right, color: Colors.grey.shade400, size: 20.sp),
                      ],
                    ),
                  ),
                ),

                // Coupons list
                if (_couponList.isNotEmpty) ...[
                  SizedBox(height: 16.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Text(
                      Provider.of<LanguageProvider>(context).translate('coupons_offers'),
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    height: 90.h,
                    child: ListView.builder(
                      padding: EdgeInsets.only(left: 16.w),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _couponList.length,
                      itemBuilder: (context, index) {
                        final coupon = _couponList[index];
                        final isPrivate = coupon['status'] == "Private";

                        if (isPrivate) {
                          return const SizedBox.shrink();
                        }

                        return GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: coupon['code_name']));
                            Fluttertoast.showToast(
                              msg: "Coupon code copied!",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.black87,
                              textColor: Colors.white,
                              fontSize: 14.sp,
                            );
                          },
                          child: Container(
                            width: 280.w,
                            margin: EdgeInsets.only(right: 8.w),
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/images/coupons.png'),
                                fit: BoxFit.fill,
                              ),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: 20.w, right: 15.w, top: 6.h, bottom: 4.h),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Coupon',
                                        style: TextStyle(
                                          color: AppColors.primaryColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15.sp,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.backgroundColor,
                                          borderRadius: BorderRadius.circular(3.r),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
                                          child: Center(
                                            child: Text(
                                              'Valid ${coupon['expiry_date']}',
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(left: 8.w, right: 6.w),
                                  child: DottedLine(
                                    dashColor: AppColors.primaryColor,
                                    lineThickness: 1.7,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(left: 25.w, right: 20.w, top: 10.h),
                                  child: Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              SvgPicture.asset(
                                                'assets/svg/coupon.svg',
                                                width: 18.w,
                                                color: AppColors.primaryColor,
                                              ),
                                              SizedBox(width: 4.w),
                                              Text(
                                                coupon['title'],
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12.sp,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            coupon['description'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12.sp,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(3.r),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
                                          child: Center(
                                            child: Text(
                                              coupon['code_name'],
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: const Color(0xffC17F06),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // Similar Products
                if (products.isNotEmpty) ...[
                  SizedBox(height: 16.h),
                  buildSection(Provider.of<LanguageProvider>(context).translate('similar_products'), products),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SimilarProduct(
                              category_id: CATEGORY_ID,
                              category_name: category_name,
                            ),
                          ),
                        );
                        setState(() {
                          fetchCartQuantities();
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(width: 1.w, color: AppColors.primaryColor),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                Provider.of<LanguageProvider>(context).translate('see_all_products'),
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: AppColors.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Icon(Icons.arrow_forward, size: 16.sp, color: AppColors.primaryColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                SizedBox(height: 120.h),
              ],
            ),
          ),

          // Bottom Checkout Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentVariant['name'] ?? '',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '₹${sellingPrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              if (discount > 0) ...[
                                SizedBox(width: 6.w),
                                Text(
                                  '₹${price.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: Colors.grey.shade500,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            Provider.of<LanguageProvider>(context).translate('inclusive_taxes'),
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (currentQuantity > 0)
                      Container(
                        width: 110.w,
                        height: 38.h,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                Icons.remove,
                                size: 18.sp,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (currentQuantity > 1) {
                                  updateQuantity(currentQuantity - 1);
                                } else {
                                  removeFromCart();
                                }
                              },
                            ),
                            Text(
                              currentQuantity.toString(),
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                Icons.add,
                                size: 18.sp,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                updateQuantity(currentQuantity + 1);
                              },
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        width: 110.w,
                        height: 38.h,
                        child: ElevatedButton(
                          onPressed: () {
                            if (Db.isSignedIn) {
                              if (stock > 0) {
                                addToCart();
                              } else {
                                Fluttertoast.showToast(
                                  msg: "This product is out of stock!",
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                );
                              }
                            } else {
                              Fluttertoast.showToast(
                                msg: Provider.of<LanguageProvider>(context, listen: false).translate('please_login_add_cart'),
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: stock > 0 ? AppColors.primaryColor : Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            elevation: 0,
                            padding: EdgeInsets.zero,
                          ),
                          child: isLoading
                              ? SizedBox(
                                  width: 18.w,
                                  height: 18.w,
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  stock > 0 ? Provider.of<LanguageProvider>(context).translate('add').toUpperCase() : Provider.of<LanguageProvider>(context).translate('out_of_stock').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Floating View Cart Banner (sitting just above checkout bar)
          if (cartProvider.getUniqueItemsCount() > 0)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.slowMiddle,
              bottom: cartProvider.getUniqueItemsCount() > 0 ? 80.h : -100.h,
              left: 80.w,
              right: 80.w,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: cartProvider.getUniqueItemsCount() > 0 ? 1.0 : 0.0,
                child: InkWell(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => CartScreen()));
                    setState(() {
                      fetchCartQuantities();
                    });
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
                            width: 24.w,
                            height: 24.w,
                            decoration: BoxDecoration(
                              color: AppColors.gray,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                cartProvider.getUniqueItemsCount().toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              Provider.of<LanguageProvider>(context).translate('view_cart'),
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.arrow_forward_ios_outlined, color: Colors.white, size: 14.sp),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }

  String formatDeliveryTime(String input) {
    input = input.replaceAll(' ', '');
    final match = RegExp(r'^(\d+)([a-zA-Z]+)').firstMatch(input);

    if (match != null) {
      final number = match.group(1) ?? '';
      final unit = match.group(2)?.substring(0, 3).toUpperCase() ?? '';
      return '$number $unit';
    } else {
      return input.substring(0, input.length.clamp(0, 6)).toUpperCase();
    }
  }

  Widget buildSection(String title, List<dynamic> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: SizedBox(
            height: 520.h,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
                childAspectRatio: 0.45,
              ),
              itemCount: list.length > 6 ? 6 : list.length,
              itemBuilder: (context, index) {
                final product = list[index];
                return ProductCard(
                  product: product,
                  userId: '',
                  onCartUpdated: () {
                    fetchCartQuantities();
                  },
                  onCategoryBack: () {
                    setState(() {
                      fetchCartQuantities();
                    });
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
