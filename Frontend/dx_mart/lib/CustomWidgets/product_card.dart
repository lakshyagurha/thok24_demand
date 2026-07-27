import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../ProductDetailScreen/product_details_screen.dart';
import '../core/supabase.dart';
import '../data/catalog_repository.dart';
import '../design/app_colors.dart';
import '../design/components/price_block.dart';
import '../design/app_gradients.dart';
import '../design/app_radius.dart';
import '../design/app_space.dart';
import '../design/app_type.dart';
import '../utils/responsive_helper.dart';
import 'cart_provider.dart';
import 'product_image.dart';
import 'wishlist_provider.dart';
import '../utils/language_provider.dart';

class ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;

  /// Ignored. Identity comes from the session and RLS enforces ownership in the
  /// database. Retained only so call sites can be migrated one at a time; pass ''.
  final String userId;

  final VoidCallback? onCartUpdated;
  final VoidCallback? onWishlistUpdated;
  final VoidCallback? onCategoryBack;
  final double? height;

  /// The width the card will actually be drawn at.
  ///
  /// Used purely as the image decode bound. The card is stretched to five
  /// different footprints across the app (98–160dp), and the image was
  /// previously bounded by the card's *height* instead — so a 99dp-wide card in
  /// the search grid decoded its photo for a 216dp box, roughly 2.6x the pixels
  /// it draws, thirty times over in a scrolling grid.
  final double? width;

  const ProductCard({
    Key? key,
    required this.product,
    required this.userId,
    this.onCartUpdated,
    this.onWishlistUpdated,
    this.onCategoryBack,
    this.height,
    this.width,
  }) : super(key: key);

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  String deliveryTime = '17 MIN';
  bool isLoading = false;
  bool isWishlistLoading = false;

  @override
  void initState() {
    super.initState();
    // Both of these used to be a network round trip PER CARD — a 30-product grid opened
    // with ~60 requests. `settings()` is now memoized process-wide and the wishlist is
    // one shared set, so a whole grid costs at most one of each.
    fetchDeliveryTime();
    context.read<WishlistProvider>().ensureLoaded();
  }

  int get _productId => int.tryParse('${widget.product['id']}') ?? 0;

  bool get isWishlisted => context.watch<WishlistProvider>().contains(_productId);

  Future<void> toggleWishlist() async {
    if (!Db.isSignedIn) {
      _showToastMessage('Please sign in to use your wishlist.');
      return;
    }
    if (isWishlistLoading) return;

    setState(() => isWishlistLoading = true);
    try {
      await context.read<WishlistProvider>().toggle(_productId);
      widget.onWishlistUpdated?.call();
    } catch (e) {
      debugPrint('Error toggling wishlist: $e');
      _showToastMessage('Could not update your wishlist. Please try again.');
    } finally {
      if (mounted) setState(() => isWishlistLoading = false);
    }
  }

  Future<void> fetchDeliveryTime() async {
    try {
      // Was its own endpoint and its own single-row table; now one app_settings key,
      // served from CatalogRepository's process-wide cache.
      final settings = await const CatalogRepository().settings();
      final time = settings['delivery_time'];
      if (!mounted) return;
      // Keep the existing default rather than showing an error string in the badge:
      // an unset setting is a configuration gap, not something the shopper caused.
      if (time != null && time.isNotEmpty) setState(() => deliveryTime = time);
    } catch (e) {
      debugPrint('Error fetching delivery time: $e');
    }
  }

  // Helper method to show toast message
  void _showToastMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  /// Applies a relative change to this product's line.
  ///
  /// All three of add / increment / decrement funnel through
  /// [CartProvider.changeQuantity], which serializes writes per line and resyncs from the
  /// server on any disagreement. The previous code computed an absolute target from an
  /// unrefreshed snapshot with no in-flight guard, so three quick `+` taps all sent
  /// `quantity = 2`.
  Future<void> _changeBy(int variantId, int delta, {String imagePath = ''}) async {
    if (!Db.isSignedIn) {
      _showToastMessage('Please sign in to add items to your cart.');
      return;
    }

    final cart = context.read<CartProvider>();
    final productId = widget.product['id'].toString();

    // Stock guard, only when going up. Advisory: this reads the catalog snapshot the
    // list was built from, so place-order re-checks it against live stock.
    if (delta > 0) {
      final variants = widget.product['variants'] as List?;
      final variant = variants?.firstWhere(
        (v) => int.tryParse(v['id']?.toString() ?? '0') == variantId,
        orElse: () => null,
      );
      if (variant != null) {
        final stock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;
        final current = cart.getQuantity('', productId, variantId.toString());
        if (current + delta > stock) {
          final lang =
              Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
          _showToastMessage(
            lang == 'hi'
                ? 'स्टॉक में केवल $stock आइटम उपलब्ध हैं'
                : lang == 'hn'
                    ? 'Stock me bas $stock items available hain'
                    : 'Only $stock items available in stock',
          );
          return;
        }
      }
    }

    final result = await cart.changeQuantity(
      productId: _productId,
      variantId: variantId,
      delta: delta,
      // The STORED path (e.g. `uploads/x.png`), not a built URL. The old backend wrote a
      // full URL with the serving host baked in, which is why existing rows contain
      // localhost and 192.168.31.10.
      imagePath: imagePath,
    );

    if (!mounted) return;
    switch (result) {
      case CartMutation.ok:
        widget.onCartUpdated?.call();
      case CartMutation.busy:
        break; // a write for this line is already running; ignore the extra tap
      case CartMutation.stale:
        widget.onCartUpdated?.call();
        _showToastMessage('Your cart changed elsewhere — refreshed.');
      case CartMutation.failed:
        widget.onCartUpdated?.call();
        _showToastMessage('Network error. Please try again.');
    }
    if (mounted) setState(() {});
  }

  Future<void> addToCart(int variantId, String imagePath) =>
      _changeBy(variantId, 1, imagePath: imagePath);

  Future<void> updateQuantityBy(int variantId, int delta) =>
      _changeBy(variantId, delta);

  Future<void> removeFromCart(int variantId) async {
    final quantity = context.read<CartProvider>().getQuantity(
          '',
          widget.product['id'].toString(),
          variantId.toString(),
        );
    if (quantity <= 0) return;
    await _changeBy(variantId, -quantity);
  }

  void _showVariantBottomSheet(List variants) {
    final productName = widget.product['name'] ?? '';
    final productImage =
    (widget.product['images'] != null && widget.product['images'].isNotEmpty)
        ? widget.product['images'][0]
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final cartProvider = Provider.of<CartProvider>(context);

              void _localAddToCart(int variantId) async {
                // Pass the stored path; the host is applied at render time.
                await addToCart(variantId, productImage);
                setModalState(() {});
              }

              void _localUpdateQuantity(int variantId, int delta) async {
                await updateQuantityBy(variantId, delta);
                setModalState(() {});
              }

              void _localRemoveFromCart(int variantId) async {
                await removeFromCart(variantId);
                setModalState(() {});
              }

              return Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 15.w),
                      child: Text(
                        productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: variants.length,
                        itemBuilder: (context, index) {
                          final variant = variants[index];
                          final variantName = variant['name'] ?? 'N/A';

                          final variantPrice = double.tryParse(variant['price']?.toString() ?? '0') ?? 0;
                          final stock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;
                          final variantSellingPrice = double.tryParse(variant['selling_price']?.toString() ?? '0') ?? 0;

                          // ✅ Discount calculate karo
                          final discountPercentage = variantPrice > 0
                              ? ((variantPrice - variantSellingPrice) / variantPrice * 100).round()
                              : 0;

                          final variantId = int.tryParse(variant['id']?.toString() ?? '0') ?? 0;
                          final quantity = cartProvider.getQuantity(
                            '',
                            widget.product['id'].toString(),
                            variantId.toString(),
                          );

                          // Out of stock check
                          final isOutOfStock = stock <= 0;

                          return Padding(
                            padding: EdgeInsets.only(left: 10.w, right: 10.w),
                            child: Container(
                              margin: EdgeInsets.only(bottom: 10.h),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              padding: EdgeInsets.all(8.w),
                              child: Stack(
                                children: [
                                  Row(
                                    children: [
                                      // 🖼️ image + badge
                                      Stack(
                                        children: [
                                          Container(
                                            width: 50.h,
                                            height: 50.h,
                                            decoration: BoxDecoration(
                                              color: AppColors.surface,
                                              borderRadius: BorderRadius.circular(10.r),
                                            ),
                                            child: Center(
                                              child: ProductImage(
                                                path:
                                                    '${widget.product['images'][0]}',
                                                width: ResponsiveHelper.getResponsiveWidth(context,
                                                  mobile: 40.w,
                                                  tablet: 50.w,
                                                  desktop: 60.w,
                                                ),
                                                height: ResponsiveHelper.getResponsiveHeight(context,
                                                  mobile: 40.h,
                                                  tablet: 50.h,
                                                  desktop: 60.h,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.r),
                                              ),
                                            ),
                                          ),

                                          // 🎯 ✅ Badge hamesha dikhega (0% bhi)
                                          Positioned(
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 2.h),
                                              decoration: BoxDecoration(
                                                color: AppColors.discount,
                                                borderRadius: BorderRadius.only(
                                                  bottomRight: Radius.circular(10.r),
                                                  topLeft: Radius.circular(10.r),
                                                ),
                                              ),
                                              child: Text(
                                                '$discountPercentage%\nOFF',
                                                style: TextStyle(
                                                  fontSize: ResponsiveHelper.getResponsiveFontSize(context,
                                                    mobile: 5.sp,
                                                    tablet: 6.sp,
                                                    desktop: 7.sp,
                                                  ),
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(width: 10.w),

                                      // Variant Name
                                      Expanded(
                                        child: Text(
                                          variantName,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),

                                      // Pricing + controls
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          if (isOutOfStock) {
                                            // Out of stock
                                            return Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.withOpacity(0.3),
                                                borderRadius: BorderRadius.circular(6.r),
                                              ),
                                              child: Text(
                                                'Out of Stock',
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  color: Colors.grey[700],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          } else if (constraints.maxWidth > 200) {
                                            // Wide screen
                                            return Row(
                                              children: [
                                                Text(
                                                  '₹${variantSellingPrice.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.w600, fontSize: 15.sp),
                                                ),

                                                // ✅ Strike-through sirf tab jab discount > 0
                                                if (discountPercentage > 0) ...[
                                                  SizedBox(width: 5.w),
                                                  Text(
                                                    '₹${variantPrice.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.normal,
                                                      fontSize: 12.sp,
                                                      decoration: TextDecoration.lineThrough,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],

                                                SizedBox(width: 10.w),
                                                _buildCartControl(
                                                    quantity,
                                                    variantId,
                                                    stock,
                                                    _localRemoveFromCart,
                                                    _localUpdateQuantity,
                                                    _localAddToCart),
                                              ],
                                            );
                                          } else {
                                            // Compact screen
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      '₹${variantSellingPrice.toStringAsFixed(0)}',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight.w600, fontSize: 15.sp),
                                                    ),

                                                    if (discountPercentage > 0) ...[
                                                      SizedBox(width: 5.w),
                                                      Text(
                                                        '₹${variantPrice.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.normal,
                                                          fontSize: 12.sp,
                                                          decoration: TextDecoration.lineThrough,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                SizedBox(height: 5.h),
                                                _buildCartControl(
                                                    quantity,
                                                    variantId,
                                                    stock,
                                                    _localRemoveFromCart,
                                                    _localUpdateQuantity,
                                                    _localAddToCart),
                                              ],
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),

                                  // Out of stock overlay
                                  if (isOutOfStock)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(20.r),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      )

                      ,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Helper method to build the cart control to avoid code duplication
  /// [updateQuantity] takes a *delta* (+1 / -1), not an absolute target — see
  /// [CartProvider.changeQuantity] for why.
  Widget _buildCartControl(int quantity, int variantId, int stock, Function(int) removeFromCart, Function(int, int) updateQuantity, Function(int) addToCart) {
    // Use a common decoration for both states to avoid code duplication
    final decoration = BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(8.r),
    );

    // Common font style for the text (High Contrast White)
    final textStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 14.sp,
      color: Colors.white,
    );

    if (quantity > 0) {
      return Container(
        decoration: decoration,
        height: 36.h, // >= Material minimum-ish; the icons inside are IconButtons
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Minus/Delete Button
                  IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16.sp,
                    icon: Icon(
                      quantity == 1 ? Icons.delete : Icons.remove,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (quantity == 1) {
                        removeFromCart(variantId);
                      } else {
                        updateQuantity(variantId, -1);
                      }
                    },
                  ),
                  // Quantity Text
                  Text(
                    quantity.toString(),
                    style: textStyle,
                  ),
                  // Add Button
                  IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16.sp,
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () {
                      if (quantity + 1 > stock) {
                        final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
                        String msg = lang == 'hi' 
                            ? 'स्टॉक में केवल $stock आइटम उपलब्ध हैं' 
                            : lang == 'hn' 
                                ? 'Stock me bas $stock items available hain' 
                                : 'Only $stock items available in stock';
                        _showToastMessage(msg);
                      } else {
                        updateQuantity(variantId, 1);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      );
    } else {
      // 'Add to Cart' button
      return GestureDetector(
        onTap: () {
          if (stock <= 0) {
            _showToastMessage(Provider.of<LanguageProvider>(context, listen: false).translate('product_out_of_stock_msg'));
          } else {
            addToCart(variantId);
          }
        },
        child: Container(
          decoration: decoration,
          height: 36.h, // >= Material minimum-ish; the icons inside are IconButtons
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Center(
              child: Text(
                Provider.of<LanguageProvider>(context).translate('add_to_cart'),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final productName = widget.product['name'] ?? '';
        final productImage =
        (widget.product['images'] != null && widget.product['images'].isNotEmpty)
            ? widget.product['images'][0]
            : null;

        final variants = widget.product['variants'] as List?;
        final Map<String, dynamic>? firstVariant =
        (variants != null && variants.isNotEmpty) ? variants[0] : null;

        final variantName = firstVariant?['name'] ?? 'N/A';
        final variantPrice = double.tryParse(firstVariant?['price']?.toString() ?? '0') ?? 0;
        final stock = int.tryParse(firstVariant?['stock']?.toString() ?? '0') ?? 0;
        final variantSellingPrice =
            double.tryParse(firstVariant?['selling_price']?.toString() ?? '0') ?? 0;

        // ✅ Discount calculate
        final discountPercentage = variantPrice > 0
            ? ((variantPrice - variantSellingPrice) / variantPrice * 100).round()
            : 0;

        final int? firstVariantId =
            int.tryParse(firstVariant?['id']?.toString() ?? '0') ?? 0;

        // ✅ Check if all variants are out of stock
        final allOutOfStock = variants != null &&
            variants.isNotEmpty &&
            variants.every((variant) =>
            (int.tryParse(variant['stock']?.toString() ?? '0') ?? 0) <= 0);
        return SizedBox(
          // 236.h rather than 222.h: 222 was tuned to sit flush against the
          // image + a two-line name + pack size + price at the *default* OS
          // text scale, with no headroom. Real phones (unlike the emulator,
          // which we tested at 1.0x) commonly ship with a larger default font
          // scale, and several OEM skins default above 1.0 out of the box.
          // 236 gives the card room to survive a moderately larger system
          // font size without the text-scale clamp below having to do all the
          // work alone.
          height: widget.height ?? 236.h,
          child: MediaQuery(
            // Caps how far the OS accessibility text-size setting can stretch
            // this specific card. This was the actual bug: a fixed-height
            // shelf card with two lines of product name, a pack-size line and
            // a price plate has no slack for arbitrary text growth, so a
            // phone with the font scale bumped past 1.0 (common on Xiaomi,
            // Oppo, Vivo and similar out of the box, and trivial for any user
            // to set under Settings > Display > Font size) rendered the
            // second name line squeezed into the pack-size line below it —
            // exactly reproduced here at font_scale 1.3 on the emulator.
            //
            // 1.15 still lets low-vision users get meaningfully larger type
            // on the shelf; the same name renders at full, unclamped scale on
            // the product detail page, where there is no such space budget.
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: 1.15),
            ),
            child: InkWell(
            borderRadius: AppRadius.mdAll,
            onTap: () async {
              if (allOutOfStock) return;

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProductDetailsScreen(product: widget.product),
                ),
              );

              if (widget.onCategoryBack != null) {
                widget.onCategoryBack!();
              }
            },
            // The card finally has a container. It used to be white on
            // white-backed screens with no border and no shadow, so the only
            // visible edge in a whole grid was the 1px line around each image
            // and the text below floated free, belonging to nothing.
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpace.w(AppSpace.sm)),
                            child: ProductImage(
                              path: productImage,
                              // Bounded to the width actually drawn. This used
                              // to be passed the card *height*, so a card ~99dp
                              // wide decoded for a 216dp box — roughly 2.6x the
                              // pixels needed, per card, per grid.
                              width: (widget.width ?? 150.w),
                              height: (widget.width ?? 150.w),
                            ),
                          ),
                        ),

                        // One discount treatment, everywhere. This was four:
                        // blue text here, a yellow corner tab in the variant
                        // sheet that rendered even at 0%, a peach pill on the
                        // detail page and a green ribbon on the variant chip.
                        if (discountPercentage > 0)
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpace.w(AppSpace.sm),
                                vertical: AppSpace.h(3),
                              ),
                              decoration: BoxDecoration(
                                gradient: AppGradients.warm,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(AppRadius.md.r),
                                  bottomRight: Radius.circular(AppRadius.md.r),
                                ),
                              ),
                              child: Text(
                                '$discountPercentage% OFF',
                                style: AppText.overline(
                                    color: AppColors.onDiscount),
                              ),
                            ),
                          ),

                        // A 44dp target instead of a bare 14dp glyph sitting
                        // directly on the packaging, and a surface behind it so
                        // it survives a light product photo.
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (!isWishlistLoading) toggleWishlist();
                            },
                            child: SizedBox(
                              width: AppSpace.w(AppSpace.minTapTarget),
                              height: AppSpace.w(AppSpace.minTapTarget),
                              child: Center(
                                child: Container(
                                  width: AppSpace.w(28),
                                  height: AppSpace.w(28),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: AppColors.border),
                                  ),
                                  child: isWishlistLoading
                                      ? SizedBox(
                                          width: AppSpace.w(12),
                                          height: AppSpace.w(12),
                                          child:
                                              const CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          isWishlisted
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          size: 16,
                                          color: isWishlisted
                                              ? AppColors.danger
                                              : AppColors.iconMuted,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ADD moves out of the text row and onto the image.
                        // In its old position it shared a Row with the pack-size
                        // chip and grew 60->78dp on tap, reflowing the chip
                        // every single time someone added an item.
                        Positioned(
                          right: AppSpace.w(AppSpace.sm),
                          bottom: AppSpace.h(AppSpace.sm),
                          child: allOutOfStock
                              ? _buildOutOfStockButton()
                              : _buildMainCartButton(
                                  variants, firstVariantId, stock),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpace.w(AppSpace.sm),
                        AppSpace.h(AppSpace.sm),
                        AppSpace.w(AppSpace.sm),
                        AppSpace.h(AppSpace.sm),
                      ),
                      // The previous version of this block sized itself
                      // against 236.h and assumed that number was the real
                      // available height. It never was, for most of this
                      // card's callers: every GRID call site (Similar
                      // Products, Search, Wishlist, Category, the detail
                      // page's "you may also like") sizes its cells from
                      // `childAspectRatio`, which imposes a TIGHT height on
                      // this Expanded regardless of what ProductCard.height
                      // says — that field only ever did anything for the
                      // horizontal rails on Home, which build their own
                      // SizedBox around the card. So the previous fix (a
                      // taller default height + a text-scale clamp) was
                      // invisible everywhere a grid was involved, which is
                      // exactly where the clipping was reported from.
                      //
                      // Structural fix instead of a size guess: measure the
                      // text block's natural height at the width this cell
                      // actually has, and if it doesn't fit — for any
                      // reason: a long name, a larger OS font-scale setting,
                      // a tighter aspect ratio some future screen picks —
                      // scale the whole block down uniformly until it does.
                      // At normal name lengths and default text scale this
                      // never engages and nothing changes visually; it is
                      // the difference between "clipped and overlapping"
                      // and "one size smaller," which is the failure mode
                      // worth having.
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: constraints.maxWidth,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // The name leads now. It used to be
                                  // rendered last and smallest (11sp w400)
                                  // under the price, while the pack size —
                                  // the least important datum on the card —
                                  // was the only element with a filled pill
                                  // behind it, so it read as the product's
                                  // title.
                                  Text(
                                    productName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.h3(),
                                  ),
                                  SizedBox(height: AppSpace.h(2)),
                                  Text(
                                    variantName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.caption(),
                                  ),
                                  SizedBox(height: AppSpace.h(AppSpace.sm)),
                                  // A warm plate behind the price with the
                                  // MRP struck through beside it. A bare
                                  // price and a bare strikethrough are two
                                  // numbers the eye has to compare; a plate
                                  // reads as "this is the deal" before
                                  // either has been parsed, which is what
                                  // matters on a shelf of twelve cards.
                                  PriceBlock(
                                    sellingPrice: variantSellingPrice,
                                    mrp: discountPercentage > 0
                                        ? variantPrice
                                        : null,
                                    highlighted: true,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainCartButton(List? variants, int? variantId, int stock) {
    final productImage =
    (widget.product['images'] != null && widget.product['images'].isNotEmpty)
        ? widget.product['images'][0]
        : null;

    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final productQuantity = cartProvider.getProductTotalQuantity('', widget.product['id'].toString());

        if (productQuantity > 0) {
          return Container(
            // The stepper needs more width than the plain ADD button because it holds
            // three controls. It only appears once the item is in the cart, by which
            // point the shopper has already read the pack size.
            width: 78.w,
            // Was 24 tall — under half the 48dp Material minimum on the two controls
            // this app exists to have people tap.
            height: 34.w,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Minus/Delete Button
                InkWell(
                  onTap: () {
                    if (productQuantity == 1) {
                      final variants = widget.product['variants'] as List;
                      for (var variant in variants) {
                        final variantId = int.tryParse(variant['id']?.toString() ?? '0') ?? 0;
                        final quantity = cartProvider
                            .getQuantity('', widget.product['id'].toString(), variantId.toString());

                        if (quantity > 0) {
                          removeFromCart(variantId);
                          break;
                        }
                      }
                    } else {
                      final variants = widget.product['variants'] as List;
                      for (var variant in variants) {
                        final variantId = int.tryParse(variant['id']?.toString() ?? '0') ?? 0;
                        final quantity = cartProvider
                            .getQuantity('', widget.product['id'].toString(), variantId.toString());

                        if (quantity > 0) {
                          updateQuantityBy(variantId, -1);
                          break;
                        }
                      }
                    }
                  },
                  child: Container(
                    // Was 18x24. These are the most-tapped controls in a grocery app
                    // and were less than half the 48dp Material minimum, which on a
                    // cheap phone with a cracked screen is a real mis-tap generator.
                    // The visual size is unchanged — the padding grows the hit area.
                    width: 34.w,
                    height: 34.w,
                    alignment: Alignment.center,
                    child: Icon(
                      productQuantity == 1 ? Icons.delete : Icons.remove,
                      size: 11.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Quantity
                Text(
                  productQuantity.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.sp,
                    color: Colors.white,
                  ),
                ),
                // Add Button
                InkWell(
                  onTap: () {
                    final variants = widget.product['variants'] as List;
                    for (var variant in variants) {
                      final variantId = int.tryParse(variant['id']?.toString() ?? '0') ?? 0;
                      final quantity = cartProvider
                          .getQuantity('', widget.product['id'].toString(), variantId.toString());

                      if (quantity > 0) {
                        final variantStock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;
                        if (quantity + 1 > variantStock) {
                          final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
                          String msg = lang == 'hi' 
                              ? 'स्टॉक में केवल $variantStock आइटम उपलब्ध हैं' 
                              : lang == 'hn' 
                                  ? 'Stock me bas $variantStock items available hain' 
                                  : 'Only $variantStock items available in stock';
                          _showToastMessage(msg);
                        } else {
                          updateQuantityBy(variantId, 1);
                        }
                        break;
                      }
                    }
                  },
                  child: Container(
                    // Was 18x24. These are the most-tapped controls in a grocery app
                    // and were less than half the 48dp Material minimum, which on a
                    // cheap phone with a cracked screen is a real mis-tap generator.
                    // The visual size is unchanged — the padding grows the hit area.
                    width: 34.w,
                    height: 34.w,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.add,
                      size: 11.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          return GestureDetector(
            onTap: () {
              if ((variants?.length ?? 0) > 1) {
                _showVariantBottomSheet(variants!);
              } else if (variantId != null) {
                if (stock <= 0) {
                  _showToastMessage(Provider.of<LanguageProvider>(context, listen: false).translate('product_out_of_stock_msg'));
                } else {
                  addToCart(variantId, productImage);
                }
              }
            },
            child: Container(
              // Width stays at the original 60: this sits beside the pack-size chip in a
              // ~100dp grid cell, and widening it squeezed "1 kg" down to an unreadable
              // sliver. Only the HEIGHT grows (24 -> 34), which is the dimension that was
              // actually failing the tap-target minimum.
              width: 60.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(color: AppColors.primary, width: 1),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        Provider.of<LanguageProvider>(context).translate('add').toUpperCase(),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10.sp,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if ((variants?.length ?? 0) > 1)
                      Padding(
                        padding: EdgeInsets.only(left: 1.w),
                        child: Icon(Icons.keyboard_arrow_down,
                            size: 10.sp, color: AppColors.primary),
                      ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildOutOfStockButton() {
    return Container(
      width: 60.w,
      height: 24.w,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Center(
        child: Text(
          Provider.of<LanguageProvider>(context).translate('out_short').toUpperCase(),
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 9.sp,
          ),
        ),
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
}