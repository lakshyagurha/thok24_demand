import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../CategoryViewScreen/categoryViewScreen.dart';
import '../../core/supabase.dart';
import '../../data/catalog_repository.dart';
import '../../data/models.dart';
import '../../utils/colors.dart';
import '../../utils/language_provider.dart';

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
      _showSnackBar("Error: ${e.message}", AppColors.errorColor);
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("Connection error: $e", AppColors.errorColor);
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

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 50.sp, color: Colors.red),
          SizedBox(height: 10.h),
          Text(
            Provider.of<LanguageProvider>(context).translate('error_loading_categories'),
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.sp),
          ),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: _fetchCategories,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
            ),
            child: Text(Provider.of<LanguageProvider>(context).translate('retry'), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primaryColor),
          SizedBox(height: 16.h),
          Text(
            Provider.of<LanguageProvider>(context).translate('loading_categories'),
            style: TextStyle(fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12.h,
          crossAxisSpacing: 10.w,
          childAspectRatio: 0.60,
        ),
        itemCount: _categoryList.length,
        itemBuilder: (context, index) {
          final category = _categoryList[index];
          final categoryName = category.localizedName(
            Provider.of<LanguageProvider>(context).currentLanguage,
          );
          final imageUrl = category.imageUrl;

          return GestureDetector(
            onTap: () => _onCategoryTap(category),
            child: Column(
              children: [
                Container(
                  width: 60.w,
                  height: 60.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.r),

                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.category, size: 30.sp, color: AppColors.primaryColor),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            color: AppColors.primaryColor,
                          ),
                        );
                      },
                    )
                        : Icon(Icons.category, size: 30.sp, color: AppColors.primaryColor),
                  ),
                ),
                SizedBox(height: 6.h),
                SizedBox(
                  width: 72.w,
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: Offset(0, 4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.only(top: 10.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 20.w),
                  Text(
                    Provider.of<LanguageProvider>(context).translate('categories'),
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const Spacer(),
                  // Refresh Button
                  IconButton(
                    onPressed: _fetchCategories,
                    icon: const Icon(Icons.refresh, color: AppColors.primaryColor),
                  ),
                  SizedBox(width: 16.w),
                ],
              ),
            ),
          ),
          Expanded(
            child: _hasError
                ? _buildErrorWidget()
                : _isLoading
                ? _buildLoadingWidget()
                : _categoryList.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 50.sp, color: Colors.grey),
                  SizedBox(height: 10.h),
                  Text(
                    Provider.of<LanguageProvider>(context).translate('no_categories_found'),
                    style: TextStyle(fontSize: 16.sp),
                  ),
                  SizedBox(height: 10.h),
                  ElevatedButton(
                    onPressed: _fetchCategories,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                    ),
                    child: Text(Provider.of<LanguageProvider>(context).translate('refresh'), style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )
                : _buildCategoryGrid(),
          )
        ],
      ),
    );
  }
}