import 'dart:convert';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../CustomWidgets/customTextFiledWidgets.dart';
import '../CustomWidgets/custom_text.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';


class EditProfile extends StatefulWidget {
  final String email;
  final String fullName;


  EditProfile({
    required this.email,
    required this.fullName,

  });

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  bool isLoading = false;

  final fullNameController = TextEditingController();
  final emailTextController = TextEditingController();





  @override
  void initState() {
    super.initState();
    fullNameController.text = widget.fullName;
    emailTextController.text = widget.email;
  }



  String? validateFields() {
    if (fullNameController.text.trim().isEmpty) {
      return "Please enter full Name";
    }
    if (emailTextController.text.trim().isEmpty) {
      return "Please enter your phone number";
    }

    return null;
  }

  void showError(String message) {
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
      final uri = Uri.parse(ApiConstants.EDIT_PROFILE); // 🟢 Replace with actual PHP API URL
      Map<String, String> body = {
        'email': widget.email,
        'name': fullNameController.text.trim(),
      };

      // Send POST request
      final response = await http.post(uri, body: body);

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile updated successfully!', style: TextStyle()),
              backgroundColor: AppColors.primaryColor,
            ),
          );
          Navigator.pop(context);
        } else {
          showError(responseData['message'] ?? 'Failed to update profile');
        }
      } else {
        showError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      showError('Error: $e');
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
          CustomText(text: 'Email Address', fontWeight: FontWeight.w500),


          SizedBox(height: 6.h),
          CustomTextField(
            controller: emailTextController,
            keyboardType: TextInputType.emailAddress,
            hintText: "Enter Email ",
            enabled: false, // yeh line add karo
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

