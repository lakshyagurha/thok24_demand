import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../design/haptics.dart';

/// Themed occasion bundle card (e.g., Ganesh Puja, Chai Nashta) in BolKeOrder chat.
/// Displays itemized list of bundle items with inline quantity adjustment and 1-tap add to cart.
class OccasionBundleCard extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final Function(String message) onAddBundleToCart;

  const OccasionBundleCard({
    super.key,
    required this.items,
    required this.onAddBundleToCart,
  });

  @override
  State<OccasionBundleCard> createState() => _OccasionBundleCardState();
}

class _OccasionBundleCardState extends State<OccasionBundleCard> {
  late List<Map<String, dynamic>> _bundleItems;

  @override
  void initState() {
    super.initState() ;
    _bundleItems = List<Map<String, dynamic>>.from(widget.items);
  }

  double get _bundleSubtotal {
    double total = 0;
    for (final item in _bundleItems) {
      final price = (item['selling_price'] ?? item['price'] ?? 0) as num;
      final qty = (item['quantity'] ?? 1) as num;
      total += price.toDouble() * qty.toDouble();
    }
    return total;
  }

  void _updateQuantity(int index, int delta) {
    AppHaptics.selection();
    setState(() {
      final current = (_bundleItems[index]['quantity'] ?? 1) as int;
      final newQty = current + delta;
      if (newQty <= 0) {
        _bundleItems.removeAt(index);
      } else {
        _bundleItems[index]['quantity'] = newQty;
      }
    });
  }

  void _submitBundle() {
    AppHaptics.success();
    if (_bundleItems.isEmpty) return;

    final parts = _bundleItems.map((item) {
      final name = item['name'] ?? item['product_name'] ?? '';
      final qty = item['quantity'] ?? 1;
      return "$qty $name";
    }).join(", ");

    widget.onAddBundleToCart(parts);
  }

  @override
  Widget build(BuildContext context) {
    if (_bundleItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF6), // Warm parchment background
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFEADBBE), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: const Color(0xFF855C08),
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pooja / Occasion Samagri List 🪔",
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5C3E00),
                      ),
                    ),
                    Text(
                      "Aap yahan quantity kam ya zyada kar sakte hain",
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: const Color(0xFF8A641A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 16.h, color: const Color(0xFFEADBBE)),
          Column(
            children: [
              for (int index = 0; index < _bundleItems.length; index++) ...[
                if (index > 0) SizedBox(height: 6.h),
                Builder(
                  builder: (context) {
                    final item = _bundleItems[index];
                    final name = item['name'] ?? item['product_name'] ?? '';
                    final variantName = item['variant_name'] ?? '';
                    final price = (item['selling_price'] ?? item['price'] ?? 0) as num;
                    final qty = item['quantity'] ?? 1;

                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (variantName.toString().isNotEmpty)
                                Text(
                                  variantName.toString(),
                                  style: TextStyle(
                                    fontSize: 10.5.sp,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          "₹${price * qty}",
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF5C3E00),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: const Color(0xFFD6E4DD)),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => _updateQuantity(index, -1),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                  child: Icon(Icons.remove, size: 14.sp, color: Colors.red.shade700),
                                ),
                              ),
                              Text(
                                "$qty",
                                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                              ),
                              InkWell(
                                onTap: () => _updateQuantity(index, 1),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                  child: Icon(Icons.add, size: 14.sp, color: const Color(0xFF0F4E34)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total: ₹${_bundleSubtotal.toStringAsFixed(0)}",
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF5C3E00),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _submitBundle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4E34),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                icon: Icon(Icons.add_shopping_cart_rounded, size: 16.sp),
                label: Text(
                  "Pooja Samagri Add Karein",
                  style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
