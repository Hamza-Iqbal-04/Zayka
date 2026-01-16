import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _appLocale = const Locale('en');

  Locale get appLocale => _appLocale;
  bool get isArabic => _appLocale.languageCode == 'ar';

  LanguageProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final String? languageCode = prefs.getString('language_code');
    if (languageCode != null) {
      _appLocale = Locale(languageCode);
      notifyListeners();
    }
  }

  Future<void> changeLanguage(Locale type) async {
    final prefs = await SharedPreferences.getInstance();
    if (_appLocale == type) return;

    if (type == const Locale('ar')) {
      _appLocale = const Locale('ar');
      await prefs.setString('language_code', 'ar');
    } else {
      _appLocale = const Locale('en');
      await prefs.setString('language_code', 'en');
    }

    notifyListeners();
  }
}

class AppStrings {
  static const Map<String, Map<String, String>> _localizedValues = {
    // ========================================================================
    // ENGLISH TRANSLATIONS
    // ========================================================================
    'en': {
      // --- General & Navigation ---
      'settings': 'Settings',
      'help_support': 'Help & Support',
      'help_support_sub': 'Get help and contact us',
      'logout': 'LOGOUT',
      'change_language': 'Language',
      'change_language_sub': 'English / العربية',
      'back_to_home': 'Back to Home',
      'back_to_menu': 'Back to Menu',
      'cancel': 'Cancel',
      'clear': 'Clear',
      'save': 'SAVE',
      'add': 'ADD',
      'apply': 'APPLY',
      'remove': 'REMOVE',
      'qar': 'QAR',
      'mins': 'mins',
      'km': 'km',
      'kms': 'kms)',
      'free': 'Free',
      'error': 'Error:',

      // --- Home & Menu ---
      'popular_items': 'Popular Items',
      'offers': 'Offers',
      'search_hint': 'Search for items...',
      'no_items': 'No items found',
      'browse_menu': 'BROWSE MENU',
      'spicy': 'Spicy',
      'out_of_stock': 'OUT OF STOCK',
      'unavailable': 'UNAVAILABLE',
      'item_unavailable': 'Item unavailable',
      'you_might_also_like': 'You might also like',
      'no_drinks_available': 'No drinks available for selected branches',

      // --- Cart & Checkout ---
      'cart_title': 'My Cart',
      'view_cart': 'View Cart',
      'add_to_cart': 'ADD TO CART',
      'items': 'items',
      'item': 'item',
      'cart_empty': 'Your cart is empty',
      'cart_empty_sub': 'Looks like you haven\'t added any items yet.',
      'your_cart_empty': 'Your cart is empty',
      'subtotal': 'Subtotal',
      'delivery_fee': 'Delivery Fee',
      'discount': 'Discount',
      'total': 'Total',
      'checkout': 'PROCEED TO CHECKOUT',
      'apply_coupon': 'Apply Coupon',
      'coupon_hint': 'Enter coupon code',
      'order_confirmed': 'Order Confirmed!',
      'order_placed_successfully': 'Your order has been placed successfully.',
      'thank_you_order': 'Thank you for your order!',
      'view_my_orders': 'View My Orders',
      'items_added_to_cart': 'Items added to your cart!',
      'clear_cart_title': 'Clear Cart?',
      'clear_cart_message': 'This will remove all items from your cart.',
      'item_removed_from_cart': 'removed from cart',
      'removed_out_of_stock': 'removed (out of stock)',
      'items_removed_out_of_stock': 'items removed (out of stock)',
      'item_unavailable_title': 'Item Unavailable',
      'items_no_longer_available':
          'The following items are no longer available:',
      'remove_items_question':
          'Would you like to remove these items from your cart?',
      'keep_items': 'Keep Items',
      'remove_all': 'Remove All',
      'unavailable_items_in_cart': 'UNAVAILABLE ITEMS IN CART',
      'your_items': 'Your Items',
      'checking_stock': 'CHECKING STOCK...',
      'processing': 'PROCESSING...',

      // --- Delivery & Branch Logic ---
      'delivery': 'Delivery',
      'pickup': 'Pickup',
      'deliver_to': 'DELIVER TO',
      'pick_up_from': 'PICK UP FROM',
      'set_delivery_address': 'Set Delivery Address',
      'select_delivery_address': 'Select Delivery Address',
      'no_delivery_address': 'No delivery address set',
      'please_login_address': 'Please log in to set an address.',
      'select_branch': 'Select Branch',
      'select_pickup_branch': 'Select Pickup Branch',
      'use_nearest_branch': 'Use Nearest Branch',
      'nearest_to_address': 'Nearest to your address',
      'finding_nearest_branch': 'Finding nearest branch...',
      'finding_nearest_branch_loading': 'Finding nearest branch...',
      'no_branches_available': 'No active branches available',
      'branch_info_not_found': 'Branch information not found',
      'branch_location_unavailable': 'Branch location not available',
      'restaurant_just_closed': 'Restaurant Just Closed',
      'branch_closed_msg':
          'The selected branch has just closed. We will try to find another open branch for you.',
      'we_are_closed': 'We are Closed',
      'all_branches_closed_msg':
          'All our restaurants are currently closed. Please check back later!',
      'restaurant_closed': 'Restaurant Closed',
      'branch_update': 'Branch Update',
      'switched_to': 'We switched you to',
      'nearest_branch': 'The nearest branch',
      'is_currently': 'is currently',
      'closed': 'closed',
      'outside_range': 'outside delivery range',
      'outside_delivery_range': 'OUTSIDE DELIVERY RANGE',
      'delivery_range_error':
          'Sorry, we do not deliver to your location. Maximum delivery range is',
      'location_not_serviceable': 'Location Not Serviceable',
      'no_delivery_available_msg':
          'Sorry, none of our branches deliver to your current location. Please try Pickup instead.',
      'delivery_updated_msg': 'Delivery fee and time have been updated.',
      'km_away': 'km away',
      'distance_to_branch': 'DISTANCE TO BRANCH',
      'from': 'from',
      'estimated_time': 'Estimated Time:',
      'est': 'EST.',
      'time': 'Time',
      'free_delivery_within': 'Free delivery (within',

      // --- Payment ---
      'payment_method': 'PAYMENT METHOD',
      'select_payment_method': 'Select Payment Method',
      'cash_on_delivery': 'Cash on Delivery',
      'online_payment': 'Online Payment',
      'loading_payment_methods': 'Loading payment methods...',
      'invalid_payment_method': 'Invalid Payment Method Selected',
      'payment_failed': 'Payment Failed',
      'payment_not_successful': 'Your payment was not successful.',
      'payment_summary': 'Payment Summary',

      // --- Order Status & Details ---
      'your_orders': 'Your Orders',
      'no_orders_found': 'No orders found.',
      'order': 'Order',
      'delivery_order': 'Delivery Order',
      'dine_in_order': 'Dine In Order',
      'takeaway_order': 'Takeaway Order',
      'placed_on': 'Placed on',
      'reorder': 'REORDER',
      'unknown': 'Unknown',
      'status_pending': 'Pending Confirmation',
      'status_preparing': 'Your order is being prepared',
      'status_prepared': 'Order prepared - awaiting rider',
      'status_pickup_prepared': 'Your order is ready for pickup!',
      'status_collected': 'Order collected - Thank you!',
      'status_rider_assigned': 'Rider assigned - picking up',
      'status_out_for_delivery': 'On the way to you',
      'status_delivered': 'Order delivered',
      'status_cancelled': 'Order cancelled',
      'status_driver_not_found': 'Busy - Searching for nearby drivers...',
      'pickup_ready_title': 'Order Ready!',
      'pickup_ready_msg': 'Your pickup order is ready to be collected.',
      'collected': 'Collected',
      'order_received_success': 'Your order has been received successfully',
      'order_prepared_at': 'Order will be prepared at',
      'order_items': 'Order Items',
      'unit_price': 'Unit Price:',
      'quantity': 'Qty:',
      'notes_optional': 'Notes (Optional)',
      'special_requests': 'Special requests, allergies, etc.',
      'special_instructions': 'Special Instructions',
      'notes_placeholder': 'e.g. No onions, Extra spicy...',
      'no_items_in_order': 'No items found in this order.',
      'no_items_to_reorder': 'This order has no items to reorder.',

      // --- Tracking & Driver ---
      'driver_details': 'Driver Details',
      'driver': 'Driver',
      'call': 'CALL',
      'no_phone_available': 'No phone available',
      'could_not_open_dialer': 'Could not open the dialer',
      'loading_driver_location': 'Loading driver location...',
      'live_tracking': 'Live Tracking',
      'fit_all_locations': 'Fit all locations',
      'center_on_driver': 'Center on driver',
      'you': 'You',
      'restaurant': 'Restaurant',
      'google_maps': 'Google Maps',
      'apple_maps': 'Apple Maps',
      'could_not_open_maps': 'Could not open maps app',
      'error_opening_navigation': 'Error opening navigation',

      // --- Filters & Search ---
      'all': 'All',
      'pending': 'Pending',
      'preparing': 'Preparing',
      'on_the_way': 'On the Way',
      'delivered': 'Delivered',
      'refunded': 'Refunded',
      'load_more': 'Load more',
      'search_by_dish': 'Search by dish name...',

      // --- Cancellation Reasons ---
      'order_cancelled': 'Order Cancelled',
      'order_cancelled_msg': 'Your order was cancelled by the restaurant.',
      'reason': 'Reason',
      'items_out_of_stock': 'Items out of stock',
      'kitchen_busy': 'Kitchen too busy',
      'closing_soon': 'Closing soon / Closed',
      'invalid_address': 'Invalid Address',
      'customer_request': 'Customer Request',
      'other': 'Other',
      'unknown_reason': 'No reason provided',

      // --- Refund Feature (New) ---
      'great': 'Great!',
      'request_refund': 'Request Refund',
      'refund_reason': 'Reason for refund',
      'refund_reason_hint': 'Explain why you are requesting a refund...',
      'attach_image': 'Attach Image (Required)',
      'submit_request': 'Submit Request',
      'refund_submitted_msg': 'Refund request submitted successfully.',
      'image_required': 'Please attach an image to proceed.',
      'reason_required': 'Please enter a reason.',
      'refund_status': 'Refund Status',
      'refund_pending': 'Pending Review',
      'refund_accepted': 'Refund Approved',
      'refund_rejected': 'Refund Rejected',
      'refund_accepted_msg': 'Your refund has been approved and processed.',
      'refund_rejected_msg': 'Your refund request was declined.',
      'refund_pending_msg': 'We are reviewing your request.',

      // --- Profile & Address ---
      'edit_profile': 'Edit Profile',
      'edit_profile_sub': 'Update your personal information',
      'full_name': 'Full Name',
      'phone_number': 'Phone Number',
      'enter_name_error': 'Please enter your name',
      'enter_phone_error': 'Please enter your phone number',
      'profile_updated': 'Profile updated successfully',
      'save_changes': 'SAVE CHANGES',
      'saved_addresses': 'Saved Addresses',
      'saved_addresses_sub': 'Manage your delivery locations',
      'add_new_address': 'Add New Address',
      'no_addresses_saved': 'No addresses saved yet',
      'no_addresses_title': 'No Addresses Saved',
      'no_addresses_subtitle':
          'Add an address to get started with your orders.',
      'edit_address': 'Edit Address',
      'tap_map_hint': 'Tap on the map to select a location',
      'search_location_hint': 'Search location...',
      'label_hint': 'Label (e.g., Home, Work)',
      'street_label': 'Street Address',
      'building_label': 'Building',
      'floor_label': 'Floor',
      'flat_label': 'Flat',
      'city_label': 'City',
      'set_as_default': 'Set as Default',
      'default_badge': 'DEFAULT',
      'my_favorites': 'My Favorites',
      'my_favorites_sub': 'View your liked items',
      'no_favorites_title': 'No Favorites Yet',
      'no_favorites_subtitle':
          'Tap the bookmark icon on any dish to save it for later.',
      'removed_from_favorites': 'Removed from favorites.',

      // --- Support ---
      'contact_us': 'CONTACT US',
      'contact_support_order': 'Contact Support about order #',
      'describe_issue': 'Describe your issue...',
      'enter_message': 'Please enter your message',
      'message_sent': 'Your message has been sent.',
      'send_message': 'SEND MESSAGE',
      'get_help': 'GET HELP',
      'legal_info': 'LEGAL INFORMATION',
      'faqs': 'FAQs',
      'live_chat': 'Live Chat',
      'terms_of_service': 'Terms of Service',
      'privacy_policy': 'Privacy Policy',
      'user_not_authenticated': 'User not authenticated',
      'user_doc_not_found': 'User document not found',

      // --- Working Hours / Closing Countdown ---
      'closing_in': 'Closing in',
      'restaurant_closing_soon': 'Restaurant closing soon - order now!',

      // --- Coupons Page ---
      'available_coupons_title': 'Available Coupons',
      'loading_offers': 'Loading amazing offers...',
      'failed_load_coupons': 'Failed to load coupons',
      'try_again': 'Please try again later',
      'no_coupons': 'No coupons available',
      'check_back_later': 'Check back later for exciting offers!',
      'apply_coupons_msg': 'Apply coupons to save more on your order!',
      'off': 'OFF',
      'on_orders_above': 'On orders above',
      'on_all_orders': 'On all orders',
      'valid_until': 'Valid until',
      'code': 'CODE',
      'not_applicable': 'Not applicable to current order',
      'coupon_applied_title': 'Coupon Applied!',
      'coupon_applied_msg': 'has been applied to your cart.',
      'go_to_cart': 'Go to Cart',
      'coupon_failed': 'Coupon Failed',
      'failed_apply_coupon': 'Failed to apply coupon:',

      // --- Navbar ---
      'nav_home': 'Home',
      'nav_orders': 'Orders',
      'nav_offers': 'Offers',
      'nav_cart': 'Cart',
      'nav_profile': 'Profile',
    },

    // ========================================================================
    // ARABIC TRANSLATIONS
    // ========================================================================
    'ar': {
      // --- General & Navigation ---
      'settings': 'الإعدادات',
      'help_support': 'المساعدة والدعم',
      'help_support_sub': 'الحصول على المساعدة والتواصل معنا',
      'logout': 'تسجيل خروج',
      'change_language': 'اللغة',
      'change_language_sub': 'English / العربية',
      'back_to_home': 'العودة للرئيسية',
      'back_to_menu': 'العودة للقائمة',
      'cancel': 'إلغاء',
      'clear': 'مسح',
      'save': 'وفر',
      'add': 'إضافة',
      'apply': 'تطبيق',
      'remove': 'إزالة',
      'qar': 'ر.ق',
      'mins': 'دقيقة',
      'km': 'كم',
      'kms': 'كم)',
      'free': 'مجاني',
      'error': 'خطأ:',

      // --- Home & Menu ---
      'popular_items': 'الأكثر طلباً',
      'offers': 'العروض',
      'search_hint': 'ابحث عن وجبات...',
      'no_items': 'لا توجد نتائج',
      'browse_menu': 'تصفح القائمة',
      'spicy': 'حار',
      'out_of_stock': 'نفذت الكمية',
      'unavailable': 'غير متوفر',
      'item_unavailable': 'العنصر غير متوفر',
      'you_might_also_like': 'قد يعجبك أيضاً',
      'no_drinks_available': 'لا توجد مشروبات متاحة للفروع المختارة',

      // --- Cart & Checkout ---
      'cart_title': 'سلة المشتريات',
      'view_cart': 'عرض السلة',
      'add_to_cart': 'أضف للسلة',
      'items': 'عناصر',
      'item': 'عنصر',
      'cart_empty': 'سلتك فارغة',
      'cart_empty_sub': 'يبدو أنك لم تضف أي وجبات بعد',
      'your_cart_empty': 'سلتك فارغة',
      'subtotal': 'المجموع الفرعي',
      'delivery_fee': 'رسوم التوصيل',
      'discount': 'الخصم',
      'total': 'الإجمالي',
      'checkout': 'إتمام الطلب',
      'apply_coupon': 'تطبيق القسيمة',
      'coupon_hint': 'أدخل رمز القسيمة',
      'order_confirmed': 'تم تأكيد الطلب!',
      'order_placed_successfully': 'تم تقديم طلبك بنجاح.',
      'thank_you_order': 'شكراً لطلبك!',
      'view_my_orders': 'عرض طلباتي',
      'items_added_to_cart': 'تمت إضافة العناصر إلى سلتك!',
      'clear_cart_title': 'مسح السلة؟',
      'clear_cart_message': 'سيؤدي هذا إلى إزالة جميع العناصر من سلتك.',
      'item_removed_from_cart': 'تمت الإزالة من السلة',
      'removed_out_of_stock': 'تمت الإزالة (نفذت الكمية)',
      'items_removed_out_of_stock': 'تمت إزالة العناصر (نفذت الكمية)',
      'item_unavailable_title': 'العنصر غير متوفر',
      'items_no_longer_available': 'العناصر التالية لم تعد متوفرة:',
      'remove_items_question': 'هل تريد إزالة هذه العناصر من سلتك؟',
      'keep_items': 'الاحتفاظ بالعناصر',
      'remove_all': 'إزالة الكل',
      'unavailable_items_in_cart': 'عناصر غير متوفرة في السلة',
      'your_items': 'أصنافك',
      'checking_stock': 'جاري التحقق من المخزون...',
      'processing': 'جاري المعالجة...',

      // --- Delivery & Branch Logic ---
      'delivery': 'توصيل',
      'pickup': 'استلام',
      'deliver_to': 'التوصيل إلى',
      'pick_up_from': 'الاستلام من',
      'set_delivery_address': 'تحديد عنوان التوصيل',
      'select_delivery_address': 'اختر عنوان التوصيل',
      'no_delivery_address': 'لم يتم تحديد عنوان التوصيل',
      'please_login_address': 'يرجى تسجيل الدخول لتحديد العنوان.',
      'select_branch': 'اختر الفرع',
      'select_pickup_branch': 'اختر فرع الاستلام',
      'use_nearest_branch': 'استخدم أقرب فرع',
      'nearest_to_address': 'الأقرب لعنوانك',
      'finding_nearest_branch': 'جاري البحث عن أقرب فرع...',
      'finding_nearest_branch_loading': 'جاري البحث عن أقرب فرع...',
      'no_branches_available': 'لا توجد فروع نشطة متاحة',
      'branch_info_not_found': 'معلومات الفرع غير موجودة',
      'branch_location_unavailable': 'موقع الفرع غير متاح',
      'restaurant_just_closed': 'المطعم أغلق للتو',
      'branch_closed_msg':
          'الفرع المختار أغلق للتو. سنحاول العثور على فرع آخر مفتوح لك.',
      'we_are_closed': 'نحن مغلقون',
      'all_branches_closed_msg':
          'جميع مطاعمنا مغلقة حالياً. يرجى التحقق لاحقاً!',
      'restaurant_closed': 'المطعم مغلق',
      'branch_update': 'تحديث الفرع',
      'switched_to': 'قمنا بتحويلك إلى',
      'nearest_branch': 'أقرب فرع',
      'is_currently': 'حالياً',
      'closed': 'مغلق',
      'outside_range': 'خارج نطاق التوصيل',
      'outside_delivery_range': 'خارج نطاق التوصيل',
      'delivery_range_error':
          'عذراً، لا نوصل إلى موقعك. نطاق التوصيل الأقصى هو',
      'location_not_serviceable': 'الموقع غير مدعوم',
      'no_delivery_available_msg':
          'عذراً، لا تقوم أي من فروعنا بالتوصيل إلى موقعك الحالي. يرجى تجربة الاستلام بدلاً من ذلك.',
      'delivery_updated_msg': 'تم تحديث رسوم ووقت التوصيل.',
      'km_away': 'كم بعيداً',
      'distance_to_branch': 'المسافة إلى الفرع',
      'from': 'من',
      'estimated_time': 'الوقت المتوقع:',
      'est': 'المتوقع',
      'time': 'الوقت',
      'free_delivery_within': 'توصيل مجاني (ضمن',

      // --- Payment ---
      'payment_method': 'طريقة الدفع',
      'select_payment_method': 'اختر طريقة الدفع',
      'cash_on_delivery': 'الدفع عند الاستلام',
      'online_payment': 'الدفع الإلكتروني',
      'loading_payment_methods': 'جاري تحميل طرق الدفع...',
      'invalid_payment_method': 'طريقة الدفع المحددة غير صالحة',
      'payment_failed': 'فشل الدفع',
      'payment_not_successful': 'عملية الدفع لم تكن ناجحة.',
      'payment_summary': 'ملخص الدفع',

      // --- Order Status & Details ---
      'your_orders': 'طلباتك',
      'no_orders_found': 'لا توجد طلبات.',
      'order': 'طلب',
      'delivery_order': 'طلب توصيل',
      'dine_in_order': 'طلب تناول في المطعم',
      'takeaway_order': 'طلب استلام',
      'placed_on': 'تم الطلب في',
      'reorder': 'إعادة الطلب',
      'unknown': 'غير معروف',
      'status_pending': 'قيد انتظار التأكيد',
      'status_preparing': 'جاري تحضير طلبك',
      'status_prepared': 'الطلب جاهز - بانتظار السائق',
      'status_pickup_prepared': 'طلبك جاهز للاستلام!',
      'status_collected': 'تم استلام الطلب - شكراً لك!',
      'status_rider_assigned': 'تم تعيين سائق - جاري الاستلام',
      'status_out_for_delivery': 'في الطريق إليك',
      'status_delivered': 'تم التوصيل',
      'status_cancelled': 'تم إلغاء الطلب',
      'status_driver_not_found': 'مشغول - جاري البحث عن سائق قريب...',
      'pickup_ready_title': 'الطلب جاهز!',
      'pickup_ready_msg': 'طلبك جاهز للاستلام.',
      'collected': 'تم الاستلام',
      'order_received_success': 'تم استلام طلبك بنجاح',
      'order_prepared_at': 'سيتم تحضير الطلب في',
      'order_items': 'عناصر الطلب',
      'unit_price': 'سعر الوحدة:',
      'quantity': 'الكمية:',
      'notes_optional': 'ملاحظات (اختياري)',
      'special_requests': 'طلبات خاصة، حساسية، إلخ.',
      'special_instructions': 'تعليمات خاصة',
      'notes_placeholder': 'مثال: بدون بصل، حار جداً...',
      'no_items_in_order': 'لا توجد عناصر في هذا الطلب.',
      'no_items_to_reorder': 'لا توجد عناصر في هذا الطلب لإعادة طلبها.',

      // --- Tracking & Driver ---
      'driver_details': 'تفاصيل السائق',
      'driver': 'السائق',
      'call': 'اتصال',
      'no_phone_available': 'لا يوجد رقم هاتف',
      'could_not_open_dialer': 'تعذر فتح تطبيق الاتصال',
      'loading_driver_location': 'جاري تحميل موقع السائق...',
      'live_tracking': 'تتبع مباشر',
      'fit_all_locations': 'عرض جميع المواقع',
      'center_on_driver': 'التركيز على السائق',
      'you': 'أنت',
      'restaurant': 'المطعم',
      'google_maps': 'خرائط جوجل',
      'apple_maps': 'خرائط أبل',
      'could_not_open_maps': 'تعذر فتح تطبيق الخرائط',
      'error_opening_navigation': 'خطأ في فتح التنقل',

      // --- Filters & Search ---
      'all': 'الكل',
      'pending': 'قيد الانتظار',
      'preparing': 'قيد التحضير',
      'on_the_way': 'في الطريق',
      'delivered': 'تم التوصيل',
      'refunded': 'تم الاسترجاع',
      'load_more': 'تحميل المزيد',
      'search_by_dish': 'ابحث باسم الطبق...',

      // --- Cancellation Reasons ---
      'order_cancelled': 'تم إلغاء الطلب',
      'order_cancelled_msg': 'تم إلغاء طلبك من قبل المطعم.',
      'reason': 'السبب',
      'items_out_of_stock': 'عناصر غير متوفرة',
      'kitchen_busy': 'المطبخ مشغول جداً',
      'closing_soon': 'سنغلق قريباً / مغلق',
      'invalid_address': 'عنوان غير صالح',
      'customer_request': 'طلب العميل',
      'other': 'سبب آخر',
      'unknown_reason': 'لم يتم تقديم سبب',

      // --- Refund Feature (New) ---
      'great': 'رائع!',
      'request_refund': 'طلب استرجاع',
      'refund_reason': 'سبب الاسترجاع',
      'refund_reason_hint': 'اشرح سبب طلب الاسترجاع...',
      'attach_image': 'إرفاق صورة (مطلوب)',
      'submit_request': 'إرسال الطلب',
      'refund_submitted_msg': 'تم إرسال طلب الاسترجاع بنجاح.',
      'image_required': 'يرجى إرفاق صورة للمتابعة.',
      'reason_required': 'يرجى إدخال السبب.',
      'refund_status': 'حالة الاسترجاع',
      'refund_pending': 'قيد المراجعة',
      'refund_accepted': 'تمت الموافقة',
      'refund_rejected': 'تم الرفض',
      'refund_accepted_msg': 'تمت الموافقة على طلب الاسترجاع ومعالجته.',
      'refund_rejected_msg': 'تم رفض طلب الاسترجاع.',
      'refund_pending_msg': 'نقوم حالياً بمراجعة طلبك.',

      // --- Profile & Address ---
      'edit_profile': 'تعديل الملف الشخصي',
      'edit_profile_sub': 'تحديث بياناتك الشخصية',
      'full_name': 'الاسم الكامل',
      'phone_number': 'رقم الهاتف',
      'enter_name_error': 'يرجى إدخال الاسم',
      'enter_phone_error': 'يرجى إدخال رقم الهاتف',
      'profile_updated': 'تم تحديث الملف الشخصي بنجاح',
      'save_changes': 'حفظ التغييرات',
      'saved_addresses': 'العناوين المحفوظة',
      'saved_addresses_sub': 'إدارة عناوين التوصيل',
      'add_new_address': 'إضافة عنوان جديد',
      'no_addresses_saved': 'لا توجد عناوين محفوظة بعد',
      'no_addresses_title': 'لا توجد عناوين محفوظة',
      'no_addresses_subtitle': 'أضف عنواناً للبدء في الطلب.',
      'edit_address': 'تعديل العنوان',
      'tap_map_hint': 'اضغط على الخريطة لتحديد موقع',
      'search_location_hint': 'البحث عن موقع...',
      'label_hint': 'الاسم (مثال: المنزل، العمل)',
      'street_label': 'اسم الشارع',
      'building_label': 'رقم المبنى',
      'floor_label': 'الطابق',
      'flat_label': 'رقم الشقة',
      'city_label': 'المدينة',
      'set_as_default': 'تعيين كافتراضي',
      'default_badge': 'افتراضي',
      'my_favorites': 'المفضلات',
      'my_favorites_sub': 'عرض العناصر المحفوظة',
      'no_favorites_title': 'لا توجد مفضلات',
      'no_favorites_subtitle': 'اضغط على أيقونة الحفظ في أي طبق لإضافته هنا.',
      'removed_from_favorites': 'تمت الإزالة من المفضلات.',

      // --- Support ---
      'contact_us': 'اتصل بنا',
      'contact_support_order': 'تواصل مع الدعم بخصوص الطلب #',
      'describe_issue': 'اشرح المشكلة...',
      'enter_message': 'الرجاء إدخال رسالتك',
      'message_sent': 'تم إرسال رسالتك.',
      'send_message': 'إرسال الرسالة',
      'get_help': 'الحصول على المساعدة',
      'legal_info': 'معلومات قانونية',
      'faqs': 'الأسئلة الشائعة',
      'live_chat': 'محادثة مباشرة',
      'terms_of_service': 'شروط الخدمة',
      'privacy_policy': 'سياسة الخصوصية',
      'user_not_authenticated': 'المستخدم غير مصادق عليه',
      'user_doc_not_found': 'بيانات المستخدم غير موجودة',

      // --- Working Hours / Closing Countdown ---
      'closing_in': 'يغلق خلال',
      'restaurant_closing_soon': 'المطعم سيغلق قريباً - اطلب الآن!',

      // --- Coupons Page ---
      'available_coupons_title': 'القسائم المتاحة',
      'loading_offers': 'جاري تحميل العروض مميزة...',
      'failed_load_coupons': 'فشل تحميل القسائم',
      'try_again': 'يرجى المحاولة مرة أخرى لاحقاً',
      'no_coupons': 'لا توجد قسائم متاحة',
      'check_back_later': 'تحقق لاحقاً من العروض المثيرة!',
      'apply_coupons_msg': 'استخدم القسائم لتوفير المزيد على طلبك!',
      'off': 'خصم',
      'on_orders_above': 'على الطلبات فوق',
      'on_all_orders': 'على جميع الطلبات',
      'valid_until': 'صالح حتى',
      'code': 'الرمز',
      'not_applicable': 'غير صالح للطلب الحالي',
      'coupon_applied_title': 'تم تطبيق القسيمة!',
      'coupon_applied_msg': 'تم تطبيقه على سلتك.',
      'go_to_cart': 'الذهاب للسلة',
      'coupon_failed': 'فشلت القسيمة',
      'failed_apply_coupon': 'فشل تطبيق القسيمة:',

      // --- Navbar ---
      'nav_home': 'الرئيسية',
      'nav_orders': 'الطلبات',
      'nav_offers': 'العروض',
      'nav_cart': 'السلة',
      'nav_profile': 'حسابي',
    },
  };

  static String get(String key, BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return _localizedValues[locale]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  // --- NEW: NUMBER FORMATTER ---
  static String formatNumber(dynamic number, BuildContext context) {
    if (number == null) return '';

    // 1. Convert input to string (handles int, double, etc.)
    String str = number.toString();

    // 2. Check if Arabic is active
    final isArabic =
        Provider.of<LanguageProvider>(context, listen: false).isArabic;
    if (!isArabic) return str;

    // 3. Replace digits
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    for (int i = 0; i < english.length; i++) {
      str = str.replaceAll(english[i], arabic[i]);
    }
    return str;
  }

  // --- NEW: PRICE FORMATTER (Combines Currency + Number) ---
  static String formatPrice(double price, BuildContext context) {
    // Formats to 2 decimal places first: "10.50"
    String formattedPrice = price.toStringAsFixed(2);
    // Converts digits to Arabic if needed
    String localizedNumbers = formatNumber(formattedPrice, context);
    // Gets "QAR" or "ر.ق"
    String currency = get('qar', context);

    return '$currency $localizedNumbers';
  }
}
