class ApiConstants {

  static const String BASE_URL = "http://192.168.31.10/api_folder/";

  // Auth
  static const String LOGIN = "$BASE_URL/auth/login.php";
  static const String SIGNUP = "$BASE_URL/auth/signup.php";
  static const String FORGET_PASSWORD = "$BASE_URL/auth/forget_password.php";
  static const String RESET_PASSWORD = "$BASE_URL/auth/reset_password.php";
  static const String OTP_VERYFLY = "$BASE_URL/auth/verify_otp.php";
  static const String GET_USER = "$BASE_URL/auth/get_user.php";
  static const String EDIT_PROFILE = "$BASE_URL/auth/edit_profile.php";


  // Brand
  static const String VIEW_BRAND = "$BASE_URL/brand_api/view_brand.php";

  // DeliveryTime
  static const String DELIVERY_TIME = "$BASE_URL/deliver_time/get_delivery_time.php";



  // Category
  static const String VIEW_MAIN_CATEGORY_CATEGORY = "$BASE_URL/main_category/all_main_category_with_category.php";
  static const String VIEW_SUB_CATEGORY = "$BASE_URL/sub_category_api/view_sub_category.php";
  static const String MAIN_VIEW_CATEGORY = "$BASE_URL/main_category/view.php";
  static const String VIEW_CATEGORY_WITH_MAIN_CATEGOTY_ID = "$BASE_URL/category_api/view_category_with_main_category_id.php";
  static const String VIEW_TOP_CATEGORY = "$BASE_URL/top_category_api/view_banner.php";
  static const String GET_MAIN_CATEGORY_WITH_POSITION = "$BASE_URL/main_category/get_main_categories_with_position.php";


  // Product
  static const String VIEW_PRODUCTS_BY_SUBCATEGORY = "$BASE_URL/product_api_project/product/get_products_by_subcategory.php";
  static const String VIEW_ALL_PRODUCTS_BY_CATEGORY = "$BASE_URL/product_api_project/product/get_all_products_by_category.php";
  static const String VIEW_PRODUCT_BY_TYPE = "$BASE_URL/product_api_project/product/get_product_by_type.php";
  static const String VIEW_ALL_PRODUCTS = "$BASE_URL/product_api_project/product/get_all_products.php";
  static const String BOL_KE_ORDER_LAST_PURCHASED = "$BASE_URL/product_api_project/product/get_last_purchased.php";
  static const String BOL_KE_ORDER_HINDI_SEARCH = "$BASE_URL/product_api_project/product/search_hindi_keywords.php";
  static const String BOL_KE_ORDER_PROCESS_CHAT = "$BASE_URL/bot/process_chat.php";
  static const String SINGLE_PRODUCT_DETAILS = "${BASE_URL}product_api_project/product/single_product_details.php";


  // Location
  static const String VIEW_DISTRICT = "$BASE_URL/location/district/view_district.php";
  static const String VIEW_CITY = "$BASE_URL/location/city/view_city.php";


  // Banner
  static const String OCCASION_BANNER = "$BASE_URL/occasion_banner_api/get_single_occasion_banner.php";
  static const String OFFER_BANNER = "$BASE_URL/offer_banner_api/view_banner.php";
  static const String DISCOUTN_BANNER = "$BASE_URL/discount_banner_api/get_single_discount_banner.php";
  static const String VIEW_SLIDER = "$BASE_URL/banner_api/view_banner.php";


  //Coupon Code
  static const String VIEW_COUPON = "$BASE_URL/coupon_code_api/view_coupon.php";
  static const String VALIDATE_COUPON = "$BASE_URL/coupon_code_api/validate_coupon.php";


  static const String VIEW_OCCASION_CATEGORY = "$BASE_URL/occasion_category_api/view_banner.php";


  // Cart item
  static const String ADD_TO_CART = "$BASE_URL/product_api_project/cart/add_to_cart.php";
  static const String GET_CART_ITEMS = "$BASE_URL/product_api_project/cart/get_cart_items.php";
  static const String UPDATE_QUANTITY = "$BASE_URL/product_api_project/cart/update_quantity.php";
  static const String REMOVE_CART_ITEM = "$BASE_URL/product_api_project/cart/remove_from_cart.php";


  // Place Order
  static const String PLACE_ORDER = "$BASE_URL/product_api_project/place_order/place_order.php";
  static const String GET_ORDER_BY_USER = "$BASE_URL/product_api_project/place_order/get_order_by_user.php";


  // Delivery Address
  static const String ADD_ADDRESS = "$BASE_URL/delivery_address/add_address.php";
  static const String VIEW_ADDRESS = "$BASE_URL/delivery_address/view_address.php";
  static const String UPDATE_ADDRESS = "$BASE_URL/delivery_address/address_edit.php";
  static const String DELETE_ADDRESS = "$BASE_URL/delivery_address/delete_address.php";


  // Wishlist
  static const String ADD_TO_WISHLIST = "$BASE_URL/wishlist/add_to_wishlist.php";
  static const String CHECK_WISHLIST = "$BASE_URL/wishlist/check_wishlist.php";
  static const String REMOVE_FROM_WISHLIST = "$BASE_URL/wishlist/remove_from_wishlist.php";
  static const String GET_WISHLIST = "$BASE_URL/wishlist/get_wishlist.php";


  // Help
  static const String GET_CALLING_NUMBER = "$BASE_URL/help_api/call/get_help_call.php";
  static const String GET_WHATSAPP_NUMBER = "$BASE_URL/help_api/whatsapp/get_help_whatsapp.php";
  static const String GET_EMAIL = "$BASE_URL/help_api/email/get_help_email.php";


  // Delivery Charge
  static const String FETCH_DELIVERY_AMOUNT = "$BASE_URL/delivery_charge/get_delivery_charge.php";

  // Minimum order Amount
  static const String GET_MINIMUM_ORDER_AMOUT = "$BASE_URL/minimum_order_amout/get_ minimum_order_amout.php";


  // Handling Charge
  static const String GET_HANDLING_CHARGE = "$BASE_URL/handling_charge/get_delivery_charge.php";

  // Free Delivery Amount
  static const String GET_FREE_DELIVERY_AMOUNT = "$BASE_URL/free_delivey/get_free_delivery.php";

}


