import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../core/admin_api.dart';
import '../core/supabase.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/colors.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  // Form controllers and state
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nameControllerHi = TextEditingController();
  final TextEditingController _nameControllerHn = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _descriptionControllerHi =
      TextEditingController();
  final TextEditingController _descriptionControllerHn =
      TextEditingController();

  // Visibility toggles for translations
  bool _showNameTranslations = false;
  bool _showDescriptionTranslations = false;
  final List<bool> _showVariantTranslations = [];
  final List<bool> _showInfoTranslations = [];
  final List<bool> _showHighlightTranslations = [];

  String? selectedMainCategoryId;
  final List<TextEditingController> _variantNameControllers = [];
  final List<TextEditingController> _variantNameControllersHi = [];
  final List<TextEditingController> _variantNameControllersHn = [];
  final List<TextEditingController> _variantPriceControllers = [];
  final List<TextEditingController> _wholesalePriceControllers = [];
  final List<TextEditingController> _sellingPriceControllers = [];
  final List<TextEditingController> _variantStockControllers = [];
  final List<Uint8List> _imageBytes = [];
  final List<TextEditingController> _infoAttributeControllers = [];
  final List<TextEditingController> _infoAttributeControllersHi = [];
  final List<TextEditingController> _infoAttributeControllersHn = [];
  final List<TextEditingController> _infoValueControllers = [];
  final List<TextEditingController> _infoValueControllersHi = [];
  final List<TextEditingController> _infoValueControllersHn = [];
  final List<TextEditingController> _highlightAttributeControllers = [];
  final List<TextEditingController> _highlightAttributeControllersHi = [];
  final List<TextEditingController> _highlightAttributeControllersHn = [];
  final List<TextEditingController> _highlightValueControllers = [];
  final List<TextEditingController> _highlightValueControllersHi = [];
  final List<TextEditingController> _highlightValueControllersHn = [];

  List<String> _uploadedImageUrls = [];

  // State variables
  List<String?> _existingVariantIds = [];
  List<String?> _existingInfoIds = [];
  List<String?> _existingHighlightIds = [];

  // Product list state
  List<dynamic> products = [];
  int currentPage = 1;
  int itemsPerPage = 10;
  int totalProducts = 0;
  bool isLoading = false;
  bool isFormLoading = false;
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  Map<String, dynamic>? editingProduct;
  Map<int, List<String>> selectedTypesMap = {};

  List _mainCategoryList = [];
  String? _filterCategoryId;

  @override
  void initState() {
    super.initState();

    fetchProducts();
    _addVariantField();
    _addInfoField();
    _addHighlightField();

    _fetchMainCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameControllerHi.dispose();
    _nameControllerHn.dispose();
    _descriptionController.dispose();
    _descriptionControllerHi.dispose();
    _descriptionControllerHn.dispose();

    for (var controller in _variantNameControllers) controller.dispose();
    for (var controller in _variantNameControllersHi) controller.dispose();
    for (var controller in _variantNameControllersHn) controller.dispose();
    for (var controller in _variantPriceControllers) controller.dispose();
    for (var controller in _sellingPriceControllers) controller.dispose();
    for (var controller in _wholesalePriceControllers) controller.dispose();
    for (var controller in _variantStockControllers) controller.dispose();

    for (var controller in _infoAttributeControllers) controller.dispose();
    for (var controller in _infoAttributeControllersHi) controller.dispose();
    for (var controller in _infoAttributeControllersHn) controller.dispose();
    for (var controller in _infoValueControllers) controller.dispose();
    for (var controller in _infoValueControllersHi) controller.dispose();
    for (var controller in _infoValueControllersHn) controller.dispose();

    for (var controller in _highlightAttributeControllers) controller.dispose();
    for (var controller in _highlightAttributeControllersHi)
      controller.dispose();
    for (var controller in _highlightAttributeControllersHn)
      controller.dispose();
    for (var controller in _highlightValueControllers) controller.dispose();
    for (var controller in _highlightValueControllersHi) controller.dispose();
    for (var controller in _highlightValueControllersHn) controller.dispose();

    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchProducts() async {
    setState(() => isLoading = true);
    try {
      final rows = await AdminCatalog.productsWithDetail(
        limit: itemsPerPage,
        offset: (currentPage - 1) * itemsPerPage,
      );

      // The old endpoint took search and category as query params; the Edge Function
      // exposes equality filters only, so the page is narrowed client-side.
      final q = searchQuery.trim().toLowerCase();
      var filtered = q.isEmpty
          ? rows
          : rows
                .where((r) => '${r['name'] ?? ''}'.toLowerCase().contains(q))
                .toList();
      if (_filterCategoryId != null && _filterCategoryId != 'all') {
        filtered = filtered
            .where((r) => r['main_category_id'].toString() == _filterCategoryId)
            .toList();
      }

      if (mounted) {
        setState(() {
          products = filtered;
          totalProducts = filtered.length;
          selectedTypesMap.clear();
          for (var product in products) {
            final productId = int.tryParse(product['id'].toString()) ?? 0;
            selectedTypesMap[productId] = getSelectedTypes(
              product['types'] ?? "",
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchMainCategories() async {
    try {
      final data = await AdminApi.list(AdminTables.mainCategory, limit: 200);
      if (!mounted) return;
      setState(() {
        _mainCategoryList = data;
      });
    } catch (e) {
      _showSnackBar(
        "Connection error fetching main categories: $e",
        AppColors.errorColor,
      );
    }
  }

  /// The PHP backend proxied an external translation service (translate_api.php) that
  /// no longer exists. Returning empty strings leaves the Hindi/Hinglish fields for the
  /// operator to fill: an auto-translated product name nobody checked is worse than a
  /// blank one, especially for a Hindi-first shopper.
  Future<Map<String, String>> _translateText(String text) async {
    return {'hi': '', 'hn': ''};
  }

  Future<void> _autoTranslateAll() async {
    final nameEng = _nameController.text.trim();
    if (nameEng.isEmpty) {
      _showSnackBar(
        "Please enter Product Name (English) first!",
        AppColors.warningColor,
      );
      return;
    }

    _showSnackBar("Auto-translating all fields...", AppColors.infoColor);
    setState(() => isFormLoading = true);

    try {
      // 1. Translate Name
      final nameTrans = await _translateText(nameEng);
      _nameControllerHi.text = nameTrans['hi'] ?? '';
      _nameControllerHn.text = nameTrans['hn'] ?? '';

      // 2. Translate Description
      final descEng = _descriptionController.text.trim();
      if (descEng.isNotEmpty) {
        final descTrans = await _translateText(descEng);
        _descriptionControllerHi.text = descTrans['hi'] ?? '';
        _descriptionControllerHn.text = descTrans['hn'] ?? '';
      }

      // 3. Translate Variants
      for (int i = 0; i < _variantNameControllers.length; i++) {
        final vEng = _variantNameControllers[i].text.trim();
        if (vEng.isNotEmpty) {
          final vTrans = await _translateText(vEng);
          if (_variantNameControllersHi.length > i)
            _variantNameControllersHi[i].text = vTrans['hi'] ?? '';
          if (_variantNameControllersHn.length > i)
            _variantNameControllersHn[i].text = vTrans['hn'] ?? '';
        }
      }

      // 4. Translate Info
      for (int i = 0; i < _infoAttributeControllers.length; i++) {
        final attrEng = _infoAttributeControllers[i].text.trim();
        if (attrEng.isNotEmpty) {
          final attrTrans = await _translateText(attrEng);
          if (_infoAttributeControllersHi.length > i)
            _infoAttributeControllersHi[i].text = attrTrans['hi'] ?? '';
          if (_infoAttributeControllersHn.length > i)
            _infoAttributeControllersHn[i].text = attrTrans['hn'] ?? '';
        }
        final valEng = _infoValueControllers[i].text.trim();
        if (valEng.isNotEmpty) {
          final valTrans = await _translateText(valEng);
          if (_infoValueControllersHi.length > i)
            _infoValueControllersHi[i].text = valTrans['hi'] ?? '';
          if (_infoValueControllersHn.length > i)
            _infoValueControllersHn[i].text = valTrans['hn'] ?? '';
        }
      }

      // 5. Translate Highlights
      for (int i = 0; i < _highlightAttributeControllers.length; i++) {
        final attrEng = _highlightAttributeControllers[i].text.trim();
        if (attrEng.isNotEmpty) {
          final attrTrans = await _translateText(attrEng);
          if (_highlightAttributeControllersHi.length > i)
            _highlightAttributeControllersHi[i].text = attrTrans['hi'] ?? '';
          if (_highlightAttributeControllersHn.length > i)
            _highlightAttributeControllersHn[i].text = attrTrans['hn'] ?? '';
        }
        final valEng = _highlightValueControllers[i].text.trim();
        if (valEng.isNotEmpty) {
          final valTrans = await _translateText(valEng);
          if (_highlightValueControllersHi.length > i)
            _highlightValueControllersHi[i].text = valTrans['hi'] ?? '';
          if (_highlightValueControllersHn.length > i)
            _highlightValueControllersHn[i].text = valTrans['hn'] ?? '';
        }
      }

      _showSnackBar("All translations populated! ✅", AppColors.successColor);
    } catch (e) {
      _showSnackBar("Error translating: $e", AppColors.errorColor);
    } finally {
      setState(() => isFormLoading = false);
    }
  }

  Future<void> _getImage() async {
    final Uint8List? bytes = await ImagePickerWeb.getImageAsBytes();
    if (bytes != null) {
      if (bytes.length <= 1024 * 1024) {
        setState(() => _imageBytes.add(bytes));
      } else {
        _showSnackBar(
          'Image must be smaller than 1 MB',
          AppColors.warningColor,
        );
      }
    }
  }

  Future<void> _saveProductHandler() async {
    if (_nameController.text.isEmpty || selectedMainCategoryId == null) {
      _showSnackBar(
        'Please fill all main product fields',
        AppColors.errorColor,
      );
      return;
    }

    if (editingProduct != null) {
      await _updateProduct();
    } else {
      await _saveProduct();
    }
  }

  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty || selectedMainCategoryId == null) {
      _showSnackBar(
        'Please fill all main product fields',
        AppColors.errorColor,
      );
      return;
    }

    _showSnackBar('Saving product...', AppColors.infoColor);

    try {
      final body = {
        'name': _nameController.text.trim(),
        'name_hi': _nameControllerHi.text.trim(),
        'name_hn': _nameControllerHn.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? "test"
            : _descriptionController.text.trim(),
        'description_hi': _descriptionControllerHi.text.trim(),
        'description_hn': _descriptionControllerHn.text.trim(),
        'main_category_id': selectedMainCategoryId,
        'images': _uploadedImageUrls,
      };

      // Products, variants, images, info and highlights are separate tables and the
      // Edge Function writes one table per call by design, so the parent row is created
      // first and its id used for the children.
      body.remove('images');
      final saved = await AdminApi.insert(AdminTables.products, body);
      final savedProductId = saved['id']?.toString();

      {
        if (savedProductId != null) {
          // Upload Images
          for (int i = 0; i < _imageBytes.length; i++) {
            await _uploadImage(_imageBytes[i], int.parse(savedProductId));
          }

          // Save Variants
          for (int i = 0; i < _variantNameControllers.length; i++) {
            if (_variantNameControllers[i].text.isNotEmpty) {
              await _saveVariant(
                savedProductId,
                _variantNameControllers[i].text,
                _variantNameControllersHi.length > i
                    ? _variantNameControllersHi[i].text
                    : '',
                _variantNameControllersHn.length > i
                    ? _variantNameControllersHn[i].text
                    : '',
                _variantPriceControllers[i].text,
                _sellingPriceControllers[i].text,
                _wholesalePriceControllers[i].text,
                _variantStockControllers[i].text,
              );
            }
          }

          // Save Info
          for (int i = 0; i < _infoAttributeControllers.length; i++) {
            if (_infoAttributeControllers[i].text.isNotEmpty &&
                _infoValueControllers[i].text.isNotEmpty) {
              await _saveProductDetail(
                AdminTables.productInfo,
                savedProductId,
                _infoAttributeControllers[i].text,
                _infoAttributeControllersHi.length > i
                    ? _infoAttributeControllersHi[i].text
                    : '',
                _infoAttributeControllersHn.length > i
                    ? _infoAttributeControllersHn[i].text
                    : '',
                _infoValueControllers[i].text,
                _infoValueControllersHi.length > i
                    ? _infoValueControllersHi[i].text
                    : '',
                _infoValueControllersHn.length > i
                    ? _infoValueControllersHn[i].text
                    : '',
              );
            }
          }

          // Save Highlights
          for (int i = 0; i < _highlightAttributeControllers.length; i++) {
            if (_highlightAttributeControllers[i].text.isNotEmpty &&
                _highlightValueControllers[i].text.isNotEmpty) {
              await _saveProductDetail(
                AdminTables.productHighlights,
                savedProductId,
                _highlightAttributeControllers[i].text,
                _highlightAttributeControllersHi.length > i
                    ? _highlightAttributeControllersHi[i].text
                    : '',
                _highlightAttributeControllersHn.length > i
                    ? _highlightAttributeControllersHn[i].text
                    : '',
                _highlightValueControllers[i].text,
                _highlightValueControllersHi.length > i
                    ? _highlightValueControllersHi[i].text
                    : '',
                _highlightValueControllersHn.length > i
                    ? _highlightValueControllersHn[i].text
                    : '',
              );
            }
          }

          _showSnackBar(
            'Product and all details added successfully!',
            AppColors.successColor,
          );

          _clearFields();
          fetchProducts();
        }
      }
    } catch (e) {
      _showSnackBar(
        e is AdminApiException ? e.message : 'Error occurred: $e',
        AppColors.errorColor,
      );
    }
  }

  Future<void> _updateProduct() async {
    if (editingProduct == null) return;

    final productId = editingProduct!['id'].toString();
    _showSnackBar('Updating product...', AppColors.infoColor);

    try {
      final body = {
        'id': productId,
        'name': _nameController.text.trim(),
        'name_hi': _nameControllerHi.text.trim(),
        'name_hn': _nameControllerHn.text.trim(),
        'description': _descriptionController.text.trim(),
        'description_hi': _descriptionControllerHi.text.trim(),
        'description_hn': _descriptionControllerHn.text.trim(),
        'main_category_id': selectedMainCategoryId,
        'images': _uploadedImageUrls,
        'variants': [
          for (int i = 0; i < _variantNameControllers.length; i++)
            {
              'id': _existingVariantIds.length > i
                  ? _existingVariantIds[i]
                  : null,
              'name': _variantNameControllers[i].text,
              'name_hi': _variantNameControllersHi.length > i
                  ? _variantNameControllersHi[i].text
                  : '',
              'name_hn': _variantNameControllersHn.length > i
                  ? _variantNameControllersHn[i].text
                  : '',
              'price': _variantPriceControllers[i].text,
              'selling_price': _sellingPriceControllers[i].text,
              'wholesale_price': _wholesalePriceControllers[i].text,
              'stock_quantity': _variantStockControllers[i].text,
            },
        ],
        'info': [
          for (int i = 0; i < _infoAttributeControllers.length; i++)
            {
              'id': _existingInfoIds.length > i ? _existingInfoIds[i] : null,
              'attribute': _infoAttributeControllers[i].text,
              'attribute_hi': _infoAttributeControllersHi.length > i
                  ? _infoAttributeControllersHi[i].text
                  : '',
              'attribute_hn': _infoAttributeControllersHn.length > i
                  ? _infoAttributeControllersHn[i].text
                  : '',
              'value': _infoValueControllers[i].text,
              'value_hi': _infoValueControllersHi.length > i
                  ? _infoValueControllersHi[i].text
                  : '',
              'value_hn': _infoValueControllersHn.length > i
                  ? _infoValueControllersHn[i].text
                  : '',
            },
        ],
        'highlights': [
          for (int i = 0; i < _highlightAttributeControllers.length; i++)
            {
              'id': _existingHighlightIds.length > i
                  ? _existingHighlightIds[i]
                  : null,
              'attribute': _highlightAttributeControllers[i].text,
              'attribute_hi': _highlightAttributeControllersHi.length > i
                  ? _highlightAttributeControllersHi[i].text
                  : '',
              'attribute_hn': _highlightAttributeControllersHn.length > i
                  ? _highlightAttributeControllersHn[i].text
                  : '',
              'value': _highlightValueControllers[i].text,
              'value_hi': _highlightValueControllersHi.length > i
                  ? _highlightValueControllersHi[i].text
                  : '',
              'value_hn': _highlightValueControllersHn.length > i
                  ? _highlightValueControllersHn[i].text
                  : '',
            },
        ],
      };

      // Same reason as the insert path: write the parent, then the children.
      final variantsPayload = (body.remove('variants') as List?) ?? const [];
      final infoPayload = (body.remove('info') as List?) ?? const [];
      final highlightsPayload =
          (body.remove('highlights') as List?) ?? const [];
      body.remove('images');
      body.remove('id');

      await AdminApi.update(AdminTables.products, productId, body);

      for (final v in variantsPayload.cast<Map<String, dynamic>>()) {
        if ('${v['name'] ?? ''}'.isEmpty) continue;
        await _saveVariant(
          productId,
          '${v['name']}',
          '${v['name_hi'] ?? ''}',
          '${v['name_hn'] ?? ''}',
          '${v['price'] ?? ''}',
          '${v['selling_price'] ?? ''}',
          '${v['wholesale_price'] ?? ''}',
          '${v['stock_quantity'] ?? ''}',
          variantId: v['id']?.toString(),
        );
      }
      for (final d in infoPayload.cast<Map<String, dynamic>>()) {
        await _saveProductDetail(
          AdminTables.productInfo,
          productId,
          '${d['attribute'] ?? ''}',
          '${d['attribute_hi'] ?? ''}',
          '${d['attribute_hn'] ?? ''}',
          '${d['value'] ?? ''}',
          '${d['value_hi'] ?? ''}',
          '${d['value_hn'] ?? ''}',
        );
      }
      for (final d in highlightsPayload.cast<Map<String, dynamic>>()) {
        await _saveProductDetail(
          AdminTables.productHighlights,
          productId,
          '${d['attribute'] ?? ''}',
          '${d['attribute_hi'] ?? ''}',
          '${d['attribute_hn'] ?? ''}',
          '${d['value'] ?? ''}',
          '${d['value_hi'] ?? ''}',
          '${d['value_hn'] ?? ''}',
        );
      }

      {
        {
          for (int i = 0; i < _imageBytes.length; i++) {
            await _uploadImage(_imageBytes[i], int.parse(productId));
          }

          _showSnackBar(
            'Product updated successfully!',
            AppColors.successColor,
          );
          _clearFields();
          fetchProducts();
        }
      }
    } catch (e) {
      _showSnackBar(
        e is AdminApiException ? e.message : 'Error occurred: $e',
        AppColors.errorColor,
      );
    }
  }

  Future<void> _saveVariant(
    String productId,
    String name,
    String nameHi,
    String nameHn,
    String price,
    String sellingPrice,
    String wholesalePrice,
    String stockQuantity, {
    String? variantId,
  }) async {
    try {
      double? parsedPrice = double.tryParse(price) ?? 0.0;
      double? parsedWholesalePrice = double.tryParse(wholesalePrice) ?? 0.0;
      int? parsedStock = int.tryParse(stockQuantity) ?? 0;

      // Columns are properly typed now, so numbers are sent as numbers. The column is
      // `stock`, not `stock_quantity` -- that was the PHP endpoint's own field name.
      final values = {
        'product_id': int.tryParse(productId) ?? productId,
        'name': name,
        'name_hi': nameHi,
        'name_hn': nameHn,
        'price': parsedPrice,
        'selling_price': double.tryParse(sellingPrice) ?? 0.0,
        'wholesale_price': parsedWholesalePrice,
        'stock': parsedStock,
      };

      if (variantId == null || variantId.isEmpty) {
        await AdminApi.insert(AdminTables.productVariants, values);
      } else {
        await AdminApi.update(AdminTables.productVariants, variantId, values);
      }
    } catch (e) {
      debugPrint('Error saving variant "$name": $e');
    }
  }

  Future<void> _uploadImage(Uint8List bytes, int productId) async {
    try {
      // Upload through the Edge Function (the bucket has no client write policy), then
      // record the returned PATH. Storing a path rather than a URL is what keeps rows
      // portable between environments.
      final path = await AdminApi.uploadImage(bytes, contentType: 'image/png');
      await AdminApi.insert(AdminTables.productImages, {
        'product_id': productId,
        'image_url': path,
      });
    } catch (e) {
      debugPrint('Error uploading image: $e');
    }
  }

  final List<String> typeOptions = [
    'Everyday Essentials',
    'Best selling',
    'Hot deals',
  ];

  List<String> getSelectedTypes(String typeString) {
    return typeString
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _updateProductType(int productId, String newType) async {
    try {
      print('Updating product type: id=$productId, type=$newType');

      await AdminApi.update(AdminTables.products, productId, {
        'types': newType,
      });

      _showSnackBar(
        'Product type updated successfully',
        AppColors.successColor,
      );

      // Update local state
      setState(() {
        selectedTypesMap[productId] = getSelectedTypes(newType);
      });

      // Refresh products list
      fetchProducts();
    } catch (e) {
      debugPrint('Exception: $e');
      _showSnackBar(
        e is AdminApiException ? e.message : 'Error updating product type: $e',
        AppColors.errorColor,
      );
    }
  }

  Widget _buildPaginationControls() {
    final totalPages = (totalProducts / itemsPerPage).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: currentPage > 1
              ? () {
                  setState(() => currentPage--);
                  fetchProducts();
                }
              : null,
          color: currentPage > 1 ? AppColors.primaryColor : Colors.grey,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Text(
            'Page $currentPage of $totalPages',
            style: GoogleFonts.poppins(
              color: AppColors.primaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: currentPage < totalPages
              ? () {
                  setState(() => currentPage++);
                  fetchProducts();
                }
              : null,
          color: currentPage < totalPages
              ? AppColors.primaryColor
              : Colors.grey,
        ),
      ],
    );
  }

  void _editProduct(Map<String, dynamic> product) {
    setState(() {
      editingProduct = product;

      _nameController.text = product['name'] ?? '';
      _descriptionController.text = product['description'] ?? '';
      selectedMainCategoryId = product['main_category_id']?.toString() ?? '';

      // Clear previous fields
      _variantNameControllers.clear();
      _variantPriceControllers.clear();
      _sellingPriceControllers.clear();
      _wholesalePriceControllers.clear();
      _variantStockControllers.clear();
      _existingVariantIds.clear();

      // Load Variants
      final variants = product['variants'] ?? [];
      if (variants.isNotEmpty) {
        for (var variant in variants) {
          _variantNameControllers.add(
            TextEditingController(text: variant['name'] ?? ''),
          );
          _variantPriceControllers.add(
            TextEditingController(text: variant['price']?.toString() ?? ''),
          );
          _sellingPriceControllers.add(
            TextEditingController(
              text: variant['selling_price']?.toString() ?? '',
            ),
          );
          _wholesalePriceControllers.add(
            TextEditingController(
              text: variant['wholesale_price']?.toString() ?? '',
            ),
          );
          _variantStockControllers.add(
            TextEditingController(
              text:
                  variant['stock_quantity']?.toString() ??
                  variant['stock']?.toString() ??
                  '',
            ),
          );
          _existingVariantIds.add(variant['id']?.toString());
        }
      } else {
        _addVariantField();
      }

      // Load Info
      _infoAttributeControllers.clear();
      _infoValueControllers.clear();
      _existingInfoIds.clear();
      final infoList = product['info'] ?? [];
      if (infoList.isNotEmpty) {
        for (var info in infoList) {
          _infoAttributeControllers.add(
            TextEditingController(text: info['attribute'] ?? ''),
          );
          _infoValueControllers.add(
            TextEditingController(text: info['value'] ?? ''),
          );
          _existingInfoIds.add(info['id']?.toString());
        }
      } else {
        _addInfoField();
      }

      // Load Highlights
      _highlightAttributeControllers.clear();
      _highlightValueControllers.clear();
      _existingHighlightIds.clear();
      final highlights = product['highlights'] ?? [];
      if (highlights.isNotEmpty) {
        for (var highlight in highlights) {
          _highlightAttributeControllers.add(
            TextEditingController(text: highlight['attribute'] ?? ''),
          );
          _highlightValueControllers.add(
            TextEditingController(text: highlight['value'] ?? ''),
          );
          _existingHighlightIds.add(highlight['id']?.toString());
        }
      } else {
        _addHighlightField();
      }

      // Load Uploaded Images
      _uploadedImageUrls.clear();
      final imageUrls = product['images'] ?? [];
      for (var url in imageUrls) {
        if (url is String && url.isNotEmpty) {
          _uploadedImageUrls.add(url);
        }
      }
    });
  }

  Future<void> _deleteProduct(String productId) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Delete',
          style: GoogleFonts.poppins(color: AppColors.primaryTextColor),
        ),
        content: Text(
          'Are you sure you want to delete this product?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: AppColors.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => isLoading = true);
      try {
        await AdminApi.delete(AdminTables.products, productId);

        _showSnackBar('Product deleted successfully', AppColors.successColor);
        fetchProducts();
      } catch (e) {
        _showSnackBar(
          e is AdminApiException ? e.message : 'Error deleting product: $e',
          AppColors.errorColor,
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Product Management",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryTextColor,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - Product List
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  // Search bar
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: AppColors.surfaceColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              onChanged: (value) {
                                setState(() {
                                  searchQuery = value;
                                  currentPage = 1;
                                });
                                fetchProducts();
                              },
                              style: GoogleFonts.poppins(),
                              decoration: InputDecoration(
                                labelText: 'Search Products',
                                labelStyle: GoogleFonts.poppins(
                                  color: AppColors.secondaryTextColor,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: AppColors.hintTextColor,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderColor,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderColor,
                                  ),
                                ),
                                filled: true,
                                fillColor: AppColors.backgroundColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  searchQuery = '';
                                  searchController.clear();
                                  currentPage = 1;
                                });
                                fetchProducts();
                              },
                              tooltip: 'Refresh',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  _buildCategoryFilterDropdown(),

                  const SizedBox(height: 16),

                  Text(
                    'Total Products: ${totalProducts.toString()}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryTextColor,
                    ),
                  ),

                  // Product List
                  Expanded(
                    child: isLoading
                        ? _buildShimmerLoader()
                        : products.isEmpty
                        ? Center(
                            child: Text(
                              'No products found',
                              style: GoogleFonts.poppins(
                                color: AppColors.secondaryTextColor,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index];
                              return _buildProductListItem(product);
                            },
                          ),
                  ),

                  if (totalProducts > itemsPerPage)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _buildPaginationControls(),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 20),

            // Right side - Product Form
            Expanded(
              flex: 2,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: AppColors.surfaceColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          editingProduct != null
                              ? "Edit Product"
                              : "Add New Product",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildProductForm(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductForm() {
    final validatedMainCategoryId =
        _mainCategoryList.any(
          (mc) => mc['id'].toString() == selectedMainCategoryId,
        )
        ? selectedMainCategoryId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          style: GoogleFonts.poppins(),
          decoration: InputDecoration(
            labelText: 'Product Name (English)',
            labelStyle: GoogleFonts.poppins(
              color: AppColors.secondaryTextColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            prefixIcon: const Icon(
              Icons.shopping_bag,
              color: AppColors.hintTextColor,
            ),
            filled: true,
            fillColor: AppColors.backgroundColor,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => setState(
                () => _showNameTranslations = !_showNameTranslations,
              ),
              icon: Icon(
                _showNameTranslations ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(
                _showNameTranslations
                    ? "Hide Name Translations"
                    : "Show Name Translations",
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
            TextButton.icon(
              onPressed: _autoTranslateAll,
              icon: const Icon(
                Icons.translate,
                size: 16,
                color: AppColors.primaryColor,
              ),
              label: Text(
                "Auto-Translate All",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryColor,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        if (_showNameTranslations) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _nameControllerHi,
            style: GoogleFonts.poppins(),
            decoration: InputDecoration(
              labelText: 'Product Name (Hindi)',
              labelStyle: GoogleFonts.poppins(
                color: AppColors.secondaryTextColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              filled: true,
              fillColor: AppColors.backgroundColor,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameControllerHn,
            style: GoogleFonts.poppins(),
            decoration: InputDecoration(
              labelText: 'Product Name (Hinglish)',
              labelStyle: GoogleFonts.poppins(
                color: AppColors.secondaryTextColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              filled: true,
              fillColor: AppColors.backgroundColor,
            ),
          ),
        ],
        const SizedBox(height: 16),

        TextField(
          controller: _descriptionController,
          maxLines: 3,
          style: GoogleFonts.poppins(),
          decoration: InputDecoration(
            labelText: 'Description (English)',
            labelStyle: GoogleFonts.poppins(
              color: AppColors.secondaryTextColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            prefixIcon: const Icon(
              Icons.description,
              color: AppColors.hintTextColor,
            ),
            filled: true,
            fillColor: AppColors.backgroundColor,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => setState(
                () => _showDescriptionTranslations =
                    !_showDescriptionTranslations,
              ),
              icon: Icon(
                _showDescriptionTranslations
                    ? Icons.expand_less
                    : Icons.expand_more,
                size: 18,
              ),
              label: Text(
                _showDescriptionTranslations
                    ? "Hide Description Translations"
                    : "Show Description Translations",
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
          ],
        ),
        if (_showDescriptionTranslations) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionControllerHi,
            maxLines: 2,
            style: GoogleFonts.poppins(),
            decoration: InputDecoration(
              labelText: 'Description (Hindi)',
              labelStyle: GoogleFonts.poppins(
                color: AppColors.secondaryTextColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              filled: true,
              fillColor: AppColors.backgroundColor,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionControllerHn,
            maxLines: 2,
            style: GoogleFonts.poppins(),
            decoration: InputDecoration(
              labelText: 'Description (Hinglish)',
              labelStyle: GoogleFonts.poppins(
                color: AppColors.secondaryTextColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              filled: true,
              fillColor: AppColors.backgroundColor,
            ),
          ),
        ],
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: validatedMainCategoryId,
          items: _mainCategoryList.map((mc) {
            return DropdownMenuItem(
              value: mc['id'].toString(),
              child: Text(mc['name'], style: GoogleFonts.poppins()),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              selectedMainCategoryId = val;
            });
          },
          style: GoogleFonts.poppins(),
          decoration: InputDecoration(
            labelText: 'Main Category',
            labelStyle: GoogleFonts.poppins(
              color: AppColors.secondaryTextColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            prefixIcon: const Icon(
              Icons.category,
              color: AppColors.hintTextColor,
            ),
            filled: true,
            fillColor: AppColors.backgroundColor,
          ),
          dropdownColor: AppColors.surfaceColor,
        ),
        const SizedBox(height: 16),

        Text(
          'Product Gallery',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryTextColor,
            fontSize: 16,
          ),
        ),
        Text(
          'नोट: कृपया पहले प्रोडक्ट की मेन इमेज चुनें।',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryTextColor,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 10),
        _buildImageUploadSection(),
        const SizedBox(height: 20),
        _buildVariantSection(),
        const SizedBox(height: 20),
        _buildInfoSection(),
        const SizedBox(height: 20),
        _buildHighlightSection(),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (editingProduct != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    editingProduct = null;
                    _clearFields();
                  });
                },
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: AppColors.secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _saveProductHandler,
              icon: const Icon(Icons.save, size: 20),
              label: Text(
                editingProduct != null ? "Update Product" : "Save Product",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterCategoryId,
                hint: Text(
                  "Filter by Category",
                  style: GoogleFonts.poppins(
                    color: AppColors.secondaryTextColor,
                  ),
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: 'all',
                    child: Text(
                      "All Categories",
                      style: GoogleFonts.poppins(
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                  ),
                  ..._mainCategoryList.map<DropdownMenuItem<String>>((
                    category,
                  ) {
                    return DropdownMenuItem<String>(
                      value: category['id'].toString(),
                      child: Text(
                        category['name'],
                        style: GoogleFonts.poppins(
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                    );
                  }).toList(),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    _filterCategoryId = newValue;
                    currentPage = 1;
                  });
                  fetchProducts();
                },
                style: GoogleFonts.poppins(
                  color: AppColors.primaryTextColor,
                  fontSize: 14,
                ),
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.primaryColor,
                ),
                isExpanded: true,
              ),
            ),
          ),
          if (_filterCategoryId != null && _filterCategoryId != 'all')
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                setState(() {
                  _filterCategoryId = null;
                  currentPage = 1;
                });
                fetchProducts();
              },
              tooltip: 'Clear filter',
            ),
        ],
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (int i = 0; i < _uploadedImageUrls.length; i++)
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(Db.imageUrl(_uploadedImageUrls[i])),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _uploadedImageUrls.removeAt(i)),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.errorColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            for (int i = 0; i < _imageBytes.length; i++)
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: MemoryImage(_imageBytes[i]),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _imageBytes.removeAt(i)),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.errorColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            GestureDetector(
              onTap: _getImage,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.backgroundColor,
                  border: Border.all(color: AppColors.borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo,
                      size: 20,
                      color: AppColors.hintTextColor,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.hintTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Add images 1:1 (100K each)',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.hintTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildVariantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Product Variants',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryTextColor,
                fontSize: 16,
              ),
            ),
            IconButton(
              onPressed: _addVariantField,
              icon: const Icon(Icons.add_circle, color: AppColors.successColor),
              tooltip: 'Add Variant',
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_variantNameControllers.length, (i) {
          if (_showVariantTranslations.length <= i) {
            _showVariantTranslations.add(false);
          }
          if (_variantNameControllersHi.length <= i) {
            _variantNameControllersHi.add(TextEditingController());
          }
          if (_variantNameControllersHn.length <= i) {
            _variantNameControllersHn.add(TextEditingController());
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _variantNameControllers[i],
                          style: GoogleFonts.poppins(),
                          decoration: InputDecoration(
                            labelText: 'Variant Name (English)',
                            labelStyle: GoogleFonts.poppins(
                              color: AppColors.secondaryTextColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _variantPriceControllers[i],
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(),
                          decoration: InputDecoration(
                            labelText: 'MRP Price',
                            labelStyle: GoogleFonts.poppins(
                              color: AppColors.secondaryTextColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            prefixText: '₹ ',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sellingPriceControllers[i],
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(),
                          decoration: InputDecoration(
                            labelText: 'Selling Price',
                            labelStyle: GoogleFonts.poppins(
                              color: AppColors.secondaryTextColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            prefixText: '₹ ',
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _wholesalePriceControllers[i],
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(),
                          decoration: InputDecoration(
                            labelText: 'Purchase Price',
                            labelStyle: GoogleFonts.poppins(
                              color: AppColors.secondaryTextColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            prefixText: '₹ ',
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _variantStockControllers[i],
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(),
                          decoration: InputDecoration(
                            labelText: 'Stock',
                            labelStyle: GoogleFonts.poppins(
                              color: AppColors.secondaryTextColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => setState(
                          () => _showVariantTranslations[i] =
                              !_showVariantTranslations[i],
                        ),
                        icon: Icon(
                          _showVariantTranslations[i]
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                        ),
                        label: Text(
                          "Translations",
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle,
                          color: AppColors.errorColor,
                        ),
                        onPressed: () => _removeVariantField(i),
                        tooltip: 'Remove Variant',
                      ),
                    ],
                  ),
                  if (_showVariantTranslations[i]) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _variantNameControllersHi[i],
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                        labelText: 'Variant Name (Hindi)',
                        labelStyle: GoogleFonts.poppins(
                          color: AppColors.secondaryTextColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.borderColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.borderColor,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _variantNameControllersHn[i],
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                        labelText: 'Variant Name (Hinglish)',
                        labelStyle: GoogleFonts.poppins(
                          color: AppColors.secondaryTextColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.borderColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.borderColor,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Product Information',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryTextColor,
                fontSize: 16,
              ),
            ),
            IconButton(
              onPressed: _addInfoField,
              icon: const Icon(Icons.add_circle, color: AppColors.successColor),
              tooltip: 'Add Info',
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_infoAttributeControllers.length, (i) {
          if (_showInfoTranslations.length <= i) {
            _showInfoTranslations.add(false);
          }
          if (_infoAttributeControllersHi.length <= i) {
            _infoAttributeControllersHi.add(TextEditingController());
          }
          if (_infoAttributeControllersHn.length <= i) {
            _infoAttributeControllersHn.add(TextEditingController());
          }
          if (_infoValueControllersHi.length <= i) {
            _infoValueControllersHi.add(TextEditingController());
          }
          if (_infoValueControllersHn.length <= i) {
            _infoValueControllersHn.add(TextEditingController());
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _infoAttributeControllers[i],
                          style: GoogleFonts.poppins(),
                          decoration: InputDecoration(
                            labelText: 'Attribute (English)',
                            labelStyle: GoogleFonts.poppins(
                              color: AppColors.secondaryTextColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _infoValueControllers[i],
                          style: GoogleFonts.poppins(),
                          decoration: InputDecoration(
                            labelText: 'Value (English)',
                            labelStyle: GoogleFonts.poppins(
                              color: AppColors.secondaryTextColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => setState(
                          () => _showInfoTranslations[i] =
                              !_showInfoTranslations[i],
                        ),
                        icon: Icon(
                          _showInfoTranslations[i]
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                        ),
                        label: Text(
                          "Translations",
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle,
                          color: AppColors.errorColor,
                        ),
                        onPressed: () => _removeInfoField(i),
                        tooltip: 'Remove Info',
                      ),
                    ],
                  ),
                  if (_showInfoTranslations[i]) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _infoAttributeControllersHi[i],
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              labelText: 'Attribute (Hindi)',
                              labelStyle: GoogleFonts.poppins(
                                color: AppColors.secondaryTextColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _infoValueControllersHi[i],
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              labelText: 'Value (Hindi)',
                              labelStyle: GoogleFonts.poppins(
                                color: AppColors.secondaryTextColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _infoAttributeControllersHn[i],
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              labelText: 'Attribute (Hinglish)',
                              labelStyle: GoogleFonts.poppins(
                                color: AppColors.secondaryTextColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _infoValueControllersHn[i],
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              labelText: 'Value (Hinglish)',
                              labelStyle: GoogleFonts.poppins(
                                color: AppColors.secondaryTextColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHighlightSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Product Highlights',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryTextColor,
                fontSize: 16,
              ),
            ),
            IconButton(
              onPressed: _addHighlightField,
              icon: const Icon(Icons.add_circle, color: AppColors.successColor),
              tooltip: 'Add Highlight',
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_highlightAttributeControllers.length, (i) {
          if (_showHighlightTranslations.length <= i) {
            _showHighlightTranslations.add(false);
          }
          if (_highlightAttributeControllersHi.length <= i) {
            _highlightAttributeControllersHi.add(TextEditingController());
          }
          if (_highlightAttributeControllersHn.length <= i) {
            _highlightAttributeControllersHn.add(TextEditingController());
          }
          if (_highlightValueControllersHi.length <= i) {
            _highlightValueControllersHi.add(TextEditingController());
          }
          if (_highlightValueControllersHn.length <= i) {
            _highlightValueControllersHn.add(TextEditingController());
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _highlightAttributeControllers[i],
                          style: GoogleFonts.poppins(),
                          decoration: InputDecoration(
                            labelText: 'Attribute (English)',
                            labelStyle: GoogleFonts.poppins(
                              color: AppColors.secondaryTextColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _highlightValueControllers[i],
                          style: GoogleFonts.poppins(),
                          decoration: InputDecoration(
                            labelText: 'Value (English)',
                            labelStyle: GoogleFonts.poppins(
                              color: AppColors.secondaryTextColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.borderColor,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => setState(
                          () => _showHighlightTranslations[i] =
                              !_showHighlightTranslations[i],
                        ),
                        icon: Icon(
                          _showHighlightTranslations[i]
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                        ),
                        label: Text(
                          "Translations",
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle,
                          color: AppColors.errorColor,
                        ),
                        onPressed: () => _removeHighlightField(i),
                        tooltip: 'Remove Highlight',
                      ),
                    ],
                  ),
                  if (_showHighlightTranslations[i]) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _highlightAttributeControllersHi[i],
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              labelText: 'Attribute (Hindi)',
                              labelStyle: GoogleFonts.poppins(
                                color: AppColors.secondaryTextColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _highlightValueControllersHi[i],
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              labelText: 'Value (Hindi)',
                              labelStyle: GoogleFonts.poppins(
                                color: AppColors.secondaryTextColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _highlightAttributeControllersHn[i],
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              labelText: 'Attribute (Hinglish)',
                              labelStyle: GoogleFonts.poppins(
                                color: AppColors.secondaryTextColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _highlightValueControllersHn[i],
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              labelText: 'Value (Hinglish)',
                              labelStyle: GoogleFonts.poppins(
                                color: AppColors.secondaryTextColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProductListItem(Map<String, dynamic> product) {
    final int productId = int.tryParse(product['id'].toString()) ?? 0;
    final List<String> selectedTypes =
        selectedTypesMap[productId] ?? getSelectedTypes(product['types'] ?? "");

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        title: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.backgroundColor,
                    image:
                        product['images'] != null &&
                            product['images'].isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(
                              Db.imageUrl('${product['images'][0]}'),
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: product['images'] == null || product['images'].isEmpty
                      ? const Icon(Icons.image, color: AppColors.hintTextColor)
                      : null,
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'],
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'C : ' + product['main_category_name'],
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.primaryTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${product['variants']?.length ?? 0} variants',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          color: AppColors.infoColor,
                          onPressed: () => _editProduct(product),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          color: AppColors.errorColor,
                          onPressed: () =>
                              _deleteProduct(product['id'].toString()),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'Product Types:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: typeOptions.map((type) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: selectedTypes.contains(type),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                selectedTypes.add(type);
                              } else {
                                selectedTypes.remove(type);
                              }
                              selectedTypesMap[productId] = List.from(
                                selectedTypes,
                              );
                            });
                          },
                        ),
                        Text(type, style: GoogleFonts.poppins(fontSize: 14)),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    print(
                      "Updating product ID: $productId with types: ${selectedTypes.join(',')}",
                    );
                    _updateProductType(productId, selectedTypes.join(','));
                  },
                  child: const Text("Update Type"),
                ),
              ],
            ),
          ],
        ),
        children: [
          if (product['variants'] != null && product['variants'].isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Variants:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...product['variants'].map<Widget>((variant) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${variant['name']} - MRP: ₹${variant['price']} | Selling: ₹${variant['selling_price']} | Wholesale: ₹${variant['wholesale_price'] ?? 'N/A'}",
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        Text(
                          "Stock: ${variant['stock'].toString()}",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 12),
              ],
            )
          else
            const Text("No variants found", style: TextStyle(fontSize: 14)),

          if (product['info'] != null && product['info'].isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Info:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...product['info'].map<Widget>((info) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        "${info['attribute']}: ${info['value']}",
                        style: GoogleFonts.poppins(fontSize: 14),
                        textAlign: TextAlign.left,
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 12),
                ],
              ),
            )
          else
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("No info found", style: TextStyle(fontSize: 14)),
            ),

          if (product['highlights'] != null && product['highlights'].isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Highlights:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...product['highlights'].map<Widget>((high) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        "${high['attribute']}: ${high['value']}",
                        style: GoogleFonts.poppins(fontSize: 14),
                        textAlign: TextAlign.left,
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 8),
                ],
              ),
            )
          else
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "No highlights found",
                style: TextStyle(fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 100,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      width: 80,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 60,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveProductDetail(
    String table,
    String productId,
    String attribute,
    String attributeHi,
    String attributeHn,
    String value,
    String valueHi,
    String valueHn,
  ) async {
    try {
      await AdminApi.insert(table, {
        'product_id': int.tryParse(productId) ?? productId,
        'attribute': attribute,
        'attribute_hi': attributeHi,
        'attribute_hn': attributeHn,
        'value': value,
        'value_hi': valueHi,
        'value_hn': valueHn,
      });
    } catch (e) {
      debugPrint('Error saving detail (Attribute: $attribute): $e');
    }
  }

  void _addVariantField() {
    setState(() {
      _variantNameControllers.add(TextEditingController());
      _variantNameControllersHi.add(TextEditingController());
      _variantNameControllersHn.add(TextEditingController());
      _variantPriceControllers.add(TextEditingController());
      _sellingPriceControllers.add(TextEditingController());
      _wholesalePriceControllers.add(TextEditingController());
      _variantStockControllers.add(TextEditingController());
      _showVariantTranslations.add(false);
    });
  }

  void _removeVariantField(int index) {
    setState(() {
      _variantNameControllers[index].dispose();
      if (_variantNameControllersHi.length > index)
        _variantNameControllersHi[index].dispose();
      if (_variantNameControllersHn.length > index)
        _variantNameControllersHn[index].dispose();
      _variantPriceControllers[index].dispose();
      _sellingPriceControllers[index].dispose();
      _wholesalePriceControllers[index].dispose();
      _variantStockControllers[index].dispose();

      _variantNameControllers.removeAt(index);
      if (_variantNameControllersHi.length > index)
        _variantNameControllersHi.removeAt(index);
      if (_variantNameControllersHn.length > index)
        _variantNameControllersHn.removeAt(index);
      _variantPriceControllers.removeAt(index);
      _sellingPriceControllers.removeAt(index);
      _wholesalePriceControllers.removeAt(index);
      _variantStockControllers.removeAt(index);
      if (_showVariantTranslations.length > index)
        _showVariantTranslations.removeAt(index);
    });
  }

  void _addInfoField() {
    setState(() {
      _infoAttributeControllers.add(TextEditingController());
      _infoAttributeControllersHi.add(TextEditingController());
      _infoAttributeControllersHn.add(TextEditingController());
      _infoValueControllers.add(TextEditingController());
      _infoValueControllersHi.add(TextEditingController());
      _infoValueControllersHn.add(TextEditingController());
      _showInfoTranslations.add(false);
    });
  }

  void _removeInfoField(int index) {
    setState(() {
      _infoAttributeControllers[index].dispose();
      if (_infoAttributeControllersHi.length > index)
        _infoAttributeControllersHi[index].dispose();
      if (_infoAttributeControllersHn.length > index)
        _infoAttributeControllersHn[index].dispose();
      _infoValueControllers[index].dispose();
      if (_infoValueControllersHi.length > index)
        _infoValueControllersHi[index].dispose();
      if (_infoValueControllersHn.length > index)
        _infoValueControllersHn[index].dispose();

      _infoAttributeControllers.removeAt(index);
      if (_infoAttributeControllersHi.length > index)
        _infoAttributeControllersHi.removeAt(index);
      if (_infoAttributeControllersHn.length > index)
        _infoAttributeControllersHn.removeAt(index);
      _infoValueControllers.removeAt(index);
      if (_infoValueControllersHi.length > index)
        _infoValueControllersHi.removeAt(index);
      if (_infoValueControllersHn.length > index)
        _infoValueControllersHn.removeAt(index);
      if (_showInfoTranslations.length > index)
        _showInfoTranslations.removeAt(index);
    });
  }

  void _addHighlightField() {
    setState(() {
      _highlightAttributeControllers.add(TextEditingController());
      _highlightAttributeControllersHi.add(TextEditingController());
      _highlightAttributeControllersHn.add(TextEditingController());
      _highlightValueControllers.add(TextEditingController());
      _highlightValueControllersHi.add(TextEditingController());
      _highlightValueControllersHn.add(TextEditingController());
      _showHighlightTranslations.add(false);
    });
  }

  void _removeHighlightField(int index) {
    setState(() {
      _highlightAttributeControllers[index].dispose();
      if (_highlightAttributeControllersHi.length > index)
        _highlightAttributeControllersHi[index].dispose();
      if (_highlightAttributeControllersHn.length > index)
        _highlightAttributeControllersHn[index].dispose();
      _highlightValueControllers[index].dispose();
      if (_highlightValueControllersHi.length > index)
        _highlightValueControllersHi[index].dispose();
      if (_highlightValueControllersHn.length > index)
        _highlightValueControllersHn[index].dispose();

      _highlightAttributeControllers.removeAt(index);
      if (_highlightAttributeControllersHi.length > index)
        _highlightAttributeControllersHi.removeAt(index);
      if (_highlightAttributeControllersHn.length > index)
        _highlightAttributeControllersHn.removeAt(index);
      _highlightValueControllers.removeAt(index);
      if (_highlightValueControllersHi.length > index)
        _highlightValueControllersHi.removeAt(index);
      if (_highlightValueControllersHn.length > index)
        _highlightValueControllersHn.removeAt(index);
      if (_showHighlightTranslations.length > index)
        _showHighlightTranslations.removeAt(index);
    });
  }

  void _clearFields() {
    _nameController.clear();
    _nameControllerHi.clear();
    _nameControllerHn.clear();
    _descriptionController.clear();
    _descriptionControllerHi.clear();
    _descriptionControllerHn.clear();
    setState(() {
      _imageBytes.clear();
      editingProduct = null;
      selectedMainCategoryId = null;

      _uploadedImageUrls.clear();
      _imageBytes.clear();

      _variantNameControllers.clear();
      _variantNameControllersHi.clear();
      _variantNameControllersHn.clear();
      _variantPriceControllers.clear();
      _sellingPriceControllers.clear();
      _wholesalePriceControllers.clear();
      _variantStockControllers.clear();
      _showVariantTranslations.clear();
      _addVariantField();

      _infoAttributeControllers.clear();
      _infoAttributeControllersHi.clear();
      _infoAttributeControllersHn.clear();
      _infoValueControllers.clear();
      _infoValueControllersHi.clear();
      _infoValueControllersHn.clear();
      _showInfoTranslations.clear();
      _addInfoField();

      _highlightAttributeControllers.clear();
      _highlightAttributeControllersHi.clear();
      _highlightAttributeControllersHn.clear();
      _highlightValueControllers.clear();
      _highlightValueControllersHi.clear();
      _highlightValueControllersHn.clear();
      _showHighlightTranslations.clear();
      _addHighlightField();
    });
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
