import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';

import '../../CustomWidgets/cart_provider.dart';
import '../../core/supabase.dart';
import '../../data/cart_repository.dart';
import '../../data/catalog_repository.dart';
import '../../data/order_repository.dart';
import '../../utils/colors.dart';
import '../../utils/language_provider.dart';
import 'models/chat_message.dart';
import 'services/bot_service.dart';
import 'services/supabase_bot_service.dart';
import 'widgets/bahi_khata_bill.dart';
import 'widgets/ramu_bhai_avatar.dart';
import '../ProductDetailScreen/product_details_screen.dart';
import '../Checkout/checkout_screen.dart';
import '../CustomWidgets/product_image.dart';

class BolKeOrderScreen extends StatefulWidget {
  const BolKeOrderScreen({Key? key}) : super(key: key);

  @override
  State<BolKeOrderScreen> createState() => _BolKeOrderScreenState();
}

class _BolKeOrderScreenState extends State<BolKeOrderScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  
  // Same BotService contract as before, but the request carries only the message: the
  // Edge Function reads identity from the verified JWT instead of a client-supplied id.
  final BotService _botService = const SupabaseBotService();
  final CartRepository _cart = const CartRepository();
  final CatalogRepository _catalog = const CatalogRepository();
  final OrderRepository _orders = const OrderRepository();

  RamuBhaiState _avatarState = RamuBhaiState.idle;
  String _speechBubbleText = "Namaste Didi! 🙏 Aaj kya bhejna hai? Aap bas likh dijiye ya mic daba kar boliye.";

  bool _isLoading = true;
  List<dynamic> _previousPurchases = [];

  // Speech to Text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _listeningTranscript = "";



  @override
  void initState() {
    super.initState();
    _loadHistory();
    _initializeSpeech();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _speech.stop();
    super.dispose();
  }

  // Initializing speech engine
  void _initializeSpeech() async {
    try {
      await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
              if (_avatarState == RamuBhaiState.listening) {
                _avatarState = RamuBhaiState.idle;
              }
            });
            if (_listeningTranscript.trim().isNotEmpty) {
              _sendMessage(_listeningTranscript);
            }
          }
        },
        onError: (val) {
          setState(() {
            _isListening = false;
            _avatarState = RamuBhaiState.idle;
          });
        },
      );
    } catch (e) {
      debugPrint("Speech init error: $e");
    }
  }

  /// Warms the cart and the "aapka regular" suggestions. Nothing here identifies the
  /// user: the session does, and RLS scopes both reads to their own rows.
  Future<void> _loadHistory() async {
    try {
      if (Db.isSignedIn) {
        // Sync cart provider initial state
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        await cartProvider.refreshCartData();

        // Load last ordered items
        await _fetchLastPurchased();
      }
    } catch (e) {
      debugPrint("Error loading history in BolKeOrder: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLastPurchased() async {
    if (!Db.isSignedIn) return;
    try {
      final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
      final rows = await _orders.regulars();
      if (!mounted) return;
      setState(() {
        // Reshaped to the {'name': ...} entries the suggestion builder already reads, so
        // the chip copy and ordering are unchanged.
        _previousPurchases = rows.map((r) {
          final product = (r['products'] as Map?) ?? const {};
          final hindi = (product['name_hi'] ?? '').toString();
          final english = (product['name'] ?? '').toString();
          return {
            'name': (lang == 'hi' && hindi.isNotEmpty) ? hindi : english,
            'product_id': r['product_id'],
            'variant_id': r['variant_id'],
          };
        }).toList();
      });
    } catch (e) {
      debugPrint("Error loading last purchased: $e");
    }
  }

  List<String> _getDynamicSuggestions() {
    final List<String> suggestions = [];
    
    // 1. Add key commands first
    suggestions.add("bill dikhao");
    suggestions.add("mera regular order");

    // 2. Add short names of previously purchased items
    for (var item in _previousPurchases) {
      final String fullName = item['name'] ?? '';
      if (fullName.isNotEmpty) {
        // Extract first 1-2 words
        final words = fullName.split(',')[0].split(' ');
        final shortName = words.take(2).join(' ');
        final prompt = "$shortName bhej do";
        if (!suggestions.contains(prompt)) {
          suggestions.add(prompt);
        }
      }
    }

    // 3. Add fallbacks if list is small
    final fallbacks = ["2 kilo aata", "1 litre tel", "chai aur biscuit"];
    for (var fallback in fallbacks) {
      if (suggestions.length < 8 && !suggestions.contains(fallback)) {
        suggestions.add(fallback);
      }
    }

    return suggestions;
  }

  void _startListening() async {
    if (!_speech.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice input is not active on this device')),
      );
      return;
    }

    setState(() {
      _isListening = true;
      _avatarState = RamuBhaiState.listening;
      _listeningTranscript = "";
    });

    _speech.listen(
      onResult: (val) {
        setState(() {
          _listeningTranscript = val.recognizedWords;
        });
      },
      localeId: 'hi_IN', // Default to Hindi speech model for Tier 2/3
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
      _avatarState = RamuBhaiState.idle;
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: MessageSender.user,
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _avatarState = RamuBhaiState.thinking;
      _speechBubbleText = "Hisab laga raha hoon, ek second Didi...";
    });
    
    _inputController.clear();
    _scrollToBottom();

    // Call bot logic parser. The empty string is the vestigial userId parameter on the
    // BotService interface: SupabaseBotService ignores it and the function derives the
    // user from the JWT, so there is no id to pass.
    final botResponse = await _botService.processMessage(text, '', context);

    final botMsg = ChatMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      sender: MessageSender.bot,
      text: botResponse.replyText,
      timestamp: DateTime.now(),
      type: botResponse.messageType,
      cartItems: botResponse.cartItems,
      subtotal: botResponse.subtotal,
      finalAmount: botResponse.finalAmount,
    );

    // Refresh history if order confirmed, or just reload history in general
    if (botResponse.messageType == MessageType.orderConfirmed) {
      _fetchLastPurchased();
    }

    setState(() {
      _messages.add(botMsg);
      _avatarState = botResponse.avatarState;
      _speechBubbleText = botResponse.replyText;
    });

    _scrollToBottom();

    if (botResponse.messageType == MessageType.checkout) {
      _navigateToCheckout();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Hands off to checkout. Nothing is carried across any more — no user id, no email,
  /// and none of the amounts the parchi is showing. CheckoutScreen recomputes the
  /// preview from the same cart rows, and the place-order function recomputes the real
  /// totals server-side, so the numbers Ramu Bhai quotes can never become the price.
  void _navigateToCheckout() {
    if (!Db.isSignedIn) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CheckoutScreen(),
      ),
    );
  }

  /// Shared body for the parchi card's quantity controls.
  ///
  /// Both of these used to have no try/catch at all: a failed write — the likely case on
  /// a patchy connection — threw out of the callback and left Ramu Bhai stuck in the
  /// "thinking" pose forever with nothing shown to the user.
  Future<void> _mutateCart(Future<void> Function() action) async {
    setState(() => _avatarState = RamuBhaiState.thinking);
    try {
      await action();
      if (!mounted) return;
      await Provider.of<CartProvider>(context, listen: false).refreshCartData();
      if (!mounted) return;
      // Re-trigger the bill summary.
      await _sendMessage("bill dikhao");
    } catch (e) {
      debugPrint('parchi cart update failed: $e');
      if (!mounted) return;
      setState(() {
        _avatarState = RamuBhaiState.idle;
        _messages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: MessageSender.bot,
            text: 'Maaf karna Bhai, cart update nahi ho paya. Phir se try karein.',
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  // Update quantities directly from the parchi card.
  //
  // The row id alone is enough: the UPDATE policy makes another user's cart row
  // invisible, so a tampered id affects nothing rather than the wrong cart.
  Future<void> _updateQuantityDirectly(int cartItemId, int newQty) =>
      _mutateCart(() => _cart.setQuantity(cartItemId: cartItemId, quantity: newQty));

  // Remove items directly from the parchi card.
  Future<void> _removeItemDirectly(int cartItemId) =>
      _mutateCart(() => _cart.remove(cartItemId));

  Future<void> _openProductDetails(int productId) async {
    if (productId <= 0) return;

    // 1. Dismiss keyboard cleanly and wait for it to slide down to prevent resize glitches
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    bool dialogOpened = true;

    // 2. Show blurry loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent dismissing by back button
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.primaryColor,
                      strokeWidth: 3.w,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      "Samaan ki jankari aa rahi hai...",
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    try {
      final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
      final product = await _catalog.product(productId);

      // 3. Dismiss loading dialog safely
      if (mounted && dialogOpened) {
        Navigator.of(context).pop();
        dialogOpened = false;
      }

      // 4. Wait for dialog fade-out animation to complete to prevent transition collision
      await Future.delayed(const Duration(milliseconds: 250));

      if (product != null) {
        // Same key set the old `single_product_details.php` returned, so the details
        // sheet renders identically.
          final productData = <String, dynamic>{
            'id': product.id,
            'name': product.localizedName(lang),
            'description': product.localizedDescription(lang),
            'main_category_id': product.mainCategoryId,
            'images': product.imageUrls,
            'variants': [
              for (final v in product.variants)
                {
                  'id': v.id,
                  'name': v.localizedName(lang),
                  'price': v.price,
                  'selling_price': v.sellingPrice,
                  'stock': v.stock,
                },
            ],
          };

          if (!mounted) return;

          // 5. Open in a premium bottom-sheet drawer (85% height) to retain chat context
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Stack(
                children: [
                  ProductDetailsScreen(product: productData),
                  // Drag handle indicator
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: EdgeInsets.only(top: 8.h),
                      width: 40.w,
                      height: 5.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
      } else {
        _showErrorSnackBar("Product details missing on server");
      }
    } catch (e) {
      // Dismiss loading dialog if error occurs and it's still open
      if (mounted && dialogOpened) {
        Navigator.of(context).pop();
        dialogOpened = false;
      }
      _showErrorSnackBar("Network issue, please try again");
      debugPrint("Error opening product details: $e");
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: 13.sp, color: Colors.white),
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: const Color(0xFFD2E5DC), // Calm Eucalyptus/Sage Green
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 44.h,
        iconTheme: const IconThemeData(color: Color(0xFF0F4E34)), // Dark forest green icons
        title: Text(
          "Bol Ke Order (बोल के ऑर्डर)",
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F4E34), // Dark forest green text
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: 6.h),
              
              // 1. Ramu Bhai Hero Widget
              RamuBhaiAvatar(
                state: _avatarState,
                speechBubbleText: _isListening 
                    ? "Main sun raha hoon Didi, boliye..." 
                    : (_listeningTranscript.isNotEmpty ? _listeningTranscript : _speechBubbleText),
              ),
              
              SizedBox(height: 4.h),
              
              // 3. Conversational Chat Thread
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg.sender == MessageSender.user;

                    if (isUser) {
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: EdgeInsets.only(left: 40.w, bottom: 10.h),
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16.r),
                              topRight: Radius.circular(16.r),
                              bottomLeft: Radius.circular(16.r),
                            ),
                          ),
                          child: Text(
                            msg.text,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }

                    // Bot visual cards (Bahi Khata, Confirmed Success)
                    if (msg.type == MessageType.cartSummary) {
                      return BahiKhataBill(
                        cartItems: msg.cartItems,
                        subtotal: msg.subtotal,
                        finalAmount: msg.finalAmount,
                        onQuantityChanged: _updateQuantityDirectly,
                        onItemRemoved: _removeItemDirectly,
                        onOrderConfirmed: _navigateToCheckout,
                        isConfirmedView: false,
                      );
                    }

                    if (msg.type == MessageType.orderConfirmed) {
                      return BahiKhataBill(
                        cartItems: msg.cartItems,
                        subtotal: msg.subtotal,
                        finalAmount: msg.finalAmount,
                        onQuantityChanged: (_, __) {},
                        onItemRemoved: (_) {},
                        onOrderConfirmed: () {},
                        isConfirmedView: true,
                      );
                    }

                    // Normal bot text response bubble (with optional cart cards)
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.only(right: 40.w, bottom: 10.h),
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16.r),
                            topRight: Radius.circular(16.r),
                            bottomRight: Radius.circular(16.r),
                          ),
                          border: Border.all(color: AppColors.borderColor, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.text,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            if (msg.cartItems.isNotEmpty) ...[
                              SizedBox(height: 8.h),
                              ...msg.cartItems.map((item) {
                                final double price = double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;
                                final double sellingPrice = double.tryParse(item['selling_price']?.toString() ?? '0.0') ?? 0.0;
                                final String imageUrl = item['image_url'] ?? '';

                                return GestureDetector(
                                  onTap: () => _openProductDetails(int.tryParse(item['product_id']?.toString() ?? '0') ?? 0),
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: 6.h),
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                                    decoration: BoxDecoration(
                                      color: AppColors.neutral50,
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Row(
                                      children: [
                                        // Product Image
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6.r),
                                          child: imageUrl.isNotEmpty
                                              ? ProductImage(
                                                  path: imageUrl,
                                                  width: 36.w,
                                                  height: 36.w,
                                                  fit: BoxFit.cover,
                                                  errorIcon: Icons.shopping_basket,
                                                )
                                              : Container(
                                                  width: 36.w,
                                                  height: 36.w,
                                                  color: Colors.grey.shade200,
                                                  child: Icon(Icons.shopping_basket, size: 18.sp, color: Colors.grey),
                                                ),
                                        ),
                                        SizedBox(width: 8.w),
                                        
                                        // Product Details & Prices
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "${item['name']}",
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 2.h),
                                              Row(
                                                children: [
                                                  Text(
                                                    "₹${sellingPrice.toStringAsFixed(0)}",
                                                    style: TextStyle(
                                                      fontSize: 11.5.sp,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.primaryColor,
                                                  ),
                                                ),
                                                if (price > sellingPrice) ...[
                                                  SizedBox(width: 6.w),
                                                  Text(
                                                    "₹${price.toStringAsFixed(0)}",
                                                    style: TextStyle(
                                                      fontSize: 10.sp,
                                                      color: Colors.grey,
                                                      decoration: TextDecoration.lineThrough,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Quantity
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary100,
                                          borderRadius: BorderRadius.circular(4.r),
                                        ),
                                        child: Text(
                                          "Qty: ${item['quantity']}",
                                          style: TextStyle(
                                            fontSize: 10.5.sp,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryColor,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 6.w),
                                      Icon(Icons.check_circle, color: Colors.green, size: 15.sp),
                                    ],
                                  ),
                                ),
                              );
                              }).toList(),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // 4. Suggested Prompts Horizontal Bar
              Builder(
                builder: (context) {
                  final suggestions = _getDynamicSuggestions();
                  return SizedBox(
                    height: 36.h,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        final isHistory = suggestion.contains("bhej do");
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: ActionChip(
                            backgroundColor: isHistory ? Colors.white : AppColors.neutral100,
                            side: BorderSide(
                              color: isHistory ? AppColors.primaryColor.withOpacity(0.4) : Colors.grey.shade300,
                              width: 0.8,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
                            label: isHistory
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.history, size: 13.sp, color: AppColors.primaryColor),
                                      SizedBox(width: 4.w),
                                      Text(
                                        suggestion,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: AppColors.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    suggestion,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                            onPressed: () {
                              _sendMessage(suggestion);
                            },
                          ),
                        );
                      },
                    ),
                  );
                }
              ),
              
              SizedBox(height: 4.h),
              
              // 5. Input Bar Section
              Container(
                color: Colors.white,
                padding: EdgeInsets.only(
                  left: 12.w,
                  right: 12.w,
                  top: 6.h,
                  bottom: 8.h + MediaQuery.of(context).viewPadding.bottom,
                ),
                child: Row(
                  children: [
                    // Ledger Parchi / Bill Summary Button
                    GestureDetector(
                      onTap: () => _sendMessage("bill dikhao"),
                      child: Container(
                        height: 42.h,
                        width: 42.w,
                        margin: EdgeInsets.only(right: 8.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCFBEB),
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(color: const Color(0xFFD6C885), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: Color(0xff855C08),
                          size: 20,
                        ),
                      ),
                    ),
                    // Text Input
                    Expanded(
                      child: Container(
                        height: 42.h,
                        decoration: BoxDecoration(
                          color: AppColors.neutral50,
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(color: Colors.grey.shade300, width: 1.2),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Center(
                          child: TextField(
                            controller: _inputController,
                            focusNode: _focusNode,
                            style: TextStyle(fontSize: 14.sp),
                            textInputAction: TextInputAction.send,
                            onSubmitted: _sendMessage,
                            decoration: InputDecoration(
                              hintText: "likhiye ya boliye... / लिखिए या बोलिए...",
                              hintStyle: TextStyle(
                                fontSize: 13.sp,
                                color: AppColors.hintTextColor,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(width: 8.w),
                    
                    // Voice Mic or Send Button
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _inputController,
                        builder: (context, value, child) {
                          final hasText = value.text.trim().isNotEmpty;
                          if (hasText) {
                            return FloatingActionButton(
                              key: const ValueKey("send_btn"),
                              mini: true,
                              backgroundColor: AppColors.primaryColor,
                              onPressed: () => _sendMessage(_inputController.text),
                              child: const Icon(Icons.send, color: Colors.white, size: 18),
                            );
                          }
                          
                          // Microphone button with pulse colors
                          return FloatingActionButton(
                            key: const ValueKey("mic_btn"),
                            mini: true,
                            backgroundColor: _isListening ? Colors.red : AppColors.secondaryColor,
                            onPressed: _isListening ? _stopListening : _startListening,
                            child: Icon(
                              _isListening ? Icons.mic_off : Icons.mic,
                              color: _isListening ? Colors.white : Colors.black,
                              size: 18,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Audio Listening Fullscreen overlay
          if (_isListening)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(24.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 12),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic, size: 50.sp, color: Colors.red),
                        SizedBox(height: 16.h),
                        Text(
                          "Didi, main sun raha hoon... 🎙️",
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          _listeningTranscript.isNotEmpty ? _listeningTranscript : "(kuch boliye)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        ElevatedButton(
                          onPressed: _stopListening,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                          ),
                          child: const Text("Stop"),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
