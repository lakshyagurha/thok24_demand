import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/admin_api.dart';
import '../utils/colors.dart';

/// The shape of the catalogue, as one screen.
///
/// The category form edits one row at a time and cannot show what the operator
/// actually needs to see: which sections exist, what order they appear in, which
/// shelves are empty, and which are hidden from the app. Without that, the taxonomy
/// rots — a shelf gets added twice under different names, a section drifts to the
/// bottom of the app because nobody set its sort order, a retired category quietly
/// keeps its products.
///
/// So this is a read-and-arrange screen: expand a section, drag its shelves into
/// order, toggle what the app shows, and see stock and warnings per node. Everything
/// that changes a *name* still happens in the form, deliberately — this screen cannot
/// rename anything, so it cannot be the thing that breaks a slug.
class CategoryTreeScreen extends StatefulWidget {
  const CategoryTreeScreen({super.key});

  @override
  State<CategoryTreeScreen> createState() => _CategoryTreeScreenState();
}

class _CategoryTreeScreenState extends State<CategoryTreeScreen> {
  List<AdminCategory> _tree = [];
  Map<int, int> _stock = {};
  bool _isLoading = true;
  String? _error;
  final Set<int> _expanded = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final tree = await AdminCatalog.categoryTree();
      // Best-effort: the tree is still usable without the health view, so a failure
      // here costs badges rather than the screen.
      Map<int, int> stock = {};
      try {
        stock = await AdminCatalog.categoryHealth();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _tree = tree;
        _stock = stock;
        _isLoading = false;
        if (_expanded.isEmpty) {
          // Open the sections that hold something, so the screen opens on the part
          // of the catalogue that is actually live.
          for (final u in tree) {
            if (_subtreeStock(u) > 0) _expanded.add(u.id);
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e is AdminApiException ? e.message : '$e';
      });
    }
  }

  int _subtreeStock(AdminCategory c) =>
      (_stock[c.id] ?? 0) +
      c.descendants.fold<int>(0, (s, k) => s + (_stock[k.id] ?? 0));

  void _toast(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Persists a new sibling order in one call.
  ///
  /// Moving one shelf renumbers every sibling below it, so this is `reorder` rather
  /// than N updates: one round trip, and no half-ordered tree if something fails
  /// partway.
  Future<void> _persistOrder(List<AdminCategory> siblings) async {
    setState(() => _isSaving = true);
    try {
      final payload = [
        for (var i = 0; i < siblings.length; i++)
          (id: siblings[i].id, sortOrder: i + 1),
      ];
      await AdminApi.reorderCategories(payload);
      if (!mounted) return;
      _toast('Order saved', AppColors.successColor);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast(
        e is AdminApiException ? e.message : 'Could not save order: $e',
        AppColors.errorColor,
      );
      // Reload so the screen shows what the database actually holds rather than the
      // order the drag implied.
      await _load();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _setActive(AdminCategory node, bool active) async {
    setState(() => _isSaving = true);
    try {
      await AdminApi.update(AdminTables.mainCategory, node.id, {
        'is_active': active,
      });
      if (!mounted) return;
      _toast(
        active
            ? '${node.name} is visible in the app'
            : '${node.name} is hidden from the app',
        AppColors.successColor,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast(
        e is AdminApiException ? e.message : 'Could not update: $e',
        AppColors.errorColor,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 16),
            if (_isSaving) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final sections = _tree.length;
    final shelves = _tree.fold<int>(0, (s, u) => s + u.descendants.length);
    final empty = [
      for (final u in _tree) ...u.descendants,
    ].where((c) => _subtreeStock(c) == 0 && c.isActive).length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Category Tree',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isLoading
                    ? 'Loading…'
                    : '$sections sections · $shelves shelves · $empty empty',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _isLoading ? null : _load,
          icon: const Icon(Icons.refresh, color: AppColors.primaryColor),
        ),
      ],
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: AppColors.errorColor),
            const SizedBox(height: 12),
            Text(_error!, style: GoogleFonts.poppins()),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_tree.isEmpty) {
      return Center(
        child: Text('No categories yet.', style: GoogleFonts.poppins()),
      );
    }

    return ListView(
      children: [
        for (final umbrella in _tree) _umbrellaCard(umbrella),
        const SizedBox(height: 24),
        _rulesCard(),
      ],
    );
  }

  Widget _umbrellaCard(AdminCategory umbrella) {
    final open = _expanded.contains(umbrella.id);
    final stock = _subtreeStock(umbrella);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              open ? _expanded.remove(umbrella.id) : _expanded.add(umbrella.id);
            }),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.secondaryTextColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          umbrella.name,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: umbrella.isActive
                                ? AppColors.primaryTextColor
                                : AppColors.secondaryTextColor,
                          ),
                        ),
                        Text(
                          '${umbrella.nameHi ?? ''}  ·  ${umbrella.children.length} shelves',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _stockChip(stock),
                  const SizedBox(width: 8),
                  ..._warningChips(umbrella),
                  Switch(
                    value: umbrella.isActive,
                    activeColor: AppColors.primaryColor,
                    onChanged: _isSaving
                        ? null
                        : (v) => _setActive(umbrella, v),
                  ),
                ],
              ),
            ),
          ),
          if (open) ...[
            const Divider(height: 1),
            if (umbrella.children.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No shelves under this section yet.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.secondaryTextColor,
                  ),
                ),
              )
            else
              _shelfList(umbrella),
          ],
        ],
      ),
    );
  }

  Widget _shelfList(AdminCategory umbrella) {
    final shelves = List<AdminCategory>.from(umbrella.children);
    return ReorderableListView.builder(
      shrinkWrap: true,
      buildDefaultDragHandles: false,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: shelves.length,
      onReorder: (oldIndex, newIndex) {
        if (_isSaving) return;
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final moved = shelves.removeAt(oldIndex);
          shelves.insert(newIndex, moved);
        });
        _persistOrder(shelves);
      },
      itemBuilder: (context, i) {
        final shelf = shelves[i];
        final stock = _subtreeStock(shelf);
        return Padding(
          key: ValueKey(shelf.id),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: i,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 18,
                    color: AppColors.secondaryTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shelf.name,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: shelf.isActive
                            ? AppColors.primaryTextColor
                            : AppColors.secondaryTextColor,
                      ),
                    ),
                    Text(
                      shelf.slug ?? '—',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              _stockChip(stock),
              const SizedBox(width: 8),
              ..._warningChips(shelf),
              Switch(
                value: shelf.isActive,
                activeColor: AppColors.primaryColor,
                onChanged: _isSaving ? null : (v) => _setActive(shelf, v),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stockChip(int stock) {
    final none = stock == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: none
            ? AppColors.backgroundColor
            : AppColors.primaryColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        none ? 'empty' : '$stock',
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: none ? AppColors.secondaryTextColor : AppColors.primaryColor,
        ),
      ),
    );
  }

  /// The rules the taxonomy is held to, surfaced where they are broken rather than
  /// only in a document nobody opens.
  List<Widget> _warningChips(AdminCategory c) {
    final warnings = <String>[
      if (c.name.length > CategoryNameRules.maxLength) 'long name',
      if ('&'.allMatches(c.name).length > 1) 'two &',
      if ((c.nameHi ?? '').isEmpty) 'no Hindi',
      if ((c.nameHn ?? '').isEmpty) 'no Hinglish',
      if ((c.slug ?? '').isEmpty) 'no slug',
      // A node holding both products and children is the one thing the level >= 2
      // trigger deliberately does not block, because blocking it would deadlock
      // adding a sub-shelf under a stocked shelf. It is reported instead.
      if (!c.isLeaf && (_stock[c.id] ?? 0) > 0) 'products + sub-categories',
    ];
    if (warnings.isEmpty) return const [];
    return [
      Tooltip(
        message: warnings.join(', '),
        child: const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.warningColor,
          ),
        ),
      ),
    ];
  }

  Widget _rulesCard() {
    const rules = [
      'Every product belongs to exactly one shelf. If you cannot decide, park it on '
          'Uncategorised — that is a work queue, not a shelf, and never shows in the app.',
      'Do not create a category for a single product. Add a sub-shelf only once one '
          'shelf passes roughly 40 items.',
      'Seasonal ranges (Diwali, Summer) are tags on the product, or an existing '
          'section switched on for the season. Never a new permanent category.',
      'To stop selling something, switch it off. Deleting a category deletes its '
          'products, their variants, images and voice aliases with it.',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keeping the tree healthy',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          for (final r in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(
                    child: Text(
                      r,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.secondaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
