import 'package:flutter/material.dart';
import '../models/chat_message.dart';

enum RamuBhaiState {
  idle,
  listening,
  thinking,
  thumbsUp
}

class BotResponse {
  final String replyText;
  final MessageType messageType;
  final RamuBhaiState avatarState;
  final List<Map<String, dynamic>> cartItems;
  final double subtotal;
  final double finalAmount;

  BotResponse({
    required this.replyText,
    this.messageType = MessageType.text,
    this.avatarState = RamuBhaiState.idle,
    this.cartItems = const [],
    this.subtotal = 0.0,
    this.finalAmount = 0.0,
  });
}

abstract class BotService {
  Future<BotResponse> processMessage(
    String message,
    String userId,
    BuildContext context,
  );
}
