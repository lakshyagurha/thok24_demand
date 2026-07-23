import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/api_constants.dart';
import '../utils/colors.dart';

class DeliveryAddressScreen extends StatefulWidget {
  const DeliveryAddressScreen({super.key});

  @override
  State<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  String userEmail = "";
  String userName = "";
  String userID = "";

  List<dynamic> addressList = [];
  bool isLoading = false;
  bool isAddingAddress = false;
  bool isEditing = false;
  String? editingAddressId;

  // Selected address id store करने के लिए variable
  String? selectedAddressId;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController fullAddressController = TextEditingController();
  final TextEditingController pinCodeController = TextEditingController();
  final TextEditingController landmarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUserData();
    _loadSelectedAddress();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    fullAddressController.dispose();
    pinCodeController.dispose();
    landmarkController.dispose();
    super.dispose();
  }

  // Shared Preferences से selected address load करें
  Future<void> _loadSelectedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAddressId = prefs.getString('selected_address_id');
    setState(() {
      selectedAddressId = savedAddressId;
    });
  }

  Future<void> _addOrUpdateAddress() async {
    // Basic validation
    if (nameController.text.isEmpty ||
        phoneController.text.isEmpty ||
        fullAddressController.text.isEmpty ||
        pinCodeController.text.isEmpty ||
        landmarkController.text.isEmpty) {
      _showSnackBar("Please fill all the fields!", AppColors.warningColor);
      return;
    }

    // Check if user ID is available
    if (userID.isEmpty) {
      _showSnackBar("User not logged in or data not fetched.", AppColors.errorColor);
      return;
    }

    setState(() {
      isAddingAddress = true;
    });

    try {
      final apiUrl = isEditing ? ApiConstants.UPDATE_ADDRESS : ApiConstants.ADD_ADDRESS;

      final body = {
        "user_id": userID,
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "full_address": fullAddressController.text.trim(),
        "pin_code": pinCodeController.text.trim(),
        "landmark": landmarkController.text.trim(),
      };

      // Add address_id if editing
      if (isEditing && editingAddressId != null) {
        body["address_id"] = editingAddressId!;
      }

      final res = await http.post(Uri.parse(apiUrl), body: body);

      if (res.statusCode == 200) {
        final response = jsonDecode(res.body);
        if (response["success"] == "true" || response["status"] == "success") {
          _showSnackBar(
            isEditing ? "Address Updated Successfully! ✅" : "Address Added Successfully! ✅",
            AppColors.successColor,
          );
          _resetForm();
          fetchAddresses(); // Refresh addresses
          Navigator.pop(context); // Close the bottom sheet
        } else {
          _showSnackBar(response["message"] ?? "An unknown error occurred.", AppColors.errorColor);
        }
      } else {
        _showSnackBar("Server Error: ${res.statusCode}", AppColors.errorColor);
      }
    } catch (e) {
      _showSnackBar("Network error: $e", AppColors.errorColor);
    } finally {
      setState(() {
        isAddingAddress = false;
      });
    }
  }

  Future<void> _deleteAddress(String addressId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.DELETE_ADDRESS),
        body: {"id": addressId},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData["success"] == "true") {
          _showSnackBar("Address deleted successfully", AppColors.successColor);
          // अगर deleted address selected थी, तो selectedAddressId को null करें
          if (selectedAddressId == addressId) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('selected_address_id');
            await prefs.remove('selected_address_full');
            setState(() {
              selectedAddressId = null;
            });
          }
          fetchAddresses(); // List refresh
        } else {
          _showSnackBar(
            jsonData["message"] ?? "Failed to delete address",
            AppColors.errorColor,
          );
        }
      } else {
        _showSnackBar(
          "Server error: ${response.statusCode}",
          AppColors.errorColor,
        );
      }
    } catch (e) {
      _showSnackBar(
        "Error deleting address: $e",
        AppColors.errorColor,
      );
    }
  }

  void _showDeleteConfirmation(String addressId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Delete", style: const TextStyle()),
        content: Text("Are you sure you want to delete this address?", style: const TextStyle()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: AppColors.primaryColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAddress(addressId);
            },
            child: Text("Delete", style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _resetForm() {
    nameController.clear();
    phoneController.clear();
    fullAddressController.clear();
    pinCodeController.clear();
    landmarkController.clear();
    setState(() {
      isEditing = false;
      editingAddressId = null;
    });
  }

  Future<void> fetchAddresses() async {
    if (userID.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.VIEW_ADDRESS),
        body: {"user_id": userID},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["status"] == "success") {
          setState(() {
            addressList = jsonData["data"];
          });
        } else {
          setState(() {
            addressList = [];
          });
          _showSnackBar(jsonData["message"] ?? "No addresses found.", AppColors.warningColor);
        }
      } else {
        _showSnackBar("Server error: ${response.statusCode}", AppColors.errorColor);
      }
    } catch (e) {
      _showSnackBar("Error fetching addresses: $e", AppColors.errorColor);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    if (email != null) {
      setState(() => userEmail = email);
      fetchUserDetails(email);
    }
  }

  Future<void> fetchUserDetails(String email) async {
    final url = Uri.parse("${ApiConstants.BASE_URL}auth/get_user.php?email=$email");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["status"] == "success") {
          setState(() {
            userName = data["user"]["name"];
            userID = data["user"]["id"];
          });
          await fetchAddresses();
        } else {
          _showSnackBar(data["message"] ?? "Failed to fetch user details.", AppColors.errorColor);
        }
      } else {
        _showSnackBar("Server error: ${response.statusCode}", AppColors.errorColor);
      }
    } catch (e) {
      _showSnackBar("Error fetching user details: $e", AppColors.errorColor);
    }
  }

  void _editAddress(Map<String, dynamic> address) {
    setState(() {
      isEditing = true;
      editingAddressId = address["id"].toString();
      nameController.text = address["name"] ?? "";
      phoneController.text = address["phone"] ?? "";
      fullAddressController.text = address["full_address"] ?? "";
      pinCodeController.text = address["pin_code"] ?? "";
      landmarkController.text = address["landmark"] ?? "";
    });
    _showAddAddressModal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          SizedBox(height: 17.h),
          _buildAppBar(),
          SizedBox(height: 17.h),

          // Add New Address Button
          InkWell(
            onTap: () {
              _resetForm();
              _showAddAddressModal();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/svg/add.svg',
                  width: 18.w,
                  height: 18.h,
                  color: AppColors.searchBorderHome,
                ),
                SizedBox(width: 10.w),
                Text(
                  'Add New Address',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                    color: AppColors.searchBorderHome,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 17.h),

          // Address List
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
                : addressList.isEmpty
                ? const Center(
              child: Text(
                "No addresses found.",
                style: TextStyle(),
              ),
            )
                : ListView.builder(
              itemCount: addressList.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final address = addressList[index];
                final isSelected = address["id"].toString() == selectedAddressId;

                return GestureDetector(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('selected_address_id', address["id"].toString());
                    await prefs.setString('selected_address_full', address["full_address"] ?? "");

                    setState(() {
                      selectedAddressId = address["id"].toString();
                    });

                    _showSnackBar("Address Selected ✅", AppColors.successColor);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: isSelected ? Colors.green : AppColors.lineColor,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ] : [],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    address["name"] ?? "Name Not Available",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    SizedBox(width: 8.w),
                                    Icon(
                                      Icons.check_circle,
                                      size: 16.sp,
                                      color: Colors.green,
                                    ),
                                  ]
                                ],
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _editAddress(address),
                                    child: Icon(
                                      Icons.edit,
                                      size: 18.sp,
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  GestureDetector(
                                    onTap: () => _showDeleteConfirmation(address["id"].toString()),
                                    child: Icon(
                                      Icons.delete,
                                      size: 18.sp,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 5.h),
                          Text(
                            "${address["full_address"] ?? ""}, Landmark: ${address["landmark"] ?? ""}, Pin: ${address["pin_code"] ?? ""}",
                            style: TextStyle(fontSize: 12.sp),
                          ),
                          SizedBox(height: 5.h),
                          Text(
                            "Phone: ${address["phone"] ?? "Not available"}",
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey,
                            ),
                          ),
                          if (isSelected) ...[
                            SizedBox(height: 8.h),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(5.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 12.sp,
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    "Selected Address",
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
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
              onTap: () => Navigator.pop(context),
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
              "Delivery Address",
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
    );
  }

  void _showAddAddressModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEditing ? "Edit Address" : "Add New Address",
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16.h),
              _buildTextField(
                controller: nameController,
                icon: 'assets/svg/l_user.svg',
                hint: 'Name',
              ),
              SizedBox(height: 12.h),
              _buildTextField(
                controller: phoneController,
                icon: 'assets/svg/phone.svg',
                hint: 'Mobile no.',
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 12.h),
              _buildTextField(
                controller: fullAddressController,
                icon: 'assets/svg/l_location.svg',
                hint: 'Full Address',
              ),
              SizedBox(height: 12.h),
              _buildTextField(
                controller: pinCodeController,
                icon: 'assets/svg/pincode.svg',
                hint: 'Pin code',
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12.h),
              _buildTextField(
                controller: landmarkController,
                icon: 'assets/svg/landmark.svg',
                hint: 'Landmark',
              ),
              SizedBox(height: 20.h),
              GestureDetector(
                onTap: isAddingAddress ? null : _addOrUpdateAddress,
                child: Container(
                  height: 45.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(30.r),
                  ),
                  child: Center(
                    child: isAddingAddress
                        ? CircularProgressIndicator(color: Colors.black)
                        : Text(
                      isEditing ? "Update" : "Save",
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String icon,
    String? hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintStyle: TextStyle(
            color: Colors.grey,
            fontSize: 16.sp,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.all(12.w),
            child: SvgPicture.asset(icon, width: 18.w, height: 18.h,color: AppColors.primaryColor,),
          ),
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}