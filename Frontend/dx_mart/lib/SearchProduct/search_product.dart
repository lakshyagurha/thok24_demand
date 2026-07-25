import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../BottomNav/Screens/cartScreen.dart';
import '../CustomWidgets/product_card.dart';
import '../core/supabase.dart';
import '../data/catalog_repository.dart';
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
      final result = search.trim().isEmpty
          ? await repo.products(limit: 20)
          : await repo.search(search);
      if (!mounted) return;
      setState(() => products = result.map((p) => p.toCardMap()).toList());
    } catch (e) {
      debugPrint('Search failed: $e');
      if (mounted) setState(() => products = []);
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

              // ✅ Products Grid or No Results
              if (products.isNotEmpty)
                Expanded(child: buildSection(products)),

              if (hasSearched && products.isEmpty && !isLoading)
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

          // ✅ Floating Cart Button (Only show if cartList is not empty)
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              final uniqueItemsCount = cartProvider.getUniqueItemsCount();
              final hasItems = uniqueItemsCount > 0;

              return AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.slowMiddle,
                bottom: (hasItems && !_isListening) ? 40.h : -100.h, // Hide below screen
                left: 80.w,
                right: 80.w,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: (hasItems && !_isListening) ? 1.0 : 0.0, // Fade in/out
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
                            Icon(Icons.arrow_forward_ios_outlined, color: AppColors.primaryTextColor, size: 16.sp),
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

  /// ✅ Custom Header with Search Bar
  Widget buildAppBar() {
    return Container(
      width: double.infinity,
      height: 110.h,
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
      ),
      child: Column(
        children: [
          SizedBox(height: 15.h),

          Padding(
            padding:  EdgeInsets.only(top: 10.h),
            child: Row(
              children: [
                SizedBox(width: 13.w),

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
              height: 40.h,
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.lineColor, width: 1.5),
              ),
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 20.sp, color: AppColors.hintTextColor),
                  SizedBox(width: 6.w),

                  /// ✅ Expanded TextField with Animated Placeholder
                  Expanded(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // ✅ Animated Hint (visible only when empty)
                        if (searchController.text.isEmpty)
                          IgnorePointer(
                            child: AnimatedTextKit(
                              repeatForever: true,
                              pause: Duration(milliseconds: 2000),
                              animatedTexts: [
                                TyperAnimatedText(Provider.of<LanguageProvider>(context).translate('search_grocery'),
                                    textStyle: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.hintTextColor),
                                    speed: Duration(milliseconds: 80)),
                                TyperAnimatedText(Provider.of<LanguageProvider>(context).translate('search_beauty'),
                                    textStyle: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.hintTextColor),
                                    speed: Duration(milliseconds: 80)),
                                TyperAnimatedText(Provider.of<LanguageProvider>(context).translate('search_snacks'),
                                    textStyle: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.hintTextColor),
                                    speed: Duration(milliseconds: 80)),
                              ],
                            ),
                          ),

                        // ✅ TextField
                        Padding(
                          padding:  EdgeInsets.only(top: 8.h),
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
                              contentPadding: EdgeInsets.only(bottom: 8.h),
                            ),
                            onChanged: (value) {
                              setState(() {}); // update clear button
                            },
                            onSubmitted: (value) {
                              fetchProducts(search: value);
                            },
                          ),
                        ),
                      ],
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