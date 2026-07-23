import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../CustomWidgets/cart_provider.dart';
import '../../utils/api_constants.dart';
import '../../utils/language_provider.dart';
import '../models/chat_message.dart';
import 'bot_service.dart';

class FakeBotService implements BotService {
  @override
  Future<BotResponse> processMessage(
    String message,
    String userId,
    BuildContext context,
  ) async {
    final cleanMsg = message.trim().toLowerCase();

    // 1. Check for Confirmation intent
    if (cleanMsg == 'confirm' ||
        cleanMsg.contains('order confirm') ||
        cleanMsg.contains('pakka kardo') ||
        cleanMsg.contains('order bhej do') ||
        cleanMsg.contains('order book') ||
        cleanMsg.contains('done kardo') ||
        cleanMsg.contains('bhej do')) {
      return await _handleConfirm(userId, context);
    }

    // 2. Check for Order Summary / Show Bill intent
    if (cleanMsg == 'order dikhao' ||
        cleanMsg.contains('bill dikhao') ||
        cleanMsg.contains('order list') ||
        cleanMsg.contains('parchi dikhao') ||
        cleanMsg.contains('kya kya add hua') ||
        cleanMsg.contains('cart dikhao') ||
        cleanMsg.contains('bill')) {
      return await _handleShowSummary(userId, context, "Ji Didi, aapki parchi ye rahi:");
    }

    // 3. Check for Removal intent (e.g. "tel hata do", "remove aata")
    if (cleanMsg.contains('hata') ||
        cleanMsg.contains('remove') ||
        cleanMsg.contains('delete') ||
        cleanMsg.contains('nikal') ||
        cleanMsg.contains('mat bhejo')) {
      return await _handleRemoveItem(cleanMsg, userId, context);
    }

    // 4. Regular product add (e.g. "2 kilo aata", "1 packet chai")
    return await _handleAddProduct(cleanMsg, userId, context);
  }

  // --- CONFIRM ORDER INTENT ---
  Future<BotResponse> _handleConfirm(String userId, BuildContext context) async {
    final cartData = await _fetchCartItemsFromServer(userId);
    if (cartData.isEmpty) {
      return BotResponse(
        replyText: "Didi, abhi aapki parchi khali hai. Kuch add karne ko boliye, jaise '2 kilo aata bhej do'. 😊",
        avatarState: RamuBhaiState.idle,
      );
    }

    final totals = _calculateTotals(cartData);
    
    // Clear cart in provider & local DB simulator
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.clearCart(userId);

    // Call place order or remove items from cart on backend
    // Since this is a simulation, we can hit the checkout clear endpoint, or just return confirmed.
    // For Phase 1, we just return a gorgeous success confirmation screen.
    return BotResponse(
      replyText: "Bahut badhiya Didi! 👍 Aapka order book ho gaya hai aur agle 15 minute mein aapke ghar pahunch jayega. Ramu Bhai ki dukaan se shopping karne ke liye dhanyawad! 🙏",
      messageType: MessageType.orderConfirmed,
      avatarState: RamuBhaiState.thumbsUp,
      cartItems: cartData,
      subtotal: totals['subtotal']!,
      finalAmount: totals['finalAmount']!,
    );
  }

  // --- SHOW SUMMARY INTENT ---
  Future<BotResponse> _handleShowSummary(
    String userId,
    BuildContext context,
    String replyIntro,
  ) async {
    final cartData = await _fetchCartItemsFromServer(userId);
    if (cartData.isEmpty) {
      return BotResponse(
        replyText: "Didi, abhi aapki parchi khali hai. Kuch mangvana ho toh boliye! 🛍️",
        avatarState: RamuBhaiState.idle,
      );
    }

    final totals = _calculateTotals(cartData);

    return BotResponse(
      replyText: replyIntro,
      messageType: MessageType.cartSummary,
      avatarState: RamuBhaiState.thumbsUp,
      cartItems: cartData,
      subtotal: totals['subtotal']!,
      finalAmount: totals['finalAmount']!,
    );
  }

  // --- REMOVE ITEM INTENT ---
  Future<BotResponse> _handleRemoveItem(
    String cleanMsg,
    String userId,
    BuildContext context,
  ) async {
    final keyword = _extractProductKeyword(cleanMsg);
    if (keyword == null) {
      return BotResponse(
        replyText: "Didi, kaunsa item bill se hatana hai? Aap bol sakte hain 'aata hata do'.",
        avatarState: RamuBhaiState.idle,
      );
    }

    final cartData = await _fetchCartItemsFromServer(userId);
    Map<String, dynamic>? itemToRemove;

    // Search for match in cart
    for (var item in cartData) {
      final name = (item['product_name'] ?? item['name'] ?? '').toString().toLowerCase();
      if (name.contains(keyword) || _isSynonymMatch(keyword, name)) {
        itemToRemove = item;
        break;
      }
    }

    if (itemToRemove == null) {
      return BotResponse(
        replyText: "Didi, aapki parchi mein yeh item nahi mila. Parchi dekhne ke liye 'order dikhao' boliye.",
        avatarState: RamuBhaiState.idle,
      );
    }

    final cartItemId = int.tryParse(itemToRemove['id']?.toString() ?? '0') ?? 0;
    if (cartItemId > 0) {
      final removeUrl = Uri.parse('${ApiConstants.REMOVE_CART_ITEM}?id=$cartItemId');
      await http.get(removeUrl);

      // Update provider
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.removeCartItem(
        userId,
        itemToRemove['product_id']?.toString() ?? '',
        itemToRemove['variant_id']?.toString() ?? '',
      );
    }

    final updatedCart = await _fetchCartItemsFromServer(userId);
    final totals = _calculateTotals(updatedCart);

    final pName = itemToRemove['product_name'] ?? itemToRemove['name'] ?? 'Item';
    
    return BotResponse(
      replyText: "Ji Didi, $pName ko parchi se hata diya hai. ❌",
      messageType: updatedCart.isNotEmpty ? MessageType.cartSummary : MessageType.text,
      avatarState: RamuBhaiState.idle,
      cartItems: updatedCart,
      subtotal: totals['subtotal']!,
      finalAmount: totals['finalAmount']!,
    );
  }

  // --- ADD PRODUCT INTENT ---
  Future<BotResponse> _handleAddProduct(
    String cleanMsg,
    String userId,
    BuildContext context,
  ) async {
    // 1. Extract keyword
    final keyword = _extractProductKeyword(cleanMsg);
    if (keyword == null) {
      return BotResponse(
        replyText: "Namaste Didi! 🙏\n\nMain aapka trusted dukaan owner Ramu Bhai hoon. Aap bas bol dijiye jo mangvana hai, jaise '2 kilo aata aur doodh bhej do'. Main sab note kar loonga!",
        avatarState: RamuBhaiState.idle,
      );
    }

    // 2. Extract quantity and unit
    final quantityInfo = _extractQuantityAndUnit(cleanMsg);
    final quantity = quantityInfo['quantity'] as int;
    final unit = quantityInfo['unit'] as String;

    // 3. Call backend synonym search
    final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
    final searchUrl = Uri.parse('${ApiConstants.BOL_KE_ORDER_HINDI_SEARCH}?keyword=$keyword&lang=$lang');
    try {
      final response = await http.get(searchUrl);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && (data['products'] as List).isNotEmpty) {
          final product = data['products'][0];
          final productId = product['id'].toString();
          final variants = product['variants'] as List;

          if (variants.isEmpty) {
            return BotResponse(
              replyText: "Didi, ${product['name']} abhi out of stock chal raha hai. Kuch aur chahiye?",
              avatarState: RamuBhaiState.idle,
            );
          }

          // Pick variant matching the requested unit, or default to first
          var selectedVariant = variants[0];
          
          // Simple heuristic to match unit (e.g. 5kg to 5 kg variant)
          for (var v in variants) {
            final name = (v['name'] ?? '').toString().toLowerCase().replaceAll(' ', '');
            final searchUnit = unit.replaceAll(' ', '');
            if (name.contains(searchUnit) && searchUnit.isNotEmpty) {
              selectedVariant = v;
              break;
            }
          }

          final variantId = selectedVariant['id'].toString();
          final variantName = selectedVariant['name']?.toString() ?? '';
          final stock = int.tryParse(selectedVariant['stock']?.toString() ?? '0') ?? 0;

          if (stock <= 0) {
            return BotResponse(
              replyText: "Didi, ${product['name']} ($variantName) abhi out of stock hai. Iska koi doosra pack bhejoon?",
              avatarState: RamuBhaiState.idle,
            );
          }

          // Fetch current cart to see if this variant is already in cart
          final cartProvider = Provider.of<CartProvider>(context, listen: false);
          final currentQty = cartProvider.getQuantity(userId, productId, variantId);

          if (currentQty > 0) {
            // Update quantity
            final cartId = cartProvider.getCartId(userId, productId, variantId);
            final newQty = currentQty + quantity;

            final updateUrl = Uri.parse(ApiConstants.UPDATE_QUANTITY);
            await http.post(
              updateUrl,
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'id': cartId, 'quantity': newQty}),
            );

            cartProvider.updateCartQuantities(userId, productId, variantId, newQty, cartId);
          } else {
            // Add new item to cart
            final imageUrl = (product['images'] != null && (product['images'] as List).isNotEmpty)
                ? product['images'][0].toString()
                : '';

            final addUrl = Uri.parse(ApiConstants.ADD_TO_CART);
            final addResponse = await http.post(
              addUrl,
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'user_id': userId,
                'product_id': productId,
                'variant_id': variantId,
                'quantity': quantity,
                'image_url': imageUrl,
              }),
            );

            final addData = json.decode(addResponse.body);
            if (addData['success'] == true) {
              cartProvider.updateCartQuantities(
                userId,
                productId,
                variantId,
                quantity,
                addData['cart_id'] ?? 0,
              );
            }
          }

          // Fetch updated cart items for summary
          final updatedCart = await _fetchCartItemsFromServer(userId);
          final totals = _calculateTotals(updatedCart);

          String promptConfirm = "Ji Didi 👍\n\n";
          if (quantity > 1) {
            promptConfirm += "$quantity $variantName ${product['name']} note kar liya hai.";
          } else {
            promptConfirm += "$variantName ${product['name']} note kar liya hai.";
          }

          return BotResponse(
            replyText: promptConfirm,
            messageType: MessageType.cartSummary,
            avatarState: RamuBhaiState.thumbsUp,
            cartItems: updatedCart,
            subtotal: totals['subtotal']!,
            finalAmount: totals['finalAmount']!,
          );
        }
      }
    } catch (e) {
      debugPrint("Error in Bot adding product: $e");
    }

    return BotResponse(
      replyText: "Mafi chahta hoon Didi, mujhe '$keyword' nahi mila. Aap kuch aur mangvana chahein toh boliye, jaise 'aata' ya 'tel'.",
      avatarState: RamuBhaiState.idle,
    );
  }

  // --- HELPER METHODS ---

  Future<List<Map<String, dynamic>>> _fetchCartItemsFromServer(String userId) async {
    try {
      final url = Uri.parse('${ApiConstants.GET_CART_ITEMS}?user_id=$userId');
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['cart'] ?? []);
      }
    } catch (e) {
      debugPrint("Error fetching cart from bot: $e");
    }
    return [];
  }

  Map<String, double> _calculateTotals(List<Map<String, dynamic>> cartItems) {
    double subtotal = 0.0;
    for (var item in cartItems) {
      final sellingPrice = double.tryParse(item['selling_price']?.toString() ?? '0') ?? 0.0;
      final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      subtotal += sellingPrice * quantity;
    }
    
    // Hardcoded logic mirrors backend delivery/handling charge
    double delivery = subtotal < 500 ? 10.0 : 0.0;
    double handling = 5.0;
    double finalAmount = subtotal > 0 ? (subtotal + delivery + handling) : 0.0;

    return {
      'subtotal': subtotal,
      'finalAmount': finalAmount
    };
  }

  // Basic regex parser to extract product keyword from Hinglish / Hindi commands
  String? _extractProductKeyword(String text) {
    // Stop words / fluff words to ignore
    final itemsList = [
      'aata', 'atta', 'flour', 'oil', 'tel', 'mustard', 'dal', 'moong', 'chana', 'rice', 'chawal', 'suji',
      'sooji', 'doodh', 'milk', 'paneer', 'curd', 'dahi', 'butter', 'makkhan', 'tea', 'chai', 'coffee',
      'biscuit', 'cookies', 'sugar', 'cheeni', 'shakar', 'soap', 'sabun', 'bulb', 'light', 'led'
    ];

    for (var item in itemsList) {
      if (text.contains(item)) {
        return item;
      }
    }
    
    // Regex fallback to capture nouns after number or directly
    final match = RegExp(r'(?:bhej\s+do|add\s+karo|chai\s+aur|aur)?\s*([a-zA-Z\u0900-\u097F]+)$').firstMatch(text);
    if (match != null) {
      final word = match.group(1);
      if (word != 'kilo' && word != 'kg' && word != 'packet' && word != 'litre' && word != 'liter' && word != 'gm' && word != 'gram') {
        return word;
      }
    }
    return null;
  }

  // Helper matching synonyms to prevent missing cart items
  bool _isSynonymMatch(String keyword, String productName) {
    final name = productName.toLowerCase();
    if (keyword == 'aata' || keyword == 'atta') return name.contains('atta') || name.contains('flour');
    if (keyword == 'tel' || keyword == 'oil') return name.contains('oil') || name.contains('ghee');
    if (keyword == 'dal') return name.contains('dal') || name.contains('moong') || name.contains('chana');
    if (keyword == 'chawal' || keyword == 'rice') return name.contains('rice');
    if (keyword == 'doodh' || keyword == 'milk') return name.contains('milk') || name.contains('taaza');
    if (keyword == 'chai' || keyword == 'tea') return name.contains('tea');
    if (keyword == 'biscuit') return name.contains('biscuit');
    if (keyword == 'sugar' || keyword == 'cheeni') return name.contains('sugar');
    if (keyword == 'soap' || keyword == 'sabun') return name.contains('soap');
    return false;
  }

  // Helper parsing quantity & unit (e.g. "2 kilo aata" -> {quantity: 2, unit: "kg"})
  Map<String, dynamic> _extractQuantityAndUnit(String text) {
    // 1. Look for explicit matches: e.g. "2 kilo"
    final regExp = RegExp(r'(\d+)\s*(kilo|kg|packet|litre|liter|l|gram|g|pc|piece|kilo\s+gram|kilos|packets|litres)', caseSensitive: false);
    final match = regExp.firstMatch(text);
    if (match != null) {
      final qty = int.tryParse(match.group(1) ?? '1') ?? 1;
      var rawUnit = match.group(2) ?? '';
      
      // Standardize unit
      var unit = '';
      rawUnit = rawUnit.toLowerCase();
      if (rawUnit.contains('kilo') || rawUnit.contains('kg')) {
        unit = 'kg';
      } else if (rawUnit.contains('packet')) {
        unit = 'pack';
      } else if (rawUnit.contains('liter') || rawUnit.contains('litre') || rawUnit == 'l') {
        unit = 'L';
      } else if (rawUnit.contains('gram') || rawUnit == 'g') {
        unit = 'g';
      } else if (rawUnit.contains('pc') || rawUnit.contains('piece')) {
        unit = 'pc';
      }

      return {'quantity': qty, 'unit': unit};
    }

    // 2. Simple numeric extraction (e.g. "2 aata" -> {quantity: 2, unit: ""})
    final simpleNumExp = RegExp(r'\b(\d+)\b');
    final simpleMatch = simpleNumExp.firstMatch(text);
    if (simpleMatch != null) {
      final qty = int.tryParse(simpleMatch.group(1) ?? '1') ?? 1;
      return {'quantity': qty, 'unit': ''};
    }

    return {'quantity': 1, 'unit': ''};
  }
}
