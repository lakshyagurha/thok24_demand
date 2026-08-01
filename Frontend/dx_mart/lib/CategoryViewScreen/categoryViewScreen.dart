import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../BottomNav/Screens/cartScreen.dart';
import '../CustomWidgets/product_card.dart';
import '../core/supabase.dart';
import '../data/catalog_repository.dart';
import '../data/models.dart';
import '../SearchProduct/search_product.dart';
import '../design/app_colors.dart';
import '../design/app_gradients.dart';
import '../design/app_radius.dart';
import '../design/app_space.dart';
import '../design/app_type.dart';
import '../design/components/app_header.dart';
import '../design/components/cart_bar.dart';
import '../design/components/skeleton.dart';
import '../design/components/states.dart';
import '../design/haptics.dart';
import 'package:provider/provider.dart';
import '../utils/language_provider.dart';
import '../CustomWidgets/cart_provider.dart';
import '../CustomWidgets/product_image.dart';

/// Shapes a [Product] into the map [ProductCard] still reads. Transitional — see the
/// identical note in `homeScreen.dart`.
Map<String, dynamic> _productCardData(Product p, String lang) => {
      'id': p.id,
      'name': p.localizedName(lang),
      // See the note in `homeScreen.dart`: the product page needs this to populate
      // its "similar products" section.
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

  /// The shelves shown in the left rail: the siblings of the current shelf, i.e. the
  /// children of one umbrella — not every category in the shop.
  ///
  /// The rail used to list all twelve rows of a flat table, which meant sliding
  /// sideways from "Dairy" landed you in "Electronics". Scoping it to one umbrella is
  /// what makes the rail a set of related aisles rather than the whole store index.
  List<Category> categories = [];

  /// The whole tree, for the breadcrumb and the umbrella switcher.
  List<Category> _tree = [];
  Category? _umbrella;

  List<Product> products = [];
  bool _isLoadingProducts = false;
  bool _isLoadingCategories = true;

  /// Whether the last load FAILED, as distinct from returning nothing. Both catches here
  /// used to just set the list to [] with no logging, so a dropped connection was shown
  /// to the shopper as "no products found" — telling them the shop is empty when it is
  /// their network that died, and giving them no reason to retry.
  bool _productsFailed = false;
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
    if (selectedCategoryId != 0) {
      await fetchProductsByCategory(selectedCategoryId);
    }
  }

  /// Loads the tree and resolves which umbrella the caller landed in.
  ///
  /// [widget.categoryId] may be either a shelf (from the Category tab, a product page
  /// or a banner) or an umbrella (from the home rail). Both are handled here rather
  /// than at each call site: an umbrella resolves to its first stocked shelf, because
  /// products never hang off an umbrella and selecting one directly would show an
  /// empty grid.
  Future<void> fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final tree = await _catalog.categoryTreeCached();
      if (!mounted) return;

      final requested = selectedCategoryId;
      Category? umbrella;
      int resolved = requested;

      final node = CatalogRepository.findInTree(tree, requested);
      if (node != null && node.isUmbrella) {
        umbrella = node;
        // Prefer a shelf that actually has stock, so opening an umbrella never
        // lands on "no products found" while its siblings are full.
        final stocked = node.children.where((c) => !c.isEmpty);
        resolved = (stocked.isNotEmpty ? stocked.first : node.children.first).id;
      } else {
        umbrella = CatalogRepository.umbrellaOf(tree, requested);
        // Unknown id (a stale link, or a category retired since): fall back to the
        // first umbrella rather than rendering an empty shell.
        if (umbrella == null && tree.isNotEmpty) {
          umbrella = tree.first;
          final stocked = umbrella.children.where((c) => !c.isEmpty);
          resolved = (stocked.isNotEmpty
                  ? stocked.first
                  : umbrella.children.first)
              .id;
        }
      }

      setState(() {
        _tree = tree;
        _umbrella = umbrella;
        categories = umbrella?.children ?? const [];
        selectedCategoryId = resolved;
        _isLoadingCategories = false;
      });
    } catch (e) {
      debugPrint('categories load failed: $e');
      if (!mounted) return;
      setState(() {
        categories = [];
        _isLoadingCategories = false;
      });
    }
  }

  /// Switches to another umbrella and opens its first stocked shelf.
  void _switchUmbrella(Category umbrella) {
    final stocked = umbrella.children.where((c) => !c.isEmpty);
    final target =
        stocked.isNotEmpty ? stocked.first : umbrella.children.first;
    setState(() {
      _umbrella = umbrella;
      categories = umbrella.children;
      selectedCategoryId = target.id;
    });
    fetchProductsByCategory(target.id);
  }

  /// The umbrella picker. Without it the only way from "Grocery & Kitchen" to
  /// "Household Essentials" is back out to the Category tab and in again.
  void _showUmbrellaSheet(String code, LanguageProvider lang) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg.r)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: AppSpace.all(AppSpace.base),
              child: Text(
                lang.translate('all_categories'),
                style: AppText.h3(color: AppColors.textPrimary),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final u in _tree)
                    ListTile(
                      leading: Icon(
                        u.id == _umbrella?.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: u.id == _umbrella?.id
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                      title: Text(
                        u.localizedName(code),
                        style: AppText.label(color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        u.productCount == 0
                            ? lang.translate('coming_soon')
                            : '${u.productCount} ${lang.translate('items')}',
                        style: AppText.caption(color: AppColors.textSecondary),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        if (u.id != _umbrella?.id) {
                          AppHaptics.selection();
                          _switchUmbrella(u);
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> fetchProductsByCategory(int categoryId) async {
    setState(() {
      _isLoadingProducts = true;
      _productsFailed = false;
      products = [];
    });

    try {
      final rows = await _catalog.productsByCategory(categoryId);
      if (!mounted) return;
      setState(() => products = rows);
    } catch (e) {
      debugPrint('category products load failed: $e');
      if (!mounted) return;
      setState(() {
        products = [];
        _productsFailed = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
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
      body: Column(
        children: [
          AppHeader(
            title: selectedCategoryName,
            subtitle: _isLoadingProducts
                ? null
                : '${products.length} ${products.length == 1 ? "item" : "items"}',
            actions: [
              HeaderAction(
                icon: Icons.search_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchProduct()),
                ),
              ),
            ],
          ),
          _breadcrumb(code, lang),
          const Divider(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _rail(code),
                Expanded(child: _content(lang, code)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cart, _) => CartBar(
          itemCount: cart.getUniqueItemsCount(),
          label: lang.translate('view_cart'),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CartScreen()),
            );
            await fetchCartQuantity();
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Breadcrumb
  // ---------------------------------------------------------------------------

  /// `Grocery & Kitchen › Atta, Rice & Dal`, where the umbrella half is tappable.
  ///
  /// With a two-level tree the shopper can otherwise be three taps deep with only a
  /// shelf name to go on, and no idea which part of the shop they are standing in.
  /// The umbrella is a button, not decoration: it opens the switcher, which is the
  /// only sideways route between umbrellas without backing all the way out.
  Widget _breadcrumb(String code, LanguageProvider lang) {
    final umbrella = _umbrella;
    if (umbrella == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpace.w(AppSpace.gutter),
        vertical: AppSpace.h(AppSpace.sm),
      ),
      child: Row(
        children: [
          Flexible(
            child: InkWell(
              onTap: () => _showUmbrellaSheet(code, lang),
              borderRadius: AppRadius.smAll,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpace.w(AppSpace.xs),
                  vertical: AppSpace.h(2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        umbrella.localizedName(code),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption(color: AppColors.primary),
                      ),
                    ),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpace.w(2)),
            child: Text(
              '›',
              style: AppText.caption(color: AppColors.textSecondary),
            ),
          ),
          Flexible(
            child: Text(
              selectedCategoryName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Left rail
  // ---------------------------------------------------------------------------

  /// The category rail.
  ///
  /// The two-level browse — groups on the left, products on the right — was
  /// already the right structure; DMart Ready and BigBasket both use it and it
  /// is the fastest way to move sideways through a catalogue without losing
  /// your place.
  ///
  /// What was wrong was the direction. The selected item's white card rounded on
  /// its **left** edge while the green accent sat on its **right**, so the card
  /// pulled away from the very pane it was supposed to be connected to. Here the
  /// accent is on the outer (left) edge and the card rounds toward the content,
  /// which is what makes the rail read as a tab strip rather than a list.
  Widget _rail(String code) {
    if (_isLoadingCategories) {
      return SizedBox(
        width: 84.w,
        child: AppSkeleton.sweep(
          child: ListView.separated(
            padding: AppSpace.symmetric(vertical: AppSpace.md),
            itemCount: 8,
            separatorBuilder: (_, _) => AppSpace.gapH(AppSpace.base),
            itemBuilder: (_, _) => Column(
              children: [
                AppSkeleton(
                  width: 48.w,
                  height: 48.w,
                  radius: AppRadius.mdAll,
                ),
                AppSpace.gapH(AppSpace.sm),
                AppSkeleton(width: 56.w, height: AppSpace.h(8)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: 84.w,
      color: AppColors.surfaceSunken,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: AppSpace.h(AppSpace.sm)),
        itemCount: categories.length,
        itemBuilder: (context, i) {
          final c = categories[i];
          final selected = c.id == selectedCategoryId;

          return InkWell(
            onTap: () {
              if (selected) return;
              AppHaptics.selection();
              setState(() => selectedCategoryId = c.id);
              fetchProductsByCategory(c.id);
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: AppSpace.h(AppSpace.md)),
              decoration: BoxDecoration(
                color: selected ? AppColors.background : Colors.transparent,
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(AppRadius.md.r),
                ),
              ),
              child: Row(
                children: [
                  // The accent, on the outer edge, pointing the selection at
                  // the content rather than away from it.
                  Container(
                    width: AppSpace.w(3),
                    height: AppSpace.h(44),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(AppRadius.xs.r),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46.w,
                          height: 46.w,
                          decoration: BoxDecoration(
                            gradient: selected ? null : AppGradients.tile,
                            color: selected ? AppColors.primarySurface : null,
                            borderRadius: AppRadius.mdAll,
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          // Unstocked shelves stay in the rail — hiding them would
                          // make the aisle look shorter than it is — but they are
                          // dimmed so the shopper can see where the stock is before
                          // tapping through to find out.
                          child: ClipRRect(
                            borderRadius: AppRadius.mdAll,
                            child: Opacity(
                              opacity: c.isEmpty ? 0.4 : 1,
                              child: ProductImage(
                                path: c.imageUrl,
                                width: 46.w,
                                height: 46.w,
                                fit: BoxFit.cover,
                                errorIcon: Icons.category_outlined,
                              ),
                            ),
                          ),
                        ),
                        AppSpace.gapH(AppSpace.xs),
                        Padding(
                          padding: AppSpace.symmetric(horizontal: 2),
                          child: Text(
                            c.localizedName(code),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: selected
                                ? AppText.overline(color: AppColors.primary)
                                : AppText.caption(
                                    color: AppColors.textSecondary),
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
    );
  }

  // ---------------------------------------------------------------------------
  // Right pane
  // ---------------------------------------------------------------------------

  Widget _content(LanguageProvider lang, String code) {
    if (_isLoadingProducts) {
      return AppSkeleton.sweep(
        child: GridView.builder(
          padding: AppSpace.all(AppSpace.md),
          itemCount: 6,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpace.h(AppSpace.md),
            crossAxisSpacing: AppSpace.w(AppSpace.md),
            childAspectRatio: 0.58,
          ),
          itemBuilder: (_, _) => const ProductCardSkeleton(),
        ),
      );
    }

    if (_productsFailed) {
      return AppEmptyState(
        icon: Icons.wifi_off_rounded,
        title: lang.translate('something_went_wrong'),
        message: lang.translate('check_connection'),
        actionLabel: lang.translate('retry'),
        onAction: () => fetchProductsByCategory(selectedCategoryId),
        tone: StateTone.error,
      );
    }

    if (products.isEmpty) {
      return AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: lang.translate('no_products_found'),
        message: lang.translate('try_another_category'),
      );
    }

    return Column(
      children: [
        _filterBar(lang),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(
              AppSpace.w(AppSpace.md),
              AppSpace.h(AppSpace.xs),
              AppSpace.w(AppSpace.md),
              AppSpace.h(AppSpace.base),
            ),
            physics: const BouncingScrollPhysics(),
            itemCount: products.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpace.h(AppSpace.md),
              crossAxisSpacing: AppSpace.w(AppSpace.md),
              childAspectRatio: 0.58,
            ),
            itemBuilder: (context, i) => ProductCard(
              product: _productCardData(products[i], code),
              userId: '',
              onCartUpdated: fetchCartQuantity,
              onCategoryBack: fetchCartQuantity,
              width: 132.w,
            ),
          ),
        ),
      ],
    );
  }

  /// Filter and sort. BigBasket puts a single "Filter & Sort" chip at the top
  /// of every category listing; without one the only way to reorder a category
  /// is to scroll it.
  ///
  /// The controls are presented but not yet wired — sorting is a data change,
  /// and this pass is presentation only. They are disabled rather than fake:
  /// the app already had two selectable dead ends (a UPI option that is
  /// rejected on tap, a rating sheet that ends in "coming soon"), and adding a
  /// third would be worse than showing none.
  Widget _filterBar(LanguageProvider lang) {
    return SizedBox(
      height: AppSpace.h(46),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: AppSpace.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        children: [
          _chip(
            label: '${products.length} ${lang.translate('items')}',
            icon: Icons.inventory_2_outlined,
            emphasised: true,
          ),
          AppSpace.gapW(AppSpace.sm),
          _chip(label: lang.translate('sort'), icon: Icons.swap_vert_rounded),
          AppSpace.gapW(AppSpace.sm),
          _chip(label: lang.translate('filter'), icon: Icons.tune_rounded),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required IconData icon,
    bool emphasised = false,
  }) {
    return Container(
      padding: AppSpace.symmetric(horizontal: AppSpace.md, vertical: 2),
      decoration: BoxDecoration(
        color: emphasised ? AppColors.primarySurface : AppColors.surface,
        borderRadius: AppRadius.pillAll,
        border: Border.all(
          color: emphasised ? AppColors.primaryBorder : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: emphasised ? AppColors.primary : AppColors.iconMuted,
          ),
          AppSpace.gapW(AppSpace.xs),
          Text(
            label,
            style: AppText.labelS(
              color: emphasised ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
