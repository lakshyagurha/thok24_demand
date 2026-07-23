import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../ProductDetailScreen/product_details_screen.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';
import '../utils/responsive_helper.dart';
import 'cart_provider.dart';
import '../utils/language_provider.dart';

class ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final String userId;
  final VoidCallback? onCartUpdated;
  final VoidCallback? onWishlistUpdated;
  final VoidCallback? onCategoryBack;
  final double? height;

  const ProductCard({
    Key? key,
    required this.product,
    required this.userId,
    this.onCartUpdated,
    this.onWishlistUpdated,
    this.onCategoryBack,
    this.height,
  }) : super(key: key);

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  String deliveryTime = '17 MIN';
  bool isLoading = false;
  bool isWishlisted = false;
  bool isWishlistLoading = false;

  @override
  void initState() {
    super.initState();
    fetchDeliveryTime();
    checkWishlistStatus();
  }

  Future<void> checkWishlistStatus() async {
    if (widget.userId.isEmpty) return;

    setState(() {
      isWishlistLoading = true;
    });

    try {
      final url = Uri.parse('${ApiConstants.CHECK_WISHLIST}?user_id=${widget.userId}&product_id=${widget.product['id']}');
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          isWishlisted = data['is_wishlisted'] ?? false;
        });
      }
    } catch (e) {
      print('Error checking wishlist status: $e');
    } finally {
      setState(() {
        isWishlistLoading = false;
      });
    }
  }

  Future<void> toggleWishlist() async {
    if (widget.userId.isEmpty) {
      // Optionally show a login prompt here
      return;
    }

    setState(() {
      isWishlistLoading = true;
    });

    try {
      final url = Uri.parse(isWishlisted ? ApiConstants.REMOVE_FROM_WISHLIST : ApiConstants.ADD_TO_WISHLIST);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': widget.userId,
          'product_id': widget.product['id'],
        }),
      );

      final data = json.decode(response.body);
      if (data['success']) {
        setState(() {
          isWishlisted = !isWishlisted;
        });
        widget.onWishlistUpdated?.call();
      }
    } catch (e) {
      print('Error toggling wishlist: $e');
    } finally {
      setState(() {
        isWishlistLoading = false;
      });
    }
  }

  Future<void> fetchDeliveryTime() async {
    final url = Uri.parse(ApiConstants.DELIVERY_TIME);

    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          deliveryTime = data['data']['time'];
        });
      } else {
        setState(() {
          deliveryTime = 'No time found';
        });
      }
    } catch (e) {
      setState(() {
        deliveryTime = 'Error fetching time';
      });
    }
  }

  // Helper method to show toast message
  void _showToastMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.errorColor,
      ),
    );
  }

  Future<void> addToCart(int variantId, String imageUrl) async {
    setState(() {
      isLoading = true;
    });

    try {
      final productId = widget.product['id'].toString();

      final url = Uri.parse(ApiConstants.ADD_TO_CART);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': widget.userId.toString(),
          'product_id': productId,
          'variant_id': variantId.toString(),
          'quantity': 1,
          'image_url': imageUrl,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);

        cartProvider.updateCartQuantities(
          widget.userId,
          productId,
          variantId.toString(),
          1,
          data['cart_id'] ?? 0,
        );

        widget.onCartUpdated?.call();
        setState(() {});
      } else {
        Fluttertoast.showToast(
          msg: data['message'] ?? "Failed to add to cart!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('❌ Error adding to cart: $e');
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


  // didChangeDependencies removed to optimize performance and prevent duplicate parallel API requests


  Future<void> updateQuantity(int variantId, int newQuantity) async {
    setState(() {
      isLoading = true;
    });

    try {
      // Variant stock check
      final variants = widget.product['variants'] as List;
      final variant = variants.firstWhere(
            (v) => int.tryParse(v['id']?.toString() ?? '0') == variantId,
        orElse: () => null,
      );

      if (variant != null) {
        final stock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;
        if (newQuantity > stock) {
          final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
          String msg = lang == 'hi' 
              ? 'स्टॉक में केवल $stock आइटम उपलब्ध हैं' 
              : lang == 'hn' 
                  ? 'Stock me bas $stock items available hain' 
                  : 'Only $stock items available in stock';
          _showToastMessage(msg);
          return;
        }
      }

      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final productId = widget.product['id'].toString();

      int cartId = cartProvider.getCartId(widget.userId, productId, variantId.toString());

      // 🟢 FIX: Try direct API if local cartId is not found
      if (cartId == 0) {
        cartId = await _findCartIdDirectly(widget.userId, productId, variantId.toString());

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

      // Update API call
      final url = Uri.parse(ApiConstants.UPDATE_QUANTITY);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': cartId, 'quantity': newQuantity}),
      );

      final data = json.decode(response.body);
      if (data['success']) {
        _refreshCartData(); // UI refresh
        cartProvider.updateCartQuantities(
          widget.userId,
          productId,
          variantId.toString(),
          newQuantity,
          cartId,
        );
        widget.onCartUpdated?.call();
        setState(() {});
      } else {
        print("⚠️ Update quantity API failed: ${data['message']}");
        Fluttertoast.showToast(
          msg: "Failed to update quantity",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error updating quantity: $e');
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


  Future<int> _findCartIdDirectly(String userId, String productId, String variantId) async {
    try {
      final url = Uri.parse('${ApiConstants.GET_CART_ITEMS}?user_id=$userId');
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['success']) {
        final cartItems = List<Map<String, dynamic>>.from(data['cart'] ?? []);

        for (var item in cartItems) {
          final itemProductId = item['product_id'].toString();
          final itemVariantId = item['variant_id'].toString();

          if (itemProductId == productId && itemVariantId == variantId) {
            return item['id'] as int;
          }
        }
      }
    } catch (e) {
      print('Error finding cart ID directly: $e');
    }

    return 0;
  }



  void _refreshCartData() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.refreshCartData(widget.userId).then((_) {
      setState(() {}); // Force UI update
    });
  }

  Future<void> removeFromCart(int variantId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final cartId = cartProvider.getCartId(widget.userId, widget.product['id'].toString(), variantId.toString());

      final url = Uri.parse('${ApiConstants.REMOVE_CART_ITEM}?id=$cartId');
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['success']) {
        cartProvider.removeCartItem(widget.userId, widget.product['id'].toString(), variantId.toString());
        widget.onCartUpdated?.call();
        // Force UI update
        setState(() {});
      }
    } catch (e) {
      print('Error removing from cart: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
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
      backgroundColor: AppColors.backgroundColor,
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
                final imageUrl = ApiConstants.BASE_URL + 'product_api_project/$productImage';
                await addToCart(variantId, imageUrl);
                setModalState(() {});
              }

              void _localUpdateQuantity(int variantId, int newQty) async {
                await updateQuantity(variantId, newQty);
                setModalState(() {});
              }

              void _localRemoveFromCart(int variantId) async {
                await removeFromCart(variantId);
                setModalState(() {});
              }

              return Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.backgroundColor,
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
                          color: AppColors.primaryTextColor,
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
                            widget.userId,
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
                                color: AppColors.primaryColor.withOpacity(0.1),
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
                                              color: AppColors.backgroundColor,
                                              borderRadius: BorderRadius.circular(10.r),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12.r),
                                              child: Center(
                                                child: Image.network(
                                                  ApiConstants.BASE_URL +
                                                      'product_api_project/${widget.product['images'][0]}',
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
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) =>
                                                      Icon(Icons.image, size: ResponsiveHelper.getResponsiveFontSize(context,
                                                        mobile: 24.sp,
                                                        tablet: 28.sp,
                                                        desktop: 32.sp,
                                                      )),
                                                ),
                                              ),
                                            ),
                                          ),

                                          // 🎯 ✅ Badge hamesha dikhega (0% bhi)
                                          Positioned(
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 2.h),
                                              decoration: BoxDecoration(
                                                color: AppColors.secondaryColor,
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
                                                  color: AppColors.primaryTextColor,
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
  Widget _buildCartControl(int quantity, int variantId, int stock, Function(int) removeFromCart, Function(int, int) updateQuantity, Function(int) addToCart) {
    // Use a common decoration for both states to avoid code duplication
    final decoration = BoxDecoration(
      color: AppColors.primaryColor,
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
        height: 28.h, // Increased for better tap target
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
                        updateQuantity(variantId, quantity - 1);
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
                        updateQuantity(variantId, quantity + 1);
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
          height: 28.h, // Increased for better tap target
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
          height: widget.height ?? 216.w,
          child: InkWell(
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
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🖼️ Image Container (acts as separation, has border)
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.grey.shade200, width: 1),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.r),
                            child: Padding(
                              padding: EdgeInsets.all(8.w),
                              child: Center(
                                child: Image.network(
                                  ApiConstants.BASE_URL +
                                      'product_api_project/$productImage',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    "assets/images/placeholder_product_card.png",
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ❤️ Wishlist
                          Positioned(
                            top: 6.w,
                            right: 6.w,
                            child: GestureDetector(
                              onTap: () {
                                if (!isWishlistLoading) {
                                  toggleWishlist();
                                }
                              },
                              child: isWishlistLoading
                                  ? SizedBox(
                                      width: 14.w,
                                      height: 14.w,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.primaryColor),
                                      ),
                                    )
                                  : SvgPicture.asset(
                                      isWishlisted
                                          ? 'assets/svg/wishlist_red.svg'
                                          : 'assets/svg/fev.svg',
                                      width: 14.w,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4.w),

                          // 1. Weight Tag and ADD button Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Weight Tag
                              Flexible(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 6.w, vertical: 3.w),
                                  decoration: BoxDecoration(
                                    color: AppColors.neutral100,
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    variantName,
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: AppColors.primaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                              // ADD Button
                              allOutOfStock
                                  ? _buildOutOfStockButton()
                                  : _buildMainCartButton(variants, firstVariantId, stock),
                            ],
                          ),
                          SizedBox(height: 4.w),

                          // 2. Price Row (Highlighted)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '₹${variantSellingPrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.sp,
                                  color: AppColors.primaryTextColor,
                                ),
                              ),
                              if (discountPercentage > 0) ...[
                                SizedBox(width: 4.w),
                                Text(
                                  '₹${variantPrice.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    fontSize: 10.sp,
                                    decoration: TextDecoration.lineThrough,
                                    color: AppColors.neutral400,
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // 3. Discount text (blue)
                          if (discountPercentage > 0) ...[
                            SizedBox(height: 1.w),
                            Text(
                              '$discountPercentage% OFF',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 9.sp,
                                color: const Color(0xFF2563EB), // Premium Blue
                              ),
                            ),
                          ],
                          SizedBox(height: 4.w),

                          // 4. Product Title / Name (At the bottom)
                          Flexible(
                            child: Text(
                              productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 11.sp,
                                height: 1.3,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),


                ],
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
        final productQuantity = cartProvider.getProductTotalQuantity(widget.userId, widget.product['id'].toString());

        if (productQuantity > 0) {
          return Container(
            width: 60.w,
            height: 24.w,
            decoration: BoxDecoration(
              color: AppColors.primaryColor,
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
                            .getQuantity(widget.userId, widget.product['id'].toString(), variantId.toString());

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
                            .getQuantity(widget.userId, widget.product['id'].toString(), variantId.toString());

                        if (quantity > 0) {
                          updateQuantity(variantId, quantity - 1);
                          break;
                        }
                      }
                    }
                  },
                  child: Container(
                    width: 18.w,
                    height: 24.w,
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
                          .getQuantity(widget.userId, widget.product['id'].toString(), variantId.toString());

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
                          updateQuantity(variantId, quantity + 1);
                        }
                        break;
                      }
                    }
                  },
                  child: Container(
                    width: 18.w,
                    height: 24.w,
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
                  final imageUrl = ApiConstants.BASE_URL +
                      'product_api_project/$productImage';
                  addToCart(variantId, imageUrl);
                }
              }
            },
            child: Container(
              width: 60.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(color: AppColors.primaryColor, width: 1),
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
                          color: AppColors.primaryColor,
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
                            size: 10.sp, color: AppColors.primaryColor),
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