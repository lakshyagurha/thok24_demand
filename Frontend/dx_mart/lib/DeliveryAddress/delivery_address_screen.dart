import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/supabase.dart';
import '../data/models.dart';
import '../data/order_repository.dart';
import '../utils/colors.dart';

class DeliveryAddressScreen extends StatefulWidget {
  const DeliveryAddressScreen({super.key});

  @override
  State<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  final AddressRepository _addresses = const AddressRepository();

  List<Address> addressList = [];
  bool isLoading = false;
  bool isAddingAddress = false;
  bool isEditing = false;
  int? editingAddressId;

  // Selected address id store करने के लिए variable.
  // This is a UI preference, not an identity: it only remembers which of the user's own
  // addresses was last chosen. The addresses themselves come from the session + RLS.
  String? selectedAddressId;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController fullAddressController = TextEditingController();
  final TextEditingController pinCodeController = TextEditingController();
  final TextEditingController landmarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSelectedAddress();
    fetchAddresses();
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
    if (!mounted) return;
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

    if (!Db.isSignedIn) {
      _showSnackBar("Please sign in first.", AppColors.errorColor);
      return;
    }

    setState(() {
      isAddingAddress = true;
    });

    try {
      // No user_id in the payload. The insert is stamped with the session's user and the
      // update simply matches zero rows if the id is not the caller's own.
      final draft = Address(
        id: editingAddressId ?? 0,
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        fullAddress: fullAddressController.text.trim(),
        pinCode: pinCodeController.text.trim(),
        landmark: landmarkController.text.trim(),
      );

      if (isEditing && editingAddressId != null) {
        await _addresses.update(editingAddressId!, draft);
      } else {
        await _addresses.add(draft);
      }

      if (!mounted) return;
      _showSnackBar(
        isEditing ? "Address Updated Successfully! ✅" : "Address Added Successfully! ✅",
        AppColors.successColor,
      );
      _resetForm();
      Navigator.pop(context); // Close the bottom sheet
      await fetchAddresses(); // Refresh addresses
    } on DataException catch (e) {
      _showSnackBar(e.message, AppColors.errorColor);
    } catch (e) {
      _showSnackBar("Could not save the address: $e", AppColors.errorColor);
    } finally {
      if (mounted) {
        setState(() {
          isAddingAddress = false;
        });
      }
    }
  }

  Future<void> _deleteAddress(int addressId) async {
    try {
      await _addresses.remove(addressId);
      if (!mounted) return;
      _showSnackBar("Address deleted successfully", AppColors.successColor);

      // अगर deleted address selected थी, तो selectedAddressId को null करें
      if (selectedAddressId == addressId.toString()) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('selected_address_id');
        // Also drop the legacy key on any device that still has one written by an
        // older build.
        await prefs.remove('selected_address_full');
        if (!mounted) return;
        setState(() {
          selectedAddressId = null;
        });
      }
      await fetchAddresses(); // List refresh
    } on DataException catch (e) {
      _showSnackBar(e.message, AppColors.errorColor);
    } catch (e) {
      _showSnackBar("Error deleting address: $e", AppColors.errorColor);
    }
  }

  void _showDeleteConfirmation(int addressId) {
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
    if (!mounted) return;
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

  /// Lists the signed-in user's addresses. No user id is sent: RLS returns only rows the
  /// caller owns, so there is no id to tamper with.
  Future<void> fetchAddresses() async {
    if (!Db.isSignedIn) return;

    setState(() {
      isLoading = true;
    });

    try {
      final rows = await _addresses.list();
      if (!mounted) return;
      setState(() {
        addressList = rows;
      });
    } on DataException catch (e) {
      _showSnackBar(e.message, AppColors.errorColor);
    } catch (e) {
      _showSnackBar("Error fetching addresses: $e", AppColors.errorColor);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _editAddress(Address address) {
    setState(() {
      isEditing = true;
      editingAddressId = address.id;
      nameController.text = address.name;
      phoneController.text = address.phone;
      fullAddressController.text = address.fullAddress;
      pinCodeController.text = address.pinCode;
      landmarkController.text = address.landmark ?? "";
    });
    _showAddAddressModal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
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
                final isSelected = address.id.toString() == selectedAddressId;

                return GestureDetector(
                  onTap: () async {
                    // Only the id. `selected_address_full` used to be written here too —
                    // the user's full street address on disk, never read back by
                    // anything, and never cleared on sign-out. The id is enough: it is
                    // validated against an RLS-scoped address list wherever it is used.
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('selected_address_id', address.id.toString());

                    if (!mounted) return;
                    setState(() {
                      selectedAddressId = address.id.toString();
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
                                    address.name.isEmpty ? "Name Not Available" : address.name,
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
                                    onTap: () => _showDeleteConfirmation(address.id),
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
                            "${address.fullAddress}, Landmark: ${address.landmark ?? ""}, Pin: ${address.pinCode}",
                            style: TextStyle(fontSize: 12.sp),
                          ),
                          SizedBox(height: 5.h),
                          Text(
                            "Phone: ${address.phone.isEmpty ? "Not available" : address.phone}",
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
