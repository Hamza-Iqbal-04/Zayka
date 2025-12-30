import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    'en': {
      // Existing translations
      'settings': 'Settings',
      'edit_profile': 'Edit Profile',
      'saved_addresses': 'Saved Addresses',
      'my_favorites': 'My Favorites',
      'help_support': 'Help & Support',
      'logout': 'LOGOUT',
      'change_language': 'Language',
      'change_language_sub': 'English / العربية',
      'popular_items': 'Popular Items',
      'offers': 'Offers',
      'search_hint': 'Search for items...',
      'no_items': 'No items found',
      'view_cart': 'View Cart',
      'add_to_cart': 'ADD TO CART',
      'out_of_stock': 'OUT OF STOCK',
      'unavailable': 'UNAVAILABLE',
      'add': 'ADD',
      'spicy': 'Spicy',
      'save': 'SAVE',
      'items': 'items',
      'item': 'item',
      'cart_title': 'My Cart',
      'cart_empty': 'Your cart is empty',
      'cart_empty_sub': 'Looks like you haven\'t added any items yet.',
      'browse_menu': 'BROWSE MENU',
      'subtotal': 'Subtotal',
      'delivery_fee': 'Delivery Fee',
      'discount': 'Discount',
      'total': 'Total',
      'checkout': 'PROCEED TO CHECKOUT',
      'apply_coupon': 'Apply Coupon',
      'coupon_hint': 'Enter coupon code',
      'apply': 'APPLY',
      'remove': 'REMOVE',
      'qar': 'QAR',

      // Cart screen translations
      'item_unavailable_title': 'Item Unavailable',
      'items_no_longer_available': 'The following items are no longer available:',
      'remove_items_question': 'Would you like to remove these items from your cart?',
      'keep_items': 'Keep Items',
      'remove_all': 'Remove All',
      'removed_out_of_stock': 'removed (out of stock)',
      'items_removed_out_of_stock': 'items removed (out of stock)',
      'you_might_also_like': 'You might also like',
      'no_drinks_available': 'No drinks available for selected branches',
      'item_unavailable': 'Item unavailable',
      'delivery_range_error': 'Sorry, we do not deliver to your location. Maximum delivery range is',
      'km': 'km',
      'your_cart_empty': 'Your cart is empty',
      'user_not_authenticated': 'User not authenticated',
      'user_doc_not_found': 'User document not found',
      'no_delivery_address': 'No delivery address set',
      'invalid_payment_method': 'Invalid Payment Method Selected',
      'free': 'Free',
      'km_away': 'km away',
      'distance_to_branch': 'DISTANCE TO BRANCH',
      'payment_failed': 'Payment Failed',
      'payment_not_successful': 'Your payment was not successful.',
      'google_maps': 'Google Maps',
      'apple_maps': 'Apple Maps',
      'branch_info_not_found': 'Branch information not found',
      'branch_location_unavailable': 'Branch location not available',
      'could_not_open_maps': 'Could not open maps app',
      'error_opening_navigation': 'Error opening navigation',
      'item_removed_from_cart': 'removed from cart',
      'order_confirmed': 'Order Confirmed!',
      'order_placed_successfully': 'Your order has been placed successfully.',
      'thank_you_order': 'Thank you for your order!',
      'view_my_orders': 'View My Orders',
      'back_to_home': 'Back to Home',
      'delivery': 'Delivery',
      'pickup': 'Pickup',
      'cash_on_delivery': 'Cash on Delivery',
      'online_payment': 'Online Payment',
      'select_payment_method': 'Select Payment Method',
      'loading_payment_methods': 'Loading payment methods...',
      'notes_optional': 'Notes (Optional)',
      'special_requests': 'Special requests, allergies, etc.',
      'select_branch': 'Select Branch',
      'use_nearest_branch': 'Use Nearest Branch',
      'estimated_time': 'Estimated Time:',
      'finding_nearest_branch': 'Finding nearest branch...',
      'quantity': 'Qty:',
      'checking_stock': 'CHECKING STOCK...',
      'outside_delivery_range': 'OUTSIDE DELIVERY RANGE',
      'unavailable_items_in_cart': 'UNAVAILABLE ITEMS IN CART',
      'processing': 'PROCESSING...',
      'your_items': 'Your Items',
      'deliver_to': 'DELIVER TO',
      'set_delivery_address': 'Set Delivery Address',
      'pick_up_from': 'PICK UP FROM',
      'nearest_to_address': 'Nearest to your address',
      'payment_method': 'PAYMENT METHOD',
      'est': 'EST.',
      'time': 'Time',
      'back_to_menu': 'Back to Menu',
      'select_delivery_address': 'Select Delivery Address',
      'no_addresses_saved': 'No addresses saved yet',
      'special_instructions': 'Special Instructions',  // ADD THIS
      'notes_placeholder': 'e.g. No onions, Extra spicy...',  // ADD THIS
      'free_delivery_within': 'Free delivery (within',  // ADD THIS
      'kms': 'kms)',
      'please_login_address': 'Please log in to set an address.',
      'select_pickup_branch': 'Select Pickup Branch',
      'no_branches_available': 'No active branches available',
      'finding_nearest_branch_loading': 'Finding nearest branch...',
      'from': 'from',
      // Orders Screen
      'your_orders': 'Your Orders',
      'no_orders_found': 'No orders found.',
      'load_more': 'Load more',
      'search_by_dish': 'Search by dish name...',

      // Status filters
      'all': 'All',
      'pending': 'Pending',
      'preparing': 'Preparing',
      'on_the_way': 'On the Way',
      'delivered': 'Delivered',

      // Order types
      'delivery_order': 'Delivery Order',
      'dine_in_order': 'Dine In Order',
      'takeaway_order': 'Takeaway Order',
      'order': 'Order',

      // Order card
      'reorder': 'REORDER',
      'placed_on': 'Placed on',
      'unknown': 'Unknown',

      // Order details
      'driver_details': 'Driver Details',
      'call': 'CALL',
      'no_phone_available': 'No phone available',
      'order_items': 'Order Items',
      'payment_summary': 'Payment Summary',
      'contact_us': 'CONTACT US',
      'unit_price': 'Unit Price:',
      'no_items_to_reorder': 'This order has no items to reorder.',
      'items_added_to_cart': 'Items added to your cart!',
      'contact_support_order': 'Contact Support about order #',
      'describe_issue': 'Describe your issue...',
      'enter_message': 'Please enter your message',
      'message_sent': 'Your message has been sent.',
      'error': 'Error:',
      'send_message': 'SEND MESSAGE',
      'could_not_open_dialer': 'Could not open the dialer',

      // Live tracking map
      'loading_driver_location': 'Loading driver location...',
      'live_tracking': 'Live Tracking',
      'fit_all_locations': 'Fit all locations',
      'center_on_driver': 'Center on driver',
      'driver': 'Driver',
      'you': 'You',
      'restaurant': 'Restaurant',
      'no_items_in_order': 'No items found in this order.',
      'clear_cart_title': 'Clear Cart?',
      'clear_cart_message': 'This will remove all items from your cart.',
      'cancel': 'Cancel',
      'clear': 'Clear',
      'edit_profile_sub': 'Update your personal information',
      'saved_addresses_sub': 'Manage your delivery locations',
      'my_favorites_sub': 'View your liked items',
      'help_support_sub': 'Get help and contact us',
      // --- EDIT PROFILE SCREEN ---
      'full_name': 'Full Name',
      'phone_number': 'Phone Number',
      'enter_name_error': 'Please enter your name',
      'enter_phone_error': 'Please enter your phone number',
      'profile_updated': 'Profile updated successfully',
      'save_changes': 'SAVE CHANGES',

      // --- SAVED ADDRESSES SCREEN ---
      'add_new_address': 'Add New Address',
      'no_addresses_title': 'No Addresses Saved',
      'no_addresses_subtitle': 'Add an address to get started with your orders.',
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

      // --- FAVORITES SCREEN ---
      'no_favorites_title': 'No Favorites Yet',
      'no_favorites_subtitle': 'Tap the bookmark icon on any dish to save it for later.',
      'removed_from_favorites': 'Removed from favorites.',

      // --- HELP & SUPPORT SCREEN ---
      'get_help': 'GET HELP',
      'legal_info': 'LEGAL INFORMATION',
      'faqs': 'FAQs',
      'live_chat': 'Live Chat',
      'terms_of_service': 'Terms of Service',
      'privacy_policy': 'Privacy Policy',

      'restaurant_just_closed': 'Restaurant Just Closed',
      'branch_closed_msg': 'The selected branch has just closed. We will try to find another open branch for you.',
      'we_are_closed': 'We are Closed',
      'all_branches_closed_msg': 'All our restaurants are currently closed. Please check back later!',
      'branch_update': 'Branch Update',
      'switched_to': 'We switched you to',
      'nearest_branch': 'The nearest branch',
      'is_currently': 'is currently',
      'closed': 'closed',
      'outside_range': 'outside delivery range',
      'delivery_updated_msg': 'Delivery fee and time have been updated.',
      'location_not_serviceable': 'Location Not Serviceable',
      'no_delivery_available_msg': 'Sorry, none of our branches deliver to your current location. Please try Pickup instead.',
      'restaurant_closed': 'Restaurant Closed',
    },
    'ar': {
      // Existing translations
      'restaurant_just_closed': 'المطعم أغلق للتو',
      'branch_closed_msg': 'الفرع المختار أغلق للتو. سنحاول العثور على فرع آخر مفتوح لك.',
      'we_are_closed': 'نحن مغلقون',
      'all_branches_closed_msg': 'جميع مطاعمنا مغلقة حالياً. يرجى التحقق لاحقاً!',
      'branch_update': 'تحديث الفرع',
      'switched_to': 'قمنا بتحويلك إلى',
      'nearest_branch': 'أقرب فرع',
      'is_currently': 'حالياً',
      'closed': 'مغلق',
      'outside_range': 'خارج نطاق التوصيل',
      'delivery_updated_msg': 'تم تحديث رسوم ووقت التوصيل.',
      'location_not_serviceable': 'الموقع غير مدعوم',
      'no_delivery_available_msg': 'عذراً، لا تقوم أي من فروعنا بالتوصيل إلى موقعك الحالي. يرجى تجربة الاستلام بدلاً من ذلك.',
      'restaurant_closed': 'المطعم مغلق',
      // --- EDIT PROFILE SCREEN ---
      'full_name': 'الاسم الكامل',
      'phone_number': 'رقم الهاتف',
      'enter_name_error': 'يرجى إدخال الاسم',
      'enter_phone_error': 'يرجى إدخال رقم الهاتف',
      'profile_updated': 'تم تحديث الملف الشخصي بنجاح',
      'save_changes': 'حفظ التغييرات',

      // --- SAVED ADDRESSES SCREEN ---
      'add_new_address': 'إضافة عنوان جديد',
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

      // --- FAVORITES SCREEN ---
      'no_favorites_title': 'لا توجد مفضلات',
      'no_favorites_subtitle': 'اضغط على أيقونة الحفظ في أي طبق لإضافته هنا.',
      'removed_from_favorites': 'تمت الإزالة من المفضلات.',

      // --- HELP & SUPPORT SCREEN ---
      'get_help': 'الحصول على المساعدة',
      'legal_info': 'معلومات قانونية',
      'faqs': 'الأسئلة الشائعة',
      'contact_us': 'اتصل بنا',
      'live_chat': 'محادثة مباشرة',
      'terms_of_service': 'شروط الخدمة',
      'privacy_policy': 'سياسة الخصوصية',
      // Orders Screen
      'clear_cart_title': 'مسح السلة؟',
      'edit_profile_sub': 'تحديث بياناتك الشخصية',
      'saved_addresses_sub': 'إدارة عناوين التوصيل',
      'my_favorites_sub': 'عرض العناصر المحفوظة',
      'help_support_sub': 'الحصول على المساعدة والتواصل معنا',
      'your_orders': 'طلباتك',
      'no_orders_found': 'لا توجد طلبات.',
      'load_more': 'تحميل المزيد',
      'search_by_dish': 'ابحث باسم الطبق...',
      'clear_cart_message': 'سيؤدي هذا إلى إزالة جميع العناصر من سلتك.',
      'cancel': 'إلغاء',
      'clear': 'مسح',


      // Status filters
      'all': 'الكل',
      'pending': 'قيد الانتظار',
      'preparing': 'قيد التحضير',
      'on_the_way': 'في الطريق',
      'delivered': 'تم التوصيل',

      // Order types
      'delivery_order': 'طلب توصيل',
      'dine_in_order': 'طلب تناول في المطعم',
      'takeaway_order': 'طلب استلام',
      'order': 'طلب',

      // Order card
      'reorder': 'إعادة الطلب',
      'placed_on': 'تم الطلب في',
      'unknown': 'غير معروف',

      // Order details
      'driver_details': 'تفاصيل السائق',
      'call': 'اتصال',
      'no_phone_available': 'لا يوجد رقم هاتف',
      'order_items': 'عناصر الطلب',
      'payment_summary': 'ملخص الدفع',
      'subtotal': 'المجموع الفرعي',
      'total': 'الإجمالي',
      'unit_price': 'سعر الوحدة:',
      'no_items_to_reorder': 'لا توجد عناصر في هذا الطلب لإعادة طلبها.',
      'items_added_to_cart': 'تمت إضافة العناصر إلى سلتك!',
      'contact_support_order': 'تواصل مع الدعم بخصوص الطلب #',
      'describe_issue': 'اشرح المشكلة...',
      'enter_message': 'الرجاء إدخال رسالتك',
      'message_sent': 'تم إرسال رسالتك.',
      'error': 'خطأ:',
      'send_message': 'إرسال الرسالة',
      'could_not_open_dialer': 'تعذر فتح تطبيق الاتصال',

      // Live tracking map
      'loading_driver_location': 'جاري تحميل موقع السائق...',
      'live_tracking': 'تتبع مباشر',
      'fit_all_locations': 'عرض جميع المواقع',
      'center_on_driver': 'التركيز على السائق',
      'driver': 'السائق',
      'you': 'أنت',
      'restaurant': 'المطعم',
      'no_items_in_order': 'لا توجد عناصر في هذا الطلب.',
      'select_pickup_branch': 'اختر فرع الاستلام',
      'no_branches_available': 'لا توجد فروع نشطة متاحة',
      'finding_nearest_branch_loading': 'جاري البحث عن أقرب فرع...',
      'from': 'من',
      'please_login_address': 'يرجى تسجيل الدخول لتحديد العنوان.',
      'settings': 'الإعدادات',
      'edit_profile': 'تعديل الملف الشخصي',
      'saved_addresses': 'العناوين المحفوظة',
      'my_favorites': 'المفضلات',
      'help_support': 'المساعدة والدعم',
      'logout': 'تسجيل خروج',
      'change_language': 'اللغة',
      'change_language_sub': 'English / العربية',
      'popular_items': 'الأكثر طلباً',
      'offers': 'العروض',
      'search_hint': 'ابحث عن وجبات...',
      'no_items': 'لا توجد نتائج',
      'view_cart': 'عرض السلة',
      'add_to_cart': 'أضف للسلة',
      'out_of_stock': 'نفذت الكمية',
      'unavailable': 'غير متوفر',
      'add': 'إضافة',
      'spicy': 'حار',
      'save': 'وفر',
      'items': 'عناصر',
      'item': 'عنصر',
      'cart_title': 'سلة المشتريات',
      'cart_empty': 'سلتك فارغة',
      'cart_empty_sub': 'يبدو أنك لم تضف أي وجبات بعد',
      'browse_menu': 'تصفح القائمة',
      'delivery_fee': 'رسوم التوصيل',
      'discount': 'الخصم',
      'checkout': 'إتمام الطلب',
      'apply_coupon': 'تطبيق القسيمة',
      'coupon_hint': 'أدخل رمز القسيمة',
      'apply': 'تطبيق',
      'remove': 'إزالة',
      'qar': 'ر.ق',
      // Cart screen translations
      'item_unavailable_title': 'العنصر غير متوفر',
      'items_no_longer_available': 'العناصر التالية لم تعد متوفرة:',
      'remove_items_question': 'هل تريد إزالة هذه العناصر من سلتك؟',
      'keep_items': 'الاحتفاظ بالعناصر',
      'remove_all': 'إزالة الكل',
      'removed_out_of_stock': 'تمت الإزالة (نفذت الكمية)',
      'items_removed_out_of_stock': 'تمت إزالة العناصر (نفذت الكمية)',
      'you_might_also_like': 'قد يعجبك أيضاً',
      'no_drinks_available': 'لا توجد مشروبات متاحة للفروع المختارة',
      'item_unavailable': 'العنصر غير متوفر',
      'delivery_range_error': 'عذراً، لا نوصل إلى موقعك. نطاق التوصيل الأقصى هو',
      'km': 'كم',
      'your_cart_empty': 'سلتك فارغة',
      'user_not_authenticated': 'المستخدم غير مصادق عليه',
      'user_doc_not_found': 'بيانات المستخدم غير موجودة',
      'no_delivery_address': 'لم يتم تحديد عنوان التوصيل',
      'invalid_payment_method': 'طريقة الدفع المحددة غير صالحة',
      'free': 'مجاني',
      'km_away': 'كم بعيداً',
      'distance_to_branch': 'المسافة إلى الفرع',
      'payment_failed': 'فشل الدفع',
      'payment_not_successful': 'عملية الدفع لم تكن ناجحة.',
      'google_maps': 'خرائط جوجل',
      'apple_maps': 'خرائط أبل',
      'branch_info_not_found': 'معلومات الفرع غير موجودة',
      'branch_location_unavailable': 'موقع الفرع غير متاح',
      'could_not_open_maps': 'تعذر فتح تطبيق الخرائط',
      'error_opening_navigation': 'خطأ في فتح التنقل',
      'item_removed_from_cart': 'تمت الإزالة من السلة',
      'order_confirmed': 'تم تأكيد الطلب!',
      'order_placed_successfully': 'تم تقديم طلبك بنجاح.',
      'thank_you_order': 'شكراً لطلبك!',
      'view_my_orders': 'عرض طلباتي',
      'back_to_home': 'العودة للرئيسية',
      'delivery': 'توصيل',
      'pickup': 'استلام',
      'cash_on_delivery': 'الدفع عند الاستلام',
      'online_payment': 'الدفع الإلكتروني',
      'select_payment_method': 'اختر طريقة الدفع',
      'loading_payment_methods': 'جاري تحميل طرق الدفع...',
      'notes_optional': 'ملاحظات (اختياري)',
      'special_requests': 'طلبات خاصة، حساسية، إلخ.',
      'select_branch': 'اختر الفرع',
      'use_nearest_branch': 'استخدم أقرب فرع',
      'estimated_time': 'الوقت المتوقع:',
      'finding_nearest_branch': 'جاري البحث عن أقرب فرع...',
      'quantity': 'الكمية:',
      'checking_stock': 'جاري التحقق من المخزون...',
      'outside_delivery_range': 'خارج نطاق التوصيل',
      'unavailable_items_in_cart': 'عناصر غير متوفرة في السلة',
      'processing': 'جاري المعالجة...',
      'your_items': 'عناصرك',
      'deliver_to': 'التوصيل إلى',
      'set_delivery_address': 'تحديد عنوان التوصيل',
      'pick_up_from': 'الاستلام من',
      'nearest_to_address': 'الأقرب لعنوانك',
      'payment_method': 'طريقة الدفع',
      'est': 'المتوقع',
      'time': 'الوقت',
      'back_to_menu': 'العودة للقائمة',
      'select_delivery_address': 'اختر عنوان التوصيل',
      'no_addresses_saved': 'لا توجد عناوين محفوظة بعد',
      'special_instructions': 'تعليمات خاصة',  // ADD THIS
      'notes_placeholder': 'مثال: بدون بصل، حار جداً...',  // ADD THIS
      'free_delivery_within': 'توصيل مجاني (ضمن',  // ADD THIS
      'kms': 'كم)',
    },
  };

  static String get(String key, BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return _localizedValues[locale]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}
