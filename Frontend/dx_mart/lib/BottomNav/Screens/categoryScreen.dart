import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../CategoryViewScreen/categoryViewScreen.dart';
import '../../core/supabase.dart';
import '../../data/catalog_repository.dart';
import '../../data/models.dart';
import '../../design/app_colors.dart';
import '../../design/app_gradients.dart';
import '../../design/app_radius.dart';
import '../../design/app_space.dart';
import '../../design/app_type.dart';
import '../../design/components/app_header.dart';
import '../../design/components/skeleton.dart';
import '../../design/components/states.dart';
import '../../design/haptics.dart';
import '../../utils/language_provider.dart';
import '../../CustomWidgets/product_image.dart';

/// The Categories tab: the whole shop, one screen.
///
/// This used to be a flat grid of twelve tiles — which were not categories but
/// *shelves*, with no umbrella above them and no way to tell that eight of the twelve
/// were empty. Tapping one of those eight opened a blank product grid.
///
/// Now it is sectioned: one section per umbrella, its shelves in a three-column grid
/// beneath it, with the section header pinned while that section scrolls so the shopper
/// always knows which part of the shop they are in. Empty shelves still render — the
/// tree was seeded whole on purpose, so the shop looks like a shop rather than like four
/// categories — but they are visibly marked *Coming soon* and do not navigate into
/// nothing.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final CatalogRepository _catalog = const CatalogRepository();

  List<Category> _tree = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Names are localized from the model at render time, so one fetch covers every
    // language instead of one round trip per language switch.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchTree());
  }

  Future<void> _fetchTree({bool force = false}) async {
    setState(() {
      _isLoading = _tree.isEmpty;
      _hasError = false;
    });

    try {
      // Cache-first: on a warm launch this returns without touching the network and
      // the screen paints real tiles in its first frame. The refresh, if the copy is
      // stale, lands afterwards and usually changes nothing.
      final tree = force
          ? await _catalog.categoryTree()
          : await _catalog.categoryTreeCached(
              onRefreshed: (fresh) {
                if (mounted) setState(() => _tree = fresh);
              },
            );
      if (!mounted) return;
      setState(() {
        _tree = tree;
        _isLoading = false;
      });
    } on DataException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // A cached tree is still worth showing; only a first-ever load is an error.
        _hasError = _tree.isEmpty;
        _errorMessage = e.message;
      });
      if (_tree.isEmpty) _showSnackBar("Error: ${e.message}", AppColors.danger);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = _tree.isEmpty;
        _errorMessage = "Connection error: $e";
      });
      if (_tree.isEmpty) _showSnackBar("Connection error: $e", AppColors.danger);
    }
  }

  int get _shelfCount =>
      _tree.fold<int>(0, (sum, u) => sum + u.descendants.length);

  void _openShelf(Category shelf, String code) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryViewScreen(
          categoryId: shelf.id,
          categoryName: shelf.localizedName(code),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
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
      body: Column(
        children: [
          AppHeader(
            title: lang.translate('categories'),
            subtitle: _isLoading || _hasError || _tree.isEmpty
                ? null
                : '${_tree.length} ${lang.translate('browse_section')} · '
                    '$_shelfCount ${lang.translate('subcategories')}',
            showBack: false,
            actions: [
              HeaderAction(
                icon: Icons.refresh_rounded,
                onTap: () => _fetchTree(force: true),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(child: _body(lang, code)),
        ],
      ),
    );
  }

  Widget _body(LanguageProvider lang, String code) {
    if (_isLoading && _tree.isEmpty) return _skeleton();

    if (_hasError) {
      return AppEmptyState(
        icon: Icons.wifi_off_rounded,
        title: lang.translate('something_went_wrong'),
        message: _errorMessage.isEmpty
            ? lang.translate('check_connection')
            : _errorMessage,
        actionLabel: lang.translate('retry'),
        onAction: () => _fetchTree(force: true),
        tone: StateTone.error,
      );
    }

    if (_tree.isEmpty) {
      return AppEmptyState(
        icon: Icons.category_outlined,
        title: lang.translate('no_categories'),
        actionLabel: lang.translate('retry'),
        onAction: () => _fetchTree(force: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        AppHaptics.selection();
        return _fetchTree(force: true);
      },
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          for (final umbrella in _tree) ...[
            // Pinned so the umbrella name stays on screen for as long as its own
            // shelves do. With 34 tiles in one scroll, an unpinned header means the
            // shopper is three swipes into a grid with no idea which section it is.
            SliverPersistentHeader(
              pinned: true,
              delegate: _SectionHeaderDelegate(
                title: umbrella.localizedName(code),
                count: umbrella.productCount,
                itemsLabel: lang.translate('items'),
                comingSoonLabel: lang.translate('coming_soon'),
              ),
            ),
            SliverPadding(
              padding: AppSpace.only(
                left: AppSpace.gutter,
                right: AppSpace.gutter,
                bottom: AppSpace.lg,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppSpace.h(AppSpace.base),
                  crossAxisSpacing: AppSpace.w(AppSpace.md),
                  childAspectRatio: 0.70,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _shelfTile(
                    umbrella.children[i],
                    code,
                    lang,
                  ),
                  childCount: umbrella.children.length,
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: AppSpace.h(AppSpace.xxl))),
        ],
      ),
    );
  }

  Widget _shelfTile(Category shelf, String code, LanguageProvider lang) {
    final name = shelf.localizedName(code);
    final empty = shelf.isEmpty;

    return InkWell(
      // An empty shelf does not navigate. The old screen let all twelve tiles
      // through and eight of them landed on "no products found", which reads as a
      // broken app rather than as a shop that has not stocked that aisle yet.
      onTap: empty
          ? () => _showSnackBar(
                '$name — ${lang.translate('coming_soon')}',
                AppColors.textSecondary,
              )
          : () => _openShelf(shelf, code),
      borderRadius: AppRadius.mdAll,
      child: Column(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppGradients.tile,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: AppColors.border),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.mdAll,
                    child: Opacity(
                      opacity: empty ? 0.35 : 1,
                      child: ProductImage(
                        path: shelf.imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorIcon: Icons.category_outlined,
                      ),
                    ),
                  ),
                  if (empty)
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpace.w(AppSpace.sm),
                          vertical: AppSpace.h(3),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.92),
                          borderRadius: AppRadius.smAll,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          lang.translate('coming_soon'),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.overline(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          AppSpace.gapH(AppSpace.sm),
          SizedBox(
            height: AppSpace.h(32),
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.labelS(
                color: empty ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeleton() {
    return AppSkeleton.sweep(
      child: ListView(
        padding: AppSpace.all(AppSpace.gutter),
        children: [
          for (var section = 0; section < 3; section++) ...[
            AppSkeleton(width: 140.w, height: AppSpace.h(14)),
            AppSpace.gapH(AppSpace.base),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppSpace.h(AppSpace.base),
                crossAxisSpacing: AppSpace.w(AppSpace.md),
                childAspectRatio: 0.70,
              ),
              itemBuilder: (_, _) => Column(
                children: [
                  Expanded(
                    child: AppSkeleton(
                      width: double.infinity,
                      height: double.infinity,
                      radius: AppRadius.mdAll,
                    ),
                  ),
                  AppSpace.gapH(AppSpace.sm),
                  AppSkeleton(width: 60.w, height: AppSpace.h(10)),
                ],
              ),
            ),
            AppSpace.gapH(AppSpace.lg),
          ],
        ],
      ),
    );
  }
}

/// Pinned umbrella heading.
///
/// Sized in logical pixels rather than with ScreenUtil's `.h` inside the extent
/// getters: a SliverPersistentHeaderDelegate must report a *constant* extent, and one
/// that changes with the text scale mid-scroll makes the sliver jump.
class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SectionHeaderDelegate({
    required this.title,
    required this.count,
    required this.itemsLabel,
    required this.comingSoonLabel,
  });

  final String title;
  final int count;
  final String itemsLabel;
  final String comingSoonLabel;

  static const double _extent = 46;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      height: _extent,
      color: AppColors.background,
      padding: EdgeInsets.symmetric(horizontal: AppSpace.w(AppSpace.gutter)),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AppSpace.gapW(AppSpace.sm),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.h3(color: AppColors.textPrimary),
            ),
          ),
          Text(
            count == 0 ? comingSoonLabel : '$count $itemsLabel',
            style: AppText.caption(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SectionHeaderDelegate old) =>
      old.title != title ||
      old.count != count ||
      old.itemsLabel != itemsLabel ||
      old.comingSoonLabel != comingSoonLabel;
}
