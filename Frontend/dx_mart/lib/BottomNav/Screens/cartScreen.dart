import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../Checkout/checkout_screen.dart';
import '../../CustomWidgets/cart_provider.dart';
import '../../CustomWidgets/product_card.dart';
import '../../SearchProduct/search_product.dart';
import '../../core/supabase.dart';
import '../../data/cart_repository.dart';
import '../../data/catalog_repository.dart';
import '../../utils/colors.dart';
import '../../utils/language_provider.dart';

class CartScreen extends StatefulWidget {
  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<dynamic> cartItems = [];
  bool isLoading = true;
  Map<int, bool> itemCheckStates = {};
  double totalSellingAmount = 0.0;
  double totalPriceAmount = 0.0;

  String _lastFetchedLang = "";





  List everydayEssentialsList = [];
  List<Map<String, dynamic>> _couponList = [];

  TextEditingController _couponController = TextEditingController();
  bool _isApplyingCoupon = false;


  // Converted to double
  double deliveryCharge = 0.0;
  double minium_amount = 0.0;
  double handling_charge = 0.0;
  double freeDelivery = 0.0;

  // Store selected coupon details
  String? selectedCodeName;
  double selectedDiscount = 0.0; // Changed to double
  String? selectedExpiry;
  double selectedMinAmount = 0.0; // Changed to double



  // Updated final amount calculation with coupon discount
  double get finalWithCharge {
    double baseAmount = totalSellingAmount + handling_charge;



    // Apply delivery charge if cart amount is less than free delivery threshold
    if (totalSellingAmount < freeDelivery) {
      baseAmount += deliveryCharge;
    }



    // Apply coupon discount if applicable
    if (selectedDiscount > 0 && totalSellingAmount >= selectedMinAmount) {
      double discountAmount = (totalSellingAmount * selectedDiscount) / 100;
      baseAmount -= discountAmount;
    }

    return baseAmount > 0 ? baseAmount : 0.0;
  }


  double get saveAmount {
    // Normal saving (MRP - Selling Price)
    double saving = totalPriceAmount - totalSellingAmount;

    // Coupon discount agar applicable hai to add kar do
    if (selectedDiscount > 0 && totalSellingAmount >= selectedMinAmount) {
      double discountAmount = (totalSellingAmount * selectedDiscount) / 100;
      saving += discountAmount;
    }

    return saving;
  }


  @override
  void initState() {
    super.initState();
    fetchCartItems();
    fetchChargeSettings();
    fetchProductsByType('Everyday Essentials');
    _fetchCoupons();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final activeLang = Provider.of<LanguageProvider>(context).currentLanguage;
    if (_lastFetchedLang != activeLang) {
      _lastFetchedLang = activeLang;
      if (Db.isSignedIn) {
        fetchCartItems();
      }
      fetchProductsByType('Everyday Essentials');
    }
  }






  /// Delivery/handling/minimum rules. These were four separate endpoints backed by four
  /// single-row tables; they are now four keys in app_settings, read in one round trip.
  /// Fallbacks match the constants the PHP backend hardcoded.
  Future<void> fetchChargeSettings() async {
    try {
      final settings = await const CatalogRepository().settings();
      double read(String key, double fallback) =>
          double.tryParse(settings[key] ?? '') ?? fallback;
      if (!mounted) return;
      setState(() {
        freeDelivery = read('free_delivery_threshold', 500);
        deliveryCharge = read('delivery_charge', 10);
        minium_amount = read('minimum_order_amount', 0);
        handling_charge = read('handling_charge', 5);
      });
    } catch (e) {
      debugPrint('Error fetching charge settings: $e');
    }
  }

  Future<void> fetchProductsByType(String type) async {
    try {
      final result = await const CatalogRepository().productsByType(type);
      if (!mounted) return;
      setState(() {
        switch (type) {
          case 'Everyday Essentials':
            everydayEssentialsList =
                result.map((p) => p.toCardMap()).toList();
            break;
        }
      });
    } catch (e) {
      debugPrint("Error fetching $type products: $e");
    }
  }

  /// Loads the cart for the signed-in user.
  ///
  /// Replaces the old chain: read an email from SharedPreferences, call get_user.php to
  /// turn it into an integer id, then send that id to the cart endpoint -- which is what
  /// let any client read any other user's cart by changing the number.
  Future<void> fetchCartItems() async {
    if (!Db.isSignedIn) {
      setState(() {
        cartItems = [];
        isLoading = false;
      });
      return;
    }

    try {
      final lines = await const CartRepository().items();
      if (!mounted) return;
      setState(() {
        cartItems = lines.map((l) => l.toCartMap()).toList();
        for (var item in cartItems) {
          itemCheckStates[item['id']] = true;
        }
        calculateTotal();
        calculateTotalPrice();
      });
      _updateCartProvider();
    } catch (e) {
      debugPrint('Error fetching cart items: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }


  void _updateCartProvider() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.clearCartData();

    for (var item in cartItems) {
      final productId = item['product_id']?.toString() ?? '';
      final variantId = item['variant_id']?.toString() ?? '';
      final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      final cartId = item['id'];

      cartProvider.updateCartQuantities(
        '',
        productId,
        variantId,
        quantity,
        cartId,
      );
    }
  }


  // Add this method to apply coupon by code
  Future<void> _applyCouponByCode() async {
    if (_couponController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please enter coupon code",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 14.sp,
      );
      return;
    }

    setState(() {
      _isApplyingCoupon = true;
    });

    try {
      final typed = _couponController.text.trim();
      final match = _couponList.where(
        (c) => (c['code_name'] as String).toLowerCase() == typed.toLowerCase(),
      );

      if (match.isNotEmpty) {
        _applyCoupon(match.first);
        _couponController.clear();
      } else {
        // Not in the public list. It may still be a valid private code -- those are
        // hidden from clients by design -- so keep it and let the server decide when
        // the order is placed.
        setState(() => selectedCodeName = typed);
        _couponController.clear();
        Fluttertoast.showToast(
          msg: "Code saved. It will be verified when you place the order.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: AppColors.primaryColor,
          textColor: Colors.white,
          fontSize: 14.sp,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error applying coupon",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 14.sp,
      );
    } finally {
      setState(() {
        _isApplyingCoupon = false;
      });
    }
  }

  void _removeCoupon() {
    setState(() {
      selectedCodeName = null;
      selectedDiscount = 0.0;
      selectedExpiry = null;
      selectedMinAmount = 0.0;
    });

    Fluttertoast.showToast(
      msg: "Coupon removed",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 14.sp,
    );
  }



  void calculateTotal() {
    double total = 0.0;
    for (var item in cartItems) {
      if (itemCheckStates[item['id']] ?? true) {
        final price = double.tryParse(item['selling_price']?.toString() ?? '0') ?? 0;
        final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
        total += price * quantity;
      }
    }
    setState(() {
      totalSellingAmount = total;
    });

    // Check if coupon is still valid after cart total change
    _checkCouponValidity();
  }

  void calculateTotalPrice() {
    double total = 0.0;
    for (var item in cartItems) {
      if (itemCheckStates[item['id']] ?? true) {
        final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
        final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
        total += price * quantity;
      }
    }
    setState(() {
      totalPriceAmount = total;
    });
  }

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


  /// Applies a relative change to one cart line.
  ///
  /// Takes a delta rather than an absolute quantity, and routes through
  /// [CartProvider.changeQuantity], which is the only writer and serializes per line.
  /// This method used to send an absolute `newQuantity` computed from the row snapshot
  /// captured in `itemBuilder`, then — worse — re-apply that same optimistic number to
  /// the provider *after* `fetchCartItems()` had already synced the real one.
  Future<void> changeQuantityBy(int cartItemId, int delta) async {
    // Not firstWhere(orElse: () => null): `cartItems` holds Map<String, dynamic>, so a
    // null orElse is a type error at runtime rather than a miss. That threw straight out
    // of the tap handler and the stepper appeared to do nothing at all.
    final item = _cartItemById(cartItemId);
    if (item == null) return;

    final productId = int.tryParse(item['product_id']?.toString() ?? '');
    final variantId = int.tryParse(item['variant_id']?.toString() ?? '');
    if (productId == null) return;

    if (delta > 0) {
      final stock = int.tryParse(item['stock']?.toString() ?? '0') ?? 0;
      final current = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
      if (current + delta > stock) {
        Fluttertoast.showToast(
          msg: "Only $stock items available in stock",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }
    }

    final result = await context.read<CartProvider>().changeQuantity(
          productId: productId,
          variantId: variantId,
          delta: delta,
        );

    if (!mounted) return;
    if (result == CartMutation.busy) return; // an earlier tap is still running
    if (result == CartMutation.failed) {
      Fluttertoast.showToast(
        msg: "Network error. Please try again.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
    // Re-read the line details (price, stock, name) this screen renders. The provider
    // holds only quantities and row ids.
    await fetchCartItems();
  }

  /// The cart line with this row id, or null. See the note in [changeQuantityBy].
  Map<String, dynamic>? _cartItemById(int cartItemId) {
    for (final item in cartItems) {
      if (item is Map<String, dynamic> && item['id'] == cartItemId) return item;
    }
    return null;
  }

  Future<void> removeItem(int cartItemId) async {
    final item = _cartItemById(cartItemId);
    if (item == null) return;
    final quantity = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
    if (quantity <= 0) return;
    await changeQuantityBy(cartItemId, -quantity);
  }



  // Check if coupon is expired.
  //
  // `coupon.expiry_date` is a Postgres `date` and reaches here as ISO `YYYY-MM-DD`
  // (see `_fetchCoupons`). The previous implementation split on '-' and read it as the
  // old PHP `DD-MM-YYYY` varchar, so "2026-12-31" parsed as day=2026/month=12/year=31 —
  // year 31 AD — and every coupon in the app reported as expired.
  //
  // The column is nullable, and a coupon with no expiry date does not expire. That also
  // matches `place-order`, which only checks expiry `if (coupon.expiry_date)`.
  bool _isCouponExpired(String? expiryDate) {
    if (expiryDate == null || expiryDate.isEmpty) return false;
    final expiry = DateTime.tryParse(expiryDate);
    if (expiry == null) return true;
    return DateTime.now().isAfter(expiry);
  }

  // Apply coupon with validation
  void _applyCoupon(Map<String, dynamic> coupon) {
    // Check if coupon is expired
    if (_isCouponExpired(coupon['expiry_date'])) {
      Fluttertoast.showToast(
        msg: "Coupon has expired",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 14.sp,
      );
      return;
    }

    // Check if cart meets minimum amount requirement
    // Compared against the item subtotal, NOT the bill total. place-order checks
    // `subtotal < coupon.min_amount`, and this used to compare `finalWithCharge`, which
    // includes handling and delivery and is therefore larger. A coupon could be accepted
    // here, shown as a discount, and then rejected by the server at place-order —
    // failing the whole order rather than merely dropping the discount. The greyed-out
    // state further down this file already used the subtotal, so the file disagreed
    // with itself too.
    final minAmount = double.tryParse(coupon['min_amount']?.toString() ?? '0') ?? 0.0;
    if (totalSellingAmount < minAmount) {
      Fluttertoast.showToast(
        msg: "Add products worth ₹${(minAmount - totalSellingAmount).toStringAsFixed(0)} more to apply this coupon",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 14.sp,
      );
      return;
    }

    setState(() {
      selectedCodeName = coupon['code_name'];
      selectedDiscount = double.tryParse(coupon['discount']?.toString() ?? '0') ?? 0.0;
      selectedExpiry = coupon['expiry_date'];
      selectedMinAmount = minAmount;
    });

    Navigator.pop(context);

    Fluttertoast.showToast(
      msg: "Coupon Applied: ${coupon['code_name']}",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 14.sp,
    );
  }



  Widget _buildBillRow(String label, String value, {String? originalPrice, bool isFree = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: AppColors.neutral600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            if (originalPrice != null) ...[
              Text(
                originalPrice,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.neutral400,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              SizedBox(width: 6.w),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: (isFree || isDiscount) ? FontWeight.bold : FontWeight.w600,
                color: isFree
                    ? Colors.green
                    : isDiscount
                        ? Colors.green
                        : AppColors.primaryTextColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral100,
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor),
            )
          : cartItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 70.sp, color: AppColors.neutral300),
                      SizedBox(height: 12.h),
                      Text(
                        Provider.of<LanguageProvider>(context).translate('cart_empty'),
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neutral500,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor,
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryColor.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            Provider.of<LanguageProvider>(context).translate('continue_shopping'),
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Column(
                      children: [
                        Container(
                          color: Colors.white,
                          height: MediaQuery.of(context).padding.top + 10.h,
                        ),
                        // Header
                        Container(
                          width: double.infinity,
                          height: 50.h,
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  height: 30.h,
                                  width: 30.w,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.arrow_back,
                                    size: 18.sp,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Provider.of<LanguageProvider>(context).translate('my_cart'),
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryTextColor,
                                    ),
                                  ),
                                  Text(
                                    "${cartItems.length} ${Provider.of<LanguageProvider>(context).translate('items_label')}",
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: AppColors.neutral500,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SearchProduct(),
                                    ),
                                  );
                                },
                                child: SvgPicture.asset(
                                  'assets/svg/search.svg',
                                  width: 18.h,
                                  height: 18.w,
                                  colorFilter: ColorFilter.mode(AppColors.primaryTextColor, BlendMode.srcIn),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 130.h),
                              child: Column(
                                children: [
                                  SizedBox(height: 14.h),

                                  // Cart Items Container Card
                                  Container(
                                    margin: EdgeInsets.symmetric(horizontal: 16.w),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16.r),
                                      border: Border.all(
                                        color: AppColors.borderColor,
                                        width: 1.w,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.all(16.w),
                                          child: Row(
                                            children: [
                                              SvgPicture.asset(
                                                'assets/svg/time.svg',
                                                width: 16.w,
                                                height: 16.h,
                                                colorFilter: ColorFilter.mode(AppColors.primaryColor, BlendMode.srcIn),
                                              ),
                                              SizedBox(width: 8.w),
                                              Text(
                                                Provider.of<LanguageProvider>(context).translate('delivery_in'),
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                                          child: DottedLine(
                                            dashColor: AppColors.lineColor,
                                            lineThickness: 1.5,
                                          ),
                                        ),
                                        ListView.separated(
                                          padding: EdgeInsets.all(16.w),
                                          itemCount: cartItems.length,
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          separatorBuilder: (context, index) => Padding(
                                            padding: EdgeInsets.symmetric(vertical: 12.h),
                                            child: Divider(height: 1.h, color: AppColors.borderColor.withOpacity(0.6)),
                                          ),
                                          itemBuilder: (context, index) {
                                            final item = cartItems[index];
                                            final productName = item['name'] ?? '';
                                            final variantName = item['variant_name'] ?? '';
                                            final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                                            final sellingPrice = double.tryParse(item['selling_price']?.toString() ?? '0') ?? 0;
                                            final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                                            final cartItemId = item['id'];
                                            final imageUlr = item['image_url'];

                                            final discountPercentage = price > 0 ? ((price - sellingPrice) / price * 100).round() : 0;

                                            return Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                // Image container
                                                Stack(
                                                  children: [
                                                    Container(
                                                      width: 55.h,
                                                      height: 55.h,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(10.r),
                                                        border: Border.all(color: AppColors.neutral200, width: 1.w),
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(9.r),
                                                        child: Padding(
                                                          padding: EdgeInsets.all(4.w),
                                                          child: Image.network(
                                                            imageUlr,
                                                            fit: BoxFit.contain,
                                                            errorBuilder: (_, __, ___) => Icon(
                                                              Icons.image,
                                                              size: 24.sp,
                                                              color: AppColors.neutral400,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    if (discountPercentage > 0)
                                                      Positioned(
                                                        left: 0,
                                                        top: 0,
                                                        child: Container(
                                                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.primaryColor,
                                                            borderRadius: BorderRadius.only(
                                                              topLeft: Radius.circular(9.r),
                                                              bottomRight: Radius.circular(9.r),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            '$discountPercentage% OFF',
                                                            style: TextStyle(
                                                              fontSize: 7.sp,
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                SizedBox(width: 12.w),
                                                // Details
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        productName,
                                                        style: TextStyle(
                                                          fontSize: 13.sp,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.primaryTextColor,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      SizedBox(height: 4.h),
                                                      Text(
                                                        variantName,
                                                        style: TextStyle(
                                                          fontSize: 11.sp,
                                                          color: AppColors.neutral500,
                                                        ),
                                                      ),
                                                      if (quantity > 1) ...[
                                                        SizedBox(height: 4.h),
                                                        Text(
                                                          '₹${sellingPrice.toStringAsFixed(0)} ${Provider.of<LanguageProvider>(context).translate('unit_price')}',
                                                          style: TextStyle(
                                                            fontSize: 10.sp,
                                                            color: AppColors.neutral400,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(width: 12.w),
                                                // Quantity & Pricing column
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Container(
                                                      height: 28.h,
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(6.r),
                                                        color: AppColors.primaryColor,
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          GestureDetector(
                                                            onTap: () {
                                                              if (quantity > 1) {
                                                                changeQuantityBy(cartItemId, -1);
                                                              } else {
                                                                removeItem(cartItemId);
                                                              }
                                                            },
                                                            child: Padding(
                                                              padding: EdgeInsets.symmetric(horizontal: 8.w),
                                                              child: Icon(
                                                                quantity == 1 ? Icons.delete_outline : Icons.remove,
                                                                color: Colors.white,
                                                                size: 14.sp,
                                                              ),
                                                            ),
                                                          ),
                                                          Text(
                                                            quantity.toString(),
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 13.sp,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                          GestureDetector(
                                                            onTap: () {
                                                              changeQuantityBy(cartItemId, 1);
                                                            },
                                                            child: Padding(
                                                              padding: EdgeInsets.symmetric(horizontal: 8.w),
                                                              child: Icon(
                                                                Icons.add,
                                                                color: Colors.white,
                                                                size: 14.sp,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(height: 8.h),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        if (discountPercentage > 0) ...[
                                                          Text(
                                                            '₹${(price * quantity).toStringAsFixed(0)}',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.normal,
                                                              fontSize: 11.sp,
                                                              decoration: TextDecoration.lineThrough,
                                                              color: AppColors.neutral400,
                                                            ),
                                                          ),
                                                          SizedBox(width: 4.w),
                                                        ],
                                                        Text(
                                                          '₹${(sellingPrice * quantity).toStringAsFixed(0)}',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 13.sp,
                                                            color: AppColors.primaryTextColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Apply Coupon Card
                                  Container(
                                    margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: selectedCodeName != null ? AppColors.primaryColor : AppColors.borderColor,
                                        width: 1.w,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        _showCouponBottomSheet();
                                      },
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.local_offer_outlined,
                                            color: AppColors.primaryColor,
                                            size: 22.sp,
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  selectedCodeName != null
                                                      ? Provider.of<LanguageProvider>(context).translate('coupon_applied')
                                                      : Provider.of<LanguageProvider>(context).translate('avail_offers'),
                                                  style: TextStyle(
                                                    fontSize: 14.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primaryTextColor,
                                                  ),
                                                ),
                                                SizedBox(height: 2.h),
                                                Text(
                                                  selectedCodeName != null
                                                      ? '$selectedCodeName (₹${(totalSellingAmount * selectedDiscount / 100).toStringAsFixed(0)} Saved!)'
                                                      : Provider.of<LanguageProvider>(context).translate('best_offers'),
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    color: selectedCodeName != null ? AppColors.successColor : AppColors.neutral500,
                                                    fontWeight: selectedCodeName != null ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (selectedCodeName != null)
                                            GestureDetector(
                                              onTap: () {
                                                _removeCoupon();
                                              },
                                              child: Container(
                                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6.r),
                                                ),
                                                child: Text(
                                                  Provider.of<LanguageProvider>(context).translate('remove'),
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            Row(
                                              children: [
                                                Text(
                                                  Provider.of<LanguageProvider>(context).translate('select'),
                                                  style: TextStyle(
                                                    color: AppColors.primaryColor,
                                                    fontSize: 13.sp,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.arrow_forward_ios,
                                                  size: 14.sp,
                                                  color: AppColors.primaryColor,
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Bill Details Card
                                  Container(
                                    margin: EdgeInsets.symmetric(horizontal: 16.w),
                                    padding: EdgeInsets.all(16.w),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16.r),
                                      border: Border.all(
                                        color: AppColors.borderColor,
                                        width: 1.w,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          Provider.of<LanguageProvider>(context).translate('bill_details'),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.sp,
                                            color: AppColors.primaryTextColor,
                                          ),
                                        ),
                                        SizedBox(height: 12.h),
                                        _buildBillRow(
                                          Provider.of<LanguageProvider>(context).translate('items_total'),
                                          '₹${totalSellingAmount.toStringAsFixed(0)}',
                                          originalPrice: totalPriceAmount > totalSellingAmount ? '₹${totalPriceAmount.toStringAsFixed(0)}' : null,
                                        ),
                                        SizedBox(height: 10.h),
                                        _buildBillRow(
                                          Provider.of<LanguageProvider>(context).translate('handling_charge'),
                                          '₹${handling_charge.toStringAsFixed(0)}',
                                        ),
                                        SizedBox(height: 10.h),
                                        _buildBillRow(
                                          Provider.of<LanguageProvider>(context).translate('delivery_charge'),
                                          totalSellingAmount >= freeDelivery
                                              ? Provider.of<LanguageProvider>(context).translate('free')
                                              : '₹${deliveryCharge.toStringAsFixed(0)}',
                                          isFree: totalSellingAmount >= freeDelivery,
                                        ),
                                        if (selectedCodeName != null) ...[
                                          SizedBox(height: 10.h),
                                          _buildBillRow(
                                            '${Provider.of<LanguageProvider>(context).translate('coupon_discount')} ($selectedCodeName)',
                                            '-₹${(totalSellingAmount * selectedDiscount / 100).toStringAsFixed(0)}',
                                            isDiscount: true,
                                          ),
                                        ],
                                        SizedBox(height: 12.h),
                                        Divider(height: 1.h, color: AppColors.borderColor),
                                        SizedBox(height: 12.h),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              Provider.of<LanguageProvider>(context).translate('to_pay'),
                                              style: TextStyle(
                                                fontSize: 15.sp,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryTextColor,
                                              ),
                                            ),
                                            Text(
                                              '₹${finalWithCharge.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 17.sp,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (saveAmount > 0) ...[
                                          SizedBox(height: 10.h),
                                          Container(
                                            width: double.infinity,
                                            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryColor.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(8.r),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle_outline,
                                                  color: AppColors.primaryColor,
                                                  size: 16.sp,
                                                ),
                                                SizedBox(width: 8.w),
                                                Text(
                                                  '${Provider.of<LanguageProvider>(context).translate('you_save')} ₹${saveAmount.toStringAsFixed(0)} ${Provider.of<LanguageProvider>(context).translate('on_this_order')}',
                                                  style: TextStyle(
                                                    color: AppColors.primaryColor,
                                                    fontSize: 11.sp,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: 14.h),
                                  if (everydayEssentialsList.isNotEmpty) ...[
                                    buildSection(
                                      'Everyday Essentials',
                                      everydayEssentialsList,
                                    ),
                                    SizedBox(height: 12.h),
                                  ],

                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SearchProduct(),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        height: 40.h,
                                        decoration: BoxDecoration(
                                          color: AppColors.neutral100,
                                          border: Border.all(
                                            width: 1.2,
                                            color: AppColors.primaryColor.withOpacity(0.4),
                                          ),
                                          borderRadius: BorderRadius.circular(8.r),
                                        ),
                                        child: Center(
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: (everydayEssentialsList.length > 3 ? 3 : everydayEssentialsList.length) * 20.0 + 8,
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  children: List.generate(
                                                    everydayEssentialsList.length > 3 ? 3 : everydayEssentialsList.length,
                                                    (index) {
                                                      final product = everydayEssentialsList[index];
                                                      return Positioned(
                                                        left: index * 20.0,
                                                        child: Container(
                                                          width: 26.h,
                                                          height: 26.h,
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            shape: BoxShape.circle,
                                                            border: Border.all(
                                                              color: AppColors.borderColor,
                                                              width: 1.w,
                                                            ),
                                                          ),
                                                          child: Padding(
                                                            padding: const EdgeInsets.all(4.0),
                                                            child: Image.network(
                                                              Db.imageUrl('${product['images'][0]}'),
                                                              fit: BoxFit.contain,
                                                              errorBuilder: (_, __, ___) => Icon(
                                                                Icons.image,
                                                                size: 16.sp,
                                                                color: AppColors.neutral400,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8.w),
                                              Text(
                                                Provider.of<LanguageProvider>(context).translate('see_all_products_btn'),
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  color: AppColors.primaryColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 6.w),
                                              Icon(Icons.arrow_forward_ios, size: 12.sp, color: AppColors.primaryColor),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Sticky Bottom Bar
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: InkWell(
                            onTap: () {
                              if (totalSellingAmount < minium_amount) {
                                final langP = Provider.of<LanguageProvider>(context, listen: false);
                                Fluttertoast.showToast(
                                  msg: "${langP.translate('min_order_err')} ₹${minium_amount.toStringAsFixed(0)}",
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                  fontSize: 14.sp,
                                );
                                return;
                              }

                              Navigator.push(
                                context,
                                          MaterialPageRoute(
                                            // Checkout no longer receives identity or any
                                            // amount from here. It reads the cart itself and
                                            // the server recomputes every monetary figure, so
                                            // this screen's arithmetic can never become the
                                            // price the customer is charged.
                                            builder: (context) => CheckoutScreen(
                                              giftName: "noGift",
                                              couponCode: selectedCodeName?.toString() ?? '',
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        height: 48.h,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryColor,
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '₹${finalWithCharge.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16.sp,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    Provider.of<LanguageProvider>(context).translate('to_pay'),
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.8),
                                                      fontSize: 11.sp,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Expanded(
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        Provider.of<LanguageProvider>(context).translate('proceed_to_checkout'),
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 15.sp,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Icon(
                                                      Icons.arrow_forward,
                                                      color: Colors.white,
                                                      size: 18.sp,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
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

  Widget buildSection(String title, List<dynamic> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          height: 235.w,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: list.length,
            itemBuilder: (context, index) {
              final product = list[index];
              return Padding(
                padding: EdgeInsets.only(
                  left: 16.w,
                  right: index == list.length - 1 ? 16.w : 0,
                ),
                child: SizedBox(
                  width: 110.w,
                  child: ProductCard(
                    product: product,
                    userId: '',
                    height: 230.w,
                    onCartUpdated: fetchCartItems,
                    onCategoryBack: fetchCartItems,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _checkCouponValidity() {
    if (selectedDiscount > 0 && totalSellingAmount < selectedMinAmount) {
      setState(() {
        selectedCodeName = null;
        selectedDiscount = 0.0;
        selectedExpiry = null;
        selectedMinAmount = 0.0;
      });

      Fluttertoast.showToast(
        msg: "Coupon removed as cart value decreased below minimum requirement",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
        fontSize: 14.sp,
      );
    }
  }

  void _showCouponBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              SizedBox(height: 10.h),
              Container(
                width: 50.w,
                height: 4.h,
                decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10)),
              ),
              SizedBox(height: 15.h),
              Text("Available Coupons",
                  style: TextStyle(
                      fontSize: 16.sp, fontWeight: FontWeight.w700)),

              // Add coupon code input field
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(

                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: TextField(
                          controller: _couponController,
                          decoration: InputDecoration(
                            hintText: "Enter coupon code",
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
                            ),
                          ),
                          style: TextStyle(fontSize: 14.sp),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    _isApplyingCoupon
                        ? Container(
                      padding: EdgeInsets.all(8.w),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                      ),
                    )
                        : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _applyCouponByCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: AppColors.primaryTextColor,
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "Apply",
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 10.h),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _couponList.length,
                  itemBuilder: (context, index) {
                    final coupon = _couponList[index];
                    return InkWell(
                      onTap: () => _applyCoupon(coupon),
                      child: _buildCouponCard(coupon),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCouponCard(Map<String, dynamic> coupon) {
    final isPrivate = coupon['status'] == "Private" || coupon['status'] == 'Private';

    // If coupon is private, return empty container (don't show it)
    if (isPrivate) {
      return Container();
    }

    final isExpired = _isCouponExpired(coupon['expiry_date']);
    final minAmount = double.tryParse(coupon['min_amount']?.toString() ?? '0') ?? 0.0;
    final canApply = totalSellingAmount >= minAmount && !isExpired;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isExpired
              ? Colors.grey.shade300
              : canApply
                  ? AppColors.primaryColor
                  : AppColors.primaryColor.withOpacity(0.4),
          width: 1.5.w,
        ),
        boxShadow: [
          BoxShadow(
            color: (isExpired ? Colors.black : AppColors.primaryColor).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Opacity(
        opacity: isExpired ? 0.6 : 1.0,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(left: 16.w, right: 12.w, top: 10.h, bottom: 6.h),
              child: Row(
                children: [
                  Text(
                    'Coupon',
                    style: TextStyle(
                      color: isExpired ? Colors.grey : AppColors.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.sp,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: isExpired
                          ? Colors.red.withOpacity(0.1)
                          : AppColors.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      child: Text(
                        isExpired ? 'Expired' : 'Valid ${coupon['expiry_date']}',
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w500,
                          color: isExpired ? Colors.red : AppColors.primaryColor,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: DottedLine(
                dashColor: (isExpired ? Colors.grey : AppColors.primaryColor).withOpacity(0.4),
                lineThickness: 1.2,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 16.w, right: 12.w, top: 10.h, bottom: 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 2.h),
                    child: SvgPicture.asset(
                      'assets/svg/coupon.svg',
                      width: 16.w,
                      colorFilter: ColorFilter.mode(
                        isExpired ? Colors.grey : AppColors.primaryColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coupon['title'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                            color: isExpired ? Colors.grey : AppColors.primaryTextColor,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          coupon['description'],
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 11.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (!canApply && !isExpired) ...[
                          SizedBox(height: 4.h),
                          Text(
                            'Add ₹${(minAmount - totalSellingAmount).toStringAsFixed(0)} more to apply',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    decoration: BoxDecoration(
                      color: isExpired
                          ? Colors.grey.shade100
                          : AppColors.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: isExpired
                            ? Colors.grey.shade300
                            : AppColors.primaryColor.withOpacity(0.4),
                        width: 1.w,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      child: Text(
                        coupon['code_name'],
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isExpired ? Colors.grey : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }}