import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter/material.dart';

import '../CustomWidgets/customTextFiledWidgets.dart';
import '../CustomWidgets/custom_text.dart';
import '../core/supabase.dart';
import '../data/auth_repository.dart';
import '../utils/colors.dart';


class EditProfile extends StatefulWidget {
  /// [email] and [fullName] are only seed values for the fields while the real profile
  /// loads. They are optional and carry no authority: the profile actually shown and
  /// updated is the signed-in user's own row, fetched with no id argument and gated by
  /// RLS.
  const EditProfile({
    super.key,
    this.email,
    this.fullName,
  });

  final String? email;
  final String? fullName;

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final AuthRepository _auth = const AuthRepository();

  bool isLoading = false;

  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fullNameController.text = widget.fullName ?? '';
    loadProfile();
  }

  @override
  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  /// No id is sent. The session identifies the user and RLS returns only their row.
  Future<void> loadProfile() async {
    setState(() => isLoading = true);
    try {
      final profile = await _auth.currentProfile();
      if (!mounted) return;
      if (profile != null) {
        fullNameController.text = (profile['name'] ?? '').toString();
        phoneController.text = (profile['phone'] ?? '').toString();
      }
    } on DataException catch (e) {
      showError(e.message);
    } catch (e) {
      showError('Could not load your profile. Try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String? validateFields() {
    if (fullNameController.text.trim().isEmpty) {
      return "Please enter full Name";
    }

    return null;
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle()),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void handleSubmit() async {
    final error = validateFields();
    if (error != null) {
      showError(error);
      return;
    }

    setState(() => isLoading = true);

    try {
      // Only the name is editable. The phone number is the login identity held by
      // Supabase Auth, so changing it here would desync the profile row from the
      // account it belongs to.
      await _auth.updateProfile(name: fullNameController.text.trim());

      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully!', style: TextStyle()),
          backgroundColor: AppColors.primaryColor,
        ),
      );
      Navigator.pop(context);
    } on DataException catch (e) {
      if (mounted) setState(() => isLoading = false);
      showError(e.message);
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      showError('Failed to update profile');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: InkWell(child: Icon(Icons.arrow_back_ios_new, size: 18),
          onTap: (){
            Navigator.pop(context);
          },
        ),
        centerTitle: true,
        title: Text(
          'Edit Profile',
          style: TextStyle(color: AppColors.primaryTextColor, fontSize: 18.sp),
        ),
        backgroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
          : ListView(
        padding: EdgeInsets.symmetric(horizontal: 15.w),
        children: [
          SizedBox(height: 20.h),

          SizedBox(height: 30.h),

          CircleAvatar(
            radius: 60.r,
            backgroundColor: AppColors.primaryColor,
            child: SvgPicture.asset(
              'assets/svg/profile.svg',
              width: 60,
              height: 60,
            ),
          ),

          SizedBox(height: 40.h),
          CustomText(text: "Full Name", fontWeight: FontWeight.w500),
          SizedBox(height: 6.h),
          CustomTextField(
            controller: fullNameController,
            hintText: "Enter full name",
            keyboardType: TextInputType.text,
          ),
          SizedBox(height: 20.h),
          CustomText(text: 'Mobile Number', fontWeight: FontWeight.w500),


          SizedBox(height: 6.h),
          CustomTextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            hintText: "Mobile Number",
            enabled: false, // login identity, not editable here
          ),


          SizedBox(height: 20.h),
          InkWell(
            onTap: handleSubmit,
            child: Container(
              width: double.infinity,
              height: 40.h,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Center(
                child: Text(
                  'Update',
                  style: TextStyle(
                    color: AppColors.primaryTextColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }
}
