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
      throw AdminApiException(_messageFrom(e.details) ?? _statusText(e.status),
          status: e.status);
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
    final variants = await AdminApi.list(AdminTables.productVariants, limit: 500);
    final images = await AdminApi.list(AdminTables.productImages, limit: 500);

    final variantsByProduct = <String, List<Map<String, dynamic>>>{};
    for (final v in variants) {
      (variantsByProduct[v['product_id'].toString()] ??= []).add(v);
    }
    final imagesByProduct = <String, List<String>>{};
    for (final i in images) {
      (imagesByProduct[i['product_id'].toString()] ??= [])
          .add((i['image_url'] ?? '').toString());
    }

    return products.map((p) {
      final id = p['id'].toString();
      return {
        ...p,
        'variants': variantsByProduct[id] ?? const [],
        'images': imagesByProduct[id] ?? const [],
      };
    }).toList();
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
        if (r['key'] != null) r['key'].toString(): (r['value'] ?? '').toString(),
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
}
