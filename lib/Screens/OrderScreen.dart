import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'cartScreen.dart';
import '../Screens/HomeScreen.dart';
import '../Widgets/models.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
  String _selectedFilter = 'All';
  final List<String> _statusFilters = const [
    'All',
    'Pending',
    'Preparing',
    'On the Way',
    'Delivered',
  ];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
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

    if (_selectedFilter != 'All') {
      query = query.where('status', isEqualTo: _selectedFilter.toLowerCase());
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

          return <String, dynamic>{
            ...data,
            'id': doc.id,
            'items':
            (data['items'] as List? ?? []).cast<Map<String, dynamic>>(),
            'formattedDate':
            _formatTimestamp(data['timestamp'] as Timestamp?),
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
        return items.any((item) =>
            (item['name'] as String? ?? '')
                .toLowerCase()
                .contains(searchQuery));
      }).toList();
    });
  }

  String _formatOrderStatus(String? status) {
    if (status == null || status.isEmpty) return 'Unknown';
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '--';
    return DateFormat('d MMM, h:mm a').format(timestamp.toDate());
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade600;
      case 'preparing':
        return Colors.blue.shade600;
      case 'on the way':
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsScreen(order: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keep bright UI
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Your Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
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
      return const Center(child: Text('No orders found.'));
    }

    // Footer will be a "Load more" button or a spinner or nothing
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
                icon: const Icon(Icons.expand_more,color: Colors.blue,),
                label: const Text('Load more', style: TextStyle(color: Colors.blue)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(
                    color: Colors.lightBlue, // light blue border
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
          hintText: 'Search by dish name...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
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
          children: _statusFilters.map((filter) {
            final isSelected = _selectedFilter == filter;

            final Color activeColor = filter == 'All'
                ? AppColors.primaryBlue
                : _getStatusColor(filter.toLowerCase());

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = selected ? filter : 'All';
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
    final items =
    (order['items'] as List).cast<Map<String, dynamic>>();
    final orderType = order['Order_type'] as String? ?? 'delivery';
    final restaurantAddress = order['restaurantAddress'] as String? ?? '';
    final status = order['status'] as String?;
    final itemSummary =
    items.map((item) => "${item['quantity']}x ${item['name']}").join(', ');
    final statusColor = _getStatusColor(status);

    String formattedOrderType;
    switch (orderType.toLowerCase()) {
      case 'delivery':
        formattedOrderType = 'Delivery Order';
        break;
      case 'dine-in':
        formattedOrderType = 'Dine In Order';
        break;
      case 'take_away':
        formattedOrderType = 'Takeaway Order';
        break;
      default:
        formattedOrderType = 'Order';
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
                                  fontSize: 13, color: Colors.grey.shade600),
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
                      order['statusDisplay'] as String? ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Placed on ${order['formattedDate']}',
                    style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                        price:
                        (itemData['price'] as num?)?.toDouble() ?? 0.0,
                        imageUrl: itemData['imageUrl'] as String? ?? '',
                        branchId: order['restaurantId'] ?? '',
                        categoryId: '',
                        description: '',
                        isAvailable: true,
                        isPopular: false,
                        sortOrder: 0,
                        tags:
                        itemData['tags'] as Map<String, dynamic>? ?? {},
                        variants:
                        itemData['variants'] as Map<String, dynamic>? ??
                            {},
                      );
                      cartService.addToCart(
                        menuItem,
                        quantity:
                        (itemData['quantity'] as num?)?.toInt() ?? 1,
                        variants:
                        itemData['variants'] as Map<String, dynamic>?,
                        addons: (itemData['addons'] as List?)
                            ?.map((e) => e.toString())
                            .toList(),
                      );
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CartScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('REORDER'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
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
    final items =
        (order['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This order has no items to reorder.')),
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
        price: (itemData['price'] as num?)?.toDouble() ?? 0.0,
        imageUrl: itemData['imageUrl'] as String? ?? '',
        branchId: order['restaurantId'] ?? '',
        categoryId: '',
        description: '',
        isAvailable: true,
        isPopular: false,
        sortOrder: 0,
        tags: itemData['tags'] as Map<String, dynamic>? ?? {},
        variants: itemData['variants'] as Map<String, dynamic>? ?? {},
      );

      cartService.addToCart(
        menuItem,
        quantity: (itemData['quantity'] as num?)?.toInt() ?? 1,
        variants: itemData['variants'] as Map<String, dynamic>?,
        addons: addonsList,
      );
    }

    Navigator.push(
        context, MaterialPageRoute(builder: (context) => const CartScreen()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Items added to your cart!')),
    );
  }

  Future<void> _contactOnWhatsApp({
    required String rawPhoneE164NoPlus, // e.g., "9745XXXXXXXX" (no +, no spaces)
    required String message,
  }) async {
    // Normalize to digits only as per WhatsApp Click-to-Chat requirements
    final phone = rawPhoneE164NoPlus.replaceAll(RegExp(r'[^0-9]'), '');

    // App scheme first (Android/iOS). If not available, fallback to wa.me universal link.
    final appUri = Uri.parse(
      'whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}',
    );
    final webUri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    // Prefer opening the app directly when possible, else use universal link.
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
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Wrap(
              runSpacing: 20,
              children: [
                Text('Contact Support about order #$orderId',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Form(
                  key: formKey,
                  child: TextFormField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: 'Describe your issue...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 4,
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Please enter your message'
                        : null,
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        try {
                          await FirebaseFirestore.instance
                              .collection('support')
                              .add({
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
                                const SnackBar(
                                    content:
                                        Text('Your message has been sent.')));
                          }
                        } catch (e) {
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('SEND MESSAGE'),
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
    final doc = await FirebaseFirestore.instance
        .collection('Branch')
        .doc(branchId)
        .get();
    return doc.data()?['address']?['geolocation'] as GeoPoint?;
  }

  @override
  Widget build(BuildContext context) {
    final items =
        (order['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final status = order['status'] as String? ?? 'pending';
    final statusColor = _getStatusColor(status);
    final orderId = order['orderId'] as String? ?? '';
    final riderId = order['riderId'] as String? ?? '';

    final bool showMap =
        riderId.isNotEmpty && status != 'delivered' && status != 'cancelled';

    final userGeo = order['deliveryAddress']?['geolocation'] as GeoPoint?;
    final branchId = order['restaurantId'] as String? ??
        'Old_Airport'; // or whatever is stored in the order
    final restaurantGeoFuture = _fetchRestaurantGeo(branchId);

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
                driverRef: FirebaseFirestore.instance
                    .collection('Drivers')
                    .doc(riderId),
                userGeo: userGeo,
                restaurantGeo: restaurantGeo,
              ),
            ),
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
              // --- CHANGE HERE ---
              // Added titlePadding to create more space between the title and the bottom banner.
              titlePadding:
                  const EdgeInsets.only(left: 16, right: 16, bottom: 60),
              title: Text(
                'Order #${orderId.split('-').last.padLeft(3, '0')}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white),
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
                        letterSpacing: 1.2),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                liveMapSection,
                _buildSectionCard(
                    title: 'Order Items', children: _buildOrderItems(items)),
                const SizedBox(height: 16),
                _buildSectionCard(
                    title: 'Payment Summary',
                    children: [_buildPaymentSummary()]),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildActionButtons(context),
    );
  }

  // --- ALL HELPER WIDGETS ARE INCLUDED ---

  Widget _buildSectionCard(
      {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  List<Widget> _buildOrderItems(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return [const Text('No items found in this order.')];
    }
    return items.map((item) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
      final itemTotal = price * quantity;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '$quantity x ${item['name'] ?? 'Item'}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              'QAR ${itemTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildPaymentSummary() {
    final subtotal = (order['subtotal'] as num?)?.toDouble() ?? 0.0;
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;

    return Column(
      children: [
        _buildPriceRow('Subtotal', subtotal),
        const Divider(height: 24),
        _buildPriceRow('Total', totalAmount, isBold: true),
      ],
    );
  }
  // OrderDetailsScreen (near the bottom of the file)

  String _formatOrderType(String? raw) {
    if (raw == null || raw.isEmpty) return 'Order';
    final pretty = raw
        .replaceAll('_', ' ')
        .split(' ')
        .map(
            (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
    return pretty; // e.g. "take_away" → "Take Away"
  }

  Widget _buildPriceRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: Colors.grey[700])),
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

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 16),
          Text(title, style: TextStyle(fontSize: 15, color: Colors.grey[700])),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _reorderItems(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const Text('REORDER',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                final dailyOrderNumber = order['dailyOrderNumber']?.toString() ?? '';
                const supportNumber = '919152822169'; // E.164 digits only, no '+' or spaces
                final msg = 'Hello, I need help with order #$dailyOrderNumber';
                _contactOnWhatsApp(
                  rawPhoneE164NoPlus: supportNumber,
                  message: msg,
                );
              },
              icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 18),
              label: const Text('CONTACT US'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366), // WhatsApp light green
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'Unknown date';
    try {
      final parsedDate = DateTime.parse(date);
      return DateFormat('d MMM yyyy, h:mm a').format(parsedDate);
    } catch (e) {
      return date;
    }
  }
}

class LiveTrackingMap extends StatefulWidget {
  const LiveTrackingMap({
    super.key,
    required this.driverRef,
    required this.userGeo, // customer GeoPoint (nullable)
    required this.restaurantGeo, // restaurant GeoPoint (nullable)
  });

  final DocumentReference<Map<String, dynamic>> driverRef;
  final GeoPoint? userGeo;
  final GeoPoint? restaurantGeo;

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap> {
  late final MapController _map;
  LatLng? _driverPos;

  @override
  void initState() {
    super.initState();
    _map = MapController();

    // listen to driver doc for live GPS
    widget.driverRef.snapshots().listen((snap) {
      final data = snap.data();
      final geo = data?['currentLocation'];
      if (geo is GeoPoint) {
        final pos = LatLng(geo.latitude, geo.longitude);
        setState(() => _driverPos = pos);

        // Schedule after first frame to avoid accessing camera before build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _map.move(pos, _map.camera.zoom ?? 15);
          } catch (_) {
            // If camera still not ready on first microtask, try once more
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

  Widget _badge(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // high-contrast background
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Icon(icon, color: color, size: 18),
    );
  }

  void _centerOnDriver() {
    if (_driverPos != null) {
      _map.move(_driverPos!, _map.camera.zoom ?? 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_driverPos == null) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // ----- build the three markers -----
    final markers = <Marker>[
      Marker(
        // driver
        point: _driverPos!,
        width: 40,
        height: 40,
        child: _badge(Icons.directions_car_filled, Colors.blue),
      ),
    ];

    if (widget.userGeo != null) {
      markers.add(
        Marker(
          // customer
          point: LatLng(widget.userGeo!.latitude, widget.userGeo!.longitude),
          width: 40,
          height: 40,
          child: _badge(Icons.home, Colors.green),
        ),
      );
    }

    if (widget.restaurantGeo != null) {
      markers.add(
        Marker(
          // restaurant
          point: LatLng(
              widget.restaurantGeo!.latitude, widget.restaurantGeo!.longitude),
          width: 40,
          height: 40,
          child: _badge(Icons.restaurant, Colors.orange),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          FlutterMap(                      // ← existing map
            mapController: _map,
            options: MapOptions(
              initialCenter: _driverPos!,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mitra_da_dhaba',
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // --- jump-to-driver FAB ---
          Positioned(
            right: 8,
            bottom: 8,
            child: FloatingActionButton.small(
              heroTag: null,                 // avoid hero clashes in lists
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              elevation: 2,
              onPressed: _centerOnDriver,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
