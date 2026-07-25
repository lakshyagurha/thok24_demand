import 'package:flutter/foundation.dart';

import '../core/supabase.dart';
import '../data/cart_repository.dart';

/// The set of product ids the signed-in user has wishlisted.
///
/// Exists to kill a per-card round trip. `ProductCard.initState` called
/// `WishlistRepository.contains(id)` to decide whether to fill the heart, so drawing a
/// 30-product grid issued 30 separate wishlist queries — on a 2G link that alone made the
/// category screen unusable. The whole set is a handful of integers and comes back in one
/// request, so every card can just read it.
class WishlistProvider with ChangeNotifier {
  final WishlistRepository _repo = const WishlistRepository();

  Set<int> _ids = <int>{};
  bool _loaded = false;

  /// De-duplicates concurrent [ensureLoaded] calls: every card on a screen mounts in the
  /// same frame and would otherwise each start their own load.
  Future<void>? _inFlight;

  bool get isLoaded => _loaded;

  bool contains(int productId) => _ids.contains(productId);

  /// Loads once. Cheap to call from every card's initState.
  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _inFlight ??= _load().whenComplete(() => _inFlight = null);
  }

  Future<void> refresh() {
    _loaded = false;
    return ensureLoaded();
  }

  Future<void> _load() async {
    if (!Db.isSignedIn) {
      _ids = <int>{};
      _loaded = true;
      return;
    }
    try {
      _ids = await _repo.productIds();
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('wishlist load failed: $e');
      // Leave _loaded false so a later screen retries rather than rendering every heart
      // as empty forever.
    }
  }

  /// Flips one product, updating locally first so the heart responds immediately.
  /// Returns the new state; rolls back and rethrows if the server rejects it.
  Future<bool> toggle(int productId) async {
    final wasIn = _ids.contains(productId);
    wasIn ? _ids.remove(productId) : _ids.add(productId);
    notifyListeners();
    try {
      final nowIn = await _repo.toggle(productId);
      // Trust the server's answer over our guess.
      nowIn ? _ids.add(productId) : _ids.remove(productId);
      notifyListeners();
      return nowIn;
    } catch (e) {
      wasIn ? _ids.add(productId) : _ids.remove(productId);
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _ids = <int>{};
    _loaded = false;
    notifyListeners();
  }
}
