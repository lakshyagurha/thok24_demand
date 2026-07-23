import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../BottomNav/Screens/order_screen.dart';
import '../DeliveryAddress/delivery_address_screen.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';
import '../utils/language_provider.dart';

class CheckoutScreen extends StatefulWidget {
  final double saveAmount;
  final double finalWithCharge;
  final String userId;
  final String userEmail;
  final String userName;
  final String giftName;
  final double deliveyCharge;
  final double handlingCharge;
  final String coupon_code_name;

  CheckoutScreen({
    required this.saveAmount,
    required this.finalWithCharge,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.giftName,
    required this.deliveyCharge,
    required this.handlingCharge,
    required this.coupon_code_name,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late DateTime selectedMonth;
  DateTime? selectedDate;
  String fullAddress = "";
  String location_id = "";
  int selectedIndex = 1;
  String selectedTimeSlot = '';
  String selectedPaymentMethod = 'cod'; // 'cod' or 'upi'
  String selectedUpiApp = ''; // For storing selected UPI app
  bool _isPlacingOrder = false; // Track if order is being placed

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

  @override
  void initState() {
    super.initState();
    selectedMonth = DateTime.now();
    selectedDate = DateTime.now();
    selectedTimeSlot = timeSlots[selectedIndex];

    // Initialize localDates with current month days
    _updateLocalDates();
    _loadSelectedAddress();
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

  // Listen for address updates when returning to this screen
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSelectedAddress();
  }

  Future<void> _loadSelectedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      location_id = prefs.getString('selected_address_id') ?? "";
      fullAddress = prefs.getString('selected_address_full') ?? "";
    });
  }

  Future<void> placeOrder({
    required String userId,
    required String couponCode,
    required double discountAmount,
    required double deliveryCharge,
    required double handlingCharge,
    required String paymentMethod,
    required String deliveryDate,
    required String deliverTime,
    required String dateTimeNow,
    required String locationId,
    required double famount,
    required BuildContext context,
  }) async {
    // Validate address
    if (locationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(context, listen: false).translate('please_select_address'),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isPlacingOrder = true; // Show progress indicator
    });

    final url = Uri.parse(ApiConstants.PLACE_ORDER);

    final body = {
      "user_id": userId,
      "coupon_code": couponCode,
      "discount_amount": discountAmount.toString(),
      "delivery_charge": deliveryCharge.toString(),
      "handling_charge": handlingCharge.toString(),
      "payment_method": paymentMethod,
      "dateTimeNow": dateTimeNow,
      "deliveryDate": deliveryDate,
      "deliverTime": deliverTime,
      "location_id": locationId,
      "famount": famount.toString(),
      "gift" : widget.giftName.toString(),
      "user_email" : widget.userEmail.toString(),
      "user_name" : widget.userName.toString(),
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      setState(() {
        _isPlacingOrder = false; // Hide progress indicator
      });

      if (data['success'] == true) {
        print("✅ Order placed successfully!");

        // Clear cart or perform other success actions here

        // Show success dialog
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
                    Provider.of<LanguageProvider>(context, listen: false).translate('order_placed'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => OrderScreen()),
                      );
                    },
                    child: Container(
                      width: 120.w,
                      height: 27.h,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(7.r),
                      ),
                      child: Center(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              Provider.of<LanguageProvider>(context, listen: false).translate('view_order'),
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
                ],
              ),
            );
          },
        );
      } else {
        print("❌ Failed: ${data['message']}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order failed: ${data['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isPlacingOrder = false; // Hide progress indicator on error
      });

      print("⚠️ Error placing order: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error placing order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            color: AppColors.primaryColor,
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
          color: AppColors.primaryColor,
          size: 18.sp,
        ),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryTextColor,
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
            color: AppColors.neutral600,
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
                    : AppColors.primaryTextColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
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
                          color: AppColors.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          size: 18.sp,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      Provider.of<LanguageProvider>(context).translate('checkout'),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryTextColor,
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
                            border: Border.all(color: AppColors.borderColor, width: 1.w),
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
                                      fullAddress.isNotEmpty
                                          ? fullAddress
                                          : Provider.of<LanguageProvider>(context).translate('no_address'),
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: fullAddress.isNotEmpty ? AppColors.neutral700 : Colors.red,
                                        fontWeight: fullAddress.isNotEmpty ? FontWeight.w500 : FontWeight.bold,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  InkWell(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DeliveryAddressScreen(),
                                        ),
                                      );
                                      _loadSelectedAddress();
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Text(
                                        fullAddress.isNotEmpty
                                            ? Provider.of<LanguageProvider>(context).translate('change')
                                            : Provider.of<LanguageProvider>(context).translate('select'),
                                        style: TextStyle(
                                          color: AppColors.primaryColor,
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
                            border: Border.all(color: AppColors.borderColor, width: 1.w),
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
                                      color: AppColors.primaryTextColor,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.arrow_back_ios, size: 16.sp, color: AppColors.primaryColor),
                                        onPressed: () => changeMonth(-1),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      SizedBox(width: 16.w),
                                      IconButton(
                                        icon: Icon(Icons.arrow_forward_ios, size: 16.sp, color: AppColors.primaryColor),
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
                                              ? AppColors.primaryColor
                                              : isAvailable
                                                  ? Colors.white
                                                  : AppColors.neutral100,
                                          borderRadius: BorderRadius.circular(12.r),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primaryColor
                                                : isAvailable
                                                    ? AppColors.borderColor
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
                                                        ? AppColors.neutral500
                                                        : AppColors.neutral400,
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
                                                        ? AppColors.primaryTextColor
                                                        : AppColors.neutral400,
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
                            border: Border.all(color: AppColors.borderColor, width: 1.w),
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
                                        setState(() {
                                          selectedIndex = index;
                                          selectedTimeSlot = timeSlots[index];
                                        });
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.primaryColor.withOpacity(0.06) : Colors.white,
                                          borderRadius: BorderRadius.circular(10.r),
                                          border: Border.all(
                                            color: isSelected ? AppColors.primaryColor : AppColors.borderColor,
                                            width: 1.5.w,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.schedule,
                                              color: isSelected ? AppColors.primaryColor : AppColors.neutral500,
                                              size: 18.sp,
                                            ),
                                            SizedBox(width: 12.w),
                                            Text(
                                              timeSlots[index],
                                              style: TextStyle(
                                                fontSize: 13.sp,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                color: isSelected ? AppColors.primaryColor : AppColors.primaryTextColor,
                                              ),
                                            ),
                                            const Spacer(),
                                            Radio<int>(
                                              value: index,
                                              groupValue: selectedIndex,
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setState(() {
                                                    selectedIndex = val;
                                                    selectedTimeSlot = timeSlots[val];
                                                  });
                                                }
                                              },
                                              activeColor: AppColors.primaryColor,
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
                            border: Border.all(color: AppColors.borderColor, width: 1.w),
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
                                  setState(() {
                                    selectedPaymentMethod = 'cod';
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16.w),
                                  decoration: BoxDecoration(
                                    color: selectedPaymentMethod == 'cod' ? AppColors.primaryColor.withOpacity(0.06) : Colors.white,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: selectedPaymentMethod == 'cod' ? AppColors.primaryColor : AppColors.borderColor,
                                      width: 1.5.w,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: 'cod',
                                        groupValue: selectedPaymentMethod,
                                        onChanged: (value) {
                                          setState(() {
                                            selectedPaymentMethod = value!;
                                          });
                                        },
                                        activeColor: AppColors.primaryColor,
                                      ),
                                      SizedBox(width: 8.w),
                                      Image.asset(
                                        'assets/images/case.png',
                                        width: 28.w,
                                        height: 28.h,
                                        errorBuilder: (_, __, ___) => Icon(Icons.money, size: 28.sp, color: AppColors.primaryColor),
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
                                                    color: AppColors.primaryTextColor,
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
                                                color: AppColors.neutral500,
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
                                  setState(() {
                                    selectedPaymentMethod = 'upi';
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16.w),
                                  decoration: BoxDecoration(
                                    color: selectedPaymentMethod == 'upi' ? AppColors.primaryColor.withOpacity(0.06) : Colors.white,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: selectedPaymentMethod == 'upi' ? AppColors.primaryColor : AppColors.borderColor,
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
                                              setState(() {
                                                selectedPaymentMethod = value!;
                                              });
                                            },
                                            activeColor: AppColors.primaryColor,
                                          ),
                                          SizedBox(width: 8.w),
                                          Icon(Icons.account_balance_wallet_outlined, size: 24.sp, color: AppColors.primaryColor),
                                          SizedBox(width: 12.w),
                                          Text(
                                            Provider.of<LanguageProvider>(context).translate('pay_upi'),
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (selectedPaymentMethod == 'upi') ...[
                                        SizedBox(height: 12.h),
                                        Divider(height: 1.h, color: AppColors.borderColor),
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
                                                    activeColor: AppColors.primaryColor,
                                                  ),
                                                  SizedBox(width: 8.w),
                                                  Container(
                                                    width: 36.w,
                                                    height: 24.h,
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: AppColors.borderColor),
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
                                        }).toList(),
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
                            border: Border.all(color: AppColors.borderColor, width: 1.w),
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
                                  color: AppColors.primaryTextColor,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              _buildSummaryRow(
                                Provider.of<LanguageProvider>(context).translate('delivery_charge'),
                                widget.deliveyCharge == 0
                                    ? Provider.of<LanguageProvider>(context).translate('free')
                                    : '₹${widget.deliveyCharge.toStringAsFixed(0)}',
                                isFree: widget.deliveyCharge == 0,
                              ),
                              SizedBox(height: 8.h),
                              _buildSummaryRow(
                                Provider.of<LanguageProvider>(context).translate('handling_charge'),
                                '₹${widget.handlingCharge.toStringAsFixed(0)}',
                              ),
                              if (widget.coupon_code_name.isNotEmpty && widget.coupon_code_name != "null" && widget.coupon_code_name != "") ...[
                                SizedBox(height: 8.h),
                                _buildSummaryRow(
                                  'Coupon Code',
                                  widget.coupon_code_name,
                                ),
                              ],
                              SizedBox(height: 10.h),
                              Divider(height: 1.h, color: AppColors.borderColor),
                              SizedBox(height: 10.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    Provider.of<LanguageProvider>(context).translate('total_to_pay'),
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryTextColor,
                                    ),
                                  ),
                                  Text(
                                    '₹${widget.finalWithCharge.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.saveAmount > 0) ...[
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
                                        '${Provider.of<LanguageProvider>(context).translate('you_save')} ₹${widget.saveAmount.toStringAsFixed(0)} ${Provider.of<LanguageProvider>(context).translate('on_this_order')}',
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
                    if (location_id.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            Provider.of<LanguageProvider>(context, listen: false).translate('please_select_address'),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (selectedPaymentMethod == 'upi') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('UPI payment not enabled yet'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (selectedPaymentMethod == 'cod') {
                      placeOrder(
                        userId: widget.userId,
                        couponCode: widget.coupon_code_name,
                        discountAmount: widget.saveAmount,
                        deliveryCharge: widget.deliveyCharge,
                        handlingCharge: widget.handlingCharge,
                        paymentMethod: 'COD',
                        deliveryDate: selectedDate != null
                            ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                            : DateFormat('yyyy-MM-dd').format(DateTime.now()),
                        deliverTime: selectedTimeSlot,
                        dateTimeNow: DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now()),
                        locationId: location_id,
                        famount: widget.finalWithCharge,
                        context: context,
                      );
                    }
                  },
                  child: Container(
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: location_id.isEmpty ? Colors.grey : AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(
                      child: Text(
                        _isPlacingOrder
                            ? Provider.of<LanguageProvider>(context).translate('placing_order')
                            : '${Provider.of<LanguageProvider>(context).translate('place_order_btn')}: ₹${widget.finalWithCharge.toStringAsFixed(0)} →',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
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
                          AppColors.primaryColor,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        Provider.of<LanguageProvider>(context).translate('placing_order'),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryTextColor,
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
}