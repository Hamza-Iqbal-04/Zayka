import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Import this for date localization
import 'package:provider/provider.dart';
import '../Widgets/bottom_nav.dart';
import 'cartScreen.dart';
import '../Screens/HomeScreen.dart';
import '../Widgets/models.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui';
import '../Services/language_provider.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrdersScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Pagination state (5 per page)
  final int _pageSize = 3;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _isInitialLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;

  // Local lists and UI state
  List<Map<String, dynamic>> _allOrders = [];
  List<Map<String, dynamic>> _filteredOrders = [];

  // Use internal keys instead of translated strings for state
  String _selectedFilterKey = 'all';

  // Internal filter keys
  final List<String> _filterKeys = const [
    'all',
    'pending',
    'preparing',
    'on_the_way',
    'delivered',
  ];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize date formatting data (essential for Arabic dates)
    initializeDateFormatting().then((_) {
      if (mounted) setState(() {});
    });

    _searchController.addListener(_applySearchFilter);
    _resetAndFetch();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applySearchFilter);
    _searchController.dispose();
    super.dispose();
  }

  // Build a base query respecting user and filter
  Query<Map<String, dynamic>> _buildBaseQuery(User user) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('Orders')
        .where('customerId', isEqualTo: user.email)
        .orderBy('timestamp', descending: true);

    if (_selectedFilterKey != 'all') {
      query = query.where('status', isEqualTo: _selectedFilterKey.toLowerCase());
    }

    return query;
  }

  Future<void> _resetAndFetch() async {
    setState(() {
      _isInitialLoading = true;
      _isFetchingMore = false;
      _hasMore = true;
      _lastDoc = null;
      _allOrders = [];
      _filteredOrders = [];
    });
    await _fetchNextPage(initial: true);
  }

  Future<void> _fetchNextPage({bool initial = false}) async {
    if (_isFetchingMore || !_hasMore) return;

    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      setState(() {
        _isInitialLoading = false;
        _isFetchingMore = false;
        _hasMore = false;
      });
      return;
    }

    setState(() {
      _isFetchingMore = true;
    });

    try {
      Query<Map<String, dynamic>> query =
      _buildBaseQuery(user).limit(_pageSize);
      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snap = await query.get();
      final docs = snap.docs;

      if (docs.isNotEmpty) {
        _lastDoc = docs.last;
        final newOrders = docs.map((doc) {
          final data = doc.data();
          final String? customerName = (data['customerName'] ??
              data['customer_name'] ??
              data['name'])
              ?.toString()
              .trim();

          return {
            ...data,
            'id': doc.id,
            'items':
            (data['items'] as List? ?? []).cast<Map<String, dynamic>>(),
            // We removed 'formattedDate' here to handle it dynamically in the UI
            'timestamp': data['timestamp'],
            'statusDisplay':
            _formatOrderStatus(data['status'] as String?),
            'customerName': customerName,
          };
        }).toList();

        setState(() {
          _allOrders.addAll(newOrders);
        });
        _applySearchFilter();
      }

      setState(() {
        _hasMore = docs.length == _pageSize;
      });
    } catch (e) {
      setState(() {
        _hasMore = false;
      });
    } finally {
      setState(() {
        _isInitialLoading = false;
        _isFetchingMore = false;
      });
    }
  }

  void _applySearchFilter() {
    final searchQuery = _searchController.text.toLowerCase();
    setState(() {
      _filteredOrders = searchQuery.isEmpty
          ? List<Map<String, dynamic>>.from(_allOrders)
          : _allOrders.where((order) {
        final items =
        (order['items'] as List).cast<Map<String, dynamic>>();
        // Check both English and Arabic names for search
        return items.any((item) {
          final name = (item['name'] as String? ?? '').toLowerCase();
          final nameAr = (item['name_ar'] as String? ?? '').toLowerCase();
          return name.contains(searchQuery) || nameAr.contains(searchQuery);
        });
      }).toList();
    });
  }

  String _formatOrderStatus(String? status) {
    if (status == null || status.isEmpty) return AppStrings.get('unknown', context);
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade600;
      case 'preparing':
        return Colors.blue.shade600;
      case 'on the way':
      case 'on_the_way':
        return Colors.purple.shade600;
      case 'delivered':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Color _getStatusBackgroundColor(String? status) {
    return _getStatusColor(status).withOpacity(0.08);
  }

  void _navigateToOrderDetails(Map<String, dynamic> order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(order: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          AppStrings.get('your_orders', context),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _resetAndFetch,
              child: _buildPagedList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagedList() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredOrders.isEmpty) {
      return Center(child: Text(AppStrings.get('no_orders_found', context)));
    }

    final footerCount = 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredOrders.length + footerCount,
        itemBuilder: (context, index) {
          if (index < _filteredOrders.length) {
            return _buildOrderCard(_filteredOrders[index]);
          }

          // Footer
          if (_isFetchingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          }

          if (_hasMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton.icon(
                onPressed: _fetchNextPage,
                icon: const Icon(Icons.expand_more, color: Colors.blue),
                label: Text(
                  AppStrings.get('load_more', context),
                  style: const TextStyle(color: Colors.blue),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(
                    color: Colors.lightBlue,
                    width: 1.5,
                  ),
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: AppStrings.get('search_by_dish', context),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filterKeys.map((filterKey) {
            final filterLabel = AppStrings.get(filterKey, context);
            final isSelected = _selectedFilterKey == filterKey;
            final Color activeColor = filterKey == 'all'
                ? AppColors.primaryBlue
                : _getStatusColor(filterKey.toLowerCase());

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filterLabel),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilterKey = selected ? filterKey : 'all';
                  });
                  _resetAndFetch();
                },
                backgroundColor: Colors.white,
                selectedColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? activeColor : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? activeColor : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final items = (order['items'] as List).cast<Map<String, dynamic>>();
    final orderType = order['Order_type'] as String? ?? 'delivery';
    final restaurantAddress = order['restaurantAddress'] as String? ?? '';
    final status = order['status'] as String?;

    // --- Dynamic Date Formatting ---
    final timestamp = order['timestamp'] as Timestamp?;
    String formattedDate = '--';
    if (timestamp != null) {
      final isArabic = Provider.of<LanguageProvider>(context).isArabic;
      final locale = isArabic ? 'ar' : 'en';
      formattedDate = DateFormat('d MMM, h:mm a', locale).format(timestamp.toDate());
    }
    // -------------------------------

    // --- Localization Logic for Item Summary ---
    final isArabic = Provider.of<LanguageProvider>(context).isArabic;
    final itemSummary = items.map((item) {
      final name = item['name'] as String? ?? '';
      final nameAr = item['name_ar'] as String? ?? '';
      final displayName = (isArabic && nameAr.isNotEmpty) ? nameAr : name;
      return "${item['quantity']}x $displayName";
    }).join(', ');
    // -------------------------------------------

    final statusColor = _getStatusColor(status);

    String formattedOrderType;
    switch (orderType.toLowerCase()) {
      case 'delivery':
        formattedOrderType = AppStrings.get('delivery_order', context);
        break;
      case 'dine-in':
        formattedOrderType = AppStrings.get('dine_in_order', context);
        break;
      case 'take_away':
        formattedOrderType = AppStrings.get('takeaway_order', context);
        break;
      default:
        formattedOrderType = AppStrings.get('order', context);
    }

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.35), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToOrderDetails(order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    orderType.toLowerCase() == 'delivery'
                        ? Icons.delivery_dining
                        : orderType.toLowerCase() == 'dine-in'
                        ? Icons.restaurant
                        : Icons.takeout_dining,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedOrderType,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (restaurantAddress.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              restaurantAddress,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: Colors.black12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      itemSummary,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'QAR ${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order['statusDisplay'] as String? ?? AppStrings.get('unknown', context),
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Now using the dynamically formatted date
                  Text(
                    '${AppStrings.get('placed_on', context)} $formattedDate',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final cartService =
                    Provider.of<CartService>(context, listen: false);
                    for (var itemData in items) {
                      final menuItem = MenuItem(
                        id: itemData['itemId'] ?? UniqueKey().toString(),
                        name: itemData['name'] ?? 'Unknown Item',
                        nameAr: itemData['name_ar'] ?? '', // Added Arabic name to MenuItem
                        price: (itemData['price'] as num?)?.toDouble() ?? 0.0,
                        imageUrl: itemData['imageUrl'] as String? ?? '',
                        branchIds: [order['restaurantId'] ?? ''],
                        categoryId: '',
                        description: '',
                        isAvailable: true,
                        isPopular: false,
                        sortOrder: 0,
                        tags: itemData['tags'] as Map<String, dynamic>? ?? {},
                        variants: itemData['variants'] as Map<String, dynamic>? ?? {},
                        outOfStockBranches: [],
                      );
                      cartService.addToCart(
                        menuItem,
                        quantity: (itemData['quantity'] as num?)?.toInt() ?? 1,
                        variants: itemData['variants'] as Map<String, dynamic>?,
                        addons: (itemData['addons'] as List?)
                            ?.map((e) => e.toString())
                            .toList(),
                      );
                    }
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const MainApp(initialIndex: 3),
                      ),
                    );
                  },
                  icon: const Icon(Icons.replay, size: 18),
                  label: Text(AppStrings.get('reorder', context)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderDetailsScreen({Key? key, required this.order}) : super(key: key);

  void _reorderItems(BuildContext context) {
    final cartService = Provider.of<CartService>(context, listen: false);
    final items = (order['items'] as List? ?? []).cast<Map<String, dynamic>>();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.get('no_items_to_reorder', context))),
      );
      return;
    }

    for (var itemData in items) {
      final dynamic rawAddons = itemData['addons'];
      final List<String> addonsList =
      rawAddons is List ? rawAddons.map((e) => e.toString()).toList() : [];

      final menuItem = MenuItem(
        id: itemData['itemId'] ?? UniqueKey().toString(),
        name: itemData['name'] ?? 'Unknown Item',
        nameAr: itemData['name_ar'] ?? '', // Added Arabic name to MenuItem
        price: (itemData['price'] as num?)?.toDouble() ?? 0.0,
        discountedPrice: (itemData['discountedPrice'] as num?)?.toDouble(),
        imageUrl: itemData['imageUrl'] as String? ?? '',
        branchIds: [order['restaurantId'] ?? ''],
        categoryId: '',
        description: '',
        isAvailable: true,
        isPopular: false,
        sortOrder: 0,
        tags: itemData['tags'] as Map<String, dynamic>? ?? {},
        variants: itemData['variants'] as Map<String, dynamic>? ?? {},
        outOfStockBranches: [],
      );

      cartService.addToCart(
        menuItem,
        quantity: (itemData['quantity'] as num?)?.toInt() ?? 1,
        variants: itemData['variants'] as Map<String, dynamic>?,
        addons: addonsList,
      );
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainApp(initialIndex: 3)),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.get('items_added_to_cart', context))),
    );
  }

  Future<void> _contactOnWhatsApp({
    required String rawPhoneE164NoPlus,
    required String message,
  }) async {
    final phone = rawPhoneE164NoPlus.replaceAll(RegExp(r'[^0-9]'), '');
    final appUri = Uri.parse(
      'whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}',
    );
    final webUri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  void _showContactUsSheet(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final messageController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;
    final orderId = order['orderId'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Wrap(
              runSpacing: 20,
              children: [
                Text(
                  '${AppStrings.get('contact_support_order', context)}$orderId',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Form(
                  key: formKey,
                  child: TextFormField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: AppStrings.get('describe_issue', context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 4,
                    validator: (value) =>
                    (value == null || value.isEmpty)
                        ? AppStrings.get('enter_message', context)
                        : null,
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        try {
                          await FirebaseFirestore.instance.collection('support').add({
                            'userId': user?.uid,
                            'userEmail': user?.email,
                            'orderId': orderId,
                            'message': messageController.text,
                            'timestamp': FieldValue.serverTimestamp(),
                            'status': 'pending',
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppStrings.get('message_sent', context))),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${AppStrings.get('error', context)} $e')),
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(AppStrings.get('send_message', context)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<GeoPoint?> _fetchRestaurantGeo(String branchId) async {
    final doc = await FirebaseFirestore.instance.collection('Branch').doc(branchId).get();
    return doc.data()?['address']?['geolocation'] as GeoPoint?;
  }

  Future<void> _callDriver(String rawPhone, BuildContext context) async {
    final phone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('could_not_open_dialer', context))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.get('error', context)} $e')),
        );
      }
    }
  }

  List<Widget> _buildOrderItems(BuildContext context, List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return [Text(AppStrings.get('no_items_in_order', context))];
    }

    final isArabic = Provider.of<LanguageProvider>(context).isArabic;

    return items.map((item) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
      final double? discountedPrice = (item['discountedPrice'] as num?)?.toDouble();
      final effectivePrice = (discountedPrice != null && discountedPrice > 0 && discountedPrice < price)
          ? discountedPrice
          : price;
      final itemTotal = effectivePrice * quantity;

      // Localization Logic
      final name = item['name'] as String? ?? 'Item';
      final nameAr = item['name_ar'] as String? ?? '';
      final displayName = (isArabic && nameAr.isNotEmpty) ? nameAr : name;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$quantity x $displayName', // Uses localized display name
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  if (effectivePrice < price)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        '${AppStrings.get('unit_price', context)} QAR ${effectivePrice.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'QAR ${itemTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                if (effectivePrice < price)
                  Text(
                    'QAR ${(price * quantity).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = (order['items'] as List? ?? []).cast<Map<String, dynamic>>();
    final status = order['status'] as String? ?? 'pending';
    final statusColor = _getStatusColor(status);
    final orderId = order['orderId'] as String? ?? '';
    final riderId = order['riderId'] as String? ?? '';
    final bool showMap = riderId.isNotEmpty && status != 'delivered' && status != 'cancelled';
    final bool showDriverInfo = riderId.isNotEmpty && status != 'delivered' && status != 'cancelled';
    final userGeo = order['deliveryAddress']?['geolocation'] as GeoPoint?;
    final branchId = order['restaurantId'] as String? ?? 'Old_Airport';
    final restaurantGeoFuture = _fetchRestaurantGeo(branchId);

    // --- Dynamic Date Formatting for Order Details Screen ---
    final timestamp = order['timestamp'] as Timestamp?;
    String formattedDate = '--';
    if (timestamp != null) {
      final isArabic = Provider.of<LanguageProvider>(context).isArabic;
      final locale = isArabic ? 'ar' : 'en';
      formattedDate = DateFormat('d MMM, h:mm a', locale).format(timestamp.toDate());
    }
    // --------------------------------------------------------

    Widget liveMapSection = const SizedBox.shrink();
    if (showMap) {
      liveMapSection = FutureBuilder<GeoPoint?>(
        future: restaurantGeoFuture,
        builder: (context, snap) {
          final restaurantGeo = snap.data;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: LiveTrackingMap(
                driverRef: FirebaseFirestore.instance.collection('Drivers').doc(riderId),
                userGeo: userGeo,
                restaurantGeo: restaurantGeo,
              ),
            ),
          );
        },
      );
    }

    Widget driverDetailsSection = const SizedBox.shrink();
    if (showDriverInfo) {
      driverDetailsSection = StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('Drivers').doc(riderId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || !(snap.data?.exists ?? false)) {
            return const SizedBox.shrink();
          }

          final data = snap.data!.data()!;
          final name = (data['name'] as String?)?.trim().isNotEmpty == true
              ? (data['name'] as String)
              : AppStrings.get('driver', context);
          final phone = (data['phone'] ?? '').toString();
          final imageUrl = (data['profileImageUrl'] as String?) ?? '';

          return _buildSectionCard(
            context: context,
            title: AppStrings.get('driver_details', context),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                    child: imageUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          phone.isEmpty ? AppStrings.get('no_phone_available', context) : phone,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: phone.isEmpty ? null : () => _callDriver(phone, context),
                    icon: const Icon(Icons.phone, size: 18),
                    label: Text(AppStrings.get('call', context)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120.0,
            backgroundColor: statusColor,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, right: 16, bottom: 60),
              title: Text(
                'Order #${orderId.split('-').last.padLeft(3, '0')}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              background: Container(color: statusColor),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(40.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: Colors.black.withOpacity(0.1),
                child: Center(
                  child: Text(
                    _formatOrderStatus(status).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      '${AppStrings.get('placed_on', context)} $formattedDate',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ),
                ),
                liveMapSection,
                if (showDriverInfo) ...[
                  driverDetailsSection,
                  const SizedBox(height: 16),
                ],
                _buildSectionCard(
                  context: context,
                  title: AppStrings.get('order_items', context),
                  children: _buildOrderItems(context, items),
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  context: context,
                  title: AppStrings.get('payment_summary', context),
                  children: [_buildPaymentSummary(context)],
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildActionButtons(context),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPaymentSummary(BuildContext context) {
    final subtotal = (order['subtotal'] as num?)?.toDouble() ?? 0.0;
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;

    return Column(
      children: [
        _buildPriceRow(context, AppStrings.get('subtotal', context), subtotal),
        const Divider(height: 24),
        _buildPriceRow(context, AppStrings.get('total', context), totalAmount, isBold: true),
      ],
    );
  }

  Widget _buildPriceRow(BuildContext context, String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 15, color: Colors.grey[700]),
          ),
          Text(
            'QAR ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _reorderItems(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Text(
                AppStrings.get('reorder', context),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                final dailyOrderNumber = order['dailyOrderNumber']?.toString() ?? '';
                const supportNumber = '919152822169';
                final msg = 'Hello, I need help with order #$dailyOrderNumber';
                _contactOnWhatsApp(
                  rawPhoneE164NoPlus: supportNumber,
                  message: msg,
                );
              },
              icon: const FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Colors.white,
                size: 18,
              ),
              label: Text(AppStrings.get('contact_us', context)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade600;
      case 'confirmed':
        return Colors.blue.shade600;
      case 'preparing':
        return Colors.teal.shade600;
      case 'ready':
      case 'delivered':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _formatOrderStatus(String? status) {
    if (status == null || status.isEmpty) return 'Unknown';
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

class LiveTrackingMap extends StatefulWidget {
  const LiveTrackingMap({
    super.key,
    required this.driverRef,
    required this.userGeo,
    required this.restaurantGeo,
  });

  final DocumentReference<Map<String, dynamic>> driverRef;
  final GeoPoint? userGeo;
  final GeoPoint? restaurantGeo;

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap> with TickerProviderStateMixin {
  late final MapController _map;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  LatLng? _driverPos;

  @override
  void initState() {
    super.initState();
    _map = MapController();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    widget.driverRef.snapshots().listen((snap) {
      final data = snap.data();
      final geo = data?['currentLocation'];
      if (geo is GeoPoint) {
        final pos = LatLng(geo.latitude, geo.longitude);
        setState(() => _driverPos = pos);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _map.move(pos, _map.camera.zoom ?? 15);
          } catch (_) {
            Future.microtask(() {
              try {
                _map.move(pos, _map.camera.zoom ?? 15);
              } catch (_) {}
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Widget _modernBadge(IconData icon, Color color, {bool isPulsing = false}) {
    Widget badge = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 4,
            offset: const Offset(0, -1),
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Icon(
        icon,
        color: Colors.white,
        size: 20,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(1, 1),
            blurRadius: 2,
          ),
        ],
      ),
    );

    if (isPulsing) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: badge,
          );
        },
      );
    }

    return badge;
  }

  void _centerOnDriver() {
    if (_driverPos != null) {
      _map.move(_driverPos!, _map.camera.zoom ?? 15);
    }
  }

  void _fitAllMarkers() {
    final points = <LatLng>[];
    if (_driverPos != null) points.add(_driverPos!);
    if (widget.userGeo != null) {
      points.add(LatLng(widget.userGeo!.latitude, widget.userGeo!.longitude));
    }
    if (widget.restaurantGeo != null) {
      points.add(LatLng(widget.restaurantGeo!.latitude, widget.restaurantGeo!.longitude));
    }

    if (points.length > 1) {
      final bounds = LatLngBounds.fromPoints(points);
      _map.fitCamera(CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ));
    } else if (points.isNotEmpty) {
      _map.move(points.first, 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_driverPos == null) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade50,
              Colors.grey.shade100,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(
                    Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.get('loading_driver_location', context),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final markers = [
      Marker(
        point: _driverPos!,
        width: 50,
        height: 50,
        child: _modernBadge(Icons.directions_car_filled, Colors.blue, isPulsing: true),
      ),
    ];

    if (widget.userGeo != null) {
      markers.add(
        Marker(
          point: LatLng(widget.userGeo!.latitude, widget.userGeo!.longitude),
          width: 45,
          height: 45,
          child: _modernBadge(Icons.home, Colors.green),
        ),
      );
    }

    if (widget.restaurantGeo != null) {
      markers.add(
        Marker(
          point: LatLng(
            widget.restaurantGeo!.latitude,
            widget.restaurantGeo!.longitude,
          ),
          width: 45,
          height: 45,
          child: _modernBadge(Icons.restaurant, Colors.orange),
        ),
      );
    }

    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _driverPos!,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                maxZoom: 18,
                minZoom: 10,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mitra_da_dhaba',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppStrings.get('live_tracking', context),
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (markers.length > 1) ...[
                    _modernFloatingButton(
                      icon: Icons.fullscreen,
                      onPressed: _fitAllMarkers,
                      tooltip: AppStrings.get('fit_all_locations', context),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _modernFloatingButton(
                    icon: Icons.my_location,
                    onPressed: _centerOnDriver,
                    tooltip: AppStrings.get('center_on_driver', context),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _legendItem(
                      Icons.directions_car_filled,
                      Colors.blue,
                      AppStrings.get('driver', context),
                    ),
                    if (widget.userGeo != null) ...[
                      const SizedBox(width: 8),
                      _legendItem(
                        Icons.home,
                        Colors.green,
                        AppStrings.get('you', context),
                      ),
                    ],
                    if (widget.restaurantGeo != null) ...[
                      const SizedBox(width: 8),
                      _legendItem(
                        Icons.restaurant,
                        Colors.orange,
                        AppStrings.get('restaurant', context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modernFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(25),
          child: Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.grey.shade700,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendItem(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 10,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}