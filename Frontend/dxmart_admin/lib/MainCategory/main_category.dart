import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../core/admin_api.dart';
import '../core/supabase.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker_web/image_picker_web.dart';

import '../utils/colors.dart';

class MainCategory extends StatefulWidget {
  const MainCategory({super.key});

  @override
  State<MainCategory> createState() => _MainCategoryState();
}

class _MainCategoryState extends State<MainCategory> {
  final TextEditingController _categoryTextController = TextEditingController();
  final TextEditingController _categoryTextControllerHi =
      TextEditingController();
  final TextEditingController _categoryTextControllerHn =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  Uint8List? _imageDataBytes;
  String? _imageFileName;
  bool _isLoadingForm = false;
  List _categoryList = [];
  List _filteredCategoryList = [];
  bool _isLoadingList = true;
  String? _selectedCategoryIdForEdit;
  String? _initialCategoryName;
  String? _initialCategoryImage;

  // --- Taxonomy fields ------------------------------------------------------
  //
  // Before these existed the form wrote name/name_hi/name_hn and nothing else, which
  // no longer inserts: a row with no parent must be level 1, and the depth trigger
  // rejects anything else. The parent picker is what decides the level, so it is
  // required, not decorative.
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _sortOrderController = TextEditingController();

  /// null = create an umbrella (level 1). Otherwise the chosen parent's id.
  int? _parentId;
  bool _isActive = true;
  List<AdminCategory> _tree = [];
  Map<int, AdminCategory> _byId = {};

  /// Set once the operator edits the slug by hand, so it stops tracking the name.
  /// A slug is a stable handle: silently rewriting it on every rename is how links
  /// and saved references break.
  bool _slugTouched = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _searchController.addListener(_filterCategories);
    _categoryTextController.addListener(_syncSlugFromName);
  }

  @override
  void dispose() {
    _categoryTextController.removeListener(_syncSlugFromName);
    _categoryTextController.dispose();
    _categoryTextControllerHi.dispose();
    _categoryTextControllerHn.dispose();
    _slugController.dispose();
    _sortOrderController.dispose();
    _searchController.removeListener(_filterCategories);
    _searchController.dispose();
    super.dispose();
  }

  /// Keeps the slug in step with the name while creating, and stops as soon as the
  /// operator types their own — or the moment they open an existing category, whose
  /// slug is already referenced elsewhere.
  void _syncSlugFromName() {
    if (_slugTouched || _selectedCategoryIdForEdit != null) return;
    final next = CategoryNameRules.slugify(_categoryTextController.text);
    if (_slugController.text != next) _slugController.text = next;
  }

  /// Slugs and names already in use, excluding the row being edited so saving a
  /// category without renaming it does not collide with itself.
  Iterable<String> get _takenSlugs => _byId.values
      .where((c) => c.id.toString() != _selectedCategoryIdForEdit)
      .map((c) => c.slug ?? '')
      .where((s) => s.isNotEmpty);

  Iterable<String> get _takenNamesLower => _byId.values
      .where((c) => c.id.toString() != _selectedCategoryIdForEdit)
      .map((c) => c.name.toLowerCase());

  /// Parents an operator may choose.
  ///
  /// Depth is capped at 3 by a check constraint, so a level-3 node can never be a
  /// parent — offering it would only produce a write the database refuses. Editing a
  /// node also cannot reparent it under itself or its own descendants, which would be
  /// a cycle.
  List<AdminCategory> get _parentOptions {
    final editingId = int.tryParse(_selectedCategoryIdForEdit ?? '');
    final banned = <int>{};
    if (editingId != null) {
      banned.add(editingId);
      final self = _byId[editingId];
      if (self != null) {
        banned.addAll(self.descendants.map((c) => c.id));
      }
    }
    return _byId.values
        .where((c) => c.level < 3 && !banned.contains(c.id))
        .toList()
      ..sort((a, b) {
        final byLevel = a.level.compareTo(b.level);
        if (byLevel != 0) return byLevel;
        return a.sortOrder.compareTo(b.sortOrder);
      });
  }

  Future<void> _autoTranslateCategory() async {
    final engText = _categoryTextController.text.trim();
    if (engText.isEmpty) {
      _showSnackBar(
        "Please enter category name in English first!",
        AppColors.warningColor,
      );
      return;
    }

    // The PHP backend proxied an external translation service (translate_api.php),
    // which no longer exists. Rather than silently do nothing, tell the operator to
    // type the Hindi and Hinglish names -- an auto-translated product name that nobody
    // checked is worse than a blank one.
    _showSnackBar(
      "Auto-translate is unavailable. Please enter the Hindi and Hinglish names.",
      AppColors.warningColor,
    );
  }

  void _filterCategories() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCategoryList = List.from(_categoryList);
      } else {
        _filteredCategoryList = _categoryList.where((category) {
          final name = category['name'].toString().toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoadingList = true);
    try {
      final rows = await AdminCatalog.categoryRows();
      final tree = await AdminCatalog.categoryTree();
      if (!mounted) return;
      setState(() {
        _categoryList = rows;
        _filteredCategoryList = List.from(_categoryList);
        _tree = tree;
        _byId = {
          for (final c in [
            for (final u in tree) ...[u, ...u.descendants],
          ])
            c.id: c,
        };
        _isLoadingList = false;
      });
    } catch (e) {
      _showSnackBar("Connection error: $e", AppColors.errorColor);
      setState(() => _isLoadingList = false);
    }
  }

  /// The first rule the form breaks, or null if it is safe to save.
  ///
  /// These mirror the assertions in the seed migration, so a category saved here would
  /// also survive that migration's own checks. Hindi and Hinglish are required because
  /// half the audience reads them: an English-only category is invisible to that half,
  /// and auto-translate is gone (see [_autoTranslateCategory]).
  String? _validateForm() {
    final nameError = CategoryNameRules.validateName(
      _categoryTextController.text,
      takenLower: _takenNamesLower,
    );
    if (nameError != null) return nameError;

    final hiError = CategoryNameRules.validateHindi(_categoryTextControllerHi.text);
    if (hiError != null) return hiError;

    final hnError =
        CategoryNameRules.validateHinglish(_categoryTextControllerHn.text);
    if (hnError != null) return hnError;

    final slugError = CategoryNameRules.validateSlug(
      _slugController.text,
      taken: _takenSlugs,
    );
    if (slugError != null) return slugError;

    if (_sortOrderController.text.trim().isNotEmpty &&
        int.tryParse(_sortOrderController.text.trim()) == null) {
      return 'Sort order must be a whole number';
    }

    // Depth is capped at 3 by a check constraint. Refusing here means the operator
    // gets a sentence rather than a Postgres error.
    final parent = _parentId == null ? null : _byId[_parentId];
    if (parent != null && parent.level >= 3) {
      return 'Categories cannot be more than three levels deep';
    }
    return null;
  }

  Future<void> _uploadCategory() async {
    final problem = _validateForm();
    if (problem != null) {
      _showSnackBar(problem, AppColors.warningColor);
      return;
    }

    setState(() => _isLoadingForm = true);

    try {
      // Upload first (if a new image was picked) and store the returned PATH.
      String? imagePath;
      if (_imageDataBytes != null) {
        imagePath = await AdminApi.uploadImage(_imageDataBytes!);
      }

      // Level is derived, never typed: a child sits exactly one below its parent, and
      // the depth trigger rejects anything else.
      final parent = _parentId == null ? null : _byId[_parentId];
      final level = parent == null ? 1 : parent.level + 1;

      final values = {
        "name": _categoryTextController.text.trim(),
        "name_hi": _categoryTextControllerHi.text.trim(),
        "name_hn": _categoryTextControllerHn.text.trim(),
        "parent_id": _parentId,
        "level": level,
        "slug": _slugController.text.trim(),
        "sort_order": int.tryParse(_sortOrderController.text.trim()) ??
            _nextSortOrderUnder(_parentId),
        "is_active": _isActive,
        if (imagePath != null) "image": imagePath,
        if (imagePath != null) "icon_url": imagePath,
      };

      if (_selectedCategoryIdForEdit == null) {
        await AdminApi.insert(AdminTables.mainCategory, values);
      } else {
        await AdminApi.update(
          AdminTables.mainCategory,
          _selectedCategoryIdForEdit!,
          values,
        );
      }

      if (!mounted) return;
      setState(() => _isLoadingForm = false);

      {
        _showSnackBar(
          "Category ${_selectedCategoryIdForEdit == null ? 'Added' : 'Updated'} Successfully! ✅",
          AppColors.successColor,
        );
        _resetForm();
        _fetchCategories();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingForm = false);
      _showSnackBar(
        e is AdminApiException ? e.message : "Network error: $e",
        AppColors.errorColor,
      );
    }
  }

  Future<void> _deleteCategory(String id) async {
    setState(() => _isLoadingList = true);
    try {
      await AdminApi.delete(AdminTables.mainCategory, id);
      if (!mounted) return;
      _showSnackBar("Category deleted successfully", AppColors.successColor);
      await _fetchCategories();
    } catch (e) {
      _showSnackBar("Deletion error: $e", AppColors.errorColor);
    } finally {
      setState(() => _isLoadingList = false);
    }
  }

  Future<void> _getImage() async {
    final Uint8List? bytesFromPicker = await ImagePickerWeb.getImageAsBytes();

    if (bytesFromPicker != null) {
      // 100 KB = 102400 bytes
      if (bytesFromPicker.lengthInBytes <= 102400) {
        setState(() {
          _imageDataBytes = bytesFromPicker;
          _imageFileName =
              "category_image_${DateTime.now().millisecondsSinceEpoch}.png";
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please select an image smaller than 100 KB")),
        );
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Next free slot among a parent's children, so a new category lands at the end
  /// rather than colliding with a sibling's sort_order — two siblings sharing one is
  /// an arbitrary display order, which is the bug the column exists to prevent.
  int _nextSortOrderUnder(int? parentId) {
    final siblings = parentId == null
        ? _tree
        : (_byId[parentId]?.children ?? const <AdminCategory>[]);
    if (siblings.isEmpty) return 1;
    return siblings.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
  }

  void _resetForm() {
    _categoryTextController.clear();
    _categoryTextControllerHi.clear();
    _categoryTextControllerHn.clear();
    _slugController.clear();
    _sortOrderController.clear();
    setState(() {
      _imageDataBytes = null;
      _imageFileName = null;
      _selectedCategoryIdForEdit = null;
      _initialCategoryName = null;
      _initialCategoryImage = null;
      _parentId = null;
      _isActive = true;
      _slugTouched = false;
    });
  }

  void _startEdit(Map<String, dynamic> category) {
    setState(() {
      _selectedCategoryIdForEdit = category['id'].toString();
      _initialCategoryName = category['name'];
      _initialCategoryImage = category['image'];
      _categoryTextController.text = category['name'] ?? '';
      _categoryTextControllerHi.text = category['name_hi'] ?? '';
      _categoryTextControllerHn.text = category['name_hn'] ?? '';
      _slugController.text = category['slug']?.toString() ?? '';
      _sortOrderController.text = category['sort_order']?.toString() ?? '';
      _parentId = (category['parent_id'] as num?)?.toInt();
      _isActive = category['is_active'] as bool? ?? true;
      // An existing slug is a stable handle; never let it track a rename.
      _slugTouched = true;
    });
  }

  void _showDeleteDialog(String categoryId) {
    // Deleting a category is the one genuinely destructive action on this screen.
    // `products.main_category_id` cascades, so deleting a stocked category deletes
    // every product on it — and each product cascades again to its variants, images,
    // info, highlights and hand-built Hindi voice aliases. Retiring is the answer
    // almost every time, so the dialog offers that instead of just warning.
    final id = int.tryParse(categoryId);
    final node = id == null ? null : _byId[id];
    if (node != null && node.children.isNotEmpty) {
      _showSnackBar(
        'Move or delete its ${node.children.length} sub-categories first.',
        AppColors.warningColor,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Delete this category?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Any products filed here will be deleted with it, along with their "
          "variants, images and voice aliases. This cannot be undone.\n\n"
          "To take it out of the app without losing anything, turn off "
          "\"Visible in the app\" instead.",
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(
              "Delete",
              style: GoogleFonts.poppins(color: AppColors.errorColor),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteCategory(categoryId);
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      );

  Widget _buildCategoryForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedCategoryIdForEdit == null
                ? "Add New Category"
                : "Edit Category",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _categoryTextController,
            decoration: InputDecoration(
              labelText: "Category Name (English)",
              labelStyle: GoogleFonts.poppins(
                color: AppColors.secondaryTextColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _autoTranslateCategory,
                icon: const Icon(
                  Icons.translate,
                  size: 16,
                  color: AppColors.primaryColor,
                ),
                label: Text(
                  "Auto-Translate",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _categoryTextControllerHi,
            decoration: InputDecoration(
              labelText: "Category Name (Hindi)",
              labelStyle: GoogleFonts.poppins(
                color: AppColors.secondaryTextColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _categoryTextControllerHn,
            decoration: InputDecoration(
              labelText: "Category Name (Hinglish)",
              labelStyle: GoogleFonts.poppins(
                color: AppColors.secondaryTextColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- Placement in the tree --------------------------------------
          DropdownButtonFormField<int?>(
            value: _parentId,
            isExpanded: true,
            decoration: _fieldDecoration('Parent'),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(
                  'None — this is a top-level section',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryTextColor,
                  ),
                ),
              ),
              for (final c in _parentOptions)
                DropdownMenuItem<int?>(
                  value: c.id,
                  child: Text(
                    c.level == 1 ? c.name : '    ${c.name}',
                    style: GoogleFonts.poppins(
                      color: c.isActive
                          ? AppColors.primaryTextColor
                          : AppColors.secondaryTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _parentId = v),
          ),
          const SizedBox(height: 8),
          Text(
            _parentId == null
                ? 'Top-level sections group the shelves beneath them. Products are '
                    'never filed directly on one.'
                : 'Products can be filed here once it has no sub-categories of its own.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _slugController,
                  onChanged: (_) => _slugTouched = true,
                  decoration: _fieldDecoration('Slug').copyWith(
                    helperText: 'Stable handle. Avoid changing it later.',
                    helperStyle: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.secondaryTextColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _sortOrderController,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecoration('Sort order').copyWith(
                    hintText: 'auto',
                    hintStyle: GoogleFonts.poppins(
                      color: AppColors.secondaryTextColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isActive,
            activeColor: AppColors.primaryColor,
            title: Text(
              'Visible in the app',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: AppColors.primaryTextColor,
              ),
            ),
            subtitle: Text(
              // The single visibility switch. Before it existed the home screen hid
              // Electronics by substring-matching its English name in Dart.
              'Turn off to retire a category without deleting it. Deleting one '
              'would take its products with it.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.secondaryTextColor,
              ),
            ),
            onChanged: (v) => setState(() => _isActive = v),
          ),

          const SizedBox(height: 24),
          Text(
            "Category Image",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _getImage,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                color: Colors.grey[50],
              ),
              child: _imageDataBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_imageDataBytes!, fit: BoxFit.cover),
                    )
                  : (_selectedCategoryIdForEdit != null &&
                            _initialCategoryImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              Db.imageUrl(_initialCategoryImage),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildPlaceholder(),
                            ),
                          )
                        : _buildPlaceholder()),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _isLoadingForm
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _uploadCategory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _selectedCategoryIdForEdit == null
                              ? "Add Category"
                              : "Update Category",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.surfaceColor,
                          ),
                        ),
                      ),
              ),
              if (_selectedCategoryIdForEdit != null) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _resetForm,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: AppColors.secondaryTextColor),
                  ),
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.poppins(
                      color: AppColors.secondaryTextColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            "Tap to select image 1:1",
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            "JPG, PNG (Max 100KB)",
            style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
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
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search categories...",
          hintStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: AppColors.primaryColor),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, color: AppColors.secondaryTextColor),
            onPressed: () {
              _searchController.clear();
              _filterCategories();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: category['image'] != null
                ? Image.network(
                    Db.imageUrl(category['image'] as String?),
                    fit: BoxFit.cover,
                  )
                : Icon(Icons.category, color: AppColors.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category['name'] ?? "Unnamed",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: AppColors.primaryColor),
            onPressed: () => _startEdit(category),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: Icon(Icons.delete, color: AppColors.errorColor),
            onPressed: () => _showDeleteDialog(category['id']),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    if (_isLoadingList) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (_filteredCategoryList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.secondaryTextColor,
            ),
            const SizedBox(height: 16),
            Text(
              "No Categories Found",
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: AppColors.secondaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try a different search term",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.secondaryTextColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 16),
      itemCount: _filteredCategoryList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final category = _filteredCategoryList[index];
        return _buildCategoryCard(category);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Main Category Management",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Category List",
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                      Text(
                        "${_filteredCategoryList.length} Items",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: AppColors.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildCategoryList()),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: _buildCategoryForm(),
            ),
          ),
        ],
      ),
    );
  }
}
