import '../core/supabase.dart';
import 'models.dart';

/// Addresses and orders.
///
/// Replaces `delivery_address/*` and `place_order/*`.
class AddressRepository {
  const AddressRepository();

  String get _uid {
    final id = Db.currentUserId;
    if (id == null) throw DataException('Please sign in first.');
    return id;
  }

  Future<List<Address>> list() async {
    final rows = await Db.client
        .from('delivery_address')
        .select('id, name, phone, full_address, pin_code, landmark')
        .order('id', ascending: false);
    return rows.map((r) => Address.fromMap(r)).toList();
  }

  Future<Address> add(Address a) async {
    final row = await Db.client
        .from('delivery_address')
        .insert({...a.toInsert(), 'user_id': _uid})
        .select()
        .single();
    return Address.fromMap(row);
  }

  Future<void> update(int id, Address a) async {
    // No manual ownership check: the UPDATE policy's USING clause makes another user's
    // row invisible, so this simply affects zero rows rather than the wrong one.
    await Db.client.from('delivery_address').update(a.toInsert()).eq('id', id);
  }

  Future<void> remove(int id) async {
    await Db.client.from('delivery_address').delete().eq('id', id);
  }
}

class OrderRepository {
  const OrderRepository();

  static const String _orderGraph = '''
    id, total_amount, discount_amount, delivery_charge, handling_charge, final_amount,
    status, payment_method, order_datetime, delivery_date, delivery_time_window,
    coupon_code,
    order_items(quantity, unit_price, image_url, products(name, name_hi))
  ''';

  Future<List<Order>> history() async {
    final rows = await Db.client
        .from('orders')
        .select(_orderGraph)
        .order('order_datetime', ascending: false);
    return rows.map((r) => Order.fromMap(r)).toList();
  }

  Future<Order?> byId(int id) async {
    final row = await Db.client
        .from('orders')
        .select(_orderGraph)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Order.fromMap(row);
  }

  /// Places an order from the current cart.
  ///
  /// Note what is NOT sent: no amounts. The `orders` table has no INSERT policy for
  /// clients at all, and the place-order Edge Function recomputes the subtotal, discount,
  /// delivery and handling charges from the catalog. The old endpoint accepted
  /// `final_amount` from the request body, so a client could name its own price.
  ///
  /// Returns the server's authoritative totals.
  Future<Order> place({
    required int deliveryAddressId,
    DateTime? deliveryDate,
    String? deliveryTimeWindow,
    String paymentMethod = 'COD',
    String? couponCode,
    String? gift,
  }) async {
    final res = await Db.client.functions.invoke('place-order', body: {
      'delivery_address_id': deliveryAddressId,
      'delivery_date': deliveryDate?.toIso8601String().split('T').first,
      'delivery_time_window': deliveryTimeWindow,
      'payment_method': paymentMethod,
      'coupon_code': couponCode,
      'gift': gift,
    });

    final data = res.data;
    if (data is! Map || data['success'] != true) {
      throw DataException(
        (data is Map ? data['message'] as String? : null) ??
            'Could not place the order.',
      );
    }

    final order = await byId(data['order_id'] as int);
    if (order == null) throw DataException('Order placed but could not be loaded.');
    return order;
  }

  /// The user's repeat-order suggestions. Read-only by design: `regular_orders` has no
  /// write policy, so the "your usual" list cannot be forged from a client.
  Future<List<Map<String, dynamic>>> regulars({int limit = 5}) async =>
      await Db.client
          .from('regular_orders')
          .select(
            'product_id, variant_id, frequency_score, last_ordered, products(name, name_hi)',
          )
          .order('frequency_score', ascending: false)
          .limit(limit);
}
