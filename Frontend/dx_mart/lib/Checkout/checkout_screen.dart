import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../BottomNav/Screens/order_screen.dart';
import '../CustomWidgets/cart_provider.dart';
import '../DeliveryAddress/delivery_address_screen.dart';
import '../OrderSummary/order_summary.dart';
import '../core/supabase.dart';
import '../data/cart_repository.dart';
import '../data/catalog_repository.dart';
import '../data/models.dart';
import '../data/order_repository.dart';
import '../design/app_colors.dart';
import '../design/app_type.dart';
import '../design/haptics.dart';
import '../utils/language_provider.dart';

/// Checkout.
///
/// The screen takes no user id, no email and no amounts. Identity comes from the
/// Supabase session, and every rupee in the placed order is recomputed server-side by
/// the place-order Edge Function. The figures rendered here before the tap are a
/// PREVIEW, derived from the same cart rows and the same app_settings the server reads;
/// nothing about money is ever sent.
class CheckoutScreen extends StatefulWidget {
  /// Optional gift note carried over from the cart / BolKeOrder flows.
  final String giftName;

  /// Code the user chose in the cart. Passed through verbatim; the server decides
  /// whether it is valid and what it is worth.
  final String couponCode;

  const CheckoutScreen({
    super.key,
    this.giftName = '',
    this.couponCode = '',
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressRepo = const AddressRepository();
  final _orderRepo = const OrderRepository();
  final _cartRepo = const CartRepository();
  final _catalog = const CatalogRepository();

  late DateTime selectedMonth;
  DateTime? selectedDate;

  List<Address> _addresses = [];
  Address? _selectedAddress;

  int selectedIndex = 1;
  String selectedTimeSlot = '';
  String selectedPaymentMethod = 'cod'; // 'cod' or 'upi'
  String selectedUpiApp = ''; // For storing selected UPI app
  bool _isPlacingOrder = false; // Track if order is being placed

  /// One key per checkout attempt, reused across retries of that attempt so a lost
  /// response cannot become a second order. Rotated only after an order succeeds.
  String _idempotencyKey = newUuidV4();

  // ---- Local PREVIEW only. Never sent anywhere. --------------------------------
  double _subtotal = 0;
  double _itemSavings = 0;
  double _deliveryCharge = 0;
  double _handlingCharge = 0;
  double _couponDiscount = 0;

  /// False until [_loadPreview] has actually produced numbers. Without this the screen
  /// rendered a confident "Place Order: ₹0" whenever the preview request failed, and the
  /// button stayed tappable — the customer would be shown ₹0 and charged the real total.
  bool _previewReady = false;
  String? _previewError;

  double get _previewTotal =>
      _subtotal - _couponDiscount + _deliveryCharge + _handlingCharge;

  double get _previewSavings => _itemSavings + _couponDiscount;

  List<DateTime> localDates = [];

  final List<String> timeSlots = ['6 AM - 8 AM', '9 AM - 2 PM', '2 PM - 8 PM'];

  // UPI apps data
  final List<Map<String, dynamic>> upiApps = [
    {
      'name': 'PhonePe UPI',
      'icon': 'assets/images/phonepe.png',
      'id': 'phonepe',
    },
    {'name': 'Google Pay UPI', 'icon': 'assets/images/gpay.png', 'id': 'gpay'},
    {'name': 'Paytm UPI', 'icon': 'assets/images/paytm.png', 'id': 'paytm'},
    {
      'name': 'Add new UPI ID',
      'icon': 'assets/images/upi.png',
      'id': 'new_upi',
    },
  ];

  String? get _couponCode {
    final code = widget.couponCode.trim();
    // The cart screen used to stringify a null selection, so "null" arrives as text.
    if (code.isEmpty || code.toLowerCase() == 'null') return null;
    return code;
  }

  String? get _gift {
    final gift = widget.giftName.trim();
    if (gift.isEmpty || gift.toLowerCase() == 'null' || gift == 'noGift') {
      return null;
    }
    return gift;
  }

  String get _fullAddress => _selectedAddress?.fullAddress ?? '';

  @override
  void initState() {
    super.initState();
    selectedMonth = DateTime.now();
    selectedDate = DateTime.now();
    selectedTimeSlot = timeSlots[selectedIndex];

    // Initialize localDates with current month days
    _updateLocalDates();
    _loadAddresses();
    _loadPreview();
  }

  // Update local dates based on selected month
  void _updateLocalDates() {
    final daysInMonth = DateUtils.getDaysInMonth(
      selectedMonth.year,
      selectedMonth.month,
    );
    localDates = List.generate(
      daysInMonth,
          (index) => DateTime(selectedMonth.year, selectedMonth.month, index + 1),
    );

    // Filter out past dates (only keep today and future dates)
    final today = DateTime.now();
    localDates =
        localDates.where((date) {
          return date.isAfter(
            today.subtract(Duration(days: 1)),
          ); // Include today
        }).toList();
  }

  /// Addresses come from the database, scoped by RLS to the signed-in user, so the id
  /// handed to place-order can only ever be one of the caller's own.
  Future<void> _loadAddresses() async {
    try {
      final addresses = await _addressRepo.list();
      if (!mounted) return;

      // The address screen remembers the last pick locally; treat it as a hint only and
      // fall back to the first address the server actually returned.
      final prefs = await SharedPreferences.getInstance();
      final rememberedId = int.tryParse(
        prefs.getString('selected_address_id') ?? '',
      );
      if (!mounted) return;

      setState(() {
        _addresses = addresses;
        _selectedAddress = addresses.isEmpty
            ? null
            : addresses.firstWhere(
                (a) => a.id == rememberedId,
                orElse: () => addresses.first,
              );
      });
    } catch (e) {
      debugPrint("Error loading addresses: $e");
    }
  }

  /// Builds the running bill shown before the user commits. Deliberately mirrors the
  /// Edge Function's arithmetic so the preview and the receipt agree, but the server's
  /// numbers are the ones that count -- see [_placeOrder].
  Future<void> _loadPreview() async {
    try {
      final lines = await _cartRepo.items();
      final settings = await _catalog.settings();
      if (!mounted) return;

      double subtotal = 0;
      double savings = 0;
      for (final CartLine l in lines) {
        subtotal += l.lineTotal;
        if (l.price > l.sellingPrice) {
          savings += (l.price - l.sellingPrice) * l.quantity;
        }
      }

      double setting(String key, double fallback) {
        final raw = settings[key];
        if (raw == null) return fallback;
        return double.tryParse(raw) ?? fallback;
      }

      final freeDeliveryOver = setting('free_delivery_threshold', 500);
      final delivery =
          subtotal >= freeDeliveryOver ? 0.0 : setting('delivery_charge', 10);
      final handling = setting('handling_charge', 5);

      final discount = await _previewCouponDiscount(subtotal);
      if (!mounted) return;

      setState(() {
        _subtotal = subtotal;
        _itemSavings = savings;
        _deliveryCharge = delivery;
        _handlingCharge = handling;
        _couponDiscount = discount;
        _previewReady = true;
        _previewError = null;
      });
    } catch (e) {
      debugPrint("Error building order preview: $e");
      if (!mounted) return;
      setState(() {
        _previewReady = false;
        _previewError = 'Could not load your bill. Check your connection.';
      });
    }
  }

  /// Best-effort preview of a coupon. Only public codes can be looked up from a client;
  /// a privately shared code still redeems, it just shows no discount until the server
  /// confirms it. The server is the only thing that actually applies a discount.
  Future<double> _previewCouponDiscount(double subtotal) async {
    final code = _couponCode;
    if (code == null) return 0;
    try {
      final coupons = await _catalog.publicCoupons();
      final match = coupons.where(
        (c) => c.codeName.toLowerCase() == code.toLowerCase(),
      );
      if (match.isEmpty) return 0;
      final coupon = match.first;
      if (coupon.expiryDate != null &&
          coupon.expiryDate!.isBefore(DateTime.now())) {
        return 0;
      }
      if (subtotal < coupon.minAmount) return 0;
      // `discount` is a percentage, matching the place-order function.
      final value = subtotal * (coupon.discount / 100);
      return value > subtotal ? subtotal : value;
    } catch (e) {
      debugPrint("Coupon preview unavailable: $e");
      return 0;
    }
  }

  /// Places the order.
  ///
  /// Sends only: which address, when, how they intend to pay, the coupon code and the
  /// gift note. No user id, no email, and no amounts -- the old endpoint took
  /// `final_amount` straight from this request body, which let a client name its own
  /// price. What comes back is the server's authoritative [Order], and that is what the
  /// confirmation shows.
  Future<void> _placeOrder() async {
    final language = Provider.of<LanguageProvider>(context, listen: false);

    if (!Db.isSignedIn) {
      _showError('Please sign in first.');
      return;
    }

    final address = _selectedAddress;
    if (address == null) {
      _showError(language.translate('please_select_address'));
      return;
    }

    // Refuse to submit against a bill we could not compute. The button is already
    // disabled in this state; this is the belt to that braces.
    if (!_previewReady) {
      _showError(_previewError ?? 'Could not load your bill. Please try again.');
      _loadPreview();
      return;
    }

    setState(() {
      _isPlacingOrder = true; // Show progress indicator
    });

    try {
      final Order order = await _orderRepo.place(
        deliveryAddressId: address.id,
        // Constant across retries of this attempt: if the response to a previous try was
        // lost after the server had already committed, this returns that same order
        // instead of creating a second one.
        idempotencyKey: _idempotencyKey,
        deliveryDate: selectedDate ?? DateTime.now(),
        deliveryTimeWindow: selectedTimeSlot,
        // 'COD' and 'RAZORPAY' are the only values the server accepts. Razorpay
        // settlement is confirmed by the payment webhook, not by this client.
        paymentMethod: selectedPaymentMethod == 'upi' ? 'RAZORPAY' : 'COD',
        couponCode: _couponCode,
        gift: _gift,
      );

      // This attempt is finished, so the next one is a genuinely new order.
      _idempotencyKey = newUuidV4();

      if (!mounted) return;

      // The server already emptied the cart; this just resyncs the local badge/state.
      await context.read<CartProvider>().refreshCartData();

      if (!mounted) return;
      AppHaptics.success();
      _showSuccessDialog(order);
    } on DataException catch (e) {
      // Bad, expired or below-minimum coupons land here with a message meant for the
      // user, as do empty carts, out-of-stock items and addresses that are not theirs.
      if (!mounted) return;
      _showError(e.message);
      // Stock and coupon rejections change what the bill should say, so re-derive it.
      _loadPreview();
    } catch (e) {
      if (!mounted) return;
      debugPrint("Error placing order: $e");
      _showError('Could not place the order. Please try again.');
    } finally {
      // In a finally rather than repeated on each exit path: a future `return` added
      // anywhere in the try block would otherwise leave the button disabled forever.
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  void _showError(String message) {
    AppHaptics.error();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Confirmation. Every figure here is [order]'s -- the server's -- not the preview
  /// this screen computed.
  void _showSuccessDialog(Order order) {
    final language = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/success.json',
                width: 200,
                height: 200,
                repeat: false,
              ),
              SizedBox(height: 10.h),
              Text(
                language.translate('order_placed'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Order #000${order.id}  •  ₹${order.finalAmount.toStringAsFixed(0)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              if (order.discountAmount > 0) ...[
                SizedBox(height: 4.h),
                Text(
                  '${language.translate('you_save')} ₹${order.discountAmount.toStringAsFixed(0)} ${language.translate('on_this_order')}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
              SizedBox(height: 20.h),
              InkWell(
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderSummary(order: order),
                    ),
                  );
                },
                child: Container(
                  width: 120.w,
                  height: 27.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(7.r),
                  ),
                  child: Center(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          language.translate('view_order'),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 7.w),
                        SvgPicture.asset(
                          'assets/svg/arrow.svg',
                          color: Colors.white, // High contrast white arrow
                          width: 15.w,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              InkWell(
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const OrderScreen()),
                  );
                },
                child: Text(
                  'My Orders',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void changeMonth(int offset) {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + offset,
        1,
      );
      _updateLocalDates();

      // By default select first available date of month
      if (localDates.isNotEmpty) {
        selectedDate = localDates.first;
      }
    });
  }

  bool isDayAvailable(DateTime date) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);

    return normalizedDate.isAtSameMomentAs(normalizedToday) ||
        normalizedDate.isAfter(normalizedToday);
  }

  void updateSelectedDate(DateTime date) {
    AppHaptics.selection();
    setState(() {
      selectedDate = date;
    });
  }

  Widget _buildStepHeader(String stepNum, String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 26.w,
          height: 26.w,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNum,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Icon(
          icon,
          color: AppColors.primary,
          size: 18.sp,
        ),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isFree = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: (isFree || isDiscount) ? FontWeight.bold : FontWeight.w600,
            color: isFree
                ? Colors.green
                : isDiscount
                    ? Colors.green
                    : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 10.h),
              // Header
              Container(
                width: double.infinity,
                height: 50.h,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        height: 30.h,
                        width: 30.w,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          size: 18.sp,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      Provider.of<LanguageProvider>(context).translate('checkout'),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 100.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 12.h),

                        // STEP 1: Delivery Address
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.border, width: 1.w),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStepHeader("1", Provider.of<LanguageProvider>(context).translate('delivery_address'), Icons.home_outlined),
                              SizedBox(height: 12.h),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _fullAddress.isNotEmpty
                                          ? _fullAddress
                                          : Provider.of<LanguageProvider>(context).translate('no_address'),
                                      style: _fullAddress.isNotEmpty
                                          ? AppText.bodyM(
                                              color: AppColors.textSecondary)
                                          : AppText.bodyM(
                                              color: AppColors.danger),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  InkWell(
                                    onTap: () async {
                                      if (_addresses.length > 1) {
                                        final picked = await _showAddressPicker();
                                        if (picked != null) {
                                          setState(() => _selectedAddress = picked);
                                          return;
                                        }
                                        if (!context.mounted) return;
                                      }
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DeliveryAddressScreen(),
                                        ),
                                      );
                                      _loadAddresses();
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Text(
                                        _fullAddress.isNotEmpty
                                            ? Provider.of<LanguageProvider>(context).translate('change')
                                            : Provider.of<LanguageProvider>(context).translate('select'),
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // STEP 2: Choose Delivery Date
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.border, width: 1.w),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStepHeader("2", Provider.of<LanguageProvider>(context).translate('choose_delivery_date'), Icons.calendar_month_outlined),
                              SizedBox(height: 12.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat.yMMMM().format(selectedMonth),
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.arrow_back_ios, size: 16.sp, color: AppColors.primary),
                                        onPressed: () => changeMonth(-1),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      SizedBox(width: 16.w),
                                      IconButton(
                                        icon: Icon(Icons.arrow_forward_ios, size: 16.sp, color: AppColors.primary),
                                        onPressed: () => changeMonth(1),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              SizedBox(
                                height: 58.h,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: localDates.length,
                                  itemBuilder: (context, index) {
                                    final date = localDates[index];
                                    final isSelected = selectedDate?.day == date.day &&
                                        selectedDate?.month == date.month &&
                                        selectedDate?.year == date.year;
                                    final isAvailable = isDayAvailable(date);

                                    return GestureDetector(
                                      onTap: isAvailable ? () => updateSelectedDate(date) : null,
                                      child: Container(
                                        width: 50.w,
                                        margin: EdgeInsets.only(right: 8.w),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.primary
                                              : isAvailable
                                                  ? Colors.white
                                                  : AppColors.surfaceSunken,
                                          borderRadius: BorderRadius.circular(12.r),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primary
                                                : isAvailable
                                                    ? AppColors.border
                                                    : Colors.transparent,
                                            width: 1.5.w,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              DateFormat('EEE').format(date).toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? Colors.white
                                                    : isAvailable
                                                        ? AppColors.textTertiary
                                                        : AppColors.textTertiary,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              date.day.toString().padLeft(2, '0'),
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? Colors.white
                                                    : isAvailable
                                                        ? AppColors.textPrimary
                                                        : AppColors.textTertiary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // STEP 3: Choose Time Slot
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.border, width: 1.w),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStepHeader("3", Provider.of<LanguageProvider>(context).translate('choose_delivery_time'), Icons.access_time),
                              SizedBox(height: 16.h),
                              Column(
                                children: List.generate(timeSlots.length, (index) {
                                  final isSelected = selectedIndex == index;
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 8.h),
                                    child: InkWell(
                                      onTap: () {
                                        AppHaptics.selection();
                                        setState(() {
                                          selectedIndex = index;
                                          selectedTimeSlot = timeSlots[index];
                                        });
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.primary.withOpacity(0.06) : Colors.white,
                                          borderRadius: BorderRadius.circular(10.r),
                                          border: Border.all(
                                            color: isSelected ? AppColors.primary : AppColors.border,
                                            width: 1.5.w,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.schedule,
                                              color: isSelected ? AppColors.primary : AppColors.textTertiary,
                                              size: 18.sp,
                                            ),
                                            SizedBox(width: 12.w),
                                            Text(
                                              timeSlots[index],
                                              style: TextStyle(
                                                fontSize: 13.sp,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                              ),
                                            ),
                                            const Spacer(),
                                            Radio<int>(
                                              value: index,
                                              groupValue: selectedIndex,
                                              onChanged: (val) {
                                                if (val != null) {
                                                  AppHaptics.selection();
                                                  setState(() {
                                                    selectedIndex = val;
                                                    selectedTimeSlot = timeSlots[val];
                                                  });
                                                }
                                              },
                                              activeColor: AppColors.primary,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),

                        // STEP 4: Select Payment Method
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.border, width: 1.w),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStepHeader("4", Provider.of<LanguageProvider>(context).translate('select_payment'), Icons.payment_outlined),
                              SizedBox(height: 16.h),

                              // COD FIRST - highlighted as recommended
                              InkWell(
                                onTap: () {
                                  AppHaptics.selection();
                                  setState(() {
                                    selectedPaymentMethod = 'cod';
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16.w),
                                  decoration: BoxDecoration(
                                    color: selectedPaymentMethod == 'cod' ? AppColors.primary.withOpacity(0.06) : Colors.white,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: selectedPaymentMethod == 'cod' ? AppColors.primary : AppColors.border,
                                      width: 1.5.w,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: 'cod',
                                        groupValue: selectedPaymentMethod,
                                        onChanged: (value) {
                                          AppHaptics.selection();
                                          setState(() {
                                            selectedPaymentMethod = value!;
                                          });
                                        },
                                        activeColor: AppColors.primary,
                                      ),
                                      SizedBox(width: 8.w),
                                      Image.asset(
                                        'assets/images/case.png',
                                        width: 28.w,
                                        height: 28.h,
                                        errorBuilder: (_, __, ___) => Icon(Icons.money, size: 28.sp, color: AppColors.primary),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  Provider.of<LanguageProvider>(context).translate('cash_on_delivery'),
                                                  style: TextStyle(
                                                    fontSize: 13.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                SizedBox(width: 6.w),
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    borderRadius: BorderRadius.circular(4.r),
                                                  ),
                                                  child: Text(
                                                    'BEST',
                                                    style: TextStyle(
                                                      fontSize: 8.sp,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              Provider.of<LanguageProvider>(context).translate('cod_subtitle'),
                                              style: TextStyle(
                                                fontSize: 11.sp,
                                                color: AppColors.textTertiary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              SizedBox(height: 12.h),

                              // UPI options Collapsible Card
                              InkWell(
                                onTap: () {
                                  AppHaptics.selection();
                                  setState(() {
                                    selectedPaymentMethod = 'upi';
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16.w),
                                  decoration: BoxDecoration(
                                    color: selectedPaymentMethod == 'upi' ? AppColors.primary.withOpacity(0.06) : Colors.white,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: selectedPaymentMethod == 'upi' ? AppColors.primary : AppColors.border,
                                      width: 1.5.w,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Radio<String>(
                                            value: 'upi',
                                            groupValue: selectedPaymentMethod,
                                            onChanged: (value) {
                                              AppHaptics.selection();
                                              setState(() {
                                                selectedPaymentMethod = value!;
                                              });
                                            },
                                            activeColor: AppColors.primary,
                                          ),
                                          SizedBox(width: 8.w),
                                          Icon(Icons.account_balance_wallet_outlined, size: 24.sp, color: AppColors.primary),
                                          SizedBox(width: 12.w),
                                          Text(
                                            Provider.of<LanguageProvider>(context).translate('pay_upi'),
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (selectedPaymentMethod == 'upi') ...[
                                        SizedBox(height: 12.h),
                                        Divider(height: 1.h, color: AppColors.border),
                                        SizedBox(height: 12.h),
                                        ...upiApps.map((app) {
                                          final isAppSelected = selectedUpiApp == app['id'];
                                          return InkWell(
                                            onTap: () {
                                              setState(() {
                                                selectedUpiApp = app['id'];
                                              });
                                            },
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(vertical: 8.h),
                                              child: Row(
                                                children: [
                                                  Radio<String>(
                                                    value: app['id'],
                                                    groupValue: selectedUpiApp,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        selectedUpiApp = value!;
                                                      });
                                                    },
                                                    activeColor: AppColors.primary,
                                                  ),
                                                  SizedBox(width: 8.w),
                                                  Container(
                                                    width: 36.w,
                                                    height: 24.h,
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: AppColors.border),
                                                      borderRadius: BorderRadius.circular(4.r),
                                                    ),
                                                    child: Padding(
                                                      padding: EdgeInsets.all(2.w),
                                                      child: Image.asset(
                                                        app['icon'],
                                                        fit: BoxFit.contain,
                                                        errorBuilder: (_, __, ___) => Icon(Icons.credit_card, size: 16.sp),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 12.w),
                                                  Text(
                                                    app['name'],
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      fontWeight: isAppSelected ? FontWeight.bold : FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Order Summary Card
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.border, width: 1.w),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Provider.of<LanguageProvider>(context).translate('order_summary'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.sp,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              _buildSummaryRow(
                                Provider.of<LanguageProvider>(context).translate('delivery_charge'),
                                _deliveryCharge == 0
                                    ? Provider.of<LanguageProvider>(context).translate('free')
                                    : '₹${_deliveryCharge.toStringAsFixed(0)}',
                                isFree: _deliveryCharge == 0,
                              ),
                              SizedBox(height: 8.h),
                              _buildSummaryRow(
                                Provider.of<LanguageProvider>(context).translate('handling_charge'),
                                '₹${_handlingCharge.toStringAsFixed(0)}',
                              ),
                              if (_couponCode != null) ...[
                                SizedBox(height: 8.h),
                                _buildSummaryRow(
                                  'Coupon Code',
                                  _couponCode!,
                                ),
                              ],
                              SizedBox(height: 10.h),
                              Divider(height: 1.h, color: AppColors.border),
                              SizedBox(height: 10.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    Provider.of<LanguageProvider>(context).translate('total_to_pay'),
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '₹${_previewTotal.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              if (_previewSavings > 0) ...[
                                SizedBox(height: 10.h),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.green,
                                        size: 16.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        '${Provider.of<LanguageProvider>(context).translate('you_save')} ₹${_previewSavings.toStringAsFixed(0)} ${Provider.of<LanguageProvider>(context).translate('on_this_order')}',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Sticky Bottom Place Order Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: InkWell(
                  onTap: () {
                    if (_isPlacingOrder) return;

                    if (_selectedAddress == null) {
                      _showError(
                        Provider.of<LanguageProvider>(context, listen: false)
                            .translate('please_select_address'),
                      );
                      return;
                    }

                    if (selectedPaymentMethod == 'upi') {
                      // Razorpay is not wired into this screen yet; the webhook that
                      // confirms payment exists, the client-side checkout does not.
                      _showError('UPI payment not enabled yet');
                      return;
                    }

                    _placeOrder();
                  },
                  child: Container(
                    height: 48.h,
                    decoration: BoxDecoration(
                      // Also disabled while the bill is unknown, so we never
                      // invite a tap on a total we could not compute.
                      color: (_selectedAddress == null || !_previewReady)
                          ? AppColors.disabledSurface
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(
                      child: Text(
                        _isPlacingOrder
                            ? Provider.of<LanguageProvider>(context).translate('placing_order')
                            : !_previewReady
                                ? Provider.of<LanguageProvider>(context).translate('loading_bill')
                                : '${Provider.of<LanguageProvider>(context).translate('place_order_btn')}: ₹${_previewTotal.toStringAsFixed(0)} →',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.button(color: AppColors.onPrimary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Order placement progress indicator (blocking screen)
          if (_isPlacingOrder)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  width: 140.w,
                  height: 120.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        Provider.of<LanguageProvider>(context).translate('placing_order'),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Lets the user switch between the addresses the server returned, without leaving
  /// checkout. Adding or editing still goes to the address screen.
  Future<Address?> _showAddressPicker() {
    return showModalBottomSheet<Address>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  Provider.of<LanguageProvider>(context, listen: false)
                      .translate('delivery_address'),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final address = _addresses[index];
                    return ListTile(
                      leading: Icon(
                        address.id == _selectedAddress?.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: AppColors.primary,
                        size: 18.sp,
                      ),
                      title: Text(
                        address.name,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        address.fullAddress,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onTap: () => Navigator.pop(sheetContext, address),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DeliveryAddressScreen(),
                      ),
                    );
                    _loadAddresses();
                  },
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 16.sp, color: AppColors.primary),
                      SizedBox(width: 8.w),
                      Text(
                        Provider.of<LanguageProvider>(context, listen: false)
                            .translate('delivery_address'),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        );
      },
    );
  }
}
