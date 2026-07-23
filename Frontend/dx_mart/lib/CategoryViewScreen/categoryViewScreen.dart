import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../BottomNav/Screens/cartScreen.dart';
import '../CustomWidgets/product_card.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';
import 'package:provider/provider.dart';
import '../utils/language_provider.dart';
import '../CustomWidgets/cart_provider.dart';

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
  late int selectedCategoryId;
  late String selectedCategoryName;
  List categories = [];
  List products = [];
  bool _isLoadingProducts = false;
  bool _isLoadingCategories = true;
  List<Map<String, dynamic>> cartList = [];

  String userEmail = "";
  String userName = "";
  String userID = "";
  String _lastFetchedLang = "";
  // shopId को हटा दिया गया

  @override
  void initState() {
    super.initState();
    fetchUserData();
    selectedCategoryId = widget.categoryId ?? 0;
    selectedCategoryName = widget.categoryName ?? "";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final activeLang = Provider.of<LanguageProvider>(context).currentLanguage;
    if (_lastFetchedLang != activeLang) {
      _lastFetchedLang = activeLang;
      fetchCategories();
      if (selectedCategoryId != 0) {
        fetchProductsByCategory(selectedCategoryId);
      }
    }
  }

  Future<void> fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('user_email');
    // shopId को हटा दिया गया
    if (email != null) {
      setState(() => userEmail = email);
      fetchUserDetails(email);
    }
  }

  Future<void> fetchUserDetails(String email) async {
    final url = Uri.parse(ApiConstants.BASE_URL + "auth/get_user.php?email=$email");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["status"] == "success") {
          setState(() {
            userName = data["user"]["name"];
            userID = data["user"]["id"];
            fetchCartQuantity(userID);
            _initializeData();
          });
        }
      }
    } catch (e) {
      print("Error fetching user details: $e");
    }
  }

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

  Future<void> _initializeData() async {
    await fetchCategories();
    if (selectedCategoryId != 0) {
      await fetchProductsByCategory(selectedCategoryId);
    } else if (categories.isNotEmpty) {
      // Agar categoryId 0 hai to pehli category select karo
      setState(() {
        selectedCategoryId = int.tryParse(categories[0]['id'].toString()) ?? 0;
        selectedCategoryName = categories[0]['name'] ?? "";
      });
      await fetchProductsByCategory(selectedCategoryId);
    }
  }

  Future<void> fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
      final url = Uri.parse("${ApiConstants.MAIN_VIEW_CATEGORY}?lang=$lang");

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          setState(() {
            categories = data;
            _isLoadingCategories = false;

            // Sync selectedCategoryName with localized name from categories list
            final currentCategory = categories.firstWhere(
              (cat) => (int.tryParse(cat['id'].toString()) ?? 0) == selectedCategoryId,
              orElse: () => null,
            );
            if (currentCategory != null) {
              selectedCategoryName = currentCategory['name'] ?? selectedCategoryName;
            }
          });
        } else if (data is Map && data.containsKey('success') && !data['success']) {
          setState(() {
            categories = [];
            _isLoadingCategories = false;
          });
        } else {
          setState(() {
            categories = [];
            _isLoadingCategories = false;
          });
        }
      } else {
        setState(() {
          categories = [];
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
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

    final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
    final url = Uri.parse(
      '${ApiConstants.VIEW_ALL_PRODUCTS_BY_CATEGORY}?category_id=$categoryId&lang=$lang',
    );

    try {
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          if (data is List) {
            products = data;
          } else if (data['products'] != null) {
            products = data['products'];
          } else {
            products = [];
          }
          _processProductVariants();
        });
      } else {
        setState(() {
          products = [];
        });
      }
    } catch (e) {
      setState(() {
        products = [];
      });
    } finally {
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  void _processProductVariants() {
    for (var product in products) {
      if (product['variants'] != null && product['variants'].isNotEmpty) {
        product['selectedVariantName'] = product['variants'][0]['name'];
        product['selectedPrice'] = double.tryParse(
          product['variants'][0]['selling_price'].toString(),
        );
      } else {
        product['selectedVariantName'] = null;
        product['selectedPrice'] = null;
      }
    }
  }

  Widget _buildCategoryImage(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        ApiConstants.BASE_URL + 'main_category/$imageUrl',
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
                            final int categoryId = int.tryParse(category['id'].toString()) ?? 0;
                            final bool isSelected = categoryId == selectedCategoryId;

                            return GestureDetector(
                              onTap: () {
                                if (categoryId != selectedCategoryId) {
                                  setState(() {
                                    selectedCategoryId = categoryId;
                                    selectedCategoryName = category['name'] ?? "";
                                  });
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
                                              child: _buildCategoryImage(category['image']),
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
                                            category['name'] ?? 'Category',
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
                                  product: product,
                                  userId: userID,
                                  onCartUpdated: () {
                                    fetchCartQuantity(userID);
                                  },
                                  onCategoryBack: (){
                                    setState(() {
                                      fetchCartQuantity(userID);
                                    });
                                  },
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
              final uniqueItemsCount = cartProvider.getUniqueItemsCount(userID);
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