import '../core/supabase.dart';
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

  Future<List<Category>> categories() async {
    final rows = await Db.client
        .from('main_category')
        .select('id, name, name_hi, name_hn, image')
        .order('id');
    return rows.map((r) => Category.fromMap(r)).toList();
  }

  Future<List<Product>> products({int limit = 100, int offset = 0}) async {
    final rows = await Db.client
        .from('products')
        .select(_productGraph)
        .order('id')
        .range(offset, offset + limit - 1);
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  /// Bounded on purpose. This had no `.limit()` at all, so opening a category pulled
  /// every product in it — each with all three description columns and its full variant
  /// and image graph — in one response, on a connection where that is the difference
  /// between usable and not. 40 is comfortably more than any current category holds;
  /// pass [offset] to page beyond it.
  Future<List<Product>> productsByCategory(
    int categoryId, {
    int limit = 40,
    int offset = 0,
  }) async {
    final rows = await Db.client
        .from('products')
        .select(_productGraph)
        .eq('main_category_id', categoryId)
        .order('id')
        .range(offset, offset + limit - 1);
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  Future<Product?> product(int id) async {
    final row = await Db.client
        .from('products')
        .select(_productGraph)
        .eq('id', id)
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
        .inFilter('id', ids);
    return byAlias.map((r) => Product.fromMap(r)).toList();
  }

  Future<List<Product>> similarProducts(int productId, int categoryId) async {
    final rows = await Db.client
        .from('products')
        .select(_productGraph)
        .eq('main_category_id', categoryId)
        .neq('id', productId)
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
