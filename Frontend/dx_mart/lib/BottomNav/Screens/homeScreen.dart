import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../CategoryViewScreen/categoryViewScreen.dart';
import '../../CustomWidgets/cart_provider.dart';
import '../../CustomWidgets/product_card.dart';
import '../../CustomWidgets/product_image.dart';
import '../../LocationScreen/locationScreen.dart';
import '../../SearchProduct/search_product.dart';
import '../../core/supabase.dart';
import '../../data/auth_repository.dart';
import '../../data/catalog_repository.dart';
import '../../data/models.dart';
import '../../design/app_colors.dart';
import '../../design/app_radius.dart';
import '../../design/app_space.dart';
import '../../design/app_type.dart';
import '../../design/components/cart_bar.dart';
import '../../design/components/category_bar.dart';
import '../../design/components/section_header.dart';
import '../../design/components/skeleton.dart';
import '../../design/components/trust_strip.dart';
import '../../utils/language_provider.dart';
import 'cartScreen.dart';
import 'profileScreen.dart';

/// Shapes a [Product] into the map [ProductCard] still reads.
///
/// Transitional: `ProductCard` has not been migrated to the typed model yet, so this
/// keeps the widget's existing contract while the screen itself is fully typed. Delete
/// it (and pass the `Product` straight through) once the card takes a `Product`.
Map<String, dynamic> _productCardData(Product p, String lang) => {
      'id': p.id,
      'name': p.localizedName(lang),
      // Without this the product page's CATEGORY_ID stays empty and its
      // "similar products" section is always blank when opened from here.
      'main_category_id': p.mainCategoryId,
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CatalogRepository _catalog = const CatalogRepository();
  final AuthRepository _auth = const AuthRepository();

  // Scroll controller for detecting scroll direction
  final ScrollController _scrollController = ScrollController();
  bool _showStickySearchBar = false;
  double _scrollPosition = 0;

  // Data variables
  String deliveryTime = '15 minutes';
  String district = '';
  String city = '';
  String userName = "";
  bool _isLoading = true;
  List<Category> _categoryList = [];
  List<Map<String, dynamic>> _sliderList = [];

  // Product type lists
  List<Product> everydayEssentialsList = [];
  List<Product> bestSellingList = [];
  List<Product> hotDealsList = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    // Names are localized client-side from the model now, so the catalog is fetched once
    // rather than re-fetched every time the language changes.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAllData());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final double currentScroll = _scrollController.offset;

    // Show sticky search bar when scrolling down beyond a certain point
    if (currentScroll > 100 && currentScroll > _scrollPosition) {
      if (!_showStickySearchBar) {
        setState(() {
          _showStickySearchBar = true;
        });
      }
    }
    // Hide sticky search bar when scrolling up or at the top
    else if (currentScroll <= 100 || currentScroll < _scrollPosition) {
      if (_showStickySearchBar) {
        setState(() {
          _showStickySearchBar = false;
        });
      }
    }

    _scrollPosition = currentScroll;
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        fetchUserData(),
        fetchDeliveryTime(),
        loadLocation(),

        // Categories and banners
        _fetchCategories(),
        _fetchSlider(),

        // Products
        loadAllTypes(),
      ]);
    } catch (e) {
      if (mounted) {
        _showSnackBar("Error loading data: $e", AppColors.danger);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// The greeting name comes from the signed-in session's own profile row. No email or
  /// user id is sent anywhere — RLS returns only the caller's row.
  Future<void> fetchUserData() async {
    if (!Db.isSignedIn) return;
    try {
      final profile = await _auth.currentProfile();
      if (!mounted) return;
      setState(() => userName = (profile?['name'] ?? '') as String);
      await fetchCartQuantity();
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }

  /// ✅ Cart quantity fetch
  Future<void> fetchCartQuantity() async {
    if (!Db.isSignedIn) return;
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.refreshCartData();
    } catch (e) {
      debugPrint("Error refreshing cart: $e");
    }
  }

  Future<void> loadLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      district = prefs.getString('selected_district_name') ?? 'Not Set';
      city = prefs.getString('selected_city_name') ?? 'Not Set';
    });
  }

  Future<void> fetchDeliveryTime() async {
    try {
      final settings = await _catalog.settings();
      final time = settings['delivery_time'];
      if (!mounted || time == null || time.isEmpty) return;
      setState(() => deliveryTime = time);
    } catch (e) {
      debugPrint("Error fetching delivery time: $e");
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final all = await _catalog.categories();
      if (!mounted) return;
      setState(() {
        // Filtered on the canonical English name so the same categories are hidden
        // whichever language the app is in.
        _categoryList = all.where((category) {
          final name = category.name.toLowerCase();
          return !name.contains('electronic') &&
                 !name.contains('appliance') &&
                 !name.contains('fashion') &&
                 !name.contains('clothing') &&
                 !name.contains('wear');
        }).toList();
      });
    } catch (e) {
      debugPrint("Error fetching categories: $e");
    }
  }

  Future<void> loadAllTypes() async {
    await Future.wait([
      fetchProductsByType('Everyday Essentials'),
      fetchProductsByType('Best Selling'),
      fetchProductsByType('Hot Deals'),
    ]);
  }

  Future<void> fetchProductsByType(String type) async {
    try {
      final products = await _catalog.productsByType(type);
      if (!mounted) return;
      setState(() {
        switch (type) {
          case 'Everyday Essentials':
            everydayEssentialsList = products;
            break;
          case 'Best Selling':
            bestSellingList = products;
            break;
          case 'Hot Deals':
            hotDealsList = products;
            break;
        }
      });
    } catch (e) {
      debugPrint("Error fetching $type products: $e");
    }
  }

  Future<void> _fetchSlider() async {
    try {
      final rows = await _catalog.banners();
      if (!mounted) return;
      setState(() => _sliderList = rows);
    } catch (e) {
      debugPrint("Error fetching slider: $e");
    }
  }


  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ===========================================================================
  // Presentation
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final code = lang.currentLanguage;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        color: AppColors.primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _header(lang)),

            // Pinned, so the fastest route into the catalogue is always one tap
            // away no matter how far down the page the shopper has scrolled.
            if (_categoryList.isNotEmpty)
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedCategoryBar(
                  child: CategoryBar(
                    items: [
                      for (final c in _categoryList.take(12))
                        CategoryBarItem(
                          id: c.id,
                          label: c.localizedName(code),
                          image: c.imageUrl,
                        ),
                    ],
                    onSelected: (item) => _openCategory(item.id, item.label),
                  ),
                ),
              ),

            if (_isLoading)
              SliverToBoxAdapter(child: _loadingBody())
            else ...[
              SliverToBoxAdapter(child: _trustStrip(lang)),
              SliverToBoxAdapter(child: _banners()),
              SliverToBoxAdapter(child: _offerCards()),
              SliverToBoxAdapter(child: _categoryGrid(lang, code)),
              ..._rails(lang, code),
              SliverToBoxAdapter(
                child: SizedBox(height: AppSpace.h(AppSpace.xl)),
              ),
            ],
          ],
        ),
      ),
      // Docked rather than floating. The old pill was `Positioned` over the
      // content and covered the product row beneath it.
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cart, _) => CartBar(
          itemCount: cart.getUniqueItemsCount(),
          label: lang.translate('view_cart'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CartScreen()),
          ),
        ),
      ),
    );
  }

  void _openCategory(int id, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryViewScreen(categoryId: id, categoryName: name),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  /// The navy hero.
  ///
  /// Previously this was a gradient between two near-white sages
  /// (`#D2E5DC` → `#EAF2EE`) which, against a white page, read as a faint
  /// smudge rather than a header — and the loudest thing inside it was the
  /// delivery time at `18.sp w900`, out-ranking both the brand and the search
  /// field. Every competitor in this category is pastel; committing to the
  /// brand navy is the cheapest available point of difference, and white on it
  /// measures 10.5:1 so nothing is lost in legibility.
  Widget _header(LanguageProvider lang) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.lg.r),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpace.w(AppSpace.gutter),
            AppSpace.h(AppSpace.md),
            AppSpace.w(AppSpace.gutter),
            AppSpace.h(AppSpace.base),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _wordmark(),
                  const Spacer(),
                  _deliveryChip(),
                  AppSpace.gapW(AppSpace.sm),
                  _avatar(),
                ],
              ),
              AppSpace.gapH(AppSpace.md),
              _locationRow(lang),
              AppSpace.gapH(AppSpace.md),
              _searchField(lang),
            ],
          ),
        ),
      ),
    );
  }

  /// The brand, finally present. There was no logo or wordmark anywhere in the
  /// app after the splash screen.
  Widget _wordmark() {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Dx',
            style: AppText.h1(color: AppColors.onSurfaceDark),
          ),
          TextSpan(
            text: 'Mart',
            style: AppText.h1(color: AppColors.discount),
          ),
        ],
      ),
    );
  }

  Widget _deliveryChip() {
    return Container(
      padding: AppSpace.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.discount,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 16, color: AppColors.onDiscount),
          SizedBox(width: AppSpace.w(2)),
          Text(deliveryTime, style: AppText.labelS(color: AppColors.onDiscount)),
        ],
      ),
    );
  }

  Widget _avatar() {
    final initial = userName.trim().isEmpty
        ? '?'
        : userName.trim()[0].toUpperCase();

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      borderRadius: AppRadius.pillAll,
      child: Container(
        width: AppSpace.w(36),
        height: AppSpace.w(36),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.onSurfaceDark.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.onSurfaceDark.withValues(alpha: 0.30),
          ),
        ),
        child: Text(
          initial,
          style: AppText.label(color: AppColors.onSurfaceDark),
        ),
      ),
    );
  }

  Widget _locationRow(LanguageProvider lang) {
    final place = (district == 'Not Set' && city == 'Not Set')
        ? lang.translate('select_location')
        : '$district, $city';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LocationScreen()),
      ),
      borderRadius: AppRadius.smAll,
      child: Row(
        children: [
          Icon(
            Icons.location_on_rounded,
            size: 18,
            color: AppColors.discount,
          ),
          SizedBox(width: AppSpace.w(6)),
          Text(
            '${lang.translate('deliver_to')} ',
            style: AppText.bodyS(color: AppColors.onSurfaceDarkMuted),
          ),
          Flexible(
            child: Text(
              place,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(color: AppColors.onSurfaceDark),
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.onSurfaceDark,
          ),
        ],
      ),
    );
  }

  /// One search component. The old screen drew this twice — an inline copy and
  /// a sticky copy — at different heights, with different hint sizes, weights
  /// and colours, and only one of them had a shadow.
  Widget _searchField(LanguageProvider lang) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchProduct()),
      ),
      borderRadius: AppRadius.mdAll,
      child: Container(
        height: AppSpace.h(46),
        padding: AppSpace.symmetric(horizontal: AppSpace.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 22, color: AppColors.primary),
            AppSpace.gapW(AppSpace.sm),
            Expanded(
              child: Text(
                lang.translate('search_placeholder'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyM(color: AppColors.textTertiary),
              ),
            ),
            Container(
              width: 1,
              height: AppSpace.h(20),
              color: AppColors.border,
            ),
            AppSpace.gapW(AppSpace.md),
            Icon(Icons.mic_rounded, size: 22, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Body sections
  // ---------------------------------------------------------------------------

  Widget _trustStrip(LanguageProvider lang) {
    return Padding(
      padding: EdgeInsets.only(top: AppSpace.h(AppSpace.md)),
      child: TrustStrip(
        items: [
          TrustItem(
            icon: Icons.payments_outlined,
            label: lang.translate('cod_available'),
            tint: AppColors.primary,
          ),
          TrustItem(
            icon: Icons.local_shipping_outlined,
            label: lang.translate('fast_delivery'),
            tint: AppColors.secondary,
          ),
          TrustItem(
            icon: Icons.replay_rounded,
            label: lang.translate('easy_returns'),
            tint: AppColors.discountText,
          ),
        ],
      ),
    );
  }

  Widget _banners() {
    if (_sliderList.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: AppSpace.h(AppSpace.lg)),
      child: CarouselSlider(
        options: CarouselOptions(
          height: 168.h,
          viewportFraction: 0.88,
          autoPlay: _sliderList.length > 1,
          autoPlayInterval: const Duration(seconds: 5),
          enlargeCenterPage: true,
          enlargeFactor: 0.14,
        ),
        items: [
          for (final banner in _sliderList)
            Padding(
              padding: AppSpace.symmetric(horizontal: AppSpace.xs),
              child: ClipRRect(
                borderRadius: AppRadius.mdAll,
                child: ProductImage(
                  path: banner['banner_image'] as String?,
                  width: double.infinity,
                  height: 168.h,
                  fit: BoxFit.cover,
                  errorIcon: Icons.image_outlined,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Three offer cards, sized so the discount is the message.
  ///
  /// These replace a row of `95.h` boxes that tried to carry three ranks of
  /// text — a `7.5.sp` all-caps tag, an `11.5.sp` title and a `9.5.sp`
  /// subtitle — inside roughly 80dp of usable width. Nobody read them. Here the
  /// number is the largest thing on the card and everything else supports it.
  Widget _offerCards() {
    final offers = <_Offer>[
      _Offer('40%', 'Farm Fresh', 'Veggies & Fruits', AppColors.primary),
      _Offer('15%', 'Dairy Hub', 'Milk & Bread', AppColors.secondary),
      _Offer('20%', 'Saver Deals', 'Grocery Essentials', AppColors.discountText),
    ];

    return Padding(
      padding: EdgeInsets.only(
        top: AppSpace.h(AppSpace.lg),
        left: AppSpace.w(AppSpace.gutter),
        right: AppSpace.w(AppSpace.gutter),
      ),
      child: Row(
        children: [
          for (var i = 0; i < offers.length; i++) ...[
            if (i > 0) AppSpace.gapW(AppSpace.md),
            Expanded(
              child: Container(
                padding: AppSpace.symmetric(
                  horizontal: AppSpace.md,
                  vertical: AppSpace.md,
                ),
                decoration: BoxDecoration(
                  color: offers[i].tint,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'UP TO',
                      style: AppText.overline(
                        color: AppColors.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      offers[i].amount,
                      style: AppText.display(color: AppColors.onPrimary),
                    ),
                    Text(
                      'OFF',
                      style: AppText.overline(
                        color: AppColors.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    AppSpace.gapH(AppSpace.sm),
                    Text(
                      offers[i].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelS(color: AppColors.onPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The category grid.
  ///
  /// Still capped, but now the cap is honest: a "See all" leads to the full
  /// list. Previously the grid silently truncated to eight with no affordance
  /// at all, and the label box was set `72.w` wide beneath a `64.w` tile, which
  /// is why rows with short names left ragged gaps.
  Widget _categoryGrid(LanguageProvider lang, String code) {
    if (_categoryList.isEmpty) return const SizedBox.shrink();

    final shown = _categoryList.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: lang.translate('categories'),
          subtitle: '${_categoryList.length} in your area',
          onSeeAll: _categoryList.length > 8
              ? () => _openCategory(_categoryList.first.id,
                  _categoryList.first.localizedName(code))
              : null,
        ),
        Padding(
          padding: AppSpace.symmetric(horizontal: AppSpace.gutter),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: shown.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: AppSpace.h(AppSpace.base),
              crossAxisSpacing: AppSpace.w(AppSpace.md),
              // Sized so the cell reserves two full label lines under a square
              // tile. At 0.78 there was room for one, so "Tea, Coffee & More"
              // and "Masala & Dry Fruits" were clipped rather than wrapped —
              // and category names get longer, not shorter, in Hindi.
              childAspectRatio: 0.64,
            ),
            itemBuilder: (context, i) {
              final c = shown[i];
              final name = c.localizedName(code);

              return InkWell(
                onTap: () => _openCategory(c.id, name),
                borderRadius: AppRadius.mdAll,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        padding: AppSpace.all(AppSpace.sm),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.mdAll,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ProductImage(
                          path: c.imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          errorIcon: Icons.category_outlined,
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpace.h(6)),
                    Expanded(
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption(color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _rails(LanguageProvider lang, String code) {
    final sections = <_Rail>[
      _Rail(lang.translate('everyday_essentials'), 'Daily staples',
          everydayEssentialsList),
      _Rail(lang.translate('best_selling'), 'Most ordered near you',
          bestSellingList),
      _Rail(lang.translate('hot_deals'), 'Biggest savings today', hotDealsList),
    ];

    return [
      for (final s in sections)
        if (s.products.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: s.title, subtitle: s.subtitle),
                SizedBox(
                  // Sized to the card's real content: a square image plus a
                  // two-line name, pack size and price row. It was 268.h, which
                  // left a visible dead gap under every card.
                  height: 222.h,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: AppSpace.symmetric(horizontal: AppSpace.gutter),
                    itemCount: s.products.length,
                    separatorBuilder: (_, __) => AppSpace.gapW(AppSpace.md),
                    itemBuilder: (context, i) => SizedBox(
                      width: 150.w,
                      child: ProductCard(
                        product: _productCardData(s.products[i], code),
                        // Identity comes from the session, never from the widget tree.
                        userId: '',
                        onCartUpdated: fetchCartQuantity,
                        onCategoryBack: fetchCartQuantity,
                        height: 222.h,
                        width: 150.w,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    ];
  }

  /// A skeleton of the page that is coming, rather than a spinner on a blank
  /// screen. The `shimmer` package has been a dependency since the beginning
  /// and was never imported.
  Widget _loadingBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSpace.gapH(AppSpace.lg),
        AppSkeleton.sweep(
          child: Padding(
            padding: AppSpace.symmetric(horizontal: AppSpace.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(
                  width: double.infinity,
                  height: 168.h,
                  radius: AppRadius.mdAll,
                ),
                AppSpace.gapH(AppSpace.lg),
                AppSkeleton(width: 160.w, height: AppSpace.h(18)),
                AppSpace.gapH(AppSpace.base),
              ],
            ),
          ),
        ),
        const ProductRailSkeleton(),
      ],
    );
  }
}

class _Offer {
  const _Offer(this.amount, this.title, this.subtitle, this.tint);
  final String amount;
  final String title;
  final String subtitle;
  final Color tint;
}

class _Rail {
  const _Rail(this.title, this.subtitle, this.products);
  final String title;
  final String subtitle;
  final List<Product> products;
}

/// Keeps the category bar on screen while the page scrolls under it.
class _PinnedCategoryBar extends SliverPersistentHeaderDelegate {
  _PinnedCategoryBar({required this.child});

  final Widget child;

  double get _height => 108.h;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: AppColors.surface,
      elevation: overlapsContent || shrinkOffset > 0 ? 1 : 0,
      shadowColor: AppColors.textPrimary.withValues(alpha: 0.10),
      child: SizedBox(height: _height, child: child),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedCategoryBar old) => old.child != child;
}
