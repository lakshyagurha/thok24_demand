import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../utils/colors.dart';

class OrderSummary extends StatelessWidget {
  final Map orderMap;
  const OrderSummary({super.key, required this.orderMap});

  @override
  Widget build(BuildContext context) {
    final orderData = orderMap["order"] ?? {};
    final orderItems = (orderMap["items"] ?? []) as List;

    final finalAmount = double.tryParse(orderData['final_amount']?.toString() ?? "0") ?? 0;
    final itemsTotal = double.tryParse(orderData['total_amount']?.toString() ?? "0") ?? finalAmount;
    final discount = double.tryParse(orderData['discount_amount']?.toString() ?? "0") ?? 0;
    final handling = double.tryParse(orderData['handling_charge']?.toString() ?? "0") ?? 0;
    final delivery = double.tryParse(orderData['delivery_charge']?.toString() ?? "0") ?? 0;
    final deliveryDate = orderData['delivery_date']?.toString() ?? "";
    final gift = orderData['gift']?.toString() ?? "";
    final deliveryTime = orderData['delivery_time']?.toString() ?? "";
    final status = orderData['status']?.toString() ?? "Pending";
    final paymentMethod = orderData['payment_method']?.toString() ?? "COD";

    // Address Details
    final addressName = orderData['address_name']?.toString() ?? "";
    final addressPhone = orderData['address_phone']?.toString() ?? "";
    final fullAddress = orderData['full_address']?.toString() ?? "";
    final pinCode = orderData['pin_code']?.toString() ?? "";
    final landmark = orderData['landmark']?.toString() ?? "";

    final rawDate = deliveryDate.toString();
    final parsedDate = DateTime.tryParse(rawDate);
    final formattedDate = parsedDate != null
        ? DateFormat("dd MMM yyyy").format(parsedDate)
        : rawDate;

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
                    if (orderData['id'] != null)
                      Text(
                        "Order #000${orderData['id']}",
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
                  if (gift.isNotEmpty && gift.toLowerCase() != "null") ...[
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
                                  gift,
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
                            final item = orderItems[index];
                            final price = double.tryParse(item['selling_price']?.toString() ?? "0") ?? 0;
                            final mrp = double.tryParse(item['price']?.toString() ?? "0") ?? price;

                            final variantPrice = double.tryParse(item?['price']?.toString() ?? "0") ?? 0;
                            final variantSellingPrice = double.tryParse(item?['selling_price']?.toString() ?? "0") ?? 0;

                            final discountPercentage = (variantPrice > 0 && variantSellingPrice > 0)
                                ? (((variantPrice - variantSellingPrice) / variantPrice) * 100).round()
                                : 0;

                            return Padding(
                              padding: EdgeInsets.all(12.w),
                              child: Row(
                                children: [
                                  // Product Image Thumbnail
                                  Stack(
                                    children: [
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
                                              item['image_url'] ?? "",
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
                                      if (discountPercentage > 0)
                                        Positioned(
                                          top: 0,
                                          left: 0,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                                            decoration: BoxDecoration(
                                              color: AppColors.secondaryColor,
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(8.r),
                                                bottomRight: Radius.circular(8.r),
                                              ),
                                            ),
                                            child: Text(
                                              '$discountPercentage% OFF',
                                              style: TextStyle(
                                                fontSize: 8.sp,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryTextColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(width: 12.w),
                                  // Product Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['product_name'] ?? "",
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
                                          "${item['variant_name'] ?? ''}  •  ${item['quantity'] ?? '1'} Unit${(int.tryParse(item['quantity']?.toString() ?? '1') ?? 1) > 1 ? 's' : ''}",
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
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "₹${price.toStringAsFixed(0)}",
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryTextColor,
                                        ),
                                      ),
                                      if (mrp > price) ...[
                                        SizedBox(height: 2.h),
                                        Text(
                                          "₹${mrp.toStringAsFixed(0)}",
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            color: AppColors.neutral400,
                                            decoration: TextDecoration.lineThrough,
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
                  if (fullAddress.isNotEmpty) ...[
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
                          if (addressName.isNotEmpty) ...[
                            Text(
                              addressName,
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
                              fullAddress,
                              if (landmark.isNotEmpty) "Landmark: $landmark",
                              if (pinCode.isNotEmpty) "Pin: $pinCode",
                            ].join(", "),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.neutral600,
                              height: 1.3,
                            ),
                          ),
                          if (addressPhone.isNotEmpty) ...[
                            SizedBox(height: 6.h),
                            Text(
                              "Phone: $addressPhone",
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
                          _billRow("Discount", "-₹${discount.toStringAsFixed(0)}", valueColor: AppColors.success500),
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