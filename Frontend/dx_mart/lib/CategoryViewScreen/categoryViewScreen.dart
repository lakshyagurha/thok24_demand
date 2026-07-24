import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../BottomNav/Screens/cartScreen.dart';
import '../CustomWidgets/product_card.dart';
import '../core/supabase.dart';
import '../data/catalog_repository.dart';
import '../data/models.dart';
import '../utils/colors.dart';
import 'package:provider/provider.dart';
import '../utils/language_provider.dart';
import '../CustomWidgets/cart_provider.dart';

/// Shapes a [Product] into the map [ProductCard] still reads. Transitional — see the
/// identical note in `homeScreen.dart`.
Map<String, dynamic> _productCardData(Product p, String lang) => {
      'id': p.id,
      'name': p.localizedName(lang),
      'images': p.images,
      'variants': [
        for (final v in p.variants)
          {
            'id': v.id,
            'name': v.localizedName(lang),
            'price': v.price,
            'selling_price': v.sellingPrice,
            'stock': v.stock,
          },
      ],
    };

class CategoryViewScreen extends StatefulWidget {
  final int? categoryId;
  final String? categoryName;

  const CategoryViewScreen({
    Key? key,
    this.categoryId,
    this.categoryName,
  }) : super(key: key);

  @override
  State<CategoryViewScreen> createState() => _CategoryViewScreenState();
}

class _CategoryViewScreenState extends State<CategoryViewScreen> {
  final CatalogRepository _catalog = const CatalogRepository();

  late int selectedCategoryId;
  List<Category> categories = [];
  List<Product> products = [];
  bool _isLoadingProducts = false;
  bool _isLoadingCategories = true;
  List<Map<String, dynamic>> cartList = [];

  @override
  void initState() {
    super.initState();
    selectedCategoryId = widget.categoryId ?? 0;
    // Names are localized from the model at render time, so no re-fetch per language.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
      fetchCartQuantity();
    });
  }

  /// Title for the header and the caller-supplied fallback. Resolved from the loaded
  /// category list so it follows the selected tab and the current language.
  String get selectedCategoryName {
    final lang = Provider.of<LanguageProvider>(context).currentLanguage;
    for (final c in categories) {
      if (c.id == selectedCategoryId) return c.localizedName(lang);
    }
    return widget.categoryName ?? "";
  }

  Future<void> fetchCartQuantity() async {
    if (!Db.isSignedIn) return;
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.refreshCartData();
      if (!mounted) return;
      setState(() {
        cartList = cartProvider.getCartItemsAsList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        cartList = [];
      });
    }
  }

  Future<void> _initializeData() async {
    await fetchCategories();
    if (selectedCategoryId == 0 && categories.isNotEmpty) {
      // Agar categoryId 0 hai to pehli category select karo
      setState(() => selectedCategoryId = categories.first.id);
    }
    if (selectedCategoryId != 0) {
      await fetchProductsByCategory(selectedCategoryId);
    }
  }

  Future<void> fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final rows = await _catalog.categories();
      if (!mounted) return;
      setState(() {
        categories = rows;
        _isLoadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        categories = [];
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> fetchProductsByCategory(int categoryId) async {
    setState(() {
      _isLoadingProducts = true;
      products = [];
    });

    try {
      final rows = await _catalog.productsByCategory(categoryId);
      if (!mounted) return;
      setState(() => products = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => products = []);
    } finally {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  Widget _buildCategoryImage(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: 45.w,
        height: 45.h,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildDefaultImage(),
      );
    } else {
      return _buildDefaultImage();
    }
  }

  Widget _buildDefaultImage() {
    return Padding(
      padding: EdgeInsets.only(top: 5.h),
      child: SvgPicture.asset(
        'assets/svg/category.svg',
        width: 26.w,
        height: 26.h,
        fit: BoxFit.contain,
        color: AppColors.primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                color: Colors.white,
                height: MediaQuery.of(context).padding.top,
              ),
              Container(
                width: double.infinity,
                height: 60.h,
                decoration: BoxDecoration(
                  color: AppColors.backgroundColor,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
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
                          height: 32.h,
                          width: 32.w,
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.arrow_back,
                              size: 18.sp,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Text(
                        selectedCategoryName.isNotEmpty ? selectedCategoryName : Provider.of<LanguageProvider>(context).translate('categories'),
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: Row(
                  children: [
                    // Left Container - Categories List
                    Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: Container(
                        width: 80.w,
                        decoration: BoxDecoration(
                            color: AppColors.neutral50,
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(10.r),
                            ),
                            border: Border(
                              right: BorderSide(color: Colors.grey.shade200, width: 1),
                            )
                        ),
                        child: _isLoadingCategories
                            ? Center(child: CircularProgressIndicator())
                            : categories.isEmpty
                            ? Center(
                          child: Text(
                            "No categories",
                            style: TextStyle(fontSize: 12.sp),
                            textAlign: TextAlign.center,
                          ),
                        )
                            : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            final int categoryId = category.id;
                            final bool isSelected = categoryId == selectedCategoryId;

                            return GestureDetector(
                              onTap: () {
                                if (categoryId != selectedCategoryId) {
                                  setState(() => selectedCategoryId = categoryId);
                                  fetchProductsByCategory(categoryId);
                                }
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    margin: EdgeInsets.symmetric(vertical: 2.h),
                                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white : Colors.transparent,
                                      borderRadius: isSelected
                                          ? BorderRadius.horizontal(left: Radius.circular(12.r))
                                          : null,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Circular icon wrapper
                                        Container(
                                          width: 44.w,
                                          height: 44.w,
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppColors.primary50 : AppColors.neutral100,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(22.r),
                                              child: _buildCategoryImage(category.imageUrl),
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        AnimatedDefaultTextStyle(
                                          duration: const Duration(milliseconds: 300),
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            color: isSelected ? AppColors.primaryColor : AppColors.neutral600,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          ),
                                          child: Text(
                                            category.localizedName(
                                              Provider.of<LanguageProvider>(context).currentLanguage,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedPositioned(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    right: isSelected ? 0 : -4.w,
                                    top: 6.h,
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryColor,
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(10.r),
                                          bottomLeft: Radius.circular(10.r),
                                        ),
                                      ),
                                      width: isSelected ? 4.w : 0,
                                      height: 40.h,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Right Container - Products
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _isLoadingProducts
                                ? Center(child: CircularProgressIndicator())
                                : products.isEmpty
                                ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 50.sp, color: Colors.grey),
                                  SizedBox(height: 10.h),
                                  Text(
                                    Provider.of<LanguageProvider>(context).translate('no_products_found'),
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                ],
                              ),
                            )
                                : GridView.builder(
                                padding: EdgeInsets.only(left: 12.w, right: 12.w, top: 12.w, bottom: cartList.isNotEmpty ? 100.h : 12.w),
                                itemCount: products.length,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.55,
                                  crossAxisSpacing: 16.w,
                                  mainAxisSpacing: 16.h,
                                ),
                              itemBuilder: (context, index) {
                                final product = products[index];
                                return ProductCard(
                                  product: _productCardData(
                                    product,
                                    Provider.of<LanguageProvider>(context).currentLanguage,
                                  ),
                                  // Identity comes from the session, never from the widget tree.
                                  userId: '',
                                  onCartUpdated: fetchCartQuantity,
                                  onCategoryBack: fetchCartQuantity,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              final uniqueItemsCount = cartProvider.getUniqueItemsCount();
              final hasItems = uniqueItemsCount > 0;

              return AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.slowMiddle,
                bottom: hasItems ? 40.h : -100.h,
                left: 80.w,
                right: 80.w,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: hasItems ? 1.0 : 0.0,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => CartScreen()));
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
                            Text(
                              Provider.of<LanguageProvider>(context).translate('go_to_cart'),
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryTextColor,
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