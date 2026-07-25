import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../Help/help_screen.dart';
import '../data/catalog_repository.dart';
import '../data/models.dart';
import '../data/order_repository.dart';
import '../utils/colors.dart';

class TrackOrder extends StatefulWidget {
  /// The order being tracked. Its live status is re-read from the server rather than
  /// trusted from whatever the list screen happened to be showing.
  final int orderId;

  /// Status already known by the caller, used only so the timeline renders instantly
  /// while [OrderRepository.byId] is in flight.
  final String status;

  const TrackOrder({
    super.key,
    required this.orderId,
    this.status = '',
  });

  @override
  State<TrackOrder> createState() => _TrackOrderState();
}

class _TrackOrderState extends State<TrackOrder> {
  final _orders = const OrderRepository();
  final _catalog = const CatalogRepository();

  int currentStep = 0;
  String deliveryTime = '0';

  @override
  void initState() {
    super.initState();
    _setCurrentStepFromStatus(widget.status);
    _loadOrder();
    fetchDeliveryTime();
  }

  /// Re-reads the order. RLS scopes `orders` to the signed-in user, so an id belonging
  /// to somebody else simply comes back null instead of leaking their order.
  Future<void> _loadOrder() async {
    try {
      final Order? order = await _orders.byId(widget.orderId);
      if (!mounted || order == null) return;
      setState(() => _setCurrentStepFromStatus(order.status));
    } catch (e) {
      debugPrint("Error loading order: $e");
    }
  }

  /// The estimated-delivery figure used to be its own single-row table and endpoint;
  /// it is now one key in app_settings.
  Future<void> fetchDeliveryTime() async {
    try {
      final settings = await _catalog.settings();
      if (!mounted) return;
      final value = settings['delivery_time'];
      setState(() {
        deliveryTime = (value == null || value.isEmpty) ? 'No time found' : value;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        deliveryTime = 'Error fetching time';
      });
    }
  }

  void _setCurrentStepFromStatus(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        currentStep = 0;
        break;
      case "packed":
        currentStep = 1;
        break;
      case "way":
        currentStep = 2;
        break;
      case "delivered":
        currentStep = 3;
        break;
      default:
        currentStep = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),


          // Header
          Container(
            width: double.infinity,
            height: 60.h,
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: Offset(0, 4.h),
                  blurRadius: 6.r,
                  spreadRadius: 1.r,
                ),
              ],
            ),
            child: Padding(
              padding:  EdgeInsets.only(top: 10.h),
              child: Row(
                children: [
                  SizedBox(width: 16.w),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 25.h,
                      width: 28.w,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(left: 7.w),
                          child: Icon(Icons.arrow_back_ios,color: AppColors.iconColor, size: 15.sp),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    "Track Order",
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  Spacer(),
                  InkWell(
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>HelpScreen()));
                    },
                    child: Container(
                      height: 25.h,
                      width: 28.w,
                      decoration: BoxDecoration(

                        borderRadius: BorderRadius.circular(100.r),
                      ),
                      child: Center(
                        child: Icon(Icons.help_outline,color: AppColors.searchBorderHome, size: 22.sp),
                      ),
                    ),
                  ),
                  SizedBox(width: 20.w,),

                ],
              ),
            ),
          ),

          // Estimated Delivery Card
          Padding(
            padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 30.h),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppColors.primaryColor,
                  width: 1.3.w,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    Text(
                      "Estimated Delivery",
                      style:
                      TextStyle(fontSize: 12.sp, color: Colors.black),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      formatDeliveryTime(deliveryTime),
                      style: TextStyle(
                        fontSize: 36.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.searchBorderHome,
                      ),
                    ),
                    Text(
                      "Minutes",
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: AppColors.searchBorderHome,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 10.h),

          // Order Steps
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 40.w),
              child: ListView(
                children: [
                  orderStep(
                    stepIndex: 0,
                    icon: "🛒",
                    title: "Order Placed",
                    subtitle: "We have received your order",
                  ),
                  orderStep(
                    stepIndex: 1,
                    icon: "📦",
                    title: "Order Packed",
                    subtitle: "Your product is packed and ready to ship",
                  ),
                  orderStep(
                    stepIndex: 2,
                    icon: "🛵",
                    title: "On the way",
                    subtitle:
                    "Our delivery partner will soon deliver the product",
                  ),
                  orderStep(
                    stepIndex: 3,
                    icon: "📦",
                    title: "Product Delivered",
                    subtitle:
                    "Your order has been delivered to your provided address.",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget orderStep({
    required int stepIndex,
    required String icon,
    required String title,
    required String subtitle,
  }) {
    bool isCompleted = stepIndex <= currentStep;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step line and circle
        Column(
          children: [
            Container(
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.searchBorderHome : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: isCompleted
                  ? Icon(Icons.check, color: AppColors.backgroundColor, size: 16.sp)
                  : null,
            ),
            if (stepIndex != 3)
              Container(
                width: 3.w,
                height: 70.h,
                color:
                stepIndex < currentStep ? Colors.orange : Colors.grey[300],
              ),
          ],
        ),
        SizedBox(width: 15.w),

        // Step content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(icon, style: TextStyle(fontSize: 18.sp)),
                  SizedBox(width: 6.w),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style:
                TextStyle(fontSize: 12.sp, color: Colors.black54),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ],
    );
  }
  String formatDeliveryTime(String input) {
    input = input.replaceAll(' ', '');
    final match = RegExp(r'^(\d+)([a-zA-Z]+)').firstMatch(input);

    if (match != null) {
      final number = match.group(1) ?? '';
      final unit = match.group(2)?.substring(0, 0).toUpperCase() ?? '';
      return '$number $unit';
    } else {
      return input.substring(0, input.length.clamp(0, 6)).toUpperCase();
    }
  }
}
