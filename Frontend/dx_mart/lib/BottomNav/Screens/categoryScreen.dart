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
import '../../utils/language_provider.dart';
import '../../CustomWidgets/product_image.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final CatalogRepository _catalog = const CatalogRepository();

  List<Category> _categoryList = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Names are localized from the model at render time, so one fetch covers every
    // language instead of one round trip per language switch.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCategories());
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final categories = await _catalog.categories();
      if (!mounted) return;
      setState(() {
        _categoryList = categories;
        _isLoading = false;
      });
    } on DataException catch (e) {
      if (!mounted) return;
      _showSnackBar("Error: ${e.message}", AppColors.danger);
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("Connection error: $e", AppColors.danger);
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = "Connection error: $e";
      });
    }
  }

  void _onCategoryTap(Category category) {
    // Category tap पर CategoryViewScreen में navigate करें
    final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryViewScreen(
          categoryId: category.id,
          categoryName: category.localizedName(lang),
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
            subtitle: _isLoading || _hasError
                ? null
                : '${_categoryList.length} ${lang.translate('categories').toLowerCase()}',
            showBack: false,
            actions: [
              HeaderAction(
                icon: Icons.refresh_rounded,
                onTap: _fetchCategories,
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
    if (_isLoading) {
      return AppSkeleton.sweep(
        child: GridView.builder(
          padding: AppSpace.all(AppSpace.gutter),
          itemCount: 12,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: AppSpace.h(AppSpace.base),
            crossAxisSpacing: AppSpace.w(AppSpace.md),
            childAspectRatio: 0.74,
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
      );
    }

    if (_hasError) {
      return AppEmptyState(
        icon: Icons.wifi_off_rounded,
        title: lang.translate('something_went_wrong'),
        message: _errorMessage.isEmpty
            ? lang.translate('check_connection')
            : _errorMessage,
        actionLabel: lang.translate('retry'),
        onAction: _fetchCategories,
        tone: StateTone.error,
      );
    }

    if (_categoryList.isEmpty) {
      return AppEmptyState(
        icon: Icons.category_outlined,
        title: lang.translate('no_categories'),
        actionLabel: lang.translate('retry'),
        onAction: _fetchCategories,
      );
    }

    // Three across rather than four.
    //
    // The old screen put twelve tiles into a four-column grid at an 0.60 aspect
    // ratio and left the bottom two-thirds of the screen empty, so a page whose
    // whole job is "show me everything you sell" managed to look like the
    // catalogue was nearly bare. Three columns give each tile a usable image
    // and a two-line label, and twelve of them fill the viewport.
    return RefreshIndicator(
      onRefresh: _fetchCategories,
      color: AppColors.primary,
      child: GridView.builder(
        padding: AppSpace.all(AppSpace.gutter),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _categoryList.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpace.h(AppSpace.base),
          crossAxisSpacing: AppSpace.w(AppSpace.md),
          childAspectRatio: 0.74,
        ),
        itemBuilder: (context, i) {
          final c = _categoryList[i];
          final name = c.localizedName(code);

          return InkWell(
            onTap: () => _onCategoryTap(c),
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
                    child: ClipRRect(
                      borderRadius: AppRadius.mdAll,
                      child: ProductImage(
                        path: c.imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorIcon: Icons.category_outlined,
                      ),
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
                    style: AppText.labelS(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
