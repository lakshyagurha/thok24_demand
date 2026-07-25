import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/catalog_repository.dart';
import '../utils/colors.dart';
import 'package:flutter/services.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final CatalogRepository _catalog = const CatalogRepository();

  String callingNumber = 'Loading...!';
  String whatsapp_Number = 'Loading...!';
  String support_email = 'Loading...!';

  @override
  void initState() {
    super.initState();
    fetchContactDetails();
  }

  /// One read replaces three endpoints. The old backend kept the call number, the
  /// WhatsApp number and the support email in three separate single-row tables behind
  /// three separate GETs; they are now three rows of `app_settings`.
  ///
  /// A key that is absent shows 'Not available' rather than blanking the card, because
  /// `app_settings` may not be populated yet.
  Future<void> fetchContactDetails() async {
    try {
      final settings = await _catalog.settings();
      if (!mounted) return;
      setState(() {
        callingNumber = _valueOr(settings['help_call'], 'Not available');
        whatsapp_Number = _valueOr(settings['help_whatsapp'], 'Not available');
        support_email = _valueOr(settings['help_email'], 'Not available');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        callingNumber = 'Error loading';
        whatsapp_Number = 'Error loading';
        support_email = 'Error loading';
      });
    }
  }

  static String _valueOr(String? value, String fallback) =>
      (value == null || value.trim().isEmpty) ? fallback : value.trim();

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $launchUri';
    }
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    // Remove any non-digit characters from the phone number
    String cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    final url = Uri.parse("https://wa.me/$cleanedNumber");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch WhatsApp'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $launchUri';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          // Header
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
                          child: Icon(Icons.arrow_back_ios,
                              size: 15.sp, color: AppColors.iconColor),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    "Help",
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 👇 Header ke niche scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  children: [
                    SizedBox(height: 30.h),
                    Image.asset('assets/images/help_image.png', width: 270.w),

                    SizedBox(height: 20.h),

                    // Call Support Card
                    _buildContactCard(
                      icon: Icons.phone_in_talk,
                      title: "Call Support",
                      subtitle: "Talk to our support team",
                      value: callingNumber,
                      color: AppColors.primaryColor,
                      onTap: () {
                        if (callingNumber != 'Loading...!' &&
                            callingNumber != 'Not available' &&
                            callingNumber != 'Error loading') {
                          _makePhoneCall(callingNumber);
                        }
                      },
                      onCopy: () {
                        if (callingNumber != 'Loading...!' &&
                            callingNumber != 'Not available' &&
                            callingNumber != 'Error loading') {
                          _copyToClipboard(callingNumber, 'Phone number');
                        }
                      },
                    ),

                    SizedBox(height: 16.h),

                    // WhatsApp Support Card
                    _buildContactCard(
                      icon: Icons.chat,
                      title: "WhatsApp Support",
                      subtitle: "Message us on WhatsApp",
                      value: whatsapp_Number,
                      color: Colors.green,
                      onTap: () {
                        if (whatsapp_Number != 'Loading...!' &&
                            whatsapp_Number != 'Not available' &&
                            whatsapp_Number != 'Error loading') {
                          _launchWhatsApp(whatsapp_Number);
                        }
                      },
                      onCopy: () {
                        if (whatsapp_Number != 'Loading...!' &&
                            whatsapp_Number != 'Not available' &&
                            whatsapp_Number != 'Error loading') {
                          _copyToClipboard(whatsapp_Number, 'WhatsApp number');
                        }
                      },
                    ),

                    SizedBox(height: 16.h),

                    // Email Support Card
                    _buildContactCard(
                      icon: Icons.email,
                      title: "Email Support",
                      subtitle: "Send us an email",
                      value: support_email,
                      color: AppColors.warningColor,
                      onTap: () {
                        if (support_email != 'Loading...!' &&
                            support_email != 'Not available' &&
                            support_email != 'Error loading') {
                          _sendEmail(support_email);
                        }
                      },
                      onCopy: () {
                        if (support_email != 'Loading...!' &&
                            support_email != 'Not available' &&
                            support_email != 'Error loading') {
                          _copyToClipboard(support_email, 'Email address');
                        }
                      },
                    ),

                    SizedBox(height: 30.h),

                    // Help Text
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Text(
                        "Our support team is available to help you with any questions or issues you might have. Feel free to reach out to us through any of the channels above.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.hintTextColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                    SizedBox(height: 30.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required Color color,
    required VoidCallback onTap,
    required VoidCallback onCopy,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              width: 50.w,
              height: 50.h,

              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.hintTextColor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: value == 'Loading...!' ||
                          value == 'Not available' ||
                          value == 'Error loading'
                          ? AppColors.errorColor
                          : AppColors.primaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(20.r),
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: Icon(
                  Icons.content_copy,
                  size: 20.sp,
                  color: AppColors.hintTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}