import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import 'bot_service.dart';
import '../../utils/api_constants.dart';
import '../../CustomWidgets/cart_provider.dart';

class HybridBotService implements BotService {
  @override
  Future<BotResponse> processMessage(
      String message, String userId, BuildContext context) async {
    try {
      // Show thinking state
      final Uri url = Uri.parse(ApiConstants.BOL_KE_ORDER_PROCESS_CHAT);
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_id": userId,
          "message": message,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        bool success = data['success'] ?? false;
        String replyText = data['reply'] ?? "Maaf karna, kuch error aa gaya.";
        List<dynamic> rawItems = data['items'] ?? [];
        String messageTypeStr = data['message_type'] ?? "text";
        
        MessageType messageType = MessageType.text;
        if (messageTypeStr == "cartSummary") {
          messageType = MessageType.cartSummary;
        } else if (messageTypeStr == "orderConfirmed") {
          messageType = MessageType.orderConfirmed;
        } else if (messageTypeStr == "checkout") {
          messageType = MessageType.checkout;
        }

        List<Map<String, dynamic>> processedItems = rawItems.map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          return {
            "id": map['id'],
            "product_id": map['product_id'],
            "variant_id": map['variant_id'],
            "name": map['name'] ?? map['product_name'] ?? '',
            "product_name": map['product_name'] ?? map['name'] ?? '',
            "variant_name": map['variant_name'] ?? '',
            "price": double.tryParse(map['price']?.toString() ?? '0.0') ?? 0.0,
            "selling_price": double.tryParse(map['selling_price']?.toString() ?? '0.0') ?? 0.0,
            "quantity": int.tryParse(map['quantity']?.toString() ?? '1') ?? 1,
            "image_url": map['image_url'] ?? '',
            "added": true,
          };
        }).toList();

        // 🟢 SYNC CART: One Source of Truth 
        if (processedItems.isNotEmpty && context.mounted) {
           await Provider.of<CartProvider>(context, listen: false).refreshCartData(userId);
        }

        double subtotal = double.tryParse(data['subtotal']?.toString() ?? '0.0') ?? 0.0;
        double finalAmount = double.tryParse(data['final_amount']?.toString() ?? '0.0') ?? 0.0;

        return BotResponse(
          replyText: replyText,
          messageType: messageType,
          avatarState: processedItems.isNotEmpty ? RamuBhaiState.thumbsUp : RamuBhaiState.idle,
          cartItems: processedItems,
          subtotal: subtotal,
          finalAmount: finalAmount,
        );

      } else {
        return BotResponse(
          replyText: "Maaf karna Bhai, network connection mein thodi dikkat hai.",
          avatarState: RamuBhaiState.idle,
        );
      }
    } catch (e) {
      debugPrint("Error in HybridBotService: $e");
      return BotResponse(
        replyText: "Network ya server issue, kripya baad mein try karein.",
        avatarState: RamuBhaiState.idle,
      );
    }
  }
}
