import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../core/supabase.dart';
import '../data/models.dart';
import '../utils/colors.dart';

/// Read-only view of one order.
///
/// Everything shown here is the server's own arithmetic, read back from `orders`. The
/// screen never recomputes a total: the place-order Edge Function is the only thing that
/// decides what an order costs.
class OrderSummary extends StatefulWidget {
  final Order order;
  const OrderSummary({super.key, required this.order});

  @override
  State<OrderSummary> createState() => _OrderSummaryState();
}

class _OrderSummaryState extends State<OrderSummary> {
  // Gift note and the delivery address are not part of the shared order graph, so they
  // are read separately. RLS scopes `orders` to the caller, and the address is reached
  // through the order row, so this cannot surface anyone else's details.
  String _gift = "";
  String _addressName = "";
  String _addressPhone = "";
  String _fullAddress = "";
  String _pinCode = "";
  String _landmark = "";

  @override
  void initState() {
    super.initState();
    _loadDeliveryDetails();
  }

  Future<void> _loadDeliveryDetails() async {
    try {
      final row = await Db.client
          .from('orders')
          .select(
            'gift, delivery_address(name, phone, full_address, pin_code, landmark)',
          )
          .eq('id', widget.order.id)
          .maybeSingle();
      if (!mounted || row == null) return;

      final address = row['delivery_address'] as Map?;
      setState(() {
        _gift = (row['gift'] ?? "") as String;
        _addressName = ((address?['name']) ?? "") as String;
        _addressPhone = ((address?['phone']) ?? "") as String;
        _fullAddress = ((address?['full_address']) ?? "") as String;
        _pinCode = ((address?['pin_code']) ?? "") as String;
        _landmark = ((address?['landmark']) ?? "") as String;
      });
    } catch (e) {
      debugPrint("Error loading order delivery details: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final orderItems = order.items;

    final finalAmount = order.finalAmount;
    final itemsTotal = order.totalAmount;
    final discount = order.discountAmount;
    final handling = order.handlingCharge;
    final delivery = order.deliveryCharge;
    final deliveryTime = order.deliveryTimeWindow ?? "";
    final status = order.status;
    final paymentMethod = order.paymentMethod;

    final formattedDate = order.deliveryDate != null
        ? DateFormat("dd MMM yyyy").format(order.deliveryDate!)
        : DateFormat("dd MMM yyyy").format(order.orderedAt);

    return Scaffold(
      backgroundColor: AppColors.neutral100,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // White status bar area
          Container(
            color: Colors.white,
            height: MediaQuery.of(context).padding.top,
          ),
          // Clean & Premium Header
          Container(
            width: double.infinity,
            height: 56.h,
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
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 32.h,
                    width: 32.w,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.arrow_back,
                        color: AppColors.primaryColor,
                        size: 18.sp,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Order Summary",
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                    Text(
                      "Order #000${order.id}",
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.neutral500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable Contents
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner Card
                  _buildStatusCard(status, formattedDate, deliveryTime),

                  // Gift Banner (If exists)
                  if (_gift.isNotEmpty && _gift.toLowerCase() != "null") ...[
                    Container(
                      margin: EdgeInsets.only(left: 14.w, right: 14.w, top: 12.h),
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color: AppColors.success50.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.success100),
                      ),
                      child: Row(
                        children: [
                          Text("🎁", style: TextStyle(fontSize: 18.sp)),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Free Gift Included!",
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success500,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  _gift,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: AppColors.neutral700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Items List Card
                  Container(
                    margin: EdgeInsets.only(left: 14.w, right: 14.w, top: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(14.w),
                          child: Text(
                            "${orderItems.length} Item${orderItems.length > 1 ? 's' : ''} in this order",
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryTextColor,
                            ),
                          ),
                        ),
                        Divider(color: AppColors.neutral100, height: 1.h, thickness: 1),
                        ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: orderItems.length,
                          separatorBuilder: (context, index) => Divider(
                            color: AppColors.neutral100,
                            height: 1.h,
                            thickness: 1,
                          ),
                          itemBuilder: (context, index) {
                            final OrderLine item = orderItems[index];
                            // What the line actually cost when it was ordered. Null for
                            // orders migrated from the old backend, which recorded no
                            // per-line price -- show nothing rather than guess from the
                            // current catalog price.
                            final unitPrice = item.unitPrice;

                            return Padding(
                              padding: EdgeInsets.all(12.w),
                              child: Row(
                                children: [
                                  // Product Image Thumbnail
                                  Container(
                                    width: 54.h,
                                    height: 54.h,
                                    decoration: BoxDecoration(
                                      color: AppColors.neutral50,
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(color: AppColors.neutral200.withOpacity(0.5)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8.r),
                                      child: Center(
                                        child: Image.network(
                                          item.imageUrl,
                                          width: 44.w,
                                          height: 44.h,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) => Icon(
                                            Icons.image_not_supported_outlined,
                                            size: 20.sp,
                                            color: AppColors.neutral400,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  // Product Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productName,
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryTextColor,
                                            height: 1.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          "${item.quantity} Unit${item.quantity > 1 ? 's' : ''}",
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            color: AppColors.neutral500,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  // Price
                                  if (unitPrice != null)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "₹${(unitPrice * item.quantity).toStringAsFixed(0)}",
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryTextColor,
                                          ),
                                        ),
                                        if (item.quantity > 1) ...[
                                          SizedBox(height: 2.h),
                                          Text(
                                            "₹${unitPrice.toStringAsFixed(0)} each",
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              color: AppColors.neutral400,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Delivery Address Card (If exists)
                  if (_fullAddress.isNotEmpty) ...[
                    Container(
                      margin: EdgeInsets.only(left: 14.w, right: 14.w, top: 12.h),
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: AppColors.primaryColor,
                                size: 18.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                "Delivery Address",
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryTextColor,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          if (_addressName.isNotEmpty) ...[
                            Text(
                              _addressName,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryTextColor,
                              ),
                            ),
                            SizedBox(height: 4.h),
                          ],
                          Text(
                            [
                              _fullAddress,
                              if (_landmark.isNotEmpty) "Landmark: $_landmark",
                              if (_pinCode.isNotEmpty) "Pin: $_pinCode",
                            ].join(", "),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.neutral600,
                              height: 1.3,
                            ),
                          ),
                          if (_addressPhone.isNotEmpty) ...[
                            SizedBox(height: 6.h),
                            Text(
                              "Phone: $_addressPhone",
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.neutral500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Bill Details Card
                  Container(
                    margin: EdgeInsets.only(left: 14.w, right: 14.w, top: 12.h, bottom: 24.h),
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              color: AppColors.primaryColor,
                              size: 18.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              "Bill Details",
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        _billRow("Items total", "₹${itemsTotal.toStringAsFixed(0)}"),
                        if (handling > 0)
                          _billRow("Handling Charge", "₹${handling.toStringAsFixed(0)}"),
                        _billRow(
                          "Delivery Charge",
                          delivery == 0 ? "Free" : "₹${delivery.toStringAsFixed(0)}",
                          valueColor: delivery == 0 ? AppColors.success500 : null,
                        ),
                        if (discount > 0)
                          _billRow(
                            order.couponCode == null || order.couponCode!.isEmpty
                                ? "Discount"
                                : "Discount (${order.couponCode})",
                            "-₹${discount.toStringAsFixed(0)}",
                            valueColor: AppColors.success500,
                          ),
                        _billRow("Payment Method", paymentMethod),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: Divider(color: AppColors.neutral100, height: 1.h, thickness: 1),
                        ),
                        _billRow("Total Amount", "₹${finalAmount.toStringAsFixed(0)}", isBold: true),
                        if (discount > 0) ...[
                          SizedBox(height: 10.h),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 10.w),
                            decoration: BoxDecoration(
                              color: AppColors.success50,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.savings_outlined,
                                  color: AppColors.success500,
                                  size: 14.sp,
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  "You saved ₹${discount.toStringAsFixed(0)} on this order!",
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success500,
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
        ],
      ),
    );
  }

  Widget _buildStatusCard(String status, String formattedDate, String deliveryTime) {
    final isCancelled = status.toLowerCase().contains('cancel');
    final isDelivered = status.toLowerCase().contains('deliver') || status.toLowerCase().contains('complete');

    Color statusColor = AppColors.primaryColor;
    IconData statusIcon = Icons.local_shipping_rounded;
    String title = "Order Placed";
    String subtitle = "Scheduled: $formattedDate • $deliveryTime";

    if (isCancelled) {
      statusColor = AppColors.error500;
      statusIcon = Icons.cancel_rounded;
      title = "Order Cancelled";
      subtitle = "This order was cancelled";
    } else if (isDelivered) {
      statusColor = AppColors.success500;
      statusIcon = Icons.check_circle_rounded;
      title = "Delivered Successfully";
      subtitle = "Arrived on $formattedDate • $deliveryTime";
    } else {
      statusColor = AppColors.warning500;
      statusIcon = Icons.local_shipping_rounded;
      title = "Order $status";
      subtitle = "Expected: $formattedDate • $deliveryTime";
    }

    return Container(
      margin: EdgeInsets.only(left: 14.w, right: 14.w, top: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 22.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryTextColor,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.neutral500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _billRow(String title, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              color: isBold ? AppColors.primaryTextColor : AppColors.neutral600,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 14.sp : 12.sp,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? AppColors.primaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
