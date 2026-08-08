enum MessageSender {
  user,
  bot
}

enum MessageType {
  text,
  cartSummary,      // Displayed as Bahi Khata / Parchi
  orderConfirmed,   // Displayed as Order Confirmed Success Card
  checkout,         // Triggers navigation to checkout page
  optionsChoice,    // Displayed as Interactive Brand Comparison Cards
  bundleSummary,    // Displayed as Occasion Bundle Parchi (e.g. Ganesh Puja)
  substituteOffer,  // Displayed as Out-of-Stock Alternative Offer Card
}

class ChatMessage {
  final String id;
  final MessageSender sender;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final List<Map<String, dynamic>> cartItems;
  final List<Map<String, dynamic>> candidateItems;
  final double subtotal;
  final double finalAmount;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.type = MessageType.text,
    this.cartItems = const [],
    this.candidateItems = const [],
    this.subtotal = 0.0,
    this.finalAmount = 0.0,
  });

  ChatMessage copyWith({
    String? id,
    MessageSender? sender,
    String? text,
    DateTime? timestamp,
    MessageType? type,
    List<Map<String, dynamic>>? cartItems,
    List<Map<String, dynamic>>? candidateItems,
    double? subtotal,
    double? finalAmount,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      cartItems: cartItems ?? this.cartItems,
      candidateItems: candidateItems ?? this.candidateItems,
      subtotal: subtotal ?? this.subtotal,
      finalAmount: finalAmount ?? this.finalAmount,
    );
  }
}

