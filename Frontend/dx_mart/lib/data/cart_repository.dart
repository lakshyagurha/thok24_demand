import '../core/supabase.dart';
import 'models.dart';

/// Cart and wishlist.
///
/// Replaces `product_api_project/cart/*` and `wishlist/*`. Every one of those endpoints
/// took `user_id` from the request, so changing the number in the request body returned
/// or modified somebody else's cart. None of these methods accept a user id: the row is
/// stamped with the session's user and RLS filters reads to that same user.
class CartRepository {
  const CartRepository();

  String get _uid {
    final id = Db.currentUserId;
    if (id == null) throw DataException('Please sign in first.');
    return id;
  }

  Future<List<CartLine>> items() async {
    // No .eq('user_id', ...): RLS already restricts this to the caller's rows.
    final rows = await Db.client.from('cart_items').select('''
          id, product_id, variant_id, quantity, image_url,
          products!inner(name),
          product_variants!inner(name, price, selling_price, stock)
        ''').order('id');
    return rows.map((r) => CartLine.fromMap(r)).toList();
  }

  Future<int> itemCount() async {
    final rows = await Db.client.from('cart_items').select('quantity');
    return rows.fold<int>(0, (sum, r) => sum + ((r['quantity'] ?? 0) as int));
  }

  Future<double> subtotal() async {
    final lines = await items();
    return lines.fold<double>(0, (sum, l) => sum + l.lineTotal);
  }

  /// Adds [quantity], or increments if the product/variant is already in the cart.
  Future<void> add({
    required int productId,
    required int? variantId,
    int quantity = 1,
    String imagePath = '',
  }) async {
    final existing = await Db.client
        .from('cart_items')
        .select('id, quantity')
        .eq('product_id', productId)
        .eq('variant_id', variantId as Object)
        .maybeSingle();

    if (existing != null) {
      await Db.client
          .from('cart_items')
          .update({'quantity': (existing['quantity'] as int) + quantity})
          .eq('id', existing['id'] as int);
      return;
    }

    await Db.client.from('cart_items').insert({
      // Stamped from the session. The INSERT policy's WITH CHECK rejects any other value,
      // so a tampered client cannot put rows in someone else's cart.
      'user_id': _uid,
      'product_id': productId,
      'variant_id': variantId,
      'quantity': quantity,
      // Stores the PATH. The old backend wrote a full URL with the serving host baked in,
      // which is why existing rows contain localhost and 192.168.31.10.
      'image_url': imagePath,
    });
  }

  /// Sets an absolute quantity. Zero or less removes the line, since the database has a
  /// CHECK (quantity > 0) and a "0 quantity" row is meaningless anyway.
  Future<void> setQuantity({required int cartItemId, required int quantity}) async {
    if (quantity <= 0) return remove(cartItemId);
    await Db.client
        .from('cart_items')
        .update({'quantity': quantity})
        .eq('id', cartItemId);
  }

  Future<void> remove(int cartItemId) async {
    await Db.client.from('cart_items').delete().eq('id', cartItemId);
  }

  /// Empties the cart. Scoped by RLS to the caller's own rows.
  Future<void> clear() async {
    await Db.client.from('cart_items').delete().eq('user_id', _uid);
  }
}

class WishlistRepository {
  const WishlistRepository();

  String get _uid {
    final id = Db.currentUserId;
    if (id == null) throw DataException('Please sign in first.');
    return id;
  }

  Future<List<Product>> items() async {
    final rows = await Db.client.from('wishlist').select('''
          id, product_id,
          products!inner(
            id, name, name_hi, name_hn, description, description_hi, description_hn,
            main_category_id, types,
            product_images(image_url),
            product_variants(id, product_id, name, name_hi, name_hn, price, selling_price, stock)
          )
        ''').order('created_at', ascending: false);

    return rows
        .map((r) => Product.fromMap(Map<String, dynamic>.from(r['products'] as Map)))
        .toList();
  }

  Future<bool> contains(int productId) async {
    final row = await Db.client
        .from('wishlist')
        .select('id')
        .eq('product_id', productId)
        .maybeSingle();
    return row != null;
  }

  Future<void> add(int productId) async {
    // UNIQUE (user_id, product_id) makes a double-tap a no-op rather than a duplicate.
    await Db.client.from('wishlist').upsert(
      {'user_id': _uid, 'product_id': productId},
      onConflict: 'user_id, product_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> remove(int productId) async {
    await Db.client.from('wishlist').delete().eq('product_id', productId);
  }

  Future<bool> toggle(int productId) async {
    if (await contains(productId)) {
      await remove(productId);
      return false;
    }
    await add(productId);
    return true;
  }
}
