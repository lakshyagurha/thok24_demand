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
import '../../design/haptics.dart';
import '../../utils/colors.dart';
import '../../utils/language_provider.dart';
import 'models/chat_message.dart';
import 'services/bot_service.dart';
import 'services/supabase_bot_service.dart';
import 'widgets/bahi_khata_bill.dart';
import 'widgets/ramu_bhai_avatar.dart';
import 'widgets/candidate_options_card.dart';
import 'widgets/occasion_bundle_card.dart';
import '../ProductDetailScreen/product_details_screen.dart';
import '../Checkout/checkout_screen.dart';
import '../CustomWidgets/product_image.dart';
import '../BottomNav/bottomNavScreen.dart';

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
  /// A request is in flight. Gates sending and drives the typing indicator.
  bool _isSending = false;
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
            // Consume the transcript before dispatching.
            //
            // speech_to_text emits BOTH 'notListening' (audio ended) and
            // 'done' (session finalised) for a single utterance, and this
            // handler fires on either. The transcript was only ever cleared in
            // _startListening, so every stop sent the same sentence twice —
            // which is why the thread filled with duplicate pairs.
            final pending = _listeningTranscript.trim();
            _listeningTranscript = '';
            if (pending.isNotEmpty) {
              _sendMessage(pending);
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
    
    // 1. Add key commands and occasion shortcuts first
    suggestions.add("bill dikhao");
    suggestions.add("mera regular order");
    suggestions.add("Ganesh Puja kit");
    suggestions.add("Chai nashta bhej do");

    // 2. Add short names of previously purchased items
    for (var item in _previousPurchases) {
      final String fullName = item['name'] ?? '';
      if (fullName.isNotEmpty) {
        final words = fullName.split(',')[0].split(' ');
        final shortName = words.take(2).join(' ');
        final prompt = "$shortName bhej do";
        if (!suggestions.contains(prompt)) {
          suggestions.add(prompt);
        }
      }
    }

    // 3. Add fallbacks if list is small
    final fallbacks = ["2 kilo aata", "1 litre tel", "monthly ration"];
    for (var fallback in fallbacks) {
      if (suggestions.length >= 8) break;
      if (!suggestions.contains(fallback)) {
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

    AppHaptics.tap();
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
    AppHaptics.selection();
    _speech.stop();
    setState(() {
      _isListening = false;
      _avatarState = RamuBhaiState.idle;
    });
  }

  /// Monotonic, so a user message and the bot reply that follows it in the same
  /// millisecond cannot share an id.
  int _msgSeq = 0;
  String _nextId() => '${DateTime.now().microsecondsSinceEpoch}-${_msgSeq++}';

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    // One request at a time. Nothing stopped a second send while the first was
    // in flight, so replies could arrive out of order and land under the wrong
    // question.
    if (_isSending) return;

    final userMsg = ChatMessage(
      id: _nextId(),
      sender: MessageSender.user,
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _isSending = true;
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
      id: _nextId(),
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
      AppHaptics.success();
      _fetchLastPurchased();
    } else if (botResponse.messageType == MessageType.cartSummary) {
      AppHaptics.tap();
    }

    setState(() {
      _isSending = false;
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
  /// Adjusts one item straight from its card in the chat.
  ///
  /// Goes through CartProvider — the app's single cart writer — so the
  /// bottom-nav badge and every other open stepper stay in step. The card is
  /// updated locally rather than by re-asking the server, so the number moves
  /// under the finger.
  Future<void> _nudgeItem(Map<String, dynamic> item, int delta) async {
    final productId = (item['product_id'] as num?)?.toInt();
    if (productId == null) return;
    final variantId = (item['variant_id'] as num?)?.toInt();
    final current = (item['quantity'] as num?)?.toInt() ?? 1;
    final target = current + delta;
    if (target < 0) return;

    AppHaptics.selection();
    final cart = Provider.of<CartProvider>(context, listen: false);
    final result = await cart.changeQuantity(
      productId: productId,
      variantId: variantId,
      delta: delta,
      imagePath: (item['image_url'] ?? '').toString(),
    );
    if (!mounted || result != CartMutation.ok) return;

    setState(() => item['quantity'] = target);
    await _refreshBillInPlace();
  }

  /// Re-reads the cart and rewrites the newest bill/item message in place.
  ///
  /// Keeps the transcript honest: adjusting a quantity edits the parchi you are
  /// looking at instead of pushing another copy of it down the thread.
  Future<void> _refreshBillInPlace() async {
    try {
      final lines = await _cart.items();
      if (!mounted) return;

      final idx = _messages.lastIndexWhere(
        (m) =>
            m.type == MessageType.cartSummary ||
            (m.sender == MessageSender.bot && m.cartItems.isNotEmpty),
      );
      if (idx < 0) return;

      final items = lines.map((l) => l.toCartMap()).toList();
      final subtotal = lines.fold<double>(
        0,
        (sum, l) => sum + l.sellingPrice * l.quantity,
      );

      setState(() {
        final old = _messages[idx];
        _messages[idx] = ChatMessage(
          id: old.id,
          sender: old.sender,
          text: old.text,
          timestamp: old.timestamp,
          type: old.type,
          cartItems: items,
          subtotal: subtotal,
          // Charges are the server's to compute; showing a stale total is worse
          // than showing none, so let the bill widget fall back to the subtotal.
          finalAmount: old.finalAmount,
        );
      });
    } catch (e) {
      debugPrint('bill refresh failed: $e');
    }
  }

  /// Applies a cart change locally.
  ///
  /// This used to finish with `_sendMessage("bill dikhao")`, so every tap on a
  /// +/- injected a fake *user* message into the transcript and paid for a full
  /// edge-function round trip before the number moved. The cart is local state;
  /// changing it is not a thing you say to the shopkeeper.
  Future<void> _mutateCart(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      await Provider.of<CartProvider>(context, listen: false).refreshCartData();
      if (!mounted) return;
      // Update the bill already on screen in place, rather than appending a new
      // one for every tap.
      await _refreshBillInPlace();
    } catch (e) {
      debugPrint('parchi cart update failed: $e');
      if (!mounted) return;
      setState(() {
        _avatarState = RamuBhaiState.idle;
        _messages.add(
          ChatMessage(
            id: _nextId(),
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
        toolbarHeight: 48.h,
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(6.r),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16.sp,
              color: const Color(0xFF0F4E34),
            ),
          ),
          onPressed: () {
            AppHaptics.tap();
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              BottomNavScreen.openTab.value = 0;
            }
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Bol Ke Order",
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F4E34),
              ),
            ),
            SizedBox(width: 6.w),
            Text(
              "(बोल के ऑर्डर)",
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F4E34).withValues(alpha: 0.8),
              ),
            ),
          ],
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

                    if (msg.type == MessageType.optionsChoice || msg.type == MessageType.substituteOffer) {
                      return CandidateOptionsCard(
                        candidates: msg.candidateItems,
                        onSelectOption: _sendMessage,
                      );
                    }

                    if (msg.type == MessageType.bundleSummary) {
                      return OccasionBundleCard(
                        items: msg.cartItems.isNotEmpty ? msg.cartItems : msg.candidateItems,
                        headerTitle: msg.text,
                        onAddBundleToCart: _sendMessage,
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
                                      
                                      // Quantity, adjustable.
                                      //
                                      // This was a read-only "Qty: n" chip, so
                                      // the only way to correct a misheard
                                      // amount was to say it again — which
                                      // adds rather than sets, and made two
                                      // kilos into four. Tapping is the honest
                                      // control.
                                      _InlineQty(
                                        quantity: (item['quantity'] as num?)?.toInt() ?? 1,
                                        onChanged: (delta) => _nudgeItem(item, delta),
                                      ),
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
                  return Container(
                    height: 38.h,
                    margin: EdgeInsets.only(bottom: 4.h),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        final isHistory = suggestion.contains("bhej do");
                        final isBill = suggestion.contains("bill");
                        
                        return Container(
                          margin: EdgeInsets.only(right: 6.w),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                AppHaptics.selection();
                                _sendMessage(suggestion);
                              },
                              borderRadius: BorderRadius.circular(18.r),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: isHistory
                                      ? const Color(0xFFF0F7F3)
                                      : (isBill ? const Color(0xFFFFFBEB) : Colors.white),
                                  border: Border.all(
                                    color: isHistory
                                        ? const Color(0xFF2E6F40).withValues(alpha: 0.4)
                                        : (isBill ? const Color(0xFFD6C885) : Colors.grey.shade300),
                                    width: 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(18.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isHistory
                                          ? Icons.history_rounded
                                          : (isBill ? Icons.receipt_long_rounded : Icons.auto_awesome_rounded),
                                      size: 13.sp,
                                      color: isHistory
                                          ? const Color(0xFF2E6F40)
                                          : (isBill ? const Color(0xFF855C08) : Colors.grey.shade700),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      suggestion,
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: isHistory
                                            ? const Color(0xFF2E6F40)
                                            : (isBill ? const Color(0xFF855C08) : Colors.black87),
                                        fontWeight: isHistory ? FontWeight.w600 : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
              ),
              
              SizedBox(height: 2.h),
              
              // 5. WhatsApp-Style Input Bar Section (Single Clean Pill with + Button)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: EdgeInsets.only(
                  left: 8.w,
                  right: 8.w,
                  top: 8.h,
                  bottom: 10.h + MediaQuery.of(context).viewPadding.bottom,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Single Seamless Input Capsule (No Inner Box!)
                    Expanded(
                      child: Container(
                        constraints: BoxConstraints(minHeight: 46.h, maxHeight: 110.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F2), // Calm light sage tint
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(color: const Color(0xFFD6E4DD), width: 1.0),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // '+' Add Image / Parchi Attachment Button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  AppHaptics.tap();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(Icons.photo_camera_outlined, color: Colors.white, size: 18.sp),
                                          SizedBox(width: 8.w),
                                          Text("Parchi photo option (Coming soon)", style: TextStyle(fontSize: 12.5.sp)),
                                        ],
                                      ),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                      margin: EdgeInsets.all(16.w),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(20.r),
                                child: Container(
                                  padding: EdgeInsets.all(8.r),
                                  child: Icon(
                                    Icons.add_rounded,
                                    color: const Color(0xFF0F4E34),
                                    size: 22.sp,
                                  ),
                                ),
                              ),
                            ),
                            
                            // Multi-line Text Field (100% borderless, no inner box)
                            Expanded(
                              child: TextField(
                                controller: _inputController,
                                focusNode: _focusNode,
                                maxLines: 4,
                                minLines: 1,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w400,
                                ),
                                textInputAction: TextInputAction.send,
                                onSubmitted: _sendMessage,
                                decoration: InputDecoration(
                                  hintText: "likhiye ya boliye... / लिखिए या बोलिए...",
                                  hintStyle: TextStyle(
                                    fontSize: 13.sp,
                                    color: Colors.grey.shade500,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 10.h),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(width: 8.w),
                    
                    // Circular Action Button (Voice Mic or Send Arrow)
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _inputController,
                      builder: (context, value, child) {
                        final hasText = value.text.trim().isNotEmpty;
                        
                        return GestureDetector(
                          onTap: () {
                            AppHaptics.tap();
                            if (hasText) {
                              _sendMessage(_inputController.text);
                            } else {
                              if (_isListening) {
                                _stopListening();
                              } else {
                                _startListening();
                              }
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 46.r,
                            height: 46.r,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isListening
                                  ? Colors.red.shade600
                                  : (hasText
                                      ? AppColors.primaryColor
                                      : const Color(0xFF0F4E34)), // Forest Green for mic
                              boxShadow: [
                                BoxShadow(
                                  color: (_isListening ? Colors.red : const Color(0xFF0F4E34)).withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 150),
                                child: Icon(
                                  hasText
                                      ? Icons.send_rounded
                                      : (_isListening ? Icons.mic_off_rounded : Icons.mic_rounded),
                                  key: ValueKey("${hasText}_$_isListening"),
                                  color: Colors.white,
                                  size: 21.sp,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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

/// Compact +/- for an item card inside the chat.
///
/// Deliberately not the shared [QtyStepper]: that one is sized for a product
/// grid and would dominate a chat bubble. The tap targets are still held to the
/// 44dp minimum — the parchi's existing steppers are ~26dp, which is below what
/// a thumb can reliably hit.
class _InlineQty extends StatelessWidget {
  const _InlineQty({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.remove_rounded, () => onChanged(-1),
            semantic: 'Ek kam karein'),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Text(
            '$quantity',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryColor,
            ),
          ),
        ),
        _btn(Icons.add_rounded, () => onChanged(1), semantic: 'Ek aur'),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, {required String semantic}) {
    return Semantics(
      button: true,
      label: semantic,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 28.w,
          height: 28.w,
          // The visible chip is small, but the hit area is padded out to a
          // comfortable target.
          margin: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: AppColors.primary100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15.sp, color: AppColors.primaryColor),
        ),
      ),
    );
  }
}
