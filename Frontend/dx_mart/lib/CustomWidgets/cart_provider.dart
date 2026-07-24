import 'package:flutter/foundation.dart';

import '../core/supabase.dart';
import '../data/cart_repository.dart';

/// In-memory mirror of the cart, so quantity steppers on product cards stay responsive
/// without a round trip per tap.
///
/// Previously every map was keyed by a client-supplied `userId` string, because the app
/// had no session and each screen re-derived the user from an email in SharedPreferences.
/// There is now exactly one signed-in user, so the keying is gone.
///
/// The `userId` parameters are retained and **ignored** purely so screens can be migrated
/// one at a time rather than in a single breaking change. New code should pass `''`.
/// Once every caller stops supplying one, drop the parameters.
class CartProvider with ChangeNotifier {
  final CartRepository _repo = const CartRepository();

  /// '<productId>-<variantId>' -> quantity
  final Map<String, int> _quantities = {};

  /// '<productId>-<variantId>' -> cart row id
  final Map<String, int> _cartIds = {};

  static String _key(String productId, String variantId) =>
      '$productId-$variantId';

  // --- local mutations -----------------------------------------------------

  void updateCartQuantities(
    String userId, // ignored
    String productId,
    String variantId,
    int quantity,
    int cartId,
  ) {
    final k = _key(productId, variantId);
    _quantities[k] = quantity;
    _cartIds[k] = cartId;
    notifyListeners();
  }

  void removeCartItem(String userId, String productId, String variantId) {
    final k = _key(productId, variantId);
    _quantities.remove(k);
    _cartIds.remove(k);
    notifyListeners();
  }

  // --- queries -------------------------------------------------------------

  int getQuantity(String userId, String productId, String variantId) =>
      _quantities[_key(productId, variantId)] ?? 0;

  int getCartId(String userId, String productId, String variantId) =>
      _cartIds[_key(productId, variantId)] ?? 0;

  int getTotalCartItems([String userId = '']) =>
      _quantities.values.fold(0, (sum, q) => sum + q);

  bool isInCart(String userId, String productId, String variantId) =>
      (_quantities[_key(productId, variantId)] ?? 0) > 0;

  bool isCartEmpty([String userId = '']) => _quantities.isEmpty;

  int getUniqueItemsCount([String userId = '']) => _quantities.length;

  /// Total across every variant of one product.
  int getProductTotalQuantity(String userId, String productId) {
    var total = 0;
    _quantities.forEach((k, q) {
      if (k.startsWith('$productId-')) total += q;
    });
    return total;
  }

  List<String> getProductIdsInCart([String userId = '']) =>
      _quantities.keys.map((k) => k.split('-').first).toSet().toList();

  List<Map<String, dynamic>> getCartItemsAsList([String userId = '']) =>
      getCartItemsAsMap().values.toList();

  Map<String, Map<String, dynamic>> getCartItemsAsMap([String userId = '']) {
    final out = <String, Map<String, dynamic>>{};
    _quantities.forEach((k, quantity) {
      final parts = k.split('-');
      if (parts.length < 2) return;
      out[k] = {
        'product_id': parts[0],
        'variant_id': parts[1],
        'quantity': quantity,
        'cart_id': _cartIds[k] ?? 0,
      };
    });
    return out;
  }

  // --- clearing ------------------------------------------------------------

  void clearCart([String userId = '']) {
    _quantities.clear();
    _cartIds.clear();
    notifyListeners();
  }

  void clearAllCartData() => clearCart();

  /// Kept for callers that used it to reset state on user change.
  void clearCartData([String userId = '']) => clearCart();

  // --- server sync ---------------------------------------------------------

  /// Reloads from Supabase. RLS scopes the read to the signed-in user, so unlike the
  /// old version there is no user_id in the request to get wrong or tamper with.
  Future<bool> refreshCartData([String userId = '']) async {
    if (!Db.isSignedIn) {
      clearCart();
      return false;
    }
    try {
      final lines = await _repo.items();
      _quantities.clear();
      _cartIds.clear();
      for (final l in lines) {
        final k = _key('${l.productId}', '${l.variantId}');
        _quantities[k] = l.quantity;
        _cartIds[k] = l.id;
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('refreshCartData failed: $e');
      return false;
    }
  }
}
