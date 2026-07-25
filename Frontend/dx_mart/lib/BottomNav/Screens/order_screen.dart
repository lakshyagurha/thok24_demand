import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../OrderSummary/order_summary.dart';
import '../../TrackOrder/track_order.dart';
import '../../core/supabase.dart';
import '../../data/models.dart';
import '../../data/order_repository.dart';
import '../../utils/colors.dart';
import '../bottomNavScreen.dart';
import '../../CustomWidgets/product_image.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> with TickerProviderStateMixin {
  final _orders = const OrderRepository();

  bool isLoading = true;
  List<Order> orders = [];
  String? _error;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// The old screen resolved an email from SharedPreferences, exchanged it for a numeric
  /// user id, then posted that id to get_order_by_user.php -- so changing the number
  /// returned somebody else's order history. There is no id in this request at all:
  /// the session identifies the caller and RLS scopes the rows.
  Future<void> fetchOrders() async {
    if (!Db.isSignedIn) {
      if (!mounted) return;
      setState(() {
        orders = [];
        isLoading = false;
        _error = 'Please sign in to see your orders.';
      });
      return;
    }

    try {
      final history = await _orders.history();
      if (!mounted) return;
      setState(() {
        orders = history;
        isLoading = false;
        _error = null;
      });
    } on DataException catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _error = e.message;
      });
    } catch (e) {
      debugPrint("Error: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _error = 'Could not load your orders.';
      });
    }
  }

  bool _isCompleteStatus(String statusRaw) {
    final status = statusRaw.toLowerCase();
    return status.contains('delivered') ||
        status.contains('completed') ||
        status.contains('cancelled') ||
        status.contains('canceled');
  }

  void _showRatingBottomSheet(String orderId) {
    int rating = 0;
    final commentController = TextEditingController();

    // Created per sheet, so it has to be disposed when the sheet closes.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16.w,
                right: 16.w,
                top: 16.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Rate Your Order',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Center(
                    child: Text(
                      'How was your experience with order #$orderId?',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            size: 30.sp,
                            color: Colors.amber,
                          ),
                          onPressed: () {
                            setState(() {
                              rating = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Add Comment (Optional)',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Share your experience...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                      onPressed: () {
                        // Handle submit rating
                        debugPrint('Rating: $rating');
                        debugPrint('Comment: ${commentController.text}');
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Thank you for your rating!'),
                          ),
                        );
                      },
                      child: Text(
                        'Submit',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(commentController.dispose);
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label = status.toUpperCase();

    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('delivered') || lowerStatus.contains('completed')) {
      bgColor = const Color(0xFFE8F5E9); // Light green
      textColor = const Color(0xFF2E7D32);
      label = "DELIVERED";
    } else if (lowerStatus.contains('cancelled') || lowerStatus.contains('canceled')) {
      bgColor = const Color(0xFFFFEBEE); // Light red
      textColor = const Color(0xFFD32F2F);
      label = "CANCELLED";
    } else if (lowerStatus.contains('placed') || lowerStatus.contains('pending')) {
      bgColor = const Color(0xFFFFF3E0); // Light orange
      textColor = const Color(0xFFF57C00);
      label = "ORDER PLACED";
    } else if (lowerStatus.contains('preparing') ||
        lowerStatus.contains('packing') ||
        lowerStatus.contains('packed')) {
      bgColor = const Color(0xFFE0F7FA); // Light cyan
      textColor = const Color(0xFF00838F);
      label = "PREPARING";
    } else if (lowerStatus.contains('out') || lowerStatus.contains('way')) {
      bgColor = const Color(0xFFE3F2FD); // Light blue
      textColor = const Color(0xFF1976D2);
      label = "OUT FOR DELIVERY";
    } else {
      bgColor = const Color(0xFFF5F5F5); // Grey
      textColor = const Color(0xFF616161);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders = orders.where((o) => !_isCompleteStatus(o.status)).toList();
    final completeOrders = orders.where((o) => _isCompleteStatus(o.status)).toList();

    return Scaffold(
      backgroundColor: AppColors.neutral100,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            height: 17.h,
          ),
          // Header
          Container(
            width: double.infinity,
            height: 50.h,
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
                SizedBox(width: 16.w),
                InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => BottomNavScreen()));
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
                  "My Order",
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryTextColor,
                  ),
                ),
              ],
            ),
          ),

          _Tabs(tabController: _tabController),
          SizedBox(height: 8.h),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
              controller: _tabController,
              children: [
                _OrderList(
                  orders: activeOrders,
                  emptyText: _error ?? "No active orders",
                  onRefresh: fetchOrders,
                  buildCard: _buildActiveOrderCard,
                ),
                _OrderList(
                  orders: completeOrders,
                  emptyText: _error ?? "No completed orders",
                  onRefresh: fetchOrders,
                  buildCard: _buildCompletedOrderCard,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Item count, thumbnails and the "X + N more" line, all from the order graph.
  _OrderCardData _cardData(Order order) {
    final itemCount = order.items.fold<int>(0, (sum, it) => sum + it.quantity);
    final images = order.items
        .map((it) => it.imageUrl)
        .where((u) => u.isNotEmpty)
        .toList();

    String itemSummaryText = "";
    if (order.items.isNotEmpty) {
      final firstItem = order.items.first;
      final otherItemsCount = itemCount - firstItem.quantity;
      if (otherItemsCount > 0) {
        itemSummaryText =
            "${firstItem.productName} + $otherItemsCount more item${otherItemsCount > 1 ? 's' : ''}";
      } else {
        itemSummaryText = firstItem.productName;
      }
    }

    return _OrderCardData(
      itemCount: itemCount,
      images: images,
      itemSummaryText: itemSummaryText,
      // order_datetime is a real timestamptz now, already converted to local time by the
      // model, so there is no string date to hand-parse and fail on.
      dateText: DateFormat("dd MMM yyyy").format(order.orderedAt),
      timeText: DateFormat("hh:mm a").format(order.orderedAt),
    );
  }

  Widget _buildActiveOrderCard(Order order) {
    final data = _cardData(order);
    final showImages = data.images.take(2).toList();
    final extraCount = data.images.length > 3
        ? data.images.length - 2
        : (data.images.length == 3 ? 1 : 0);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderSummary(order: order),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFECECEC)),
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
            // Header: ID & Status
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_shipping_outlined,
                    color: AppColors.primaryColor,
                    size: 16.sp,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  "Order #000${order.id}",
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryTextColor,
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(order.status),
              ],
            ),
            SizedBox(height: 12.h),

            // Order Meta: Price, Date, Items count
            Row(
              children: [
                Text(
                  '₹${order.finalAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryTextColor,
                  ),
                ),
                SizedBox(width: 6.w),
                Text("•", style: TextStyle(color: AppColors.neutral400, fontSize: 12.sp)),
                SizedBox(width: 6.w),
                Text(
                  "${data.itemCount} Item${data.itemCount > 1 ? 's' : ''}",
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.neutral600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 6.w),
                Text("•", style: TextStyle(color: AppColors.neutral400, fontSize: 12.sp)),
                SizedBox(width: 6.w),
                Text(
                  "${data.dateText}, ${data.timeText}",
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.neutral500,
                  ),
                ),
              ],
            ),

            SizedBox(height: 10.h),
            Divider(height: 1.h, color: AppColors.borderColor.withOpacity(0.5)),
            SizedBox(height: 10.h),

            // Item Summary Name Text
            if (data.itemSummaryText.isNotEmpty) ...[
              Text(
                data.itemSummaryText,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.neutral700,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 10.h),
            ],

            // Thumbnails and Track Order button
            Row(
              children: [
                ...showImages.map((url) => _Thumb(url: url)),
                if (data.images.length >= 3)
                  _ThirdThumbWithOverlay(
                    url: data.images[2],
                    overlayText: extraCount > 0 ? "+$extraCount" : null,
                  ),
                const Spacer(),

                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TrackOrder(orderId: order.id, status: order.status),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(8.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryColor.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      'Track Order',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white,
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
    );
  }

  Widget _buildCompletedOrderCard(Order order) {
    final data = _cardData(order);
    final showImages = data.images.take(2).toList();
    final extraCount = data.images.length > 3
        ? data.images.length - 2
        : (data.images.length == 3 ? 1 : 0);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderSummary(order: order),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFECECEC)),
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
            // Header: ID & Status
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: AppColors.success50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success500,
                    size: 16.sp,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  "Order #000${order.id}",
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryTextColor,
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(order.status),
              ],
            ),
            SizedBox(height: 12.h),

            // Order Meta: Price, Date, Items count
            Row(
              children: [
                Text(
                  '₹${order.finalAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryTextColor,
                  ),
                ),
                SizedBox(width: 6.w),
                Text("•", style: TextStyle(color: AppColors.neutral400, fontSize: 12.sp)),
                SizedBox(width: 6.w),
                Text(
                  "${data.itemCount} Item${data.itemCount > 1 ? 's' : ''}",
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.neutral600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 6.w),
                Text("•", style: TextStyle(color: AppColors.neutral400, fontSize: 12.sp)),
                SizedBox(width: 6.w),
                Text(
                  "${data.dateText}, ${data.timeText}",
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.neutral500,
                  ),
                ),
              ],
            ),

            SizedBox(height: 10.h),
            Divider(height: 1.h, color: AppColors.borderColor.withOpacity(0.5)),
            SizedBox(height: 10.h),

            // Item Summary Name Text
            if (data.itemSummaryText.isNotEmpty) ...[
              Text(
                data.itemSummaryText,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.neutral700,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 10.h),
            ],

            // Thumbnails and Rate button
            Row(
              children: [
                ...showImages.map((url) => _Thumb(url: url)),
                if (data.images.length >= 3)
                  _ThirdThumbWithOverlay(
                    url: data.images[2],
                    overlayText: extraCount > 0 ? "+$extraCount" : null,
                  ),
                const Spacer(),

                InkWell(
                  onTap: () => _showRatingBottomSheet('${order.id}'),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: AppColors.primaryColor,
                        width: 1.5.w,
                      ),
                    ),
                    child: Text(
                      'Rate Now',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================== SMALL WIDGETS ===================

/// Everything a card needs that is derived rather than stored.
class _OrderCardData {
  const _OrderCardData({
    required this.itemCount,
    required this.images,
    required this.itemSummaryText,
    required this.dateText,
    required this.timeText,
  });

  final int itemCount;
  final List<String> images;
  final String itemSummaryText;
  final String dateText;
  final String timeText;
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tabController});
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: TabBar(
        controller: tabController,
        isScrollable: false,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            width: 3.h,
            color: AppColors.primaryColor,
          ),
          insets: EdgeInsets.zero,
        ),
        labelColor: Colors.black,
        unselectedLabelColor: AppColors.neutral500,
        tabs: [
          Tab(
            child: Text(
              'Active',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Tab(
            child: Text(
              'Completed',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.emptyText,
    required this.buildCard,
    required this.onRefresh,
  });

  final List<Order> orders;
  final String emptyText;
  final Widget Function(Order order) buildCard;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 48.sp,
              color: AppColors.neutral300,
            ),
            SizedBox(height: 12.h),
            Text(
              emptyText,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.neutral500,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      // Actually re-reads from the server now, rather than waiting 400ms and showing
      // the same list back.
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.only(top: 8.h, bottom: 20.h),
        itemCount: orders.length,
        itemBuilder: (_, i) => buildCard(orders[i]),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.w,
      height: 40.w,
      margin: EdgeInsets.only(right: 8.w),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 0.1,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? const Icon(Icons.image_not_supported_outlined)
          : Padding(
        padding: const EdgeInsets.all(8.0),
        child: ProductImage(path: url, width: 40.w, height: 40.w),
      ),
    );
  }
}

class _ThirdThumbWithOverlay extends StatelessWidget {
  const _ThirdThumbWithOverlay({required this.url, this.overlayText});
  final String url;
  final String? overlayText;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _Thumb(url: url),
        if (overlayText != null)
          Positioned(
            child: Container(
              width: 40.w,
              height: 35.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(overlayText!, style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w700, fontSize: 12.sp)),
            ),
          ),
      ],
    );
  }
}
