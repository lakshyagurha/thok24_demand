import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../OrderSummary/order_summary.dart';
import '../../TrackOrder/track_order.dart';
import '../../utils/api_constants.dart';
import '../../utils/colors.dart';
import '../../utils/language_provider.dart';
import '../bottomNavScreen.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> with TickerProviderStateMixin {
  bool isLoading = true;
  List orders = [];
  String _lastFetchedLang = '';


  late final TabController _tabController;
  String userName = "";
  String userEmail = "";
  String userId = "";


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final activeLang = Provider.of<LanguageProvider>(context).currentLanguage;
    if (_lastFetchedLang != activeLang) {
      _lastFetchedLang = activeLang;
      if (userId.isNotEmpty) {
        fetchOrders(userId);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  Future<void> fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('user_email');
    if (email != null) {
      setState(() => userEmail = email);
      await fetchUserDetails(email);
    }
  }

  Future<void> fetchUserDetails(String email) async {
    final url = Uri.parse(ApiConstants.BASE_URL + "auth/get_user.php?email=$email");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["status"] == "success") {
          setState(() {
            userName = data["user"]["name"];
            userId = data["user"]["id"];
            fetchOrders(userId);

          });
        }

      }
    } catch (e) {
      debugPrint("Error fetching user details: $e");
    }
  }

  Future<void> fetchOrders(String userid) async {
    try {
      final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
      final response = await http.post(
        Uri.parse(ApiConstants.GET_ORDER_BY_USER),
        body: {
          "user_id": userId.toString(),
          "lang": lang,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          orders = (data["orders"] ?? []) as List;
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load orders");
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isLoading = false);
    }
  }

  bool _isCompleteStatus(String? statusRaw) {
    final status = (statusRaw ?? '').toLowerCase();
    return status.contains('delivered') ||
        status.contains('completed') ||
        status.contains('cancelled') ||
        status.contains('canceled');
  }

  void _showRatingBottomSheet(String orderId) {
    int rating = 0;
    TextEditingController commentController = TextEditingController();

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
    );
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
    } else if (lowerStatus.contains('placed')) {
      bgColor = const Color(0xFFFFF3E0); // Light orange
      textColor = const Color(0xFFF57C00);
      label = "ORDER PLACED";
    } else if (lowerStatus.contains('preparing') || lowerStatus.contains('packing')) {
      bgColor = const Color(0xFFE0F7FA); // Light cyan
      textColor = const Color(0xFF00838F);
      label = "PREPARING";
    } else if (lowerStatus.contains('out')) {
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
    final activeOrders = orders.where((o) => !_isCompleteStatus((o["order"]?["status"]).toString())).toList();
    final completeOrders = orders.where((o) => _isCompleteStatus((o["order"]?["status"]).toString())).toList();

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
                  emptyText: "No active orders",
                  buildCard: _buildActiveOrderCard,
                ),
                _OrderList(
                  orders: completeOrders,
                  emptyText: "No completed orders",
                  buildCard: _buildCompletedOrderCard,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderCard(Map orderMap) {
    final orderData = orderMap["order"] ?? {};
    final orderItems = (orderMap["items"] ?? []) as List;

    final finalAmount = orderData['final_amount'] ?? orderData['grand_total'] ?? orderData['amount'] ?? '';
    final orderId = orderData['id']?.toString() ?? orderData['order_id']?.toString() ?? '';
    final createdAt = orderData['order_datetime']?.toString() ?? orderData['order_date']?.toString() ?? '';
    final status = orderData['status']?.toString() ?? '';
    final itemCount = orderItems.fold<int>(0, (sum, it) => sum + (int.tryParse(it['quantity']?.toString() ?? '0') ?? 0));
    final images = orderItems.map<String>((it) => (it['image_url'] ?? it['image'] ?? '').toString()).where((u) => u.isNotEmpty).toList();

    final showImages = images.take(2).toList();
    final extraCount = images.length > 3 ? images.length - 2 : (images.length == 3 ? 1 : 0);

    // Date formatting
    String dateText = '';
    String timeText = '';
    try {
      DateTime parsedDate = DateFormat("dd-MM-yyyy hh:mm a").parse(createdAt);
      dateText = DateFormat("dd MMM yyyy").format(parsedDate);
      timeText = DateFormat("hh:mm a").format(parsedDate);
    } catch (e) {
      debugPrint("Date parsing error: $e");
    }

    // Build product summary text
    String itemSummaryText = "";
    if (orderItems.isNotEmpty) {
      final firstItem = orderItems[0];
      final firstItemName = firstItem['name'] ?? '';
      final firstItemQuantity = int.tryParse(firstItem['quantity']?.toString() ?? '1') ?? 1;
      final otherItemsCount = itemCount - firstItemQuantity;
      if (otherItemsCount > 0) {
        itemSummaryText = "$firstItemName + $otherItemsCount more item${otherItemsCount > 1 ? 's' : ''}";
      } else {
        itemSummaryText = firstItemName;
      }
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderSummary(orderMap: orderMap),
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
                  "Order #000$orderId",
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryTextColor,
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(status),
              ],
            ),
            SizedBox(height: 12.h),

            // Order Meta: Price, Date, Items count
            Row(
              children: [
                Text(
                  '₹${(double.tryParse(finalAmount) ?? 0).toStringAsFixed(0)}',
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
                  "$itemCount Item${itemCount > 1 ? 's' : ''}",
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
                  "$dateText, $timeText",
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
            if (itemSummaryText.isNotEmpty) ...[
              Text(
                itemSummaryText,
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
                if (images.length >= 3)
                  _ThirdThumbWithOverlay(url: images[2], overlayText: extraCount > 0 ? "+$extraCount" : null),
                const Spacer(),

                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrackOrder(status: status),
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

  Widget _buildCompletedOrderCard(Map orderMap) {
    final orderData = orderMap["order"] ?? {};
    final orderItems = (orderMap["items"] ?? []) as List;

    final finalAmount = orderData['final_amount'] ?? orderData['grand_total'] ?? orderData['amount'] ?? '';
    final orderId = orderData['id']?.toString() ?? orderData['order_id']?.toString() ?? '';
    final createdAt = orderData['order_datetime']?.toString() ?? orderData['order_date']?.toString() ?? '';
    final status = orderData['status']?.toString() ?? '';
    final itemCount = orderItems.fold<int>(0, (sum, it) => sum + (int.tryParse(it['quantity']?.toString() ?? '0') ?? 0));
    final images = orderItems.map<String>((it) => (it['image_url'] ?? it['image'] ?? '').toString()).where((u) => u.isNotEmpty).toList();

    final showImages = images.take(2).toList();
    final extraCount = images.length > 3 ? images.length - 2 : (images.length == 3 ? 1 : 0);

    // Date formatting
    String dateText = '';
    String timeText = '';
    try {
      DateTime parsedDate = DateFormat("dd-MM-yyyy hh:mm a").parse(createdAt);
      dateText = DateFormat("dd MMM yyyy").format(parsedDate);
      timeText = DateFormat("hh:mm a").format(parsedDate);
    } catch (e) {
      debugPrint("Date parsing error: $e");
    }

    // Build product summary text
    String itemSummaryText = "";
    if (orderItems.isNotEmpty) {
      final firstItem = orderItems[0];
      final firstItemName = firstItem['name'] ?? '';
      final firstItemQuantity = int.tryParse(firstItem['quantity']?.toString() ?? '1') ?? 1;
      final otherItemsCount = itemCount - firstItemQuantity;
      if (otherItemsCount > 0) {
        itemSummaryText = "$firstItemName + $otherItemsCount more item${otherItemsCount > 1 ? 's' : ''}";
      } else {
        itemSummaryText = firstItemName;
      }
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderSummary(orderMap: orderMap),
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
                  "Order #000$orderId",
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryTextColor,
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(status),
              ],
            ),
            SizedBox(height: 12.h),

            // Order Meta: Price, Date, Items count
            Row(
              children: [
                Text(
                  '₹${(double.tryParse(finalAmount) ?? 0).toStringAsFixed(0)}',
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
                  "$itemCount Item${itemCount > 1 ? 's' : ''}",
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
                  "$dateText, $timeText",
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
            if (itemSummaryText.isNotEmpty) ...[
              Text(
                itemSummaryText,
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
                if (images.length >= 3)
                  _ThirdThumbWithOverlay(url: images[2], overlayText: extraCount > 0 ? "+$extraCount" : null),
                const Spacer(),

                InkWell(
                  onTap: () => _showRatingBottomSheet(orderId),
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
  const _OrderList({required this.orders, required this.emptyText, required this.buildCard});

  final List orders;
  final String emptyText;
  final Widget Function(Map order) buildCard;

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
      onRefresh: () async => await Future.delayed(const Duration(milliseconds: 400)),
      child: ListView.builder(
        padding: EdgeInsets.only(top: 8.h, bottom: 20.h),
        itemCount: orders.length,
        itemBuilder: (_, i) => buildCard(orders[i] as Map),
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
        child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
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