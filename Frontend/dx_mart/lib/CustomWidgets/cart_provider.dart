import 'package:flutter/foundation.dart';

import '../core/supabase.dart';
import '../data/cart_repository.dart';

/// Outcome of a cart mutation, so callers can tell "we ignored your tap" from
/// "the server said no".
enum CartMutation {
  /// Applied, locally and on the server.
  ok,

  /// A write for this same line was already in flight; this tap was dropped.
  busy,

  /// The server row was not where we thought it was (someone else's tab, an earlier
  /// racing delete). Local state has been resynced from the server.
  stale,

  /// The write failed. Local state has been resynced from the server.
  failed,
}

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
///
/// ## Why mutations live here rather than in the screens
///
/// Four screens render quantity steppers, and each used to compute an *absolute* target
/// from a snapshot it had not refreshed, then call the repository directly with no
/// in-flight guard. Tapping `+` three times quickly sent `quantity = 2` three times and
/// the server ended on 2. Tapping `+` then `-` at quantity 1 put a PATCH and a DELETE in
/// flight with no ordering, and a PATCH that lands after the DELETE matches zero rows and
/// returns 200 — so the client believed it had succeeded.
///
/// [changeQuantity] is the single writer: it serializes per line, applies a *relative*
/// delta, and resyncs from the server whenever reality disagrees.
class CartProvider with ChangeNotifier {
  final CartRepository _repo = const CartRepository();

  /// '<productId>-<variantId>' -> quantity
  final Map<String, int> _quantities = {};

  /// '<productId>-<variantId>' -> cart row id
  final Map<String, int> _cartIds = {};

  /// Lines with a write currently in flight.
  final Set<String> _busy = {};

  /// Taps that arrived while a write for that line was already running, folded together
  /// and drained by the in-flight writer when it finishes. Dropping them instead would be
  /// safe but lossy — five quick taps on `+` should mean five, not "however many fit
  /// between round trips".
  final Map<String, int> _pendingDelta = {};

  /// Incremented on every refresh so a slow earlier response cannot overwrite a newer
  /// one. Without this, refresh A starting before B but resolving after it would wipe
  /// whatever B had just loaded.
  int _generation = 0;

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

  /// True while a write for this line is in flight. Steppers should disable on this
  /// rather than firing a second overlapping write.
  bool isBusy(String productId, String variantId) =>
      _busy.contains(_key(productId, variantId));

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
    _busy.clear();
    // Invalidate any refresh already in flight, so a response that was requested under
    // the previous session cannot repopulate the cart after sign-out.
    _generation++;
    notifyListeners();
  }

  void clearAllCartData() => clearCart();

  /// Kept for callers that used it to reset state on user change.
  void clearCartData([String userId = '']) => clearCart();

  // --- the single writer ----------------------------------------------------

  /// Applies a *relative* change to one cart line.
  ///
  /// Relative rather than absolute because the caller's idea of the current quantity may
  /// already be one tap out of date.
  ///
  /// Exactly one write per line is in flight at a time. Taps that arrive during that
  /// window are added to [_pendingDelta] and applied by the running writer as soon as it
  /// is free, so a burst of taps is coalesced into the smallest number of round trips
  /// without losing any of them. The displayed quantity updates immediately; the server
  /// catches up, and any disagreement resyncs from the server.
  ///
  /// [variantId] is the variant's id, or null for a product with no variant.
  Future<CartMutation> changeQuantity({
    required int productId,
    required int? variantId,
    required int delta,
    String imagePath = '',
  }) async {
    if (!Db.isSignedIn) return CartMutation.failed;
    if (delta == 0) return CartMutation.ok;

    final k = _key('$productId', '$variantId');

    // Optimistic display update either way, so the stepper never feels stuck.
    void showDelta(int d) {
      final next = (_quantities[k] ?? 0) + d;
      if (next <= 0) {
        _quantities.remove(k);
      } else {
        _quantities[k] = next;
      }
    }

    if (_busy.contains(k)) {
      _pendingDelta[k] = (_pendingDelta[k] ?? 0) + delta;
      showDelta(delta);
      notifyListeners();
      return CartMutation.ok;
    }

    // What the server currently holds, tracked explicitly: `_quantities` is about to run
    // ahead of it optimistically, so it can no longer be used as the baseline.
    var serverQuantity = _quantities[k] ?? 0;
    showDelta(delta);
    _busy.add(k);
    notifyListeners();

    try {
      var pending = delta;
      while (pending != 0) {
        final target = serverQuantity + pending;
        final result = await _writeTarget(
          key: k,
          productId: productId,
          variantId: variantId,
          from: serverQuantity,
          to: target,
          imagePath: imagePath,
        );
        if (result != CartMutation.ok) return result;
        serverQuantity = target < 0 ? 0 : target;
        pending = _pendingDelta.remove(k) ?? 0;
      }
      return CartMutation.ok;
    } catch (e) {
      debugPrint('changeQuantity failed: $e');
      // Never leave the UI showing an optimistic value the server did not accept.
      await _reload();
      return CartMutation.failed;
    } finally {
      _pendingDelta.remove(k);
      _busy.remove(k);
      notifyListeners();
    }
  }

  /// Moves one line from [from] to [to] on the server. Resyncs and reports on any
  /// disagreement instead of leaving local state ahead of reality.
  Future<CartMutation> _writeTarget({
    required String key,
    required int productId,
    required int? variantId,
    required int from,
    required int to,
    required String imagePath,
  }) async {
    if (to <= 0) {
      final id = _cartIds[key];
      _quantities.remove(key);
      _cartIds.remove(key);
      // Nothing on the server to remove.
      if (id == null || id == 0) return CartMutation.ok;
      final removed = await _repo.remove(id);
      if (!removed) {
        await _reload();
        return CartMutation.stale;
      }
      return CartMutation.ok;
    }

    if (from <= 0) {
      // New line. cart_add is an atomic insert-or-increment, so even if two writers ever
      // did overlap they could not create two rows. Reload to learn the row id.
      await _repo.add(
        productId: productId,
        variantId: variantId,
        quantity: to,
        imagePath: imagePath,
      );
      await _reload();
      return CartMutation.ok;
    }

    final id = _cartIds[key];
    if (id == null || id == 0) {
      await _reload();
      return CartMutation.stale;
    }
    final updated = await _repo.setQuantity(cartItemId: id, quantity: to);
    if (!updated) {
      // The row is gone — a racing remove won. Server truth wins.
      await _reload();
      return CartMutation.stale;
    }
    _quantities[key] = to;
    return CartMutation.ok;
  }

  // --- server sync ---------------------------------------------------------

  /// Reloads from Supabase. RLS scopes the read to the signed-in user, so unlike the
  /// old version there is no user_id in the request to get wrong or tamper with.
  ///
  /// Returns false if the load failed; callers that can show an error should check it.
  Future<bool> refreshCartData([String userId = '']) async {
    if (!Db.isSignedIn) {
      clearCart();
      return false;
    }
    try {
      await _reload();
      return true;
    } catch (e) {
      debugPrint('refreshCartData failed: $e');
      return false;
    }
  }

  /// Loads server state into the local maps, discarding the result if a newer refresh
  /// or a sign-out has happened in the meantime.
  Future<void> _reload() async {
    final generation = ++_generation;
    final lines = await _repo.items();
    if (generation != _generation) return; // superseded; drop this response

    _quantities.clear();
    _cartIds.clear();
    for (final l in lines) {
      final k = _key('${l.productId}', '${l.variantId}');
      _quantities[k] = l.quantity;
      _cartIds[k] = l.id;
    }
    notifyListeners();
  }
}
