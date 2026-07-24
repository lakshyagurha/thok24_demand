import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../BottomNav/bottomNavScreen.dart';
import '../CustomWidgets/customButton.dart';
import '../data/catalog_repository.dart';
import '../utils/colors.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final CatalogRepository _catalog = const CatalogRepository();

  bool isLoading = true;
  List<dynamic> districtList = [];
  List<dynamic> cityList = [];

  String? selected_district;
  String? selected_city;

  String selected_district_name = "";
  String selected_city_name = "";

  @override
  void initState() {
    super.initState();
    getAllDistricts();
  }

  Future<void> getAllDistricts() async {
    try {
      setState(() => isLoading = true);
      final rows = await _catalog.districts();
      if (!mounted) return;
      setState(() {
        districtList = rows;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      debugPrint('Error fetching districts: $e');
    }
  }

  Future<void> viewCity() async {
    final districtId = int.tryParse(selected_district ?? '');
    if (districtId == null) return;

    try {
      setState(() => isLoading = true);
      final rows = await _catalog.cities(districtId);
      if (!mounted) return;
      setState(() {
        cityList = rows;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      debugPrint('Error fetching cities: $e');
    }
  }

  Future<void> saveLocationData({
    required String district,
    required String city,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_district_name', district);
    await prefs.setString('selected_city_name', city);
  }

  InputDecoration modernDropdownDecoration(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
      ),
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w500,
        fontSize: 14.sp,
      ),
    );
  }

  Widget _buildDropdownSection({
    required String title,
    required String hint,
    required String? value,
    required List items,
    required String idKey,
    required String nameKey,
    required Function(String?)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14.sp,
              color: AppColors.primaryTextColor),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: value,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade600),
          decoration: modernDropdownDecoration(hint),
          items: items.map<DropdownMenuItem<String>>((item) {
            return DropdownMenuItem<String>(
              value: item[idKey].toString(),
              child: Text(item[nameKey],
                  style: TextStyle(
                      fontSize: 14.sp, color: Colors.grey.shade800)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? Center(
          child:
          CircularProgressIndicator(color: AppColors.primaryColor))
          : Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 60.h),
              Center(
                child: Image.asset(
                  'assets/images/location.png',
                  width: 180.w,
                  height: 120.h,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 20.h),
              Center(
                child: Text(
                  'Select Your Location',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 20.sp,
                      color: Colors.grey.shade800),
                ),
              ),
              SizedBox(height: 10.h),
              Center(
                child: Text(
                  'Switch on your location to stay in tune with\nwhat’s happening in your area',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12.sp,
                      height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 36.h),

              // District Dropdown
              _buildDropdownSection(
                title: "Your City",
                hint: "Select Your City",
                value: selected_district,
                items: districtList,
                idKey: 'id',
                nameKey: 'district_name',
                onChanged: (value) {
                  final selectedItem = districtList.firstWhere(
                          (e) => e['id'].toString() == value,
                      orElse: () => null);

                  setState(() {
                    selected_district = value;
                    selected_district_name =
                        selectedItem?['district_name'] ?? '';
                    selected_city = null;
                    selected_city_name = '';
                    cityList.clear();
                  });

                  if (selected_district != null) {
                    viewCity();
                  }
                },
              ),

              SizedBox(height: 24.h),

              // City Dropdown
              _buildDropdownSection(
                title: "Your Area",
                hint: "Select Your Area",
                value: selected_city,
                items: cityList,
                idKey: 'id',
                nameKey: 'city_name',
                onChanged: selected_district == null
                    ? null
                    : (value) {
                  final selectedItem = cityList.firstWhere(
                          (e) => e['id'].toString() == value,
                      orElse: () => null);
                  setState(() {
                    selected_city = value;
                    selected_city_name =
                        selectedItem?['city_name'] ?? '';
                  });
                },
              ),

              SizedBox(height: 40.h),

              CustomButton(
                text: "Submit",
                onPressed: () async {
                  if (selected_district == null ||
                      selected_city == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please select complete location',
                            style: TextStyle()),
                        backgroundColor: Colors.red.shade400,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r)),
                      ),
                    );
                  } else {
                    await saveLocationData(
                      district: selected_district_name,
                      city: selected_city_name,
                    );

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => BottomNavScreen()),
                    );
                  }
                },
              ),
              SizedBox(height: 30.h),
            ],
          ),
        ),
      ),
    );
  }
}
