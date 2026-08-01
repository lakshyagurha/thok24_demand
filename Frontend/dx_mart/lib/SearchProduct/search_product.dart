import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../BottomNav/Screens/cartScreen.dart';
import '../CategoryViewScreen/categoryViewScreen.dart';
import '../CustomWidgets/product_card.dart';
import '../core/supabase.dart';
import '../data/catalog_repository.dart';
import '../data/models.dart';
import '../design/components/app_header.dart';
import '../design/components/cart_bar.dart';
import '../utils/colors.dart';
import 'package:provider/provider.dart';
import '../CustomWidgets/cart_provider.dart';
import '../utils/language_provider.dart';

class SearchProduct extends StatefulWidget {
  final String? category_name; // category name optional
  const SearchProduct({super.key, this.category_name});

  @override
  State<SearchProduct> createState() => _SearchProductState();
}

class _SearchProductState extends State<SearchProduct> {
  TextEditingController searchController = TextEditingController();
  List products = [];

  /// Category matches for the current term.
  ///
  /// Searching "dairy" used to return only products whose *name* contained "dairy" —
  /// so it found the dairy whitener and missed the entire Dairy, Bread & Eggs shelf.
  /// Shown above the products because a matching aisle is a better answer than a
  /// partial name match: one tap gets the whole shelf.
  List<Category> categoryHits = [];
  bool isLoading = false;
  String currentSearchTerm = "";
  bool hasSearched = false;

  List<Map<String, dynamic>> cartList = [];


  // Voice recognition variables
  stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    fetchProducts(); // First load all products
    _refreshCart();
    _initializeSpeech();
  }

  // Initialize speech to text
  void _initializeSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        if (status == 'done') {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (errorNotification) {
        print('Speech error: $errorNotification');
        setState(() {
          _isListening = false;
        });
      },
    );

    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice search not available on this device')),
      );
    }
  }

  // Start listening for voice input
  void _startListening() async {
    if (!_speech.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice search not available')),
      );
      return;
    }

    setState(() {
      _isListening = true;
      _recognizedText = '';
    });

    _speech.listen(
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
          if (result.finalResult) {
            searchController.text = _recognizedText;
            fetchProducts(search: _recognizedText);
            _isListening = false;
          }
        });
      },
      listenFor: Duration(seconds: 10),
      pauseFor: Duration(seconds: 5),
      partialResults: true,
      localeId: 'en_US',
    );
  }

  // Stop listening
  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  Future<void> fetchProducts({String search = ""}) async {
    setState(() {
      isLoading = true;
      currentSearchTerm = search;
      hasSearched = true;
    });

    try {
      final repo = const CatalogRepository();
      // An empty query means "show the catalog", not "search for nothing".
      final isBrowse = search.trim().isEmpty;
      // Categories are matched in memory against the cached tree, so this adds no
      // round trip to the search.
      final results = await Future.wait([
        isBrowse ? repo.products(limit: 20) : repo.search(search),
        if (!isBrowse) repo.searchCategories(search),
      ]);
      if (!mounted) return;
      setState(() {
        products = (results[0] as List<Product>)
            .map((p) => p.toCardMap())
            .toList();
        categoryHits =
            isBrowse ? const [] : (results[1] as List<Category>);
      });
    } catch (e) {
      debugPrint('Search failed: $e');
      if (mounted) {
        setState(() {
          products = [];
          categoryHits = [];
        });
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Cart sync. RLS scopes this to the signed-in user, so there is no id to pass and
  /// no email-to-id lookup to perform.
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

  /// ✅ Cart quantity fetch

  @override
  void dispose() {
    _speech.stop();
    searchController.dispose();
    super.dispose();
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

              // ✅ Top Custom AppBar with Search Bar
              buildAppBar(),

              SizedBox(height: 10.h),

              // ✅ Showing Results Text
              if (hasSearched && currentSearchTerm.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: Provider.of<LanguageProvider>(context).currentLanguage == 'hi'
                                ? '"$currentSearchTerm" के लिए परिणाम'
                                : Provider.of<LanguageProvider>(context).currentLanguage == 'hn'
                                    ? '"$currentSearchTerm" ke liye results'
                                    : 'Showing Results for "$currentSearchTerm"',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              SizedBox(height: 10.h),

              // ✅ Matching categories, then the products grid
              if (categoryHits.isNotEmpty) buildCategoryHits(),

              if (products.isNotEmpty)
                Expanded(child: buildSection(products)),

              if (hasSearched &&
                  products.isEmpty &&
                  categoryHits.isEmpty &&
                  !isLoading)
                Expanded(
                  child: Center(
                    child: Text(
                      Provider.of<LanguageProvider>(context).translate('no_products_found'),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.hintTextColor,
                      ),
                    ),
                  ),
                ),

              if (isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),

          // Voice listening overlay
          if (_isListening)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mic,
                        size: 64.sp,
                        color: Colors.white,
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        Provider.of<LanguageProvider>(context).translate('listening'),
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        _recognizedText,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 30.h),
                      ElevatedButton(
                        onPressed: _stopListening,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(
                            horizontal: 30.w,
                            vertical: 15.h,
                          ),
                        ),
                        child: Text(
                          Provider.of<LanguageProvider>(context).translate('stop_listening'),
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
      bottomNavigationBar: _isListening
          ? null
          : Consumer<CartProvider>(
              builder: (context, cart, _) => CartBar(
                itemCount: cart.getUniqueItemsCount(),
                label: Provider.of<LanguageProvider>(context, listen: false)
                    .translate('view_cart'),
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => CartScreen()));
                },
              ),
            ),
    );
  }

  /// ✅ Custom Header with Search Bar
  Widget buildAppBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 15.h),

          Padding(
            padding:  EdgeInsets.only(top: 10.h),
            child: Row(
              children: [
                SizedBox(width: 13.w),

                AppBackButton(onTap: () => Navigator.pop(context)),
                Spacer(),

                Text(Provider.of<LanguageProvider>(context).translate('search'), style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15.sp,
                )),
                Spacer(),

                SizedBox(width: 40.w),
              ],
            ),
          ),

          SizedBox(height: 20.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.lineColor, width: 1.5),
              ),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 20.sp, color: AppColors.hintTextColor),
                  SizedBox(width: 6.w),

                  /// A single static hint, not a looping typewriter. The
                  /// animation lived in a Stack next to the real field with
                  /// its own, different top padding — the moving hint text
                  /// and the real caret sat on two different baselines,
                  /// which is what read as "an input under the input."
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        isCollapsed: true,
                        hintText: Provider.of<LanguageProvider>(context)
                            .translate('search_placeholder'),
                        hintStyle: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.hintTextColor,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {}); // update clear button
                      },
                      onSubmitted: (value) {
                        fetchProducts(search: value);
                      },
                    ),
                  ),

                  /// ✅ Mic / Clear button
                  if (searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        searchController.clear();
                        fetchProducts();
                        setState(() {});
                      },
                      child: Icon(Icons.close, size: 18.sp, color: Colors.grey),
                    )
                  else
                    GestureDetector(
                      onTap: _startListening,
                      child: Icon(
                        Icons.mic,
                        size: 20.sp,
                        color: _isListening ? AppColors.primaryColor : AppColors.hintTextColor,
                      ),
                    ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  /// Matching aisles, as a horizontal chip row above the product grid.
  ///
  /// A row rather than a list so it costs a fixed strip of height no matter how many
  /// match — the products are still the main answer and must not be pushed off screen.
  Widget buildCategoryHits() {
    final lang = Provider.of<LanguageProvider>(context);
    final code = lang.currentLanguage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          child: Text(
            lang.translate('categories'),
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.hintTextColor,
            ),
          ),
        ),
        SizedBox(
          height: 36.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: categoryHits.length,
            separatorBuilder: (_, _) => SizedBox(width: 8.w),
            itemBuilder: (context, i) {
              final c = categoryHits[i];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryViewScreen(
                      categoryId: c.id,
                      categoryName: c.localizedName(code),
                    ),
                  ),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        c.isUmbrella
                            ? Icons.widgets_outlined
                            : Icons.label_outline,
                        size: 14.sp,
                        color: AppColors.primaryColor,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        c.localizedName(code),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${c.productCount}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.hintTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 8.h),
      ],
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