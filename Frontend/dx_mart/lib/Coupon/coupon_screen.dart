import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../core/supabase.dart';
import '../data/catalog_repository.dart';
import '../data/models.dart';
import '../utils/colors.dart';


class CouponScreen extends StatefulWidget {
  const CouponScreen({super.key});

  @override
  State<CouponScreen> createState() => _CouponScreenState();
}

class _CouponScreenState extends State<CouponScreen> {
  final _catalog = const CatalogRepository();

  List<Coupon> _couponList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCoupons();
  }

  Future<void> _fetchCoupons() async {
    try {
      // No client-side status filter any more: RLS only exposes status = 'Public'
      // rows, so private codes cannot be enumerated from here at all. A privately
      // shared code still redeems at checkout, where the server validates it.
      final coupons = await _catalog.publicCoupons();
      if (!mounted) return;
      setState(() {
        _couponList = coupons;
        _isLoading = false;
      });
    } on DataException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching coupons: $e");
      if (!mounted) return;
      setState(() {
        _error = "Could not load coupons.";
        _isLoading = false;
      });
    }
  }

  String _validityLabel(Coupon coupon) {
    final expiry = coupon.expiryDate;
    if (expiry == null) return 'No expiry';
    return 'Valid ${DateFormat('dd MMM yyyy').format(expiry)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body:
      Column(
        children: [
          // Header

          SizedBox(height: 17.h,),
          Container(
            width: double.infinity,
            height: 60.h,
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: Offset(0, 4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding:  EdgeInsets.only(top: 10.h),
              child: Row(
                children: [
                  SizedBox(width: 16.w),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 25.h,
                      width: 28.w,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(100),
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
                    "Coupon",
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Spacer(),

                  SizedBox(width: 20.w),
                ],
              ),
            ),
          ),

          SizedBox(height: 10.h,),

          Expanded(
            child: Builder(
              builder: (context) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_error != null) {
                  return Center(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                }
                if (_couponList.isEmpty) {
                  return Center(
                    child: Text(
                      "No coupons available right now",
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.zero,
                  scrollDirection: Axis.vertical,
                  itemCount: _couponList.length,
                  itemBuilder: (context, index) {
                    final coupon = _couponList[index];

                    return InkWell(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: coupon.codeName),
                        );
                        Fluttertoast.showToast(
                          msg: "Coupon code copied!",
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                          backgroundColor: Colors.black87,
                          textColor: Colors.white,
                          fontSize: 14.sp,
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: AppColors.primaryColor,
                            width: 1.5.w,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                  left: 16.w, right: 12.w, top: 10.h, bottom: 4.h),
                              child: Row(
                                children: [
                                  Text(
                                    'Coupon',
                                    style: TextStyle(
                                      color: AppColors.primaryColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.sp,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8.w, vertical: 2.h),
                                      child: Text(
                                        _validityLabel(coupon),
                                        style: TextStyle(
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.primaryColor,
                                        ),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.w),
                              child: DottedLine(
                                dashColor: AppColors.primaryColor.withOpacity(0.4),
                                lineThickness: 1.2,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(
                                  left: 16.w, right: 12.w, top: 8.h, bottom: 10.h),
                              child: Row(
                                children: [
                                  SvgPicture.asset(
                                    'assets/svg/coupon.svg',
                                    width: 16.w,
                                    color: AppColors.primaryColor,
                                  ),
                                  SizedBox(width: 6.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          coupon.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.sp,
                                          ),
                                        ),
                                        Text(
                                          coupon.description,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 10.sp,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6.r),
                                      border: Border.all(
                                        color: AppColors.primaryColor.withOpacity(0.4),
                                        width: 1.w,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10.w, vertical: 4.h),
                                      child: Text(
                                        coupon.codeName,
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          color: AppColors.primaryColor,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),


        ],
      ),
    );
  }
}
