import 'dart:async';

// `show` on purpose: foundation also exports a `Category` annotation, which would
// otherwise shadow the model of the same name in every reference below.
import 'package:flutter/foundation.dart' show debugPrint;

import '../core/supabase.dart';
import 'category_cache.dart';
import 'models.dart';

/// Catalog reads: categories, products, variants, images, search, banners, coupons.
///
/// Replaces the whole `product_api_project/product/`, `main_category/` and `banner_api/`
/// endpoint set. Several of those built SQL by interpolation, including
/// `get_all_products.php`, `get_products_by_subcategory.php`, `search_hindi_keywords.php`,
/// `update_stock.php` and `update_type.php`.
///
/// Everything here is a read. The catalog has no write policy for any client role, so
/// catalog edits go through the admin Edge Function, not this app.
class CatalogRepository {
  const CatalogRepository();

  static const String _productGraph = '''
    id, name, name_hi, name_hn, description, description_hi, description_hn,
    main_category_id, types,
    product_images(image_url),
    product_variants(id, product_id, name, name_hi, name_hn, price, selling_price, stock)
  ''';

  /// The whole browsable tree — 6 umbrellas, each carrying its shelves — in one call.
  ///
  /// This replaces "fetch the flat category list, then open each category to find out
  /// whether it has anything in it". `product_count` arrives with the tree, so the
  /// Category tab can tell a stocked shelf from an empty one without a second request.
  ///
  /// Inactive nodes never appear: the RPC filters them, so `is_active` is the single
  /// visibility switch and there is nothing for the client to re-filter. The hardcoded
  /// "hide anything whose name contains 'electronic'" list on the home screen existed
  /// only because that switch did not exist yet.
  Future<List<Category>> categoryTree() async {
    final payload = await Db.client.rpc('category_tree');
    final tree = [
      for (final n in (payload as List? ?? const []))
        Category.fromTreeNode(Map<String, dynamic>.from(n as Map)),
    ];
    await CategoryCache.save(tree);
    return tree;
  }

  /// Stale-while-revalidate: hands back the cached tree immediately when there is one,
  /// then refreshes in the background and calls [onRefreshed] only if the tree actually
  /// changed. Falls through to a plain fetch on a cold install.
  ///
  /// Callers get a painted screen on the first frame; the network cost is paid off
  /// screen. [onRefreshed] fires at most once per call.
  Future<List<Category>> categoryTreeCached({
    void Function(List<Category> fresh)? onRefreshed,
  }) async {
    final cached = await CategoryCache.load();
    if (cached == null) return categoryTree();

    if (CategoryCache.isStale) {
      // Deliberately not awaited: a stale-but-usable tree is already being returned.
      unawaited(() async {
        try {
          final fresh = await categoryTree();
          if (onRefreshed != null && CategoryCache.differs(cached, fresh)) {
            onRefreshed(fresh);
          }
        } catch (e) {
          // Offline with a cached tree is a working app, not an error state.
          debugPrint('category tree refresh failed: $e');
        }
      }());
    }
    return cached;
  }

  /// Every active shelf, flat and in display order. For callers that want a list of
  /// places a product can live rather than the hierarchy — the admin-facing shape.
  Future<List<Category>> shelves() async {
    final tree = await categoryTreeCached();
    return [
      for (final umbrella in tree) ...umbrella.descendants,
    ];
  }

  /// The umbrella a shelf sits under, or null if [shelf] is itself an umbrella.
  static Category? umbrellaOf(List<Category> tree, int shelfId) {
    for (final u in tree) {
      if (u.id == shelfId) return null;
      if (u.descendants.any((c) => c.id == shelfId)) return u;
    }
    return null;
  }

  /// Finds any node in the tree by id, at any level.
  static Category? findInTree(List<Category> tree, int id) {
    for (final u in tree) {
      if (u.id == id) return u;
      for (final c in u.descendants) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  /// Category name matches for the search screen, so searching "dairy" offers the
  /// shelf and not only the products whose *name* happens to contain it.
  ///
  /// Matched in memory against the cached tree rather than over the network: the tree
  /// is already local, it is 40 rows, and a search screen should not wait on a round
  /// trip it does not need. All three name variants are matched, so "डेयरी" and
  /// "dairy" both find the same shelf.
  Future<List<Category>> searchCategories(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final tree = await categoryTreeCached();
    final hits = <Category>[];
    for (final umbrella in tree) {
      for (final node in [umbrella, ...umbrella.descendants]) {
        final matched = node.name.toLowerCase().contains(q) ||
            (node.nameHi ?? '').toLowerCase().contains(q) ||
            (node.nameHn ?? '').toLowerCase().contains(q);
        // An empty shelf is not a useful search result — it leads nowhere.
        if (matched && !node.isEmpty) hits.add(node);
      }
    }
    // Stocked shelves first, then umbrellas, so the most specific answer leads.
    hits.sort((a, b) {
      if (a.level != b.level) return b.level.compareTo(a.level);
      return b.productCount.compareTo(a.productCount);
    });
    return hits;
  }

  /// Flat list of active shelves. Kept for callers that predate the tree.
  ///
  /// Now filtered to `level = 2` and `is_active`: since the taxonomy landed, the raw
  /// table also holds 6 umbrellas and 4 hidden rows, and an unfiltered read would put
  /// "Unfiled" and two retired categories in front of a shopper.
  Future<List<Category>> categories() async {
    final rows = await Db.client
        .from('main_category')
        .select(
          'id, name, name_hi, name_hn, image, parent_id, slug, level, '
          'icon_url, sort_order, is_active',
        )
        .eq('level', 2)
        .eq('is_active', true)
        .order('sort_order');
    return rows.map((r) => Category.fromMap(r)).toList();
  }

  /// Withdrawn SKUs are excluded from every read below.
  ///
  /// `products.is_active` is a soft withdrawal — the row, its variants, images and
  /// hand-built Hindi voice aliases all stay, because deleting a product cascades and
  /// takes that vocabulary with it. Nothing filtered on it when the column landed, so
  /// a withdrawn product went on rendering everywhere: in its category, in search, in
  /// "similar products" and in the home rails.
  Future<List<Product>> products({int limit = 100, int offset = 0}) async {
    final rows = await Db.client
        .from('products')
        .select(_productGraph)
        .eq('is_active', true)
        .order('id')
        .range(offset, offset + limit - 1);
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  /// Bounded on purpose. This had no `.limit()` at all, so opening a category pulled
  /// every product in it — each with all three description columns and its full variant
  /// and image graph — in one response, on a connection where that is the difference
  /// between usable and not. 40 is comfortably more than any current category holds;
  /// pass [offset] to page beyond it.
  ///
  /// Pass [includeDescendants] to open an umbrella: products hang off shelves, never
  /// off an umbrella, so filtering on an umbrella's own id returns nothing. With it,
  /// the id set is resolved from the cached tree and matched with `in`, which keeps
  /// this one round trip.
  Future<List<Product>> productsByCategory(
    int categoryId, {
    int limit = 40,
    int offset = 0,
    bool includeDescendants = false,
  }) async {
    var q = Db.client.from('products').select(_productGraph);

    if (includeDescendants) {
      final tree = await categoryTreeCached();
      final node = findInTree(tree, categoryId);
      final ids = node == null
          ? [categoryId]
          : [node.id, ...node.descendants.map((c) => c.id)];
      q = q.inFilter('main_category_id', ids);
    } else {
      q = q.eq('main_category_id', categoryId);
    }

    final rows = await q
        .eq('is_active', true)
        .order('id')
        .range(offset, offset + limit - 1);
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  /// A withdrawn product resolves to null, so a stale link or an old wishlist row
  /// lands on "not found" rather than on a page that can still be added to a cart.
  Future<Product?> product(int id) async {
    final row = await Db.client
        .from('products')
        .select(_productGraph)
        .eq('id', id)
        .eq('is_active', true)
        .maybeSingle();
    return row == null ? null : Product.fromMap(row);
  }

  /// Products carrying a tag such as 'Best selling' or 'Everyday Essentials'.
  ///
  /// `types` is a comma-separated string in the source schema, so this filters on
  /// substring. A `text[]` column with a GIN index would be the idiomatic Postgres shape
  /// and is worth revisiting once the catalog is larger.
  /// Bounded for the same reason as [productsByCategory]. These feed horizontal
  /// carousels on the home screen — nobody scrolls 200 of them, and three of these run
  /// concurrently at launch.
  Future<List<Product>> productsByType(String type, {int limit = 20}) async {
    final rows = await Db.client
        .from('products')
        .select(_productGraph)
        .ilike('types', '%$type%')
        .eq('is_active', true)
        .order('id')
        .limit(limit);
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  /// Searches English, Devanagari and romanized Hinglish names together, plus the
  /// hand-built voice alias vocabulary. The PHP had a separate
  /// `search_hindi_keywords.php` for the Hindi case; one query covers both here.
  Future<List<Product>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    // `q` goes into a PostgREST filter *expression*, where a comma separates conditions
    // and parentheses group them. Interpolated raw, an ordinary query like "dal, chawal"
    // produced a malformed filter and a 400. Escaping the structural characters keeps
    // the search a search.
    final safe = q.replaceAll(RegExp(r'[,()\\]'), ' ').trim();
    if (safe.isEmpty) return const [];

    final rows = await Db.client
        .from('products')
        .select(_productGraph)
        .or('name.ilike.%$safe%,name_hi.ilike.%$safe%,name_hn.ilike.%$safe%')
        .eq('is_active', true)
        .limit(50);
    final results = rows.map((r) => Product.fromMap(r)).toList();
    if (results.isNotEmpty) return results;

    // Nothing matched by name; fall back to aliases so a spoken/colloquial term such as
    // "moong" still finds "Tata Sampann Unpolished Green Moong".
    final aliasRows = await Db.client
        .from('product_aliases')
        .select('product_id')
        .ilike('alias', '%$q%')
        .limit(20);
    final ids = aliasRows.map((r) => r['product_id'] as int).toSet().toList();
    if (ids.isEmpty) return const [];

    final byAlias = await Db.client
        .from('products')
        .select(_productGraph)
        .inFilter('id', ids)
        .eq('is_active', true);
    return byAlias.map((r) => Product.fromMap(r)).toList();
  }

  Future<List<Product>> similarProducts(int productId, int categoryId) async {
    final rows = await Db.client
        .from('products')
        .select(_productGraph)
        .eq('main_category_id', categoryId)
        .neq('id', productId)
        .eq('is_active', true)
        .limit(10);
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  Future<List<Map<String, dynamic>>> banners() async =>
      await Db.client.from('banner').select('id, category_id, banner_image');

  /// Only `status = 'Public'` coupons are visible — RLS hides private codes so they
  /// cannot be enumerated. A private code still redeems at checkout, where the
  /// place-order function validates it server-side.
  Future<List<Coupon>> publicCoupons() async {
    final rows = await Db.client
        .from('coupon')
        .select('id, title, description, code_name, discount, min_amount, expiry_date')
        .order('id');
    return rows.map((r) => Coupon.fromMap(r)).toList();
  }

  /// Delivery charges, minimum order value and the help contact numbers, which used to
  /// be nine separate single-row tables and nine endpoints.
  ///
  /// Memoized process-wide. These are a handful of global values that change about never,
  /// and they were being fetched **once per product card** — `ProductCard.initState`
  /// called this just to render the "10 MIN" delivery badge, so a 30-product grid issued
  /// 30 identical requests for the same row set, on top of one from the parent screen.
  /// Callers share one in-flight request and then the cached map.
  ///
  /// Pass [forceRefresh] from an explicit pull-to-refresh.
  Future<Map<String, String>> settings({bool forceRefresh = false}) {
    if (forceRefresh) _settingsCache = null;
    return _settingsCache ??= _loadSettings().catchError((Object e) {
      // Do not cache a failure: the next caller should get a real attempt, not a
      // permanently poisoned future.
      _settingsCache = null;
      throw e;
    });
  }

  static Future<Map<String, String>>? _settingsCache;

  Future<Map<String, String>> _loadSettings() async {
    final rows = await Db.client.from('app_settings').select('key, value');
    return {
      for (final r in rows) r['key'] as String: r['value'] as String,
    };
  }

  /// Drops the settings cache. Called on sign-out so nothing survives a user switch.
  static void invalidateSettings() => _settingsCache = null;
}
