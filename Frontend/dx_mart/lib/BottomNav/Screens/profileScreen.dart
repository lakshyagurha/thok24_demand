import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../Auth/edit_profile.dart';
import '../../Auth/loginScreen.dart';
import '../../Coupon/coupon_screen.dart';
import '../../DeliveryAddress/delivery_address_screen.dart';
import '../../Help/help_screen.dart';
import '../../ProfileScreen/about_screen.dart';
import '../../ProfileScreen/privacy_policy.dart';
import '../../ProfileScreen/return_policy.dart';
import '../../ProfileScreen/terms_condition.dart';
import '../../utils/api_constants.dart';
import '../../utils/colors.dart';
import '../../utils/language_provider.dart';
import 'order_screen.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userEmail = "";
  String userName = "";

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('user_email');
    if (email != null) {
      setState(() => userEmail = email);
      fetchUserDetails(email);
    }
  }

  Future<void> fetchUserDetails(String email) async {
    final url = Uri.parse(ApiConstants.BASE_URL+"auth/get_user.php?email=$email");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["status"] == "success") {
          setState(() => userName = data["user"]["name"]);
        }
      }
    } catch (e) {
      print("Error fetching user details: $e");
    }
  }

  Future<void> logoutUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
  }

  void showLogoutDialog() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(lang.translate('logout'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp)),
        content: Text(lang.translate('logout_confirm_msg'), style: TextStyle(fontSize: 14.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.translate('cancel'), style: TextStyle(color: AppColors.hintTextColor, fontSize: 14.sp)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              logoutUser();
            },
            child: Text(lang.translate('logout'), style: TextStyle(color: Colors.red, fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

            Padding(
              padding:  EdgeInsets.only(left: 20.w,right: 20.w,top: 50.h),
              child: Row(
                children: [

                  CircleAvatar(
                    radius: 25.r,
                    backgroundColor: AppColors.primaryColor,
                    child: SvgPicture.asset('assets/svg/profile.svg',
                    color: AppColors.primaryTextColor,
                    width: 25.w,height: 25.h,),
                  ),

                  SizedBox(width: 10.w,),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        child: Row(
                          children: [
                            Text(userName,style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600
                            ),),
                            SizedBox(width: 2.w,),
                            Icon(Icons.edit,size: 18.sp,color: AppColors.primaryColor,)
                          ],
                        ),
                        onTap: (){
                          Navigator.push(context, MaterialPageRoute(builder: (context)=>EditProfile(email: userEmail, fullName: userName)));
                        },
                      ),
                      Text(userEmail,style: TextStyle(
                        fontWeight: FontWeight.w400,

                      ),)



                    ],
                  )

                ],
              ),
            ),

            SizedBox(height: 20.h,),

            Container(
              color: Colors.grey.withOpacity(0.5),
              height: 0.5,
            ),


            Padding(
              padding:  EdgeInsets.only(left: 20.w,right: 20.w,top: 25.h),
              child: Column(
                children: [

                  // Order
                  InkWell(
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>OrderScreen()));
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        SizedBox(height: 16.h),
                        SvgPicture.asset('assets/svg/p_order.svg',
                        height: 18.h,width: 18.w,),
                        SizedBox(width: 10.w,),
                        Text(langProvider.translate('orders'),style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.sp,
                        ),),
                        Spacer(),
                        Icon(Icons.arrow_forward_ios,size: 17.sp,)
                      ],
                    ),
                  ),
                  SizedBox(height: 15.w,),
                  Container(
                    color: Colors.grey.withOpacity(0.5),
                    height: 0.7,
                  ),

                  // Delivery Address
                  SizedBox(height: 20.w,),
                  InkWell(
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>DeliveryAddressScreen()));
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        SizedBox(height: 16.h),
                        SvgPicture.asset('assets/svg/p_location.svg',
                          height: 18.h,width: 18.w,),
                        SizedBox(width: 10.w,),
                        Text(langProvider.translate('delivery_address'),style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.sp,
                        ),),
                        Spacer(),
                        Icon(Icons.arrow_forward_ios,size: 17.sp,)
                      ],
                    ),
                  ),
                  SizedBox(height: 15.w,),
                  Container(
                    color: Colors.grey.withOpacity(0.5),
                    height: 0.7,
                  ),

                  // Coupon
                  SizedBox(height: 20.w,),
                  InkWell(
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>CouponScreen()));
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        SizedBox(height: 16.h),
                        SvgPicture.asset('assets/svg/p_coupon.svg',
                          height: 18.h,width: 18.w,),
                        SizedBox(width: 10.w,),
                        Text(langProvider.translate('coupons'),style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.sp,
                        ),),
                        Spacer(),
                        Icon(Icons.arrow_forward_ios,size: 17.sp,)
                      ],
                    ),
                  ),
                  SizedBox(height: 15.w,),
                  Container(
                    color: Colors.grey.withOpacity(0.5),
                    height: 0.7,
                  ),


                  // Help
                  SizedBox(height: 20.w,),
                  InkWell(

                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>HelpScreen()));
                    },

                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        SizedBox(height: 16.h),
                        SvgPicture.asset('assets/svg/p_help.svg',
                          height: 18.h,width: 18.w,),
                        SizedBox(width: 10.w,),
                        Text(langProvider.translate('help_support'),style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.sp,
                        ),),
                        Spacer(),
                        Icon(Icons.arrow_forward_ios,size: 17.sp,)
                      ],
                    ),
                  ),
                  SizedBox(height: 15.w,),
                  Container(
                    color: Colors.grey.withOpacity(0.5),
                    height: 0.7,
                  ),

                  // Language Selection Tile
                  SizedBox(height: 20.w,),
                  InkWell(
                    onTap: (){
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                        ),
                        builder: (context) => Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                langProvider.translate('choose_language'),
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryTextColor,
                                ),
                              ),
                              SizedBox(height: 15.h),
                              ListTile(
                                leading: Icon(Icons.language, color: langProvider.currentLanguage == 'en' ? AppColors.primaryColor : Colors.grey),
                                title: Text(langProvider.translate('english')),
                                trailing: langProvider.currentLanguage == 'en' ? Icon(Icons.check_circle, color: AppColors.primaryColor) : null,
                                onTap: () {
                                  langProvider.changeLanguage('en');
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.language, color: langProvider.currentLanguage == 'hi' ? AppColors.primaryColor : Colors.grey),
                                title: Text(langProvider.translate('hindi')),
                                trailing: langProvider.currentLanguage == 'hi' ? Icon(Icons.check_circle, color: AppColors.primaryColor) : null,
                                onTap: () {
                                  langProvider.changeLanguage('hi');
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.language, color: langProvider.currentLanguage == 'hn' ? AppColors.primaryColor : Colors.grey),
                                title: Text(langProvider.translate('hinglish')),
                                trailing: langProvider.currentLanguage == 'hn' ? Icon(Icons.check_circle, color: AppColors.primaryColor) : null,
                                onTap: () {
                                  langProvider.changeLanguage('hn');
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16.h),
                        Icon(Icons.translate, size: 18.sp, color: AppColors.primaryColor),
                        SizedBox(width: 10.w,),
                        Text(langProvider.translate('choose_language'), style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.sp,
                        ),),
                        Spacer(),
                        Text(
                          langProvider.currentLanguage == 'en'
                              ? 'English'
                              : langProvider.currentLanguage == 'hi'
                                  ? 'हिंदी'
                                  : 'Hinglish',
                          style: TextStyle(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 14.sp,
                          ),
                        ),
                        SizedBox(width: 5.w),
                        Icon(Icons.arrow_forward_ios, size: 17.sp,)
                      ],
                    ),
                  ),
                  SizedBox(height: 15.w,),
                  Container(
                    color: Colors.grey.withOpacity(0.5),
                    height: 0.7,
                  ),

                  // About
                  SizedBox(height: 20.w,),
                  InkWell(
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>AboutScreen()));
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        SizedBox(height: 16.h),
                        SvgPicture.asset('assets/svg/p_about.svg',
                          height: 18.h,width: 18.w,),
                        SizedBox(width: 10.w,),
                        Text(langProvider.translate('about'),style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.sp,
                        ),),
                        Spacer(),
                        Icon(Icons.arrow_forward_ios,size: 17.sp,)
                      ],
                    ),
                  ),
                  SizedBox(height: 15.w,),
                  Container(
                    color: Colors.grey.withOpacity(0.5),
                    height: 0.7,
                  ),

                  // Terms & Condition
                  SizedBox(height: 20.w,),
                  InkWell(
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>TermsCondition()));
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        SizedBox(height: 16.h),
                        SvgPicture.asset('assets/svg/p_term_condition.svg',
                          height: 18.h,width: 18.w,),
                        SizedBox(width: 10.w,),
                        Text(langProvider.translate('terms_condition'),style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.sp,
                        ),),
                        Spacer(),
                        Icon(Icons.arrow_forward_ios,size: 17.sp,)
                      ],
                    ),
                  ),
                  SizedBox(height: 15.w,),
                  Container(
                    color: Colors.grey.withOpacity(0.5),
                    height: 0.7,
                  ),


                  // Privacy Policy
                  SizedBox(height: 20.w,),
                  InkWell(
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>PrivacyPolicy()));

                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        SizedBox(height: 16.h),
                        SvgPicture.asset('assets/svg/p_privacy_policy.svg',
                          height: 18.h,width: 18.w,),
                        SizedBox(width: 10.w,),
                        Text(langProvider.translate('privacy_policy'),style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.sp,
                        ),),
                        Spacer(),
                        Icon(Icons.arrow_forward_ios,size: 17.sp,)
                      ],
                    ),
                  ),
                  SizedBox(height: 15.w,),
                  Container(
                    color: Colors.grey.withOpacity(0.5),
                    height: 0.7,
                  ),


                  // Return Policy
                  SizedBox(height: 20.w,),
                  InkWell(
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>ReturnPolicy()));
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        SizedBox(height: 16.h),
                        SvgPicture.asset('assets/svg/p_return_policy.svg',
                          height: 18.h,width: 18.w,),
                        SizedBox(width: 10.w,),
                        Text(langProvider.translate('shipping_policy'),style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.sp,
                        ),),
                        Spacer(),
                        Icon(Icons.arrow_forward_ios,size: 17.sp,)
                      ],
                    ),
                  ),
                  SizedBox(height: 15.w,),
                  Container(
                    color: Colors.grey.withOpacity(0.5),
                    height: 0.7,
                  ),



                  SizedBox(height: 30.w,),



                  InkWell(
                    child: Container(
                      width: double.infinity,
                      height: 39.h,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [

                          SvgPicture.asset('assets/svg/p_logout.svg',color: AppColors.iconColor,),
                          SizedBox(width: 10.w,),
                          Text(langProvider.translate('logout'),style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.primaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),)

                        ],
                      ),
                    ),

                    onTap: (){
                      showLogoutDialog();
                    },
                  )






                ]

              ),


            )



            // Profile Options





          ],
        ),
      ),
    );
  }

 

}
