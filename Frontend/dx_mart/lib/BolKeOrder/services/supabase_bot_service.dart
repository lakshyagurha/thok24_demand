import 'package:flutter/material.dart';

import '../../core/supabase.dart';
import '../models/chat_message.dart';
import 'bot_service.dart';

/// BolKeOrder backed by the `process-chat` Edge Function.
///
/// Drop-in replacement for [HybridBotService]: same [BotService] contract, same
/// [BotResponse] shape, so `bol_ke_order_screen.dart` and the Ramu Bhai widgets need no
/// changes beyond which service they construct.
///
/// The difference is what crosses the wire. The old service POSTed
/// `{"user_id": ..., "message": ...}` to `process_chat.php`, so the cart being driven was
/// whichever id the client chose to send. Here the function reads identity from the
/// verified JWT and the `userId` argument is ignored entirely.
class SupabaseBotService implements BotService {
  const SupabaseBotService();

  @override
  Future<BotResponse> processMessage(
    String message,
    String userId, // ignored -- kept only to satisfy the BotService interface
    BuildContext context,
  ) async {
    if (!Db.isSignedIn) {
      return BotResponse(
        replyText: 'Pehle login kar lijiye, phir main aapka order le sakta hoon.',
        avatarState: RamuBhaiState.idle,
      );
    }

    try {
      final res = await Db.client.functions.invoke(
        'process-chat',
        body: {'message': message},
      );

      final data = res.data;
      if (data is! Map || data['success'] != true) {
        return BotResponse(
          replyText: 'Maaf karna Bhai, thodi dikkat aa gayi. Phir se boliye.',
          avatarState: RamuBhaiState.idle,
        );
      }

      final items = ((data['items'] as List?) ?? const [])
          .map((e) => _normaliseItem(Map<String, dynamic>.from(e as Map)))
          .toList();

      final type = _messageType(data['message_type'] as String?);

      return BotResponse(
        replyText: (data['reply'] as String?) ?? 'Maaf karna, kuch error aa gaya.',
        messageType: type,
        avatarState:
            items.isNotEmpty ? RamuBhaiState.thumbsUp : RamuBhaiState.idle,
        cartItems: type == MessageType.optionsChoice || type == MessageType.substituteOffer ? const [] : items,
        candidateItems: type == MessageType.optionsChoice || type == MessageType.substituteOffer ? items : const [],
        subtotal: _toDouble(data['subtotal']),
        finalAmount: _toDouble(data['final_amount']),
      );
    } catch (e) {
      debugPrint('SupabaseBotService failed: $e');
      return BotResponse(
        replyText: 'Network ya server issue, kripya baad mein try karein.',
        avatarState: RamuBhaiState.idle,
      );
    }
  }

  static MessageType _messageType(String? raw) => switch (raw) {
        'cartSummary' => MessageType.cartSummary,
        'orderConfirmed' => MessageType.orderConfirmed,
        'checkout' => MessageType.checkout,
        'optionsChoice' => MessageType.optionsChoice,
        'bundleSummary' => MessageType.bundleSummary,
        'substituteOffer' => MessageType.substituteOffer,
        _ => MessageType.text,
      };

  /// Keeps the exact key set the parchi/bill widgets already read.
  static Map<String, dynamic> _normaliseItem(Map<String, dynamic> m) => {
        'id': m['id'],
        'product_id': m['product_id'],
        'variant_id': m['variant_id'],
        'name': m['name'] ?? m['product_name'] ?? '',
        'product_name': m['product_name'] ?? m['name'] ?? '',
        'variant_name': m['variant_name'] ?? '',
        'price': _toDouble(m['price']),
        'selling_price': _toDouble(m['selling_price']),
        'quantity': int.tryParse('${m['quantity']}') ?? 1,
        // Resolved to a full URL here rather than stored as one, so the row stays
        // portable between environments.
        'image_url': Db.imageUrl(m['image_url'] as String?),
        'added': true,
      };

  static double _toDouble(Object? v) => switch (v) {
        null => 0,
        final num n => n.toDouble(),
        final String s => double.tryParse(s) ?? 0,
        _ => 0,
      };
}
