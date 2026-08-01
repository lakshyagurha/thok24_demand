import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// The single data path for the admin app.
///
/// Every admin read and write goes through the `admin-api` Edge Function. The admin
/// app deliberately does NOT query Supabase tables directly:
///
///  * catalog tables have no write policy for any client role, so a direct write is
///    impossible by design — the function holds the service-role key server-side;
///  * the function checks the caller against a private `admin_users` table, so staff
///    membership is not something a client can claim for itself.
///
/// Two rules follow from that and must not be relaxed:
///  1. the service-role key never appears in this app;
///  2. no method here takes a caller id. Identity is the JWT that `functions.invoke`
///     attaches from the current session — which is exactly what the old PHP backend
///     got wrong when it trusted a `user_id` from the request body.
class AdminApi {
  const AdminApi._();

  static const String _function = 'admin-api';

  static SupabaseClient get _client => Supabase.instance.client;

  /// Reads rows from [table]. [filters] are equality matches only, which is all the
  /// Edge Function exposes. The function caps [limit] at 500.
  static Future<List<Map<String, dynamic>>> list(
    String table, {
    Map<String, dynamic>? filters,
    int limit = 100,
    int offset = 0,
  }) async {
    final body = await _invoke({
      'action': 'list',
      'table': table,
      if (filters != null && filters.isNotEmpty) 'filters': filters,
      'limit': limit,
      'offset': offset,
    });
    final rows = body['data'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  /// Convenience for the many screens that only ever want one row back.
  static Future<Map<String, dynamic>?> first(
    String table, {
    Map<String, dynamic>? filters,
  }) async {
    final rows = await list(table, filters: filters, limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  static Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> values,
  ) async {
    final body = await _invoke({
      'action': 'insert',
      'table': table,
      'values': values,
    });
    return _row(body);
  }

  static Future<Map<String, dynamic>> update(
    String table,
    Object id,
    Map<String, dynamic> values,
  ) async {
    final body = await _invoke({
      'action': 'update',
      'table': table,
      'id': id,
      'values': values,
    });
    return _row(body);
  }

  static Future<void> delete(String table, Object id) async {
    await _invoke({'action': 'delete', 'table': table, 'id': id});
  }

  /// Upserts an app_settings row by its text key. app_settings has no `id` column, so
  /// [update] cannot address it -- this is the action to use for settings.
  static Future<Map<String, dynamic>> setSetting(
    String key,
    String value,
  ) async {
    final body = await _invoke({
      'action': 'set_setting',
      'key': key,
      'value': value,
    });
    return _row(body);
  }

  /// Uploads an image and returns its STORED PATH (e.g. `uploads/<uuid>.jpg`).
  ///
  /// The bucket has no client write policy: a signed-in customer must not be able to
  /// push files into the store's bucket, so uploads go through the function where staff
  /// membership is already established. Store the returned path on the row and resolve
  /// it with `Db.imageUrl()` at render time -- never store a full URL.
  static Future<String> uploadImage(
    List<int> bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final body = await _invoke({
      'action': 'upload_image',
      'value': base64Encode(bytes),
      'status': contentType,
    });
    return _row(body)['path']?.toString() ?? '';
  }

  /// Blocks or unblocks a customer. `user_profiles` is not generally writable -- ops
  /// should not be able to rewrite arbitrary columns on someone's profile -- so status
  /// has its own narrow action.
  static Future<Map<String, dynamic>> setUserStatus(
    Object userId,
    String status,
  ) async {
    final body = await _invoke({
      'action': 'set_user_status',
      'id': userId,
      'status': status,
    });
    return _row(body);
  }

  /// Orders are otherwise immutable: status is the only field ops may move, and only
  /// to one of [AdminTables.orderStatuses].
  static Future<Map<String, dynamic>> setOrderStatus(
    Object orderId,
    String status,
  ) async {
    final body = await _invoke({
      'action': 'order_status',
      'order_id': orderId,
      'status': status,
    });
    return _row(body);
  }

  /// Writes a new `sort_order` for several categories in one call.
  ///
  /// Reordering one shelf renumbers every sibling below it. As individual [update]
  /// calls that is N round trips, and a failure halfway leaves the tree visibly
  /// half-ordered. The function's `reorder` action is deliberately narrower than
  /// `update`: it writes one integer column on `main_category` only, so a reorder
  /// cannot be steered into editing a name or a price.
  static Future<int> reorderCategories(
    List<({int id, int sortOrder})> order,
  ) async {
    if (order.isEmpty) return 0;
    final body = await _invoke({
      'action': 'reorder',
      'order': [
        for (final e in order) {'id': e.id, 'sort_order': e.sortOrder},
      ],
    });
    return (_row(body)['updated'] as num?)?.toInt() ?? 0;
  }

  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _row(Map<String, dynamic> body) {
    final data = body['data'];
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    if (_client.auth.currentSession == null) {
      throw const AdminApiException('Not signed in', status: 401);
    }

    late final FunctionResponse res;
    try {
      // invoke() attaches the current session's access token; the function rejects
      // anything else with 401, and a signed-in non-staff user with 403.
      res = await _client.functions.invoke(_function, body: body);
    } on FunctionException catch (e) {
      throw AdminApiException(
        _messageFrom(e.details) ?? _statusText(e.status),
        status: e.status,
      );
    } catch (e) {
      throw AdminApiException('Network error: $e');
    }

    final data = res.data;
    if (data is! Map) {
      throw AdminApiException(_statusText(res.status), status: res.status);
    }
    final decoded = Map<String, dynamic>.from(data);
    if (decoded['success'] != true) {
      throw AdminApiException(
        decoded['message']?.toString() ?? 'Request failed',
        status: res.status,
      );
    }
    return decoded;
  }

  static String? _messageFrom(dynamic details) {
    if (details is Map && details['message'] != null) {
      return details['message'].toString();
    }
    return null;
  }

  static String _statusText(int status) {
    switch (status) {
      case 401:
        return 'Session expired. Please sign in again.';
      case 403:
        return 'This account is not an admin.';
      default:
        return 'Request failed ($status)';
    }
  }
}

/// Thrown for anything worth showing an operator. [status] mirrors the HTTP status
/// so callers can single out 401/403 without string matching.
class AdminApiException implements Exception {
  const AdminApiException(this.message, {this.status});

  final String message;
  final int? status;

  bool get isAuthFailure => status == 401 || status == 403;

  @override
  String toString() => message;
}

/// Table names the Edge Function will accept, and the order statuses it validates.
/// Kept here so a typo is a compile error rather than a 400 at runtime.
class AdminTables {
  const AdminTables._();

  // Writable.
  static const String products = 'products';
  static const String productVariants = 'product_variants';
  static const String productImages = 'product_images';
  static const String productInfo = 'product_info';
  static const String productHighlights = 'product_highlights';
  static const String productAliases = 'product_aliases';
  static const String mainCategory = 'main_category';
  static const String banner = 'banner';
  static const String coupon = 'coupon';
  static const String city = 'city';
  static const String district = 'district';
  static const String appSettings = 'app_settings';
  static const String deliveryBoy = 'delivery_boy';

  // Read-only.
  static const String orders = 'orders';
  static const String orderItems = 'order_items';
  static const String userProfiles = 'user_profiles';
  static const String deliveryAddress = 'delivery_address';

  /// Per-category data-quality report: stock, leaf-ness and naming-rule violations.
  /// Backs the warning badges on the category tree screen.
  static const String categoryHealth = 'v_category_health';

  static const List<String> orderStatuses = [
    'pending',
    'packed',
    'way',
    'delivered',
    'cancelled',
  ];
}

/// Catalog reads that need more than one table stitched together.
///
/// The Edge Function's `list` action returns flat rows from a single table, which is
/// deliberate -- it keeps the surface small and auditable. The screens that show a
/// product with its variants and images therefore assemble the shape here, client-side,
/// rather than the function growing a bespoke join per screen.
class AdminCatalog {
  const AdminCatalog._();

  /// Products with their variants and image paths nested, matching the shape the
  /// product and stock screens already render.
  static Future<List<Map<String, dynamic>>> productsWithDetail({
    int limit = 100,
    int offset = 0,
  }) async {
    final products = await AdminApi.list(
      AdminTables.products,
      limit: limit,
      offset: offset,
    );
    if (products.isEmpty) return const [];

    // Two extra reads rather than N: fetch the full child sets once and group in memory.
    final variants = await AdminApi.list(
      AdminTables.productVariants,
      limit: 500,
    );
    final images = await AdminApi.list(AdminTables.productImages, limit: 500);

    final variantsByProduct = <String, List<Map<String, dynamic>>>{};
    for (final v in variants) {
      (variantsByProduct[v['product_id'].toString()] ??= []).add(v);
    }
    final imagesByProduct = <String, List<String>>{};
    for (final i in images) {
      (imagesByProduct[i['product_id'].toString()] ??= []).add(
        (i['image_url'] ?? '').toString(),
      );
    }

    // The category name, which the list has always tried to render.
    //
    // `product_management_screen.dart` did `'C : ' + product['main_category_name']`
    // against a key nothing populated, so the product list threw on its first row.
    // The name is joined here rather than patched at the call site because the stock
    // screen wants the same thing.
    final categories = await categoryRows();
    final nameById = {
      for (final c in categories) c['id'].toString(): (c['name'] ?? '').toString(),
    };
    final parentById = {
      for (final c in categories)
        c['id'].toString(): c['parent_id']?.toString(),
    };

    return products.map((p) {
      final id = p['id'].toString();
      final categoryId = p['main_category_id']?.toString();
      final parentId = categoryId == null ? null : parentById[categoryId];
      return {
        ...p,
        'variants': variantsByProduct[id] ?? const [],
        'images': imagesByProduct[id] ?? const [],
        // Never null: an unresolvable id must show as such, not crash the row.
        'main_category_name': nameById[categoryId] ?? 'Uncategorised',
        'umbrella_id': parentId,
        'umbrella_name': parentId == null ? '' : (nameById[parentId] ?? ''),
      };
    }).toList();
  }

  /// Every category row, including inactive ones.
  ///
  /// The admin sees the whole table on purpose — retired and staging categories are
  /// exactly what an operator needs to be able to find. The consumer app calls
  /// `category_tree()` instead, which filters them out.
  static Future<List<Map<String, dynamic>>> categoryRows() =>
      AdminApi.list(AdminTables.mainCategory, limit: 500);

  /// The category table assembled into a tree, umbrellas first, each sorted by
  /// `sort_order` then name.
  ///
  /// Built from the flat `list` rather than from the `category_tree()` RPC because the
  /// admin needs the inactive nodes the RPC deliberately drops.
  static Future<List<AdminCategory>> categoryTree() async {
    final rows = await categoryRows();
    final all = rows.map(AdminCategory.fromMap).toList();
    final byId = {for (final c in all) c.id: c};

    for (final c in all) {
      final parent = c.parentId == null ? null : byId[c.parentId];
      parent?.children.add(c);
    }
    int order(AdminCategory a, AdminCategory b) {
      final s = a.sortOrder.compareTo(b.sortOrder);
      return s != 0 ? s : a.name.compareTo(b.name);
    }

    for (final c in all) {
      c.children.sort(order);
    }
    final roots = all.where((c) => c.parentId == null).toList()..sort(order);
    return roots;
  }

  /// Active SKU count per category id, for the tree screen's badges.
  static Future<Map<int, int>> categoryHealth() async {
    final rows = await AdminApi.list(AdminTables.categoryHealth, limit: 500);
    return {
      for (final r in rows)
        (r['id'] as num).toInt(): (r['active_products'] as num?)?.toInt() ?? 0,
    };
  }
}

/// A category as the admin sees it: the whole row, inactive nodes included.
class AdminCategory {
  AdminCategory({
    required this.id,
    required this.name,
    this.nameHi,
    this.nameHn,
    this.parentId,
    this.slug,
    this.level = 2,
    this.sortOrder = 0,
    this.isActive = true,
    this.iconUrl,
    this.image,
  });

  final int id;
  final String name;
  final String? nameHi;
  final String? nameHn;
  final int? parentId;
  final String? slug;
  final int level;
  final int sortOrder;
  final bool isActive;
  final String? iconUrl;
  final String? image;

  final List<AdminCategory> children = [];

  bool get isUmbrella => level == 1;

  /// Only a node with no children may hold products.
  ///
  /// The database deliberately does not enforce this — doing so would deadlock the
  /// day someone adds a sub-shelf under a shelf that already has stock. It is enforced
  /// here, in the picker, which is where the choice is actually made.
  bool get isLeaf => children.isEmpty;

  /// Everything beneath this node, depth-first.
  List<AdminCategory> get descendants => [
        for (final c in children) ...[c, ...c.descendants],
      ];

  String get displayPath => name;

  factory AdminCategory.fromMap(Map<String, dynamic> m) => AdminCategory(
        id: (m['id'] as num).toInt(),
        name: (m['name'] ?? '').toString(),
        nameHi: m['name_hi']?.toString(),
        nameHn: m['name_hn']?.toString(),
        parentId: (m['parent_id'] as num?)?.toInt(),
        slug: m['slug']?.toString(),
        level: (m['level'] as num?)?.toInt() ?? 2,
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
        isActive: m['is_active'] as bool? ?? true,
        iconUrl: m['icon_url']?.toString(),
        image: m['image']?.toString(),
      );
}

/// The naming rules the taxonomy is held to, enforced in the form rather than only
/// written down in the plan.
///
/// Mirrors the assertions in `20260731000002_category_tree_seed.sql`: a name that fails
/// here would also fail the migration's own checks on the next replay.
class CategoryNameRules {
  const CategoryNameRules._();

  static const int maxLength = 22;

  /// Returns null when [name] is acceptable, or the reason it is not.
  static String? validateName(String name, {Iterable<String> takenLower = const []}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Name is required';
    if (trimmed.length > maxLength) {
      return 'Max $maxLength characters (currently ${trimmed.length})';
    }
    if ('&'.allMatches(trimmed).length > 1) {
      return 'Use at most one "&"';
    }
    if (takenLower.contains(trimmed.toLowerCase())) {
      return 'A category with this name already exists';
    }
    return null;
  }

  static String? validateHindi(String v) =>
      v.trim().isEmpty ? 'Hindi name is required' : null;

  static String? validateHinglish(String v) =>
      v.trim().isEmpty ? 'Hinglish name is required' : null;

  static String? validateSlug(String slug, {Iterable<String> taken = const []}) {
    final s = slug.trim();
    if (s.isEmpty) return 'Slug is required';
    if (!RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(s)) {
      return 'Lowercase letters, numbers and single hyphens only';
    }
    if (taken.contains(s)) return 'This slug is already used';
    return null;
  }

  /// `Atta, Rice & Dal` -> `atta-rice-dal`. Matches the slugs already seeded.
  static String slugify(String name) {
    final s = name
        .toLowerCase()
        .replaceAll('&', ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s;
  }
}

/// Keys used in `app_settings`, which the schema collapsed the old one-row-per-setting
/// PHP endpoints into.
class SettingKeys {
  const SettingKeys._();

  static const String deliveryCharge = 'delivery_charge';
  static const String freeDeliveryThreshold = 'free_delivery_threshold';
  static const String handlingCharge = 'handling_charge';
  static const String minimumOrderAmount = 'minimum_order_amount';
  static const String deliveryTime = 'delivery_time';
  static const String helpCall = 'help_call';
  static const String helpEmail = 'help_email';
  static const String helpWhatsapp = 'help_whatsapp';
}

/// Reads and writes for `app_settings`.
///
/// `app_settings` is keyed by `key` (text) and has no `id` column, so the generic
/// update action cannot address it. The Edge Function grew a dedicated `set_setting`
/// upsert for exactly this, which [set] uses — writing a key that has never been
/// stored works too.
class AdminSettings {
  const AdminSettings._();

  /// All settings as a flat key -> value map.
  static Future<Map<String, String>> all() async {
    final rows = await AdminApi.list(AdminTables.appSettings, limit: 100);
    return {
      for (final r in rows)
        if (r['key'] != null)
          r['key'].toString(): (r['value'] ?? '').toString(),
    };
  }

  static Future<String?> get(String key) async {
    final row = await AdminApi.first(
      AdminTables.appSettings,
      filters: {'key': key},
    );
    return row?['value']?.toString();
  }

  static Future<void> set(String key, String value) async {
    await AdminApi.setSetting(key, value);
  }

  /// Like [set] but reports failure instead of throwing, for call sites that already
  /// branch on success and show their own message.
  static Future<bool> trySet(String key, String value) async {
    try {
      await set(key, value);
      return true;
    } catch (_) {
      return false;
    }
  }
}
