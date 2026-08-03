import 'dart:math';

import '../../CustomWidgets/cart_provider.dart';
import '../../core/supabase.dart';
import '../../data/cart_repository.dart';
import '../../data/catalog_repository.dart';
import '../../data/models.dart';
import '../../data/order_repository.dart';

/// One product the agent has put on screen.
class VoiceCard {
  const VoiceCard({
    required this.productId,
    required this.variantId,
    required this.name,
    required this.variantName,
    required this.price,
    required this.quantity,
    required this.imagePath,
  });

  final int productId;
  final int? variantId;
  final String name;
  final String variantName;
  final double price;
  final int quantity;
  final String imagePath;

  double get lineTotal => price * quantity;
}

/// Runs the tools the model asks for, against the repositories the app already
/// uses.
///
/// Nothing here is a new data path. `add_to_cart` goes through
/// [CartProvider.changeQuantity] — the app's single cart writer — so the
/// bottom-nav badge and every open stepper stay correct, and `place_order`
/// goes through [OrderRepository.place] into the existing `place-order` Edge
/// Function, which recomputes every rupee server-side. The agent therefore has
/// exactly the permissions the signed-in user already has, no more.
class ToolDispatcher {
  ToolDispatcher({
    required CartProvider cart,
    this.onCardsChanged,
  }) : _cart = cart;

  final CartProvider _cart;
  final void Function()? onCardsChanged;

  static const _catalog = CatalogRepository();
  static const _cartRepo = CartRepository();
  static const _orders = OrderRepository();
  static const _addresses = AddressRepository();

  /// Products the agent has added, newest last, for the screen to render.
  final List<VoiceCard> cards = [];

  /// Minted by `read_cart`, required by `place_order`. Bound to the exact cart
  /// contents that were read aloud.
  String? _confirmToken;
  String? _confirmedCartHash;

  /// One idempotency key per checkout attempt, reused across retries so a
  /// network wobble cannot produce two orders.
  String? _idempotencyKey;

  /// True once an order has been placed in this session.
  bool ordered = false;

  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> args,
  ) async {
    try {
      switch (name) {
        case 'search_products':
          return await _search(args);
        case 'get_price':
          return await _getPrice(args);
        case 'add_to_cart':
          return await _addToCart(args);
        case 'update_cart_item':
          return await _updateCartItem(args);
        case 'read_cart':
          return await _readCart();
        case 'place_order':
          return await _placeOrder(args);
        default:
          return {'ok': false, 'error': 'Unknown tool "$name".'};
      }
    } on DataException catch (e) {
      // Surface the real server message so the agent can say what actually went
      // wrong ("Coupon has expired") instead of inventing a reason.
      return {'ok': false, 'error': e.message};
    } catch (e) {
      return {'ok': false, 'error': 'Something went wrong. Please try again.'};
    }
  }

  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _search(Map<String, dynamic> args) async {
    final q = (args['query'] ?? '').toString().trim();
    if (q.isEmpty) return {'ok': false, 'error': 'Empty query.'};
    final found = await _catalog.search(q);
    // Capped and short-keyed for the same reason as read_cart: an oversized RPC
    // response is dropped in transit and surfaces as an unexplained failure.
    return {
      'ok': true,
      'results': found.take(6).map((p) {
        final v = p.defaultVariant;
        return {
          'pid': p.id,
          'n': p.name.length > 40 ? p.name.substring(0, 40) : p.name,
          'vid': v?.id,
          'v': v?.name,
          'p': v?.sellingPrice,
        };
      }).toList(),
    };
  }

  Future<Map<String, dynamic>> _getPrice(Map<String, dynamic> args) async {
    final pid = _asInt(args['product_id']);
    if (pid == null) return {'ok': false, 'error': 'product_id is required.'};
    final p = await _catalog.product(pid);
    if (p == null) {
      return {'ok': false, 'error': 'That product is not available.'};
    }
    final vid = _asInt(args['variant_id']);
    final variants = vid == null
        ? p.variants
        : p.variants.where((v) => v.id == vid).toList();
    return {
      'ok': true,
      'pid': p.id,
      'n': p.name.length > 40 ? p.name.substring(0, 40) : p.name,
      'variants': variants
          .take(8)
          .map((v) => {
                'vid': v.id,
                'v': v.name,
                'p': v.sellingPrice,
                'stock': v.stock,
              })
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _addToCart(Map<String, dynamic> args) async {
    final pid = _asInt(args['product_id']);
    if (pid == null) return {'ok': false, 'error': 'product_id is required.'};
    final qty = max(1, _asInt(args['quantity']) ?? 1);

    final product = await _catalog.product(pid);
    if (product == null) {
      return {'ok': false, 'error': 'That product is not available right now.'};
    }

    var vid = _asInt(args['variant_id']);
    Variant? variant;
    if (vid != null) {
      for (final v in product.variants) {
        if (v.id == vid) variant = v;
      }
    }
    variant ??= product.defaultVariant;
    if (variant == null) {
      return {'ok': false, 'error': 'That product has no size available.'};
    }
    vid = variant.id;

    if (!variant.inStock) {
      return {
        'ok': false,
        'error': '${product.name} (${variant.name}) is out of stock.',
      };
    }
    if (variant.stock < qty) {
      return {
        'ok': false,
        'error':
            'Only ${variant.stock} left of ${product.name} (${variant.name}).',
      };
    }

    final imagePath = product.images.isNotEmpty ? product.images.first : '';

    // CartProvider rejects a write while a previous one for the same line is
    // still in flight. The agent adds items back to back, so `busy` came up
    // often — and a refusal there is what produced "add kar diya" with nothing
    // in the cart: the tool failed, the model narrated success anyway.
    //
    // Busy is transient by definition, so wait for the in-flight write instead
    // of giving up on it.
    CartMutation result = CartMutation.busy;
    for (var attempt = 0; attempt < 4; attempt++) {
      result = await _cart.changeQuantity(
        productId: pid,
        variantId: vid,
        delta: qty,
        imagePath: imagePath,
      );
      if (result != CartMutation.busy) break;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    switch (result) {
      case CartMutation.ok:
        break;
      case CartMutation.busy:
        return {
          'ok': false,
          'error': 'Cart abhi busy hai. Ek second baad phir boliye.',
        };
      case CartMutation.stale:
      case CartMutation.failed:
        return {'ok': false, 'error': 'Could not add that. Please try again.'};
    }

    // Confirm against the cart itself rather than assuming the delta landed.
    // The card must never show something the cart does not actually hold.
    await _cart.refreshCartData();

    // The cart changed, so any read-back the customer already heard is stale.
    _invalidateConfirmation();

    final now = _cart.getQuantity('', '$pid', '$vid');
    // One card per product+variant, always. Appending on every call produced
    // two cards for the same moong dal — one showing x2 and one x4 — because a
    // repeated add is an update to a line that already exists, not a new line.
    _putCard(VoiceCard(
      productId: pid,
      variantId: vid,
      name: product.name,
      variantName: variant.name,
      price: variant.sellingPrice,
      quantity: now > 0 ? now : qty,
      imagePath: imagePath,
    ));
    onCardsChanged?.call();

    return {
      'ok': true,
      'name': product.name,
      'variant_name': variant.name,
      'price': variant.sellingPrice,
      'quantity_now': now > 0 ? now : qty,
      'cart_count': _cart.getTotalCartItems(),
    };
  }

  Future<Map<String, dynamic>> _updateCartItem(
    Map<String, dynamic> args,
  ) async {
    final pid = _asInt(args['product_id']);
    final target = _asInt(args['quantity']);
    if (pid == null || target == null) {
      return {'ok': false, 'error': 'product_id and quantity are required.'};
    }
    final vid = _asInt(args['variant_id']);
    final current = _cart.getQuantity('', '$pid', '${vid ?? 'null'}');
    if (current == 0 && target > 0) {
      return _addToCart({
        'product_id': pid,
        'variant_id': vid,
        'quantity': target,
      });
    }
    final delta = target - current;
    if (delta == 0) return {'ok': true, 'quantity_now': current};

    final result = await _cart.changeQuantity(
      productId: pid,
      variantId: vid,
      delta: delta,
    );
    if (result != CartMutation.ok) {
      return {'ok': false, 'error': 'Could not update that. Please try again.'};
    }

    _invalidateConfirmation();
    final now = _cart.getQuantity('', '$pid', '${vid ?? 'null'}');

    // Only drop the card when the line is actually gone. Removing it on every
    // update meant "make it three" made the product disappear from the screen
    // while staying in the cart.
    final at = cards.indexWhere((c) => c.productId == pid && c.variantId == vid);
    if (now <= 0) {
      if (at >= 0) cards.removeAt(at);
    } else if (at >= 0) {
      final old = cards[at];
      cards[at] = VoiceCard(
        productId: old.productId,
        variantId: old.variantId,
        name: old.name,
        variantName: old.variantName,
        price: old.price,
        quantity: now,
        imagePath: old.imagePath,
      );
    }
    onCardsChanged?.call();
    return {'ok': true, 'quantity_now': now, 'cart_count': _cart.getTotalCartItems()};
  }

  Future<Map<String, dynamic>> _readCart() async {
    final lines = await _cartRepo.items();
    if (lines.isEmpty) {
      _invalidateConfirmation();
      return {'ok': false, 'reason': 'empty_cart', 'error': 'The cart is empty.'};
    }

    final addresses = await _addresses.list();
    if (addresses.isEmpty) {
      _invalidateConfirmation();
      return {
        'ok': false,
        'reason': 'no_address',
        'error': 'No delivery address is saved. One must be added first.',
      };
    }

    final subtotal =
        lines.fold<double>(0, (sum, l) => sum + l.sellingPrice * l.quantity);

    // The token is bound to the exact contents just read aloud. If anything
    // changes afterwards the hash no longer matches and place_order refuses —
    // so the customer can never be talked into confirming one cart and being
    // charged for another.
    _confirmedCartHash = _hashCart(lines);
    _confirmToken = newUuidV4();

    // Deliberately lean. LiveKit caps an RPC response, and the earlier verbose
    // shape blew that cap: the reply never arrived, the agent reported
    // "Failed to read RPC v2 response stream: LengthExceeded", and the
    // customer just heard "kuch technical issue ho gaya".
    //
    // So: short keys, no prose, no redundant totals the model can add up
    // itself, and a bounded number of lines. The instruction about reading the
    // cart aloud lives in the persona, where it costs nothing per call.
    return {
      'ok': true,
      'confirm_token': _confirmToken,
      'lines': lines
          .take(25)
          .map((l) => {
                'n': l.productName.length > 40
                    ? l.productName.substring(0, 40)
                    : l.productName,
                'v': l.variantName,
                'q': l.quantity,
                'p': l.sellingPrice,
              })
          .toList(),
      'count': lines.length,
      'subtotal': subtotal,
      'addr': _shortAddress(addresses.first.fullAddress),
    };
  }

  Future<Map<String, dynamic>> _placeOrder(Map<String, dynamic> args) async {
    // Three independent conditions, because a model asserting the customer
    // agreed is not sufficient evidence to spend their money.
    final confirmed = args['confirmed'] == true;
    final token = args['confirm_token']?.toString();

    if (_confirmToken == null) {
      return {
        'ok': false,
        'reason': 'needs_confirmation',
        'error': 'Call read_cart first and read the cart aloud.',
      };
    }
    if (!confirmed || token != _confirmToken) {
      return {
        'ok': false,
        'reason': 'needs_confirmation',
        'error':
            'Not confirmed. Read the cart back and get a clear yes before ordering.',
      };
    }

    final lines = await _cartRepo.items();
    if (lines.isEmpty) {
      return {'ok': false, 'reason': 'empty_cart', 'error': 'The cart is empty.'};
    }
    if (_hashCart(lines) != _confirmedCartHash) {
      _invalidateConfirmation();
      return {
        'ok': false,
        'reason': 'cart_changed',
        'error': 'The cart changed since you read it out. Read it again.',
      };
    }

    final addresses = await _addresses.list();
    if (addresses.isEmpty) {
      return {
        'ok': false,
        'reason': 'no_address',
        'error': 'No delivery address is saved.',
      };
    }

    _idempotencyKey ??= newUuidV4();
    final order = await _orders.place(
      deliveryAddressId: addresses.first.id,
      idempotencyKey: _idempotencyKey!,
      // Online payment is refused server-side while the Razorpay webhook secret
      // is unset, so a voice order is Cash on Delivery by construction.
      paymentMethod: 'COD',
    );

    ordered = true;
    _invalidateConfirmation();
    _idempotencyKey = null;
    await _cart.refreshCartData();

    return {
      'ok': true,
      'order_id': order.id,
      'final_amount': order.finalAmount,
      'delivery_charge': order.deliveryCharge,
      'handling_charge': order.handlingCharge,
      'discount_amount': order.discountAmount,
      'payment_method': 'Cash on Delivery',
    };
  }

  // ---------------------------------------------------------------------------

  /// Inserts or replaces the card for one product+variant, keeping its place in
  /// the list so items do not jump around as quantities change.
  void _putCard(VoiceCard card) {
    final at = cards.indexWhere(
      (c) => c.productId == card.productId && c.variantId == card.variantId,
    );
    if (card.quantity <= 0) {
      if (at >= 0) cards.removeAt(at);
      return;
    }
    if (at >= 0) {
      cards[at] = card;
    } else {
      cards.add(card);
    }
  }

  /// Changes a line's quantity from the card's +/- control.
  ///
  /// The customer adjusts quantity here rather than by talking, which keeps a
  /// misheard "do" from silently becoming four of something.
  Future<void> nudge(VoiceCard card, int delta) async {
    final result = await _cart.changeQuantity(
      productId: card.productId,
      variantId: card.variantId,
      delta: delta,
      imagePath: card.imagePath,
    );
    if (result != CartMutation.ok) return;

    _invalidateConfirmation();
    final now = _cart.getQuantity(
      '',
      '${card.productId}',
      '${card.variantId ?? 'null'}',
    );
    _putCard(VoiceCard(
      productId: card.productId,
      variantId: card.variantId,
      name: card.name,
      variantName: card.variantName,
      price: card.price,
      quantity: now,
      imagePath: card.imagePath,
    ));
    onCardsChanged?.call();
  }

  void _invalidateConfirmation() {
    _confirmToken = null;
    _confirmedCartHash = null;
  }

  /// Enough address for the agent to read back, not the whole postal record.
  static String _shortAddress(String full) {
    final one = full.replaceAll(RegExp(r'\s+'), ' ').trim();
    return one.length > 80 ? '${one.substring(0, 80)}…' : one;
  }

  static String _hashCart(List<CartLine> lines) {
    final parts = lines
        .map((l) => '${l.productId}:${l.variantId}:${l.quantity}:${l.sellingPrice}')
        .toList()
      ..sort();
    return parts.join('|');
  }

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
