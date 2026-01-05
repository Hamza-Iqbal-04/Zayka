import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:mitra_da_dhaba/Widgets/models.dart';
import 'package:mitra_da_dhaba/Screens/Profile.dart';
import 'package:mitra_da_dhaba/Screens/cartScreen.dart';
import 'package:mitra_da_dhaba/Screens/OrderScreen.dart';
import 'package:shimmer/shimmer.dart';
import '../Widgets/bottom_nav.dart';
import '../Services/language_provider.dart';
import 'package:mitra_da_dhaba/Services/BranchService.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color kChipActive = AppColors.primaryBlue;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Services and state
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Branch / user UI state
  String _currentBranchId = 'Old_Airport'; // Make it mutable
  final BranchService _branchService = BranchService();
  String _estimatedTime = 'Loading...';
  String _userAddressLabel = 'Loading...';
  String _userAddress = 'Loading address...';

  // Carousel
  final PageController _pageController = PageController();
  List<String> _carouselImages = [];
  int _currentPage = 0;
  Timer? _carouselTimer;

  final Set<String> _processedCancelledOrders = {};
  StreamSubscription? _cancellationSubscription;

  // Categories and menu
  List<MenuCategory> _categories = [];
  List<MenuItem> _popularItems = [];
  Map<String, List<MenuItem>> _groupedMenuItems = {};
  StreamSubscription? _menuItemsSubscription;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String get _searchQuery => _searchController.text;

  // User addresses
  List<Map<String, dynamic>> _allAddresses = [];

  // Order status bar
  Stream<List<Order>>? ordersStream;
  String _orderStatusMessage = '';
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  double? _previousProgress;
  String? _previousStatus;

  // Category nav + scroll-to-section
  final ScrollController _categoryBarController = ScrollController();
  final ScrollController _mainScrollController = ScrollController();
  final ValueNotifier<int> _activeCategoryIndexNotifier = ValueNotifier(-1);

  // Anchors and offsets
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, double> _sectionOffsets = {};
  Timer? _offsetDebounce;
  bool _isAnimatingToSection = false;
  List<MenuItem> _allMenuItems = [];

  // Unified loading system
  bool _carouselLoaded = false;
  bool _categoriesLoaded = false;
  bool _menuItemsLoaded = false;
  bool _popularItemsLoaded = false;
  bool _addressLoaded = false;
  bool _etaLoaded = false;

  // Add these for tracking unavailable items
  final Set<String> _notifiedUnavailableItems = {};
  List<MenuItem> _previousMenuItems = [];
  bool _isFirstMenuLoad = true;

  bool get _isEverythingLoaded =>
      _carouselLoaded &&
      _categoriesLoaded &&
      _menuItemsLoaded &&
      _popularItemsLoaded &&
      _addressLoaded &&
      _etaLoaded;

  MenuCategory _createOffersCategory() {
    return MenuCategory(
      id: 'offers',
      branchIds: [_currentBranchId],
      imageUrl: 'https://example.com/offers-icon.png',
      isActive: true,
      name: 'Offers',
      nameAr: 'العروض', // Default Arabic name for hardcoded category
      sortOrder: -1,
    );
  }

  Future<void> _initializeScreen() async {
    try {
      if (mounted) {
        setState(() {
          _carouselLoaded = false;
          _categoriesLoaded = false;
          _menuItemsLoaded = false;
          _popularItemsLoaded = false;
          _addressLoaded = false;
          _etaLoaded = false;
        });
      }

      await Future.delayed(const Duration(milliseconds: 50));
      await _selectNearestBranch();

      await Future.wait([
        _loadUserAddresses(),
        _loadEstimatedTime(),
        _loadCarouselImages(),
        _loadMenuData(),
      ], eagerError: true);
    } catch (e) {
      debugPrint('Error initializing screen: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize. Please try again.';
          _carouselLoaded = true;
          _categoriesLoaded = true;
          _menuItemsLoaded = true;
          _popularItemsLoaded = true;
          _addressLoaded = true;
          _etaLoaded = true;
        });
      }
    }
  }

  Future<void> _selectNearestBranch() async {
    try {
      final nearestBranchId = await _branchService.getNearestBranch();
      if (mounted) {
        setState(() {
          _currentBranchId = nearestBranchId;
        });
      }
      if (mounted) {
        setState(() {
          _categories = [];
          _popularItems = [];
          _groupedMenuItems = {};
          _carouselImages = [];
          _carouselLoaded = false;
          _categoriesLoaded = false;
          _menuItemsLoaded = false;
          _popularItemsLoaded = false;
          _etaLoaded = false;
          _notifiedUnavailableItems.clear();
          _isFirstMenuLoad = true;
          _previousMenuItems = [];
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to select nearest branch: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Using default branch: $_currentBranchId'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Add this method for testing branch switching
  void _testBranchSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Branch for Testing'),
        content: const Text('Choose a branch to test functionality:'),
        actions: [
          TextButton(
            onPressed: () => _switchBranch('Old_Airport'),
            child: const Text('Old Airport'),
          ),
          TextButton(
            onPressed: () => _switchBranch('Mansoura'),
            child: const Text('Mansoura'),
          ),
        ],
      ),
    );
  }

  Future<void> _switchBranch(String branchId) async {
    if (mounted) {
      setState(() {
        _currentBranchId = branchId;
        _categories = [];
        _popularItems = [];
        _groupedMenuItems = {};
        _carouselImages = [];
        _carouselLoaded = false;
        _categoriesLoaded = false;
        _menuItemsLoaded = false;
        _popularItemsLoaded = false;
        _addressLoaded = false;
        _etaLoaded = false;
        _notifiedUnavailableItems.clear();
        _isFirstMenuLoad = true;
        _previousMenuItems = [];
      });

      Navigator.pop(context);

      await Future.wait([
        _loadCarouselImages(),
        _loadMenuData(),
        _loadEstimatedTime(),
      ]);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to branch: $branchId')),
      );
    }
  }

  String _getStatusMessage(String status) {
    // Helper function to capitalize text
    String capitalize(String s) {
      if (s.isEmpty) return s;
      return "${s[0].toUpperCase()}${s.substring(1)}";
    }

    // 1. Clean the status string
    final cleanStatus = status.trim().toLowerCase();

    // 2. Return localized string based on status
    switch (cleanStatus) {
      case 'pending':
        return AppStrings.get('status_pending', context);

      case 'preparing':
      case 'accepted':
        return AppStrings.get('status_preparing', context);

      case 'prepared':
      case 'ready':
        return AppStrings.get('status_prepared', context);

      case 'rider_assigned':
      case 'rider assigned':
        return AppStrings.get('status_rider_assigned', context);

      case 'picked_up':
      case 'picked up':
      case 'pickedup':
      case 'on_the_way':
      case 'on the way':
      case 'ontheway':
      case 'out_for_delivery':
      case 'out for delivery':
        return AppStrings.get('status_out_for_delivery', context);

      case 'delivered':
      case 'completed':
        return AppStrings.get('status_delivered', context);

      case 'cancelled':
      case 'canceled':
      case 'rejected':
        return AppStrings.get('status_cancelled', context);

      // 3. Handle the "Driver Not Found" specific cases
      case 'driver_not_found':
      case 'driver not found':
      case 'no_driver_found':
      case 'retry_driver':
        return AppStrings.get('status_driver_not_found', context);

      // 4. Fallback for unknown statuses
      default:
        // Attempt to clean up snake_case (e.g. payment_failed -> Payment Failed)
        return capitalize(status.replaceAll('_', ' '));
    }
  }

  double _getProgressValue(String status) {
    final cleanStatus = status.trim().toLowerCase();
    switch (cleanStatus) {
      case 'pending':
        return 0.1;
      case 'preparing':
        return 0.25;
      case 'prepared':
        return 0.5;
      case 'rider_assigned':
      case 'rider assigned':
        return 0.75;
      case 'picked_up':
      case 'picked up':
      case 'pickedup':
      case 'on_the_way':
      case 'on the way':
      case 'ontheway':
      case 'out_for_delivery':
      case 'out for delivery':
        return 0.9;
      case 'delivered':
        return 1.0;
      default:
        return 0.0;
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    _setupOrdersStream();
    _setupCancellationListener();

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _bounceAnimation = Tween(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
    _bounceController.repeat(reverse: true);

    _mainScrollController.addListener(_onMainScroll);
    _searchController.addListener(_onSearchChanged);
  }

  void _setupOrdersStream() {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        if (mounted) {
          setState(() {
            ordersStream = Stream.value(const <Order>[]);
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          ordersStream = _firestore
              .collection('Orders')
              .where('customerId', isEqualTo: user.email)
              .where('status', whereNotIn: [
                'delivered',
                'cancelled',
                'rejected',
                'refunded',
                'refund_rejected'
              ])
              .orderBy('timestamp', descending: true)
              .limit(5)
              .snapshots()
              .map((snapshot) {
                return snapshot.docs
                    .map((doc) => Order.fromFirestore(doc))
                    .toList();
              })
              .handleError((error) {
                debugPrint('Error loading orders: $error');
                return <Order>[];
              });
        });
      }
    } catch (e) {
      debugPrint('Error setting up orders stream: $e');
      if (mounted) {
        setState(() {
          ordersStream = Stream.value(const <Order>[]);
        });
      }
    }
  }

  Future<void> _loadMenuData() async {
    await _loadCategories();
    await _loadPopularItems();
    _listenToMenuItems();
  }

  void _onSearchChanged() {
    _updateAndGroupMenuItems(_allMenuItems);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _carouselTimer?.cancel();
    _pageController.dispose();
    _bounceController.dispose();
    _offsetDebounce?.cancel();
    _mainScrollController.removeListener(_onMainScroll);
    _mainScrollController.dispose();
    _categoryBarController.dispose();
    _activeCategoryIndexNotifier.dispose();
    _menuItemsSubscription?.cancel();
    _cancellationSubscription?.cancel();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Update this method in your _HomeScreenState class
  Future<void> _setupCancellationListener() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    // 1. Load the last seen ID from storage BEFORE starting the stream
    final prefs = await SharedPreferences.getInstance();
    final lastShownId = prefs.getString('last_cancelled_popup_id');

    // 2. Add it to our "ignore list" in memory
    if (lastShownId != null) {
      _processedCancelledOrders.add(lastShownId);
    }

    // 3. NOW start listening to Firestore
    _cancellationSubscription = _firestore
        .collection('Orders')
        .where('customerId', isEqualTo: user.email)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final orderId = doc.id;

        // Check if status is cancelled, rejected, or refunded
        if (status == 'cancelled' ||
            status == 'rejected' ||
            status == 'refunded') {
          // 4. Simple check: Have we processed this ID before?
          // (This now includes the ID loaded from SharedPreferences in step 1)
          if (!_processedCancelledOrders.contains(orderId)) {
            // Mark as processed immediately in memory
            _processedCancelledOrders.add(orderId);

            // Save to storage immediately for the NEXT restart
            prefs.setString('last_cancelled_popup_id', orderId);

            if (mounted) {
              if (status == 'refunded') {
                // Show refund approved popup
                _showRefundApprovedDialog();
              } else {
                // Show cancellation/rejection popup
                final rawReason =
                    data['cancellationReason'] as String? ?? 'unknown';
                _showCancellationDialog(rawReason);
              }
            }
          }
        }
      }
    });
  }

  // NEW: Helper to map raw reason text to localized AppStrings
  String _getLocalizedReason(String rawReason) {
    // Normalize string: lowercase and trim to match potential keys
    String key = rawReason.toLowerCase().trim();

    // Map specific phrases to AppStrings keys
    if (key.contains('stock'))
      return AppStrings.get('items_out_of_stock', context);
    if (key.contains('busy')) return AppStrings.get('kitchen_busy', context);
    if (key.contains('clos'))
      return AppStrings.get('closing_soon', context); // matches closing/closed
    if (key.contains('address'))
      return AppStrings.get('invalid_address', context);
    if (key.contains('request'))
      return AppStrings.get('customer_request', context);
    if (key.contains('other')) return AppStrings.get('other', context);

    // Fallback if the admin sends the exact key
    return AppStrings.get(key, context) != key
        ? AppStrings.get(key, context)
        : AppStrings.get('unknown_reason', context);
  }

  // NEW: Show the Popup
  void _showCancellationDialog(String rawReason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cancel_outlined,
                  color: Colors.red.shade400, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppStrings.get('order_cancelled', context),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.get('order_cancelled_msg', context),
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // FIX: Use .toUpperCase() here instead of in TextStyle
                    AppStrings.get('reason', context).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                      // uppercase: true,  <-- REMOVED THIS LINE
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getLocalizedReason(rawReason),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // TextButton(
          //   onPressed: () => Navigator.pop(context),
          //   child: Text(
          //     AppStrings.get('contact_us', context),
          //     style: const TextStyle(color: Colors.grey),
          //   ),
          // ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Show popup for refund approved
  void _showRefundApprovedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outlined,
                  color: Colors.green.shade400, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppStrings.get('refund_accepted', context),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.get('refund_accepted_msg', context),
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      color: Colors.green.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.get('refund_status', context),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    try {
      // your code
    } catch (e, stackTrace) {
      debugPrint('Error: $e\n$stackTrace');
      _showErrorSnackBar('Failed to load data. Please try again.');
    }
  }

  Future<void> _precacheCarousel(BuildContext context) async {
    if (_carouselImages.isEmpty || !mounted) return;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final wPx = (MediaQuery.of(context).size.width * dpr).round();
    final hPx = (MediaQuery.of(context).size.width * 0.55 * dpr).round();

    for (final url in _carouselImages.take(3)) {
      await precacheImage(
        CachedNetworkImageProvider(url, maxWidth: wPx, maxHeight: hPx),
        context,
      );
    }
  }

  void _precachePopular(List<MenuItem> items, double cardW, double imgH) {
    if (items.isEmpty || !mounted) return;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final wPx = (cardW * dpr).round();
    final hPx = (imgH * dpr).round();
    for (final it in items.take(6)) {
      if (it.imageUrl.isNotEmpty) {
        precacheImage(
          CachedNetworkImageProvider(it.imageUrl,
              maxWidth: wPx, maxHeight: hPx),
          context,
        );
      }
    }
  }

  Future<void> _openOrderDetails(String orderId) async {
    try {
      HapticFeedback.lightImpact();
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        if (!mounted) return;
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
        return;
      }

      final doc = await _firestore.collection('Orders').doc(orderId).get();
      if (!mounted) return;

      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order not found')),
        );
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final orderMap = {
        ...data,
        'id': doc.id,
      };

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: orderMap)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open order details: $e')),
      );
    }
  }

  Future<void> _loadCarouselImages() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Branch')
          .doc(_currentBranchId)
          .get();
      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final images = List<String>.from(data?['offer_carousel'] ?? []);
        if (mounted) {
          setState(() {
            _carouselImages = images;
            _carouselLoaded = true;
          });
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _precacheCarousel(context);
        });
        _startCarouselTimer();
      } else {
        if (mounted) {
          setState(() {
            _carouselLoaded = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading carousel images: $e');
      if (mounted) {
        setState(() {
          _carouselLoaded = true;
        });
      }
    }
  }

  Future<List<MenuItem>> _fetchTop5ItemsSold({
    required String branchId,
    List<String> billableStatuses = const ['delivered', 'completed', 'paid'],
  }) async {
    try {
      Query q = FirebaseFirestore.instance.collection('Orders');
      q = q.where('branchId', isEqualTo: branchId);
      if (billableStatuses.isNotEmpty) {
        q = q.where('status', whereIn: billableStatuses);
      }

      final snap = await q.get();
      if (snap.docs.isEmpty) return [];

      final Map<String, int> totals = {};
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final items =
            (data['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
                const [];
        for (final it in items) {
          final String itemId = (it['itemId'] ?? '') as String;
          if (itemId.isEmpty) continue;
          final int qty = (it['quantity'] as num?)?.toInt() ??
              (it['qty'] as num?)?.toInt() ??
              0;
          if (qty <= 0) continue;
          totals[itemId] = (totals[itemId] ?? 0) + qty;
        }
      }

      if (totals.isEmpty) return [];
      final ranked = totals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topIds = ranked.take(5).map((e) => e.key).toList();

      if (topIds.isEmpty) return [];

      final itemsSnap = await FirebaseFirestore.instance
          .collection('menu_items')
          .where(FieldPath.documentId, whereIn: topIds)
          .where('branchIds', arrayContains: branchId)
          .where('isAvailable', isEqualTo: true)
          .get();

      final fetched =
          itemsSnap.docs.map((d) => MenuItem.fromFirestore(d)).toList();
      final Map<String, MenuItem> byId = {for (var m in fetched) m.id: m};

      final List<MenuItem> ordered = [];
      for (final id in topIds) {
        final m = byId[id];
        if (m != null) ordered.add(m);
      }
      return ordered;
    } catch (e) {
      debugPrint("Error fetching top items: $e");
      return [];
    }
  }

  Future<void> _loadPopularItems() async {
    try {
      final items = await _fetchTop5ItemsSold(branchId: _currentBranchId);
      if (mounted) {
        setState(() {
          _popularItems = items;
          _popularItemsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("Error loading popular items: $e");
      if (mounted) {
        setState(() {
          _popularItemsLoaded = true;
        });
      }
    }
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    if (!mounted || _carouselImages.isEmpty) return;

    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted ||
          !_pageController.hasClients ||
          _pageController.page == null) return;

      _currentPage =
          (_pageController.page!.round() + 1) % _carouselImages.length;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadEstimatedTime() async {
    final service = RestaurantService();
    final time = await service.getDynamicEtaForUser(_currentBranchId);
    if (mounted) {
      setState(() {
        _estimatedTime = time;
        _etaLoaded = true;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final querySnapshot = await _firestore
          .collection('menu_categories')
          .where('branchIds', arrayContains: _currentBranchId)
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

      if (mounted) {
        final categories = querySnapshot.docs
            .map((doc) => MenuCategory.fromFirestore(doc))
            .toList();

        setState(() {
          _categories = categories;
          _groupedMenuItems = {for (final c in categories) c.id: []};
          for (final c in categories) {
            _sectionKeys.putIfAbsent(c.id, () => GlobalKey());
          }
          _sectionKeys.putIfAbsent('offers', () => GlobalKey());
          _categoriesLoaded = true;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scheduleRecomputeOffsets();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load menu. Please try again.';
          _categoriesLoaded = true;
        });
      }
    }
  }

  void _listenToMenuItems() {
    _menuItemsSubscription = _firestore
        .collection('menu_items')
        .where('branchIds', arrayContains: _currentBranchId)
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final allItems =
          snapshot.docs.map((doc) => MenuItem.fromFirestore(doc)).toList();
      _updateAndGroupMenuItems(allItems);
      _checkForNewlyUnavailableItems(allItems);

      setState(() {
        _menuItemsLoaded = true;
        _allMenuItems = allItems;
      });
    });
  }

  void _checkForNewlyUnavailableItems(List<MenuItem> currentItems) {
    if (_isFirstMenuLoad) {
      _previousMenuItems = currentItems;
      _isFirstMenuLoad = false;
      return;
    }

    final newlyUnavailableItems = _previousMenuItems.where((previousItem) {
      final currentItem = currentItems.firstWhere(
        (item) => item.id == previousItem.id,
        orElse: () => MenuItem(
          id: '',
          name: '',
          price: 0,
          discountedPrice: null,
          imageUrl: '',
          description: '',
          categoryId: '',
          branchIds: [],
          isAvailable: false,
          isPopular: false,
          sortOrder: 0,
          variants: {},
          tags: {},
          outOfStockBranches: [],
        ),
      );

      return previousItem.isAvailableInBranch(_currentBranchId) &&
          !currentItem.isAvailableInBranch(_currentBranchId);
    }).toList();

    for (final item in newlyUnavailableItems) {
      if (!_notifiedUnavailableItems.contains(item.id)) {
        _showItemUnavailableNotification(item);
        _notifiedUnavailableItems.add(item.id);
      }
    }

    _notifiedUnavailableItems.removeWhere((itemId) {
      final currentItem = currentItems.firstWhere(
        (item) => item.id == itemId,
        orElse: () => MenuItem(
          id: '',
          name: '',
          price: 0,
          discountedPrice: null,
          imageUrl: '',
          description: '',
          categoryId: '',
          branchIds: [],
          isAvailable: false,
          isPopular: false,
          sortOrder: 0,
          variants: {},
          tags: {},
          outOfStockBranches: [],
        ),
      );
      return currentItem.isAvailableInBranch(_currentBranchId);
    });

    _previousMenuItems = currentItems;
  }

  void _showItemUnavailableNotification(MenuItem item) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${item.getLocalizedName(context)} ${AppStrings.get('out_of_stock', context).toLowerCase()}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade50,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.orange.shade200),
        ),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.orange.shade800,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _updateAndGroupMenuItems(List<MenuItem> allItems) {
    final filteredItems = allItems
        .where((item) => item
            .getLocalizedName(context)
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();

    final discountedItems = filteredItems
        .where(
            (item) => item.discountedPrice != null && item.discountedPrice! > 0)
        .toList();

    final Map<String, List<MenuItem>> newGrouped = {};

    if (discountedItems.isNotEmpty) {
      newGrouped['offers'] = discountedItems;
    }

    for (final c in _categories) {
      newGrouped[c.id] =
          filteredItems.where((item) => item.categoryId == c.id).toList();
    }

    if (mounted) {
      setState(() {
        _groupedMenuItems = newGrouped;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleRecomputeOffsets();
      });
    }
  }

  Future<void> _loadUserAddresses() async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('Not logged in');
      }

      final doc = await _firestore.collection('Users').doc(user.email).get();

      // --- NEW CHECK START ---
      // Check if doc doesn't exist OR address field is missing OR address list is empty
      if (!doc.exists ||
          !doc.data()!.containsKey('address') ||
          (doc.data()!['address'] as List).isEmpty) {
        // Trigger the popup
        _showMissingAddressDialog();

        throw Exception('No address set');
      }
      // --- NEW CHECK END ---

      final data = doc.data()!;
      final addresses = data['address'] as List;

      final List<Map<String, dynamic>> addressList = addresses.map((a) {
        final m = Map<String, dynamic>.from(a);
        return {
          'city': m['city'] ?? '',
          'street': m['street'] ?? '',
          'building': m['building'] ?? '',
          'floor': m['floor'] ?? '',
          'flat': m['flat'] ?? '',
          'label': m['label'] ?? '',
          'isDefault': m['isDefault'] ?? false,
        };
      }).toList();

      final Map<String, dynamic> defaultAddress = addressList.firstWhere(
        (a) => a['isDefault'] == true,
        orElse: () => addressList.first,
      );

      final detailedAddress = [
        if ((defaultAddress['flat'] ?? '').toString().isNotEmpty)
          'Flat ${defaultAddress['flat']}',
        if ((defaultAddress['floor'] ?? '').toString().isNotEmpty)
          'Floor ${defaultAddress['floor']}',
        if ((defaultAddress['building'] ?? '').toString().isNotEmpty)
          'Building ${defaultAddress['building']}',
        if ((defaultAddress['street'] ?? '').toString().isNotEmpty)
          'Street ${defaultAddress['street']}',
        if ((defaultAddress['city'] ?? '').toString().isNotEmpty)
          defaultAddress['city'],
      ].join(', ');

      if (mounted) {
        setState(() {
          _allAddresses = addressList;
          _userAddress = detailedAddress.isNotEmpty
              ? detailedAddress
              : 'No address details';
          _userAddressLabel = (defaultAddress['label'] ?? '').toString();
          _addressLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e.toString().contains('No address set')) {
            _userAddress =
                'No address added. Please add an address to continue.';
            _userAddressLabel = 'Add Address';
          } else if (e.toString().contains('Not logged in')) {
            _userAddress = 'Please log in to manage addresses';
            _userAddressLabel = 'Login Required';
          } else {
            _userAddress = 'Error loading address. Please try again.';
            _userAddressLabel = 'Error';
          }
          _addressLoaded = true;
        });
      }
    }
  }

  void _showMissingAddressDialog() {
    // Ensure the dialog shows after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false, // User must interact with the buttons
        builder: (BuildContext context) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_off_rounded,
                      color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Missing Address",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              "We couldn't find a saved address for you. Please add at least one address to place orders and check availability.",
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Browse Menu",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  // Go to Address Screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SavedAddressesScreen()),
                  ).then((_) {
                    // When they come back, try loading data again
                    _initializeScreen();
                  });
                },
                child: const Text("Add Address"),
              ),
            ],
          );
        },
      );
    });
  }

  void _showAddressBottomSheet(
      Function(String label, String fullAddress) onAddressSelected) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Users')
              .doc(user.email)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const SizedBox(
                  height: 200,
                  child: Center(
                    child: Text('Loading addresses...'),
                  ),
                ),
              );
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            final addresses =
                (userData?['address'] as List?)?.cast<Map<String, dynamic>>() ??
                    [];

            return SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.get('saved_addresses',
                            context), // Using localized string
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 24),
                      if (addresses.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text('No addresses saved yet',
                              style: TextStyle(color: Colors.grey[600])),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: addresses.length,
                          itemBuilder: (context, index) {
                            final address = addresses[index];
                            final detailedAddress = [
                              if (address['flat'] != null &&
                                  address['flat'] != '')
                                'Flat ${address['flat']}',
                              if (address['floor'] != null &&
                                  address['floor'] != '')
                                'Floor ${address['floor']}',
                              if (address['building'] != null &&
                                  address['building'] != '')
                                'Building ${address['building']}',
                              if (address['street'] != null &&
                                  address['street'] != '')
                                'Street ${address['street']}',
                              if (address['city'] != null &&
                                  address['city'] != '')
                                address['city'],
                            ].join(', ');
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.grey[100],
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue[50],
                                  child: Icon(
                                    address['label'] == 'Home'
                                        ? Icons.home
                                        : Icons.work,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                                title: Text(address['label'] ?? 'Unnamed',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(detailedAddress,
                                    style:
                                        const TextStyle(color: Colors.black54)),
                                trailing: address['isDefault'] == true
                                    ? const Icon(Icons.check_circle,
                                        color: Colors.green)
                                    : null,
                                onTap: () async {
                                  final currentUser =
                                      FirebaseAuth.instance.currentUser;
                                  if (currentUser == null ||
                                      currentUser.email == null) return;

                                  final updated = addresses.map((a) {
                                    final isThis =
                                        const MapEquality().equals(a, address);
                                    return {...a, 'isDefault': isThis};
                                  }).toList();

                                  await FirebaseFirestore.instance
                                      .collection('Users')
                                      .doc(currentUser.email)
                                      .update({'address': updated});

                                  final newDetailedAddress = [
                                    if (address['flat'] != null &&
                                        address['flat'] != '')
                                      'Flat ${address['flat']}',
                                    if (address['floor'] != null &&
                                        address['floor'] != '')
                                      'Floor ${address['floor']}',
                                    if (address['building'] != null &&
                                        address['building'] != '')
                                      'Building ${address['building']}',
                                    if (address['street'] != null &&
                                        address['street'] != '')
                                      'Street ${address['street']}',
                                    if (address['city'] != null &&
                                        address['city'] != '')
                                      address['city'],
                                  ].join(', ');

                                  Navigator.pop(context);
                                  onAddressSelected(
                                      address['label'] ?? 'Unnamed',
                                      newDetailedAddress);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              '${address['label']} selected for delivery')),
                                    );
                                  }
                                  _loadEstimatedTime();
                                },
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const SavedAddressesScreen()),
                            );
                          },
                          child: const Text('Manage Addresses',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _scheduleRecomputeOffsets() {
    _offsetDebounce?.cancel();
    _offsetDebounce = Timer(const Duration(milliseconds: 100), () {
      if (mounted) _recomputeSectionOffsets();
    });
  }

  void _recomputeSectionOffsets() {
    if (!mounted || !_mainScrollController.hasClients) return;

    final RenderObject? scrollRenderObject = context.findRenderObject();
    if (scrollRenderObject == null) return;

    final Map<String, double> newOffsets = {};

    void addOffset(String keyId) {
      final key = _sectionKeys[keyId];
      if (key?.currentContext != null) {
        final RenderBox? box =
            key!.currentContext!.findRenderObject() as RenderBox?;
        if (box != null) {
          final dy =
              box.localToGlobal(Offset.zero, ancestor: scrollRenderObject).dy;
          final offset = _mainScrollController.offset + dy;
          newOffsets[keyId] = offset;
        }
      }
    }

    final offersItems = _groupedMenuItems['offers'] ?? [];
    if (offersItems.isNotEmpty) {
      addOffset('offers');
    }

    for (final c in _categories) {
      if (_groupedMenuItems[c.id]?.isNotEmpty ?? false) {
        addOffset(c.id);
      }
    }

    _sectionOffsets
      ..clear()
      ..addAll(newOffsets);
  }

  void _onMainScroll() {
    if (_isAnimatingToSection) return;

    if (_sectionOffsets.isEmpty) {
      _recomputeSectionOffsets();
      if (_sectionOffsets.isEmpty) return;
    }

    final double headerHeight = kToolbarHeight + 52 + 10;
    final currentOffset = _mainScrollController.offset + headerHeight;

    final double selectionThreshold = 10.0;
    if (currentOffset < selectionThreshold) {
      if (_activeCategoryIndexNotifier.value != -1) {
        _activeCategoryIndexNotifier.value = -1;
      }
      return;
    }

    int? bestIndex;
    double smallestDistance = double.infinity;

    final allCategories = _getAllCategoriesWithOffers();

    for (int i = 0; i < allCategories.length; i++) {
      final categoryId = allCategories[i]['id'];
      final sectionOffset = _sectionOffsets[categoryId];

      if (sectionOffset != null) {
        if (currentOffset >= sectionOffset) {
          final distance = currentOffset - sectionOffset;
          if (distance < smallestDistance) {
            smallestDistance = distance;
            bestIndex = i;
          }
        }
      }
    }

    bestIndex ??= _activeCategoryIndexNotifier.value;

    if (bestIndex != _activeCategoryIndexNotifier.value) {
      _activeCategoryIndexNotifier.value = bestIndex;
      _centerCategoryChip(bestIndex);
    }
  }

  void _centerCategoryChip(int index) {
    if (!_categoryBarController.hasClients || !mounted) return;
    const double estChipWidth = 112.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset =
        (index * (estChipWidth + 8.0)) - (screenWidth / 2) + (estChipWidth / 2);

    final clampedOffset = targetOffset.clamp(
      0.0,
      _categoryBarController.position.maxScrollExtent,
    );

    _categoryBarController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _onCategoryTap(int index) async {
    final allCategories = _getAllCategoriesWithOffers();
    if (allCategories.isEmpty || index >= allCategories.length) return;

    _activeCategoryIndexNotifier.value = index;
    final category = allCategories[index];
    final id = category['id'];
    final key = _sectionKeys[id];

    if (key?.currentContext == null) {
      debugPrint("Context for category $id not found, cannot scroll.");
      return;
    }

    _isAnimatingToSection = true;
    _centerCategoryChip(index);

    await Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      alignment: 0.0,
    );

    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) {
        _isAnimatingToSection = false;
      }
    });
  }

  List<Map<String, dynamic>> _getAllCategoriesWithOffers() {
    final List<Map<String, dynamic>> allCategories = [];
    final isArabic =
        Provider.of<LanguageProvider>(context, listen: false).isArabic;

    if (_groupedMenuItems['offers']?.isNotEmpty ?? false) {
      allCategories.add({
        'id': 'offers',
        'name': AppStrings.get('offers', context),
      });
    }

    allCategories.addAll(_categories
        .map((cat) => {
              'id': cat.id,
              'name': cat.getLocalizedName(context),
            })
        .toList());

    return allCategories;
  }

  Widget buildCartAndOrderBar() {
    final pageController = PageController();

    return StreamBuilder<List<Order>>(
      stream: ordersStream,
      builder: (context, orderSnapshot) {
        List<Widget> orderBars = const [];
        if (orderSnapshot.connectionState == ConnectionState.waiting) {
          orderBars = const [];
        } else if (orderSnapshot.hasError) {
          orderBars = [_buildOrderErrorWidget()];
        } else if (orderSnapshot.hasData && orderSnapshot.data!.isNotEmpty) {
          final orders = orderSnapshot.data!;
          orderBars = orders.map((o) => _buildOrderStatusWidget(o)).toList();
        }

        return Consumer<CartService>(
          builder: (context, cart, _) {
            Widget? cartBar;
            if (cart.itemCount > 0) {
              cartBar = _buildPersistentCartBar(cart);
            }

            final pages = <Widget>[
              ...orderBars,
              if (cartBar != null) cartBar,
            ];

            if (pages.isEmpty) return const SizedBox.shrink();
            if (pages.length == 1) return pages.first;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 100,
                  child: PageView(
                    controller: pageController,
                    children: pages,
                  ),
                ),
                const SizedBox(height: 8),
                SmoothPageIndicator(
                  controller: pageController,
                  count: pages.length,
                  effect: ScrollingDotsEffect(
                    dotHeight: 8,
                    dotWidth: 8,
                    activeDotColor: AppColors.primaryBlue,
                    dotColor: Colors.grey.shade300,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOrderStatusWidget(Order order) {
    final statusMessage = _getStatusMessage(order.status);
    final progress = _getProgressValue(order.status);

    return InkWell(
      onTap: () => _openOrderDetails(order.id),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryBlue.withOpacity(0.95),
              AppColors.primaryBlue.withOpacity(0.8),
              AppColors.primaryBlue.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: AnimatedBuilder(
                animation: _bounceAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _bounceAnimation.value,
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    statusMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 6,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOutCubic,
                      width: MediaQuery.of(context).size.width * 0.6 * progress,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderErrorWidget() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: [Colors.red.shade400, Colors.red.shade600]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.error_outline, color: Colors.white, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Error loading order status',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double mainNavBarHeight =
        64.0 + MediaQuery.of(context).padding.bottom;
    const double buffer = 15.0;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            controller: _mainScrollController,
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: false,
                expandedHeight: 70,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                flexibleSpace: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFE3F2FD), Colors.white],
                    ),
                  ),
                ),
                title: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: GestureDetector(
                      onTap: () {
                        _showAddressBottomSheet((selectedLabel, selectedAddr) {
                          if (mounted) {
                            setState(() {
                              _userAddressLabel = selectedLabel;
                              _userAddress = selectedAddr;
                            });
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFF1E88E5).withOpacity(0.12),
                              width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: Colors.blue, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _userAddressLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black),
                                  ),
                                  Text(
                                    _userAddress,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.timer_outlined,
                                      size: 16, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    _estimatedTime,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.blue),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Carousel
              SliverToBoxAdapter(
                child: !_isEverythingLoaded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            height: MediaQuery.of(context).size.width * 0.55,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.width * 0.55,
                          width: double.infinity,
                          child: RepaintBoundary(
                            child: PageView.builder(
                              physics: const PageScrollPhysics(),
                              controller: _pageController,
                              itemCount: _carouselImages.length,
                              onPageChanged: (i) => _currentPage = i,
                              itemBuilder: (context, index) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 2.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: _carouselImages[index],
                                      fit: BoxFit.cover,
                                      fadeInDuration:
                                          const Duration(milliseconds: 150),
                                      fadeOutDuration:
                                          const Duration(milliseconds: 150),
                                      filterQuality: FilterQuality.low,
                                      placeholder: (_, __) => Container(
                                          color: Colors.grey.shade300),
                                      errorWidget: (_, __, ___) =>
                                          const Icon(Icons.broken_image),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
              ),

              // Sticky Category Navigation Bar
              SliverPersistentHeader(
                pinned: true,
                delegate: _GlassTabBarDelegate(
                  height: 52,
                  child: !_isEverythingLoaded
                      ? Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            color: Colors.white,
                            height: 52,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                itemCount: 6,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: Container(
                                      width: 80,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                      : ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              color: Colors.white.withOpacity(0.1),
                              alignment: Alignment.center,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 40,
                                    color: Colors.white.withOpacity(0.55),
                                    child: ListView.builder(
                                      controller: _categoryBarController,
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      itemCount: _getAllCategoriesWithOffers()
                                          .length, // Use the combined list
                                      itemBuilder: (context, index) {
                                        final allCategories =
                                            _getAllCategoriesWithOffers();
                                        final category = allCategories[index];
                                        final isOffersCategory =
                                            category['id'] == 'offers';

                                        return ValueListenableBuilder<int>(
                                          valueListenable:
                                              _activeCategoryIndexNotifier,
                                          builder: (context, activeIndex, _) {
                                            final isActive =
                                                activeIndex == index;
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4),
                                              child: GestureDetector(
                                                onTap: () =>
                                                    _onCategoryTap(index),
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                      milliseconds: 200),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 10,
                                                      vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: isActive
                                                        ? kChipActive
                                                            .withOpacity(0.85)
                                                        : Colors.white
                                                            .withOpacity(0.55),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    border: Border.all(
                                                      color: isActive
                                                          ? kChipActive
                                                          : Colors.white
                                                              .withOpacity(0.7),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (isOffersCategory)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  right: 6),
                                                          child: Icon(
                                                            Icons.local_offer,
                                                            size: 16,
                                                            color: isActive
                                                                ? Colors.white
                                                                : Colors.blue,
                                                          ),
                                                        )
                                                      else if (category[
                                                                  'imageUrl'] !=
                                                              null &&
                                                          category['imageUrl']
                                                              .isNotEmpty)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  right: 6),
                                                          child: ClipOval(
                                                            child:
                                                                CachedNetworkImage(
                                                              imageUrl: category[
                                                                  'imageUrl'],
                                                              width: 16,
                                                              height: 16,
                                                              fit: BoxFit.cover,
                                                              errorWidget: (_,
                                                                      __,
                                                                      ___) =>
                                                                  Icon(
                                                                Icons
                                                                    .fastfood_rounded,
                                                                size: 16,
                                                                color: isActive
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .black54,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      Text(
                                                        category['name'],
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          height: 1.2,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: isActive
                                                              ? Colors.white
                                                              : Colors.black87,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              // Main Content
              SliverToBoxAdapter(
                child: !_isEverythingLoaded
                    ? _buildHomeShimmer()
                    : _buildMenuContent(),
              ),
              // Bottom padding
              SliverToBoxAdapter(
                child: SizedBox(height: mainNavBarHeight + 30),
              ),
            ],
          ),

          // Swipeable cart and order bar
          Positioned(
            bottom: mainNavBarHeight - buffer,
            left: 0,
            right: 0,
            child: buildCartAndOrderBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildPersistentCartBar(CartService cart) {
    if (cart.itemCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.95 + (0.05 * value),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (_) => const MainApp(initialIndex: 3)),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.primaryBlue,
                      AppColors.primaryBlue.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.2), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            // UPDATED: Localized item count
                            AppStrings.formatNumber(cart.itemCount, context),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppStrings.get('view_cart', context),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16),
                            ),
                            Text(
                              // UPDATED: Localized count in subtitle
                              '${AppStrings.formatNumber(cart.itemCount, context)} ${AppStrings.get(cart.itemCount > 1 ? 'items' : 'item', context)}',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            // UPDATED: Localized Price
                            AppStrings.formatPrice(
                                cart.totalAfterDiscount, context),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16),
                          ),
                          if (cart.totalAfterDiscount < cart.totalAmount) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                AppStrings.get('save', context),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuContent() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(_errorMessage!),
        ),
      );
    }

    if (_categories.isEmpty && _isEverythingLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No categories available')),
      );
    }

    final screenW = MediaQuery.of(context).size.width;
    final cardW = (screenW * 0.45).clamp(150.0, 220.0);
    final imgH = cardW * 0.78;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_popularItems.isNotEmpty)
            _buildPopularItemsSection(_popularItems, cardW, imgH),
          _buildGroupedMenuSections(),
        ],
      ),
    );
  }

  Widget _buildHomeShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Container(
              height: MediaQuery.of(context).size.width * 0.55,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 6,
                itemBuilder: (context, index) => Container(
                  width: 80,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 230,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    itemBuilder: (context, index) => Container(
                      width: 160,
                      margin:
                          EdgeInsets.only(right: 16, left: index == 0 ? 0 : 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 60,
                                  height: 14,
                                  color: Colors.white,
                                ),
                              ],
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
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: List.generate(
                  4,
                  (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildMenuItemShimmer(),
                      )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemShimmer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            height: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 100,
                            height: 14,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularItemsSection(
      List<MenuItem> items, double cardW, double imgH) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _precachePopular(items, cardW, imgH);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(AppStrings.get('popular_items', context),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.none,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _PopularItemCard(
                item: item,
                cardWidth: cardW,
                imageHeight: imgH,
                currentBranchId: _currentBranchId,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildGroupedMenuSections() {
    final List<Widget> children = [];

    final offersItems = _groupedMenuItems['offers'] ?? [];
    if (offersItems.isNotEmpty) {
      children.add(
        _CategorySection(
          key: _sectionKeys['offers'],
          title: AppStrings.get('offers', context),
          items: offersItems,
          currentBranchId: _currentBranchId,
          isOffersSection: true,
        ),
      );
    }

    for (int i = 0; i < _categories.length; i++) {
      final cat = _categories[i];
      final list = _groupedMenuItems[cat.id] ?? const [];

      if (_searchQuery.isNotEmpty && list.isEmpty) continue;

      children.add(
        _CategorySection(
          key: _sectionKeys[cat.id],
          title: cat.getLocalizedName(context),
          items: list,
          currentBranchId: _currentBranchId,
        ),
      );
    }

    if (_searchQuery.isNotEmpty && children.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.search_off, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(AppStrings.get('no_items', context),
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Try adjusting your search',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 32),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _GlassTabBarDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _GlassTabBarDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _GlassTabBarDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}

class _CategorySection extends StatelessWidget {
  final String title;
  final List<MenuItem> items;
  final bool isOffersSection;
  final String currentBranchId;

  const _CategorySection({
    Key? key,
    required this.title,
    required this.items,
    required this.currentBranchId,
    this.isOffersSection = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                if (isOffersSection)
                  const Icon(Icons.local_offer, color: Colors.blue, size: 20),
                if (isOffersSection) const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'No items in this category',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: items.length,
              itemBuilder: (_, index) => MenuItemCard(
                item: items[index],
                currentBranchId: currentBranchId,
                showDiscountBadge: isOffersSection,
              ),
            ),
        ],
      ),
    );
  }
}

class _PopularItemCard extends StatelessWidget {
  const _PopularItemCard({
    Key? key,
    required this.item,
    required this.cardWidth,
    required this.imageHeight,
    required this.currentBranchId,
  }) : super(key: key);

  final MenuItem item;
  final double cardWidth;
  final double imageHeight;
  final String currentBranchId;

  @override
  Widget build(BuildContext context) {
    final isAvailable = item.isAvailableInBranch(currentBranchId);

    return GestureDetector(
      onTap: () {
        if (!isAvailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${item.getLocalizedName(context)} is currently out of stock'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => DishDetailsBottomSheet(item: item),
        );
      },
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: cardWidth,
              height: imageHeight,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Opacity(
                      opacity: isAvailable ? 1.0 : 0.6,
                      child: CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        width: cardWidth,
                        height: imageHeight,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 150),
                        fadeOutDuration: const Duration(milliseconds: 150),
                        filterQuality: FilterQuality.low,
                        placeholder: (_, __) =>
                            Container(color: Colors.grey.shade200),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.fastfood, color: Colors.grey),
                      ),
                    ),
                  ),
                  if (!isAvailable)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inventory_2_outlined,
                                  color: Colors.white, size: 24),
                              const SizedBox(height: 4),
                              Text(
                                AppStrings.get('out_of_stock', context),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (isAvailable)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Material(
                            color: Colors.white.withOpacity(0.75),
                            child: InkWell(
                              onTap: () {
                                final cart = CartService();
                                cart.addToCart(item);

                                HapticFeedback.lightImpact();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '${item.getLocalizedName(context)} added to cart'),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                child: Row(
                                  children: [
                                    Text(AppStrings.get('add', context),
                                        style: const TextStyle(
                                            color: AppColors.primaryBlue,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13)),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.add_rounded,
                                        color: AppColors.primaryBlue, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!isAvailable)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Material(
                            color: Colors.grey.withOpacity(0.75),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.block,
                                      color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                  Text(AppStrings.get('unavailable', context),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                item.getLocalizedName(context),
                textAlign: TextAlign.left,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isAvailable ? Colors.black : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _buildPriceSection(context, item, isAvailable),
            ),
            const SizedBox(height: 4),
            if (item.tags['isSpicy'] == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        color: isAvailable ? Colors.red : Colors.grey,
                        size: 16),
                    const SizedBox(width: 4),
                    Text(AppStrings.get('spicy', context),
                        style: TextStyle(
                            color: isAvailable ? Colors.red : Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection(
      BuildContext context, MenuItem item, bool isAvailable) {
    // FIX: Using formatPrice correctly with doubles
    if (item.discountedPrice != null && item.discountedPrice! > 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppStrings.formatPrice(item.discountedPrice!, context),
                style: TextStyle(
                  color: isAvailable ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                AppStrings.formatPrice(item.price, context),
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
          if (isAvailable) const SizedBox(height: 2),
          if (isAvailable)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${AppStrings.get('save', context)} ${AppStrings.formatPrice(item.price - item.discountedPrice!, context)}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      );
    } else {
      return Text(
        AppStrings.formatPrice(item.price, context),
        textAlign: TextAlign.left,
        style: TextStyle(
          color: isAvailable ? AppColors.primaryBlue : Colors.grey,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      );
    }
  }
}

class Order {
  final String id;
  final String status;

  Order({required this.id, required this.status});

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Order(
      id: doc.id,
      status: data['status'] ?? 'unknown',
    );
  }
}

class MenuItemCard extends StatefulWidget {
  final MenuItem item;
  final bool showDiscountBadge;
  final String currentBranchId;

  const MenuItemCard({
    Key? key,
    required this.item,
    this.showDiscountBadge = true,
    required this.currentBranchId,
  }) : super(key: key);

  @override
  State<MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<MenuItemCard> {
  static const double _buttonFloat = 24;
  static const double _extraBottomSpace = 12;

  bool _isFavorite = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  Future<void> _checkIfFavorite() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    try {
      final doc = await _firestore.collection('Users').doc(user.email).get();
      if (doc.exists && mounted) {
        final favorites =
            doc.data()?['favorites'] as Map<String, dynamic>? ?? {};
        if (mounted) {
          setState(() => _isFavorite = favorites.containsKey(widget.item.id));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking favorite: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add favorites.')),
      );
      return;
    }

    if (mounted) setState(() => _isFavorite = !_isFavorite);

    try {
      await _firestore.collection('Users').doc(user.email).set({
        'favorites': {
          widget.item.id:
              _isFavorite ? _createFavoriteItemMap() : FieldValue.delete()
        },
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        setState(() => _isFavorite = !_isFavorite);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating favorite: ${e.toString()}')),
        );
      }
    }
  }

  Map<String, dynamic> _createFavoriteItemMap() => {
        'id': widget.item.id,
        'name': widget.item.name,
        'imageUrl': widget.item.imageUrl,
        'price': widget.item.price,
        'description': widget.item.description,
        'isSpicy': widget.item.tags['isSpicy'] ?? false,
        'addedAt': FieldValue.serverTimestamp(),
      };

  void _updateQuantity(int newQuantity, CartService cartService) {
    if (newQuantity > 0) {
      cartService.updateQuantity(widget.item.id, newQuantity);
    } else {
      cartService.removeFromCart(widget.item.id);
    }
  }

  void _addItemToCart(MenuItem item, CartService cartService) {
    cartService.addToCart(item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.getLocalizedName(context)} added to cart'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  int _getItemCount(CartService cartService) {
    final index = cartService.items
        .indexWhere((cartItem) => cartItem.id == widget.item.id);
    return index != -1 ? cartService.items[index].quantity : 0;
  }

  Widget _buildAddButton(
      bool isAvailable, int itemCount, CartService cartService) {
    if (!isAvailable) {
      return Container(
        constraints: const BoxConstraints(minWidth: 132, minHeight: 44),
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppStrings.get('out_of_stock', context),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return itemCount > 0
        ? Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _updateQuantity(itemCount - 1, cartService),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.remove, color: Colors.white, size: 18),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    // FIX: Use localized numbers for quantity
                    AppStrings.formatNumber(itemCount, context),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _updateQuantity(itemCount + 1, cartService),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.add, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          )
        : Container(
            constraints: const BoxConstraints(minWidth: 132, minHeight: 44),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _addItemToCart(widget.item, cartService),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      AppStrings.get('add_to_cart', context),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDiscount =
        widget.item.discountedPrice != null && widget.item.discountedPrice! > 0;

    // FIX: Using raw double values here, not Strings
    final double displayPrice =
        hasDiscount ? widget.item.discountedPrice! : widget.item.price;
    final double? originalPrice = hasDiscount ? widget.item.price : null;

    final isAvailable = widget.item.isAvailableInBranch(widget.currentBranchId);

    return Consumer<CartService>(
      builder: (context, cartService, _) {
        final itemCount = _getItemCount(cartService);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                    bottom: _buttonFloat + _extraBottomSpace),
                child: Opacity(
                  opacity: isAvailable ? 1.0 : 0.6,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) =>
                            DishDetailsBottomSheet(item: widget.item),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.item.getLocalizedName(context),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isAvailable
                                              ? Colors.black87
                                              : Colors.grey,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      alignment: Alignment.center,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        splashRadius: 20,
                                        iconSize: 22,
                                        onPressed: isAvailable
                                            ? _toggleFavorite
                                            : null,
                                        icon: Icon(
                                          _isFavorite
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: _isFavorite
                                              ? Colors.red
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.item.getLocalizedDescription(context),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade700,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            // FIX: Use formatPrice with the double variable
                                            AppStrings.formatPrice(
                                                displayPrice, context),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: isAvailable
                                                  ? (hasDiscount
                                                      ? Colors.blue
                                                      : Colors.black87)
                                                  : Colors.grey,
                                            ),
                                          ),
                                          if (originalPrice != null)
                                            Text(
                                              // FIX: Use formatPrice with original double
                                              AppStrings.formatPrice(
                                                  originalPrice, context),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.normal,
                                                color: Colors.grey,
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              ),
                                            ),
                                          if (widget.showDiscountBadge &&
                                              widget.item.discountedPrice !=
                                                  null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color:
                                                    Colors.red.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                    color: Colors.red,
                                                    width: 1),
                                              ),
                                              child: const Text(
                                                'OFFER',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          if (widget.item.offerText != null &&
                                              widget.item.offerText!.isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryBlue
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                widget.item.offerText!,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.primaryBlue,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Opacity(
                              opacity: isAvailable ? 1.0 : 0.6,
                              child: CachedNetworkImage(
                                imageUrl: widget.item.imageUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    Container(color: Colors.grey.shade200),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.fastfood,
                                        color: Colors.grey, size: 30),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 8,
                child: _buildAddButton(isAvailable, itemCount, cartService),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DishDetailsBottomSheet extends StatefulWidget {
  final MenuItem item;
  const DishDetailsBottomSheet({
    Key? key,
    required this.item,
  }) : super(key: key);

  @override
  _DishDetailsBottomSheetState createState() => _DishDetailsBottomSheetState();
}

class _DishDetailsBottomSheetState extends State<DishDetailsBottomSheet> {
  late int quantity;
  bool _isInitialized = false;
  bool _isItemAvailable = true;
  bool _isCheckingAvailability = false;

  @override
  void initState() {
    super.initState();
    final cart = CartService();
    final index =
        cart.items.indexWhere((cartItem) => cartItem.id == widget.item.id);
    quantity = index != -1 ? cart.items[index].quantity : 1;

    _checkItemAvailability();
    _isInitialized = true;
  }

  Future<void> _checkItemAvailability() async {
    if (_isCheckingAvailability) return;

    setState(() => _isCheckingAvailability = true);

    try {
      final cart = CartService();
      final currentBranchIds = cart.currentBranchIds;
      // Default to Old_Airport if cart is empty, similar to main logic
      final branchToCheck =
          currentBranchIds.isNotEmpty ? currentBranchIds.first : 'Old_Airport';

      final isAvailable = widget.item.isAvailableInBranch(branchToCheck);

      if (mounted) {
        setState(() {
          _isItemAvailable = isAvailable;
          _isCheckingAvailability = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking item availability: $e');
      if (mounted) {
        setState(() => _isCheckingAvailability = false);
      }
    }
  }

  void _showRemoveConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            SizedBox(width: 12),
            Text('Remove Item?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
            'Are you sure you want to remove ${widget.item.getLocalizedName(context)} from your cart?',
            style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final cart = CartService();
              cart.removeFromCart(widget.item.id);
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${widget.item.getLocalizedName(context)} removed from cart.'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Remove', style: TextStyle(fontSize: 14)),
          ),
        ],
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _showOutOfStockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.inventory_2_outlined, color: Colors.orange, size: 24),
            SizedBox(width: 12),
            Text('Item Unavailable',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.item.getLocalizedName(context)} is currently out of stock.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check back later or choose a different item.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }

  void _handleQuantityChange(int newQuantity) {
    if (!_isItemAvailable) {
      _showOutOfStockDialog();
      return;
    }

    if (newQuantity == 0) {
      _showRemoveConfirmationDialog();
    } else {
      setState(() {
        quantity = newQuantity;
      });
    }
  }

  void _handleAddOrUpdateItem(int existingQty) {
    if (!_isItemAvailable) {
      _showOutOfStockDialog();
      return;
    }

    if (quantity == 0) {
      _showRemoveConfirmationDialog();
      return;
    }

    final cart = CartService();
    if (existingQty == 0) {
      cart.addToCart(widget.item, quantity: quantity);
    } else if (quantity > 0) {
      cart.updateQuantity(widget.item.id, quantity);
    } else {
      cart.removeFromCart(widget.item.id);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          // UPDATED: Localized quantity in snackbar
          '${AppStrings.formatNumber(quantity, context)}x ${widget.item.getLocalizedName(context)} ${existingQty == 0 ? "added" : "updated"}',
          style: const TextStyle(fontSize: 14),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildOutOfStockOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, color: Colors.white, size: 40),
              const SizedBox(height: 8),
              Text(
                AppStrings.get('out_of_stock', context),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Not available in selected branch',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityIndicator() {
    if (_isCheckingAvailability) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Checking availability...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (!_isItemAvailable) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.orange, size: 16),
            const SizedBox(width: 8),
            Text(
              'Out of stock in selected branch',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Text(
            'Available for order',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService();
    final index =
        cart.items.indexWhere((cartItem) => cartItem.id == widget.item.id);
    final existingQty = index != -1 ? cart.items[index].quantity : 0;

    final bool hasDiscount = widget.item.discountedPrice != null;

    // FIX: Using raw double values here, not Strings
    final double displayPrice =
        hasDiscount ? widget.item.discountedPrice! : widget.item.price;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: Opacity(
                    opacity: _isItemAvailable ? 1.0 : 0.6,
                    child: CachedNetworkImage(
                      imageUrl: widget.item.imageUrl,
                      fit: BoxFit.cover,
                      height: 250,
                      width: double.infinity,
                      placeholder: (c, u) =>
                          Container(height: 250, color: Colors.grey.shade200),
                      errorWidget: (c, u, e) => const Icon(Icons.fastfood,
                          color: Colors.grey, size: 40),
                    ),
                  ),
                ),
                if (!_isItemAvailable) _buildOutOfStockOverlay(),
              ],
            ),
            const SizedBox(height: 16),
            _buildAvailabilityIndicator(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                widget.item.getLocalizedName(context),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _isItemAvailable ? Colors.black : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Text(
                    // UPDATED: Localized display price
                    AppStrings.formatPrice(displayPrice, context),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isItemAvailable
                          ? (hasDiscount ? Colors.green : AppColors.primaryBlue)
                          : Colors.grey,
                    ),
                  ),
                  if (hasDiscount && _isItemAvailable) ...[
                    const SizedBox(width: 8),
                    Text(
                      // UPDATED: Localized original price
                      AppStrings.formatPrice(widget.item.price, context),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Text(
                        // UPDATED: Localized savings
                        '${AppStrings.get('save', context)} ${AppStrings.formatPrice(widget.item.price - widget.item.discountedPrice!, context)}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                widget.item.getLocalizedDescription(context).isNotEmpty
                    ? widget.item.getLocalizedDescription(context)
                    : 'No description available.',
                style: TextStyle(
                  fontSize: 14,
                  color: _isItemAvailable ? Colors.grey.shade800 : Colors.grey,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (existingQty > 0 && existingQty != quantity && _isItemAvailable)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  // UPDATED: Localized quantity in text
                  'Current in cart: ${AppStrings.formatNumber(existingQty, context)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (existingQty > 0 && !_isItemAvailable)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This item is out of stock but still in your cart. Please remove it.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Opacity(
                    opacity: _isItemAvailable ? 1.0 : 0.5,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove,
                                color: _isItemAvailable
                                    ? (quantity > 1
                                        ? Colors.black87
                                        : Colors.grey)
                                    : Colors.grey),
                            onPressed: _isItemAvailable
                                ? () {
                                    if (quantity > 1) {
                                      _handleQuantityChange(quantity - 1);
                                    } else if (quantity == 1) {
                                      _handleQuantityChange(0);
                                    }
                                  }
                                : null,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 48, minHeight: 48),
                          ),
                          SizedBox(
                            width: 40,
                            child: Center(
                              child: Text(
                                // UPDATED: Localized quantity selector
                                AppStrings.formatNumber(quantity, context),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isItemAvailable
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add,
                                color: _isItemAvailable
                                    ? Colors.black87
                                    : Colors.grey),
                            onPressed: _isItemAvailable
                                ? () {
                                    _handleQuantityChange(quantity + 1);
                                  }
                                : null,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 48, minHeight: 48),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isItemAvailable
                          ? () {
                              _handleAddOrUpdateItem(existingQty);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isItemAvailable
                            ? (quantity == 0
                                ? Colors.redAccent
                                : AppColors.primaryBlue)
                            : Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        !_isItemAvailable
                            ? AppStrings.get('out_of_stock', context)
                            : (quantity == 0
                                ? 'REMOVE ITEM'
                                : (existingQty == 0
                                    ? 'ADD ITEM'
                                    : 'UPDATE ITEM')),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

class RestaurantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> getDynamicEtaForUser(String branchId,
      {String orderType = 'delivery'}) async {
    String result = 'Calculating...';
    try {
      if (orderType == 'pickup') {
        return await _calculatePickupTime(branchId);
      } else {
        return await _calculateDeliveryTime(branchId);
      }
    } catch (e) {
      debugPrint('Error calculating dynamic ETA: $e');
      return orderType == 'delivery' ? '40 mins' : '20 mins';
    }
  }

  Future<String> _calculateDeliveryTime(String branchId) async {
    try {
      final branchDoc = await FirebaseFirestore.instance
          .collection('Branch')
          .doc(branchId)
          .get();
      if (!branchDoc.exists) throw Exception('Branch not found');
      final branchData = branchDoc.data();
      final addressData = branchData?['address'];
      if (addressData == null || addressData is! Map) {
        throw Exception('Branch address invalid');
      }
      final storeGeolocationField = addressData['geolocation'];
      if (storeGeolocationField == null || storeGeolocationField is! GeoPoint) {
        throw Exception('Branch geolocation invalid');
      }
      final double storeLatitude = storeGeolocationField.latitude;
      final double storeLongitude = storeGeolocationField.longitude;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null)
        throw Exception('User not logged in');
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.email)
          .get();
      if (!userDoc.exists) throw Exception('User data not found');
      final userData = userDoc.data();
      final userAddressesList = userData?['address'] as List?;
      if (userAddressesList == null || userAddressesList.isEmpty) {
        throw Exception('No user addresses');
      }

      Map<String, dynamic>? defaultAddressMap;
      try {
        defaultAddressMap = userAddressesList
            .firstWhere((addr) => addr is Map && (addr['isDefault'] == true))
            .cast<String, dynamic>();
      } catch (_) {
        defaultAddressMap =
            userAddressesList.isNotEmpty && userAddressesList.first is Map
                ? Map<String, dynamic>.from(userAddressesList.first as Map)
                : null;
      }
      if (defaultAddressMap == null) throw Exception('No default address');

      final userGeolocationField = defaultAddressMap['geolocation'];
      if (userGeolocationField == null || userGeolocationField is! GeoPoint) {
        throw Exception('User address geolocation invalid');
      }
      final double userLatitude = userGeolocationField.latitude;
      final double userLongitude = userGeolocationField.longitude;

      final double distanceInMeters = Geolocator.distanceBetween(
        userLatitude,
        userLongitude,
        storeLatitude,
        storeLongitude,
      );

      const double basePrepTimeMinutes = 15.0;
      const double averageSpeedMetersPerMinute = 300.0;
      final double travelTimeMinutes =
          distanceInMeters / averageSpeedMetersPerMinute;

      int totalEstimatedTimeMinutes =
          (basePrepTimeMinutes + travelTimeMinutes).round().clamp(15, 120);
      return '$totalEstimatedTimeMinutes mins';
    } catch (e) {
      debugPrint('Error calculating delivery ETA: $e');
      return '40 mins';
    }
  }

  Future<String> _calculatePickupTime(String branchId) async {
    try {
      const double basePrepTimeMinutes = 15.0;

      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('Orders')
          .where('branchId', isEqualTo: branchId)
          .where('date', isEqualTo: today)
          .where('status', whereIn: ['preparing', 'pending', 'accepted']).get();

      final activeOrderCount = ordersSnapshot.docs.length;

      final loadAdjustment = (activeOrderCount * 5).toDouble();
      final totalPrepTime = basePrepTimeMinutes + loadAdjustment;

      int totalEstimatedTimeMinutes = totalPrepTime.round().clamp(10, 60);
      return '$totalEstimatedTimeMinutes mins';
    } catch (e) {
      debugPrint('Error calculating pickup ETA: $e');
      return '20 mins';
    }
  }
}

class MenuItem {
  final String id;
  final List<String> branchIds;
  final String categoryId;
  final String description;
  final String descriptionAr; // Added Arabic Description
  final double? discountedPrice;
  final String imageUrl;
  final bool isAvailable;
  final bool isPopular;
  final String name;
  final String nameAr; // Added Arabic Name
  final double price;
  final int sortOrder;
  final Map<String, dynamic> tags;
  final Map<String, dynamic>? variants;
  final String? offerText;
  final List<String> outOfStockBranches;

  MenuItem({
    required this.id,
    required this.branchIds,
    required this.categoryId,
    required this.description,
    this.descriptionAr = '', // Default empty
    required this.imageUrl,
    required this.isAvailable,
    required this.isPopular,
    required this.name,
    this.nameAr = '', // Default empty
    required this.price,
    this.discountedPrice,
    required this.sortOrder,
    required this.tags,
    this.variants,
    this.offerText,
    required this.outOfStockBranches,
  });

  factory MenuItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MenuItem(
      id: doc.id,
      branchIds: List<String>.from(data['branchIds'] ?? []),
      categoryId: data['categoryId'] ?? '',
      description: data['description'] ?? '',
      descriptionAr: data['description_ar'] ?? '', // Read from Firestore
      imageUrl: data['imageUrl'] ?? '',
      isAvailable: data['isAvailable'] ?? false,
      isPopular: data['isPopular'] ?? false,
      name: data['name'] ?? '',
      nameAr: data['name_ar'] ?? '', // Read from Firestore
      price: (data['price'] ?? 0).toDouble(),
      discountedPrice: (data['discountedPrice'] as num?)?.toDouble(),
      sortOrder: data['sortOrder'] ?? 0,
      tags: data['tags'] ?? {},
      variants: data['variants'],
      offerText: data['offerText'],
      outOfStockBranches: List<String>.from(data['outOfStockBranches'] ?? []),
    );
  }

  bool isAvailableInBranch(String branchId) {
    return branchIds.contains(branchId) &&
        !outOfStockBranches.contains(branchId);
  }

  double get finalPrice => discountedPrice ?? price;

  // Localization Helpers
  String getLocalizedName(BuildContext context) {
    final isArabic =
        Provider.of<LanguageProvider>(context, listen: false).isArabic;
    return (isArabic && nameAr.isNotEmpty) ? nameAr : name;
  }

  String getLocalizedDescription(BuildContext context) {
    final isArabic =
        Provider.of<LanguageProvider>(context, listen: false).isArabic;
    return (isArabic && descriptionAr.isNotEmpty) ? descriptionAr : description;
  }
}

class MenuCategory {
  final String id;
  final List<String> branchIds;
  final String imageUrl;
  final bool isActive;
  final String name;
  final String nameAr; // Added Arabic Name
  final int sortOrder;

  MenuCategory({
    required this.id,
    required this.branchIds,
    required this.imageUrl,
    required this.isActive,
    required this.name,
    this.nameAr = '', // Default empty
    required this.sortOrder,
  });

  factory MenuCategory.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MenuCategory(
      id: doc.id,
      branchIds: List<String>.from(data['branchIds'] ?? []),
      imageUrl: data['imageUrl'] ?? '',
      isActive: data['isActive'] ?? false,
      name: data['name'] ?? '',
      nameAr: data['name_ar'] ?? '', // Read from Firestore
      sortOrder: data['sortOrder'] ?? 0,
    );
  }

  String getLocalizedName(BuildContext context) {
    final isArabic =
        Provider.of<LanguageProvider>(context, listen: false).isArabic;
    return (isArabic && nameAr.isNotEmpty) ? nameAr : name;
  }
}
