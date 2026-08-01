import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../design/haptics.dart';
import '../../utils/colors.dart';

class BahiKhataBill extends StatelessWidget {
  final List<Map<String, dynamic>> cartItems;
  final double subtotal;
  final double finalAmount;
  final Function(int cartItemId, int newQty) onQuantityChanged;
  final Function(int cartItemId) onItemRemoved;
  final VoidCallback onOrderConfirmed;
  final bool isConfirmedView;

  const BahiKhataBill({
    Key? key,
    required this.cartItems,
    required this.subtotal,
    required this.finalAmount,
    required this.onQuantityChanged,
    required this.onItemRemoved,
    required this.onOrderConfirmed,
    this.isConfirmedView = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (cartItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculations
    final double deliveryCharge = subtotal < 500 ? 10.0 : 0.0;
    final double handlingCharge = 5.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 2.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFBEB), // Ledger Yellow tint
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
        border: Border.all(
          color: const Color(0xFFEFE8B5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Receipt Top
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isConfirmedView ? "सफल आर्डर (SUCCESS)" : "कच्चा बिल (PARCHI)",
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.bold,
                    color: isConfirmedView ? AppColors.primaryColor : const Color(0xff855C08),
                  ),
                ),
                Text(
                  isConfirmedView ? "आर्डर बुक हो गया" : "बही खाता",
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: const DottedLine(
              dashColor: Color(0xFFD6C885),
              lineThickness: 1.2,
            ),
          ),
          
          // Items list
          ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(vertical: 4.h),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cartItems.length,
            itemBuilder: (context, index) {
              final item = cartItems[index];
              final cartItemId = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
              final pName = item['product_name'] ?? item['name'] ?? '';
              final vName = item['variant_name'] ?? item['name'] ?? '';
              final sellingPrice = double.tryParse(item['selling_price']?.toString() ?? '0') ?? 0.0;
              final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
                child: Row(
                  children: [
                    // Item Detail
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pName,
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "$vName  x  ₹${sellingPrice.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Quantity adjustments
                    if (!isConfirmedView && cartItemId > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (quantity > 1) {
                                AppHaptics.selection();
                                onQuantityChanged(cartItemId, quantity - 1);
                              } else {
                                AppHaptics.tap();
                                onItemRemoved(cartItemId);
                              }
                            },
                            child: Padding(
                              padding: EdgeInsets.all(4.r),
                              child: Icon(Icons.remove_circle_outline, size: 18.sp, color: Colors.red),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            "$quantity",
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          GestureDetector(
                            onTap: () {
                              AppHaptics.selection();
                              onQuantityChanged(cartItemId, quantity + 1);
                            },
                            child: Padding(
                              padding: EdgeInsets.all(4.r),
                              child: Icon(Icons.add_circle_outline, size: 18.sp, color: AppColors.primaryColor),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        "qty: $quantity",
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    
                    SizedBox(width: 8.w),
                    
                    // Total Item Cost
                    SizedBox(
                      width: 45.w,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "₹${(sellingPrice * quantity).toStringAsFixed(0)}",
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              );
            },
          ),
          
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: const DottedLine(
              dashColor: Color(0xFFD6C885),
              lineThickness: 1.2,
            ),
          ),
          
          // Cost Details
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            child: Column(
              children: [
                _buildCostRow("सामान का मूल्य (Subtotal)", subtotal),
                _buildCostRow("पैकिंग व हैंडलिंग (Handling)", handlingCharge),
                _buildCostRow("घर पहुंचाने का शुल्क (Delivery)", deliveryCharge),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "कुल मूल्य (Total Amount)",
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      "₹${finalAmount.toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Confirm button
          if (!isConfirmedView)
            Padding(
              padding: EdgeInsets.only(left: 8.w, right: 8.w, bottom: 8.h),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      side: BorderSide(color: AppColors.primaryColor, width: 1),
                    ),
                    elevation: 0.5,
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                  ),
                  onPressed: onOrderConfirmed,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "ऑर्डर पक्का करें (Confirm Order)",
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Icon(Icons.check_circle_outline, size: 15.sp),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCostRow(String title, double amount) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            amount > 0 ? "₹${amount.toStringAsFixed(0)}" : "फ्री (FREE)",
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: amount > 0 ? Colors.black87 : AppColors.successColor,
            ),
          ),
        ],
      ),
    );
  }
}
