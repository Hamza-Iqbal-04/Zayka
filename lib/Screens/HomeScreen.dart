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
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:mitra_da_dhaba/Widgets/models.dart';
import 'package:mitra_da_dhaba/Screens/Profile.dart';
import 'package:mitra_da_dhaba/Screens/cartScreen.dart';
// New constant for active chip color
const Color kChipActive = AppColors.primaryBlue;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // Services and state
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Branch / user UI state
  final String _currentBranchId = 'Old_Airport';
  String _estimatedTime = 'Loading...';
  String _userAddressLabel = 'Loading...';
  String _userAddress = 'Loading address...';

  // Carousel
  final PageController _pageController = PageController();
  List<String> _carouselImages = [];
  int _currentPage = 0;
  Timer? _carouselTimer;

  // Categories and menu
  List<MenuCategory> _categories = [];
  List<MenuItem> _popularItems = [];
  Map<String, List<MenuItem>> _groupedMenuItems = {};
  StreamSubscription? _menuItemsSubscription;
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String get _searchQuery => _searchController.text;

  // User addresses
  List<Map<String, dynamic>> _allAddresses = [];

  // Order status bar
  Stream<Order?>? _orderStream;
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


  String _getStatusMessage(String status) {
    final cleanStatus = status.trim().toLowerCase();
    switch (cleanStatus) {
      case 'pending':
        return 'Order placed - pending confirmation';
      case 'preparing':
        return 'Your order is being prepared';
      case 'prepared':
        return 'Order prepared - awaiting rider';
      case 'rider_assigned':
      case 'rider assigned':
        return 'Rider assigned - picking up';
      case 'picked_up':
      case 'picked up':
      case 'pickedup':
      case 'on_the_way':
      case 'on the way':
      case 'ontheway':
      case 'out_for_delivery':
      case 'out for delivery':
        return 'On the way to you';
      case 'delivered':
        return 'Order delivered';
      case 'cancelled':
      case 'canceled':
        return 'Order cancelled';
      default:
        debugPrint('WARNING: Unknown status "$status" - using default message');
        return 'Order status: $status';
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
        debugPrint('WARNING: Unknown status "$status" - using 0.0 progress');
        return 0.0;
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeScreen();

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

  Future<void> _initializeScreen() async {
    _loadUserAddresses();
    _loadEstimatedTime();
    _loadCarouselImages();
    _setupOrderStream();
    await _loadMenuData();
  }

  void _setupOrderStream() {
    final user = _auth.currentUser;
    if (user != null && user.email != null) {
      _orderStream = _firestore
          .collection('Orders')
          .where('customerId', isEqualTo: user.email)
          .where('status', whereNotIn: ['delivered', 'cancelled'])
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          return Order.fromFirestore(snapshot.docs.first);
        }
        return null;
      }).handleError((error) {
        debugPrint("Error loading order stream: $error");
        return null;
      });
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
    super.dispose();
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
          CachedNetworkImageProvider(it.imageUrl, maxWidth: wPx, maxHeight: hPx),
          context,
        );
      }
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
        if(mounted) {
          setState(() {
            _carouselImages = images;
          });
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _precacheCarousel(context);
        });
        _startCarouselTimer();
      }
    } catch (e) {
      debugPrint('Error loading carousel images: $e');
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
        final items = (data['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? const [];
        for (final it in items) {
          final String itemId = (it['itemId'] ?? '') as String;
          if (itemId.isEmpty) continue;
          final int qty = (it['quantity'] as num?)?.toInt() ?? (it['qty'] as num?)?.toInt() ?? 0;
          if (qty <= 0) continue;
          totals[itemId] = (totals[itemId] ?? 0) + qty;
        }
      }

      if (totals.isEmpty) return [];
      final ranked = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topIds = ranked.take(5).map((e) => e.key).toList();

      if (topIds.isEmpty) return [];

      final itemsSnap = await FirebaseFirestore.instance
          .collection('menu_items')
          .where(FieldPath.documentId, whereIn: topIds)
          .where('branchId', isEqualTo: branchId)
          .where('isAvailable', isEqualTo: true)
          .get();

      final fetched = itemsSnap.docs.map((d) => MenuItem.fromFirestore(d)).toList();
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
        });
      }
    } catch (e) {
      debugPrint("Error loading popular items: $e");
    }
  }


  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    if (!mounted || _carouselImages.isEmpty) return;

    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || !_pageController.hasClients || _pageController.page == null) return;

      _currentPage = (_pageController.page!.round() + 1) % _carouselImages.length;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadEstimatedTime() async {
    String estimatedTimeString = 'Calculating...';
    try {
      final branchDoc = await FirebaseFirestore.instance.collection('Branch').doc(_currentBranchId).get();
      if (!branchDoc.exists) throw Exception("Branch not found");

      final branchData = branchDoc.data();
      final addressData = branchData?['address'];
      if (addressData == null || addressData is! Map) throw Exception("Branch address invalid");

      final storeGeolocationField = addressData['geolocation'];
      if (storeGeolocationField == null || storeGeolocationField is! GeoPoint) throw Exception("Branch geolocation invalid");

      final double storeLatitude = storeGeolocationField.latitude;
      final double storeLongitude = storeGeolocationField.longitude;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) throw Exception("User not logged in");

      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.email).get();
      if (!userDoc.exists) throw Exception("User data not found");

      final userData = userDoc.data();
      final userAddressesList = userData?['address'] as List?;
      if (userAddressesList == null || userAddressesList.isEmpty) throw Exception("No user addresses");

      Map<String, dynamic>? defaultAddressMap;
      try {
        defaultAddressMap = userAddressesList
            .firstWhere((addr) => addr is Map && addr['isDefault'] == true)
            .cast<String, dynamic>();
      } catch (e) {
        defaultAddressMap = userAddressesList.isNotEmpty && userAddressesList.first is Map
            ? Map<String, dynamic>.from(userAddressesList.first as Map)
            : null;
      }

      if (defaultAddressMap == null) throw Exception("No default address");

      final userGeolocationField = defaultAddressMap['geolocation'];
      if (userGeolocationField == null || userGeolocationField is! GeoPoint) throw Exception("User address geolocation invalid");

      final double userLatitude = userGeolocationField.latitude;
      final double userLongitude = userGeolocationField.longitude;
      final double distanceInMeters = Geolocator.distanceBetween(userLatitude, userLongitude, storeLatitude, storeLongitude);

      const double basePrepTimeMinutes = 15.0;
      const double averageSpeedMetersPerMinute = 300.0;
      final double travelTimeMinutes = distanceInMeters / averageSpeedMetersPerMinute;
      int totalEstimatedTimeMinutes = (basePrepTimeMinutes + travelTimeMinutes).round().clamp(15, 120);

      estimatedTimeString = '$totalEstimatedTimeMinutes mins';
    } catch (e) {
      debugPrint("Error calculating estimated time: $e");
      estimatedTimeString = '40 mins';
    }

    if (mounted) {
      setState(() {
        _estimatedTime = estimatedTimeString;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final querySnapshot = await _firestore
          .collection('menu_categories')
          .where('branchId', isEqualTo: _currentBranchId)
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load menu. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _listenToMenuItems() {
    _menuItemsSubscription?.cancel();
    _menuItemsSubscription = _firestore
        .collection('menu_items')
        .where('branchId', isEqualTo: _currentBranchId)
        .where('isAvailable', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      _allMenuItems = snapshot.docs.map((doc) => MenuItem.fromFirestore(doc)).toList();
      _updateAndGroupMenuItems(_allMenuItems);

      setState(() {
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleRecomputeOffsets();
      });
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading items: $error';
          _isLoading = false;
        });
      }
    });
  }

  void _updateAndGroupMenuItems(List<MenuItem> allItems) {
    final filteredItems = allItems
        .where((item) => item.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    final Map<String, List<MenuItem>> newGrouped = {for (final c in _categories) c.id: []};

    for (final it in filteredItems) {
      if (newGrouped.containsKey(it.categoryId)) {
        newGrouped[it.categoryId]!.add(it);
      }
    }

    if (mounted) {
      setState(() {
        _groupedMenuItems = newGrouped;
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
      if (!doc.exists || !doc.data()!.containsKey('address')) {
        throw Exception('No address set');
      }

      final data = doc.data()!;
      final addresses = data['address'] as List;
      if (addresses.isEmpty) {
        throw Exception('No address set');
      }

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
        if ((defaultAddress['flat'] ?? '').toString().isNotEmpty) 'Flat ${defaultAddress['flat']}',
        if ((defaultAddress['floor'] ?? '').toString().isNotEmpty) 'Floor ${defaultAddress['floor']}',
        if ((defaultAddress['building'] ?? '').toString().isNotEmpty) 'Building ${defaultAddress['building']}',
        if ((defaultAddress['street'] ?? '').toString().isNotEmpty) 'Street ${defaultAddress['street']}',
        if ((defaultAddress['city'] ?? '').toString().isNotEmpty) defaultAddress['city'],
      ].join(', ');

      if (mounted) {
        setState(() {
          _allAddresses = addressList;
          _userAddress = detailedAddress.isNotEmpty ? detailedAddress : 'No address details';
          _userAddressLabel = (defaultAddress['label'] ?? '').toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userAddress = e.toString().contains('No address set') ? 'No address set' : 'Error loading address';
          _userAddressLabel = e.toString().contains('Not logged in') ? 'Not logged in' : 'Error';
        });
      }
    }
  }

  void _showAddressBottomSheet(Function(String label, String fullAddress) onAddressSelected) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('Users').doc(user.email).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            final addresses = (userData?['address'] as List?)?.cast<Map<String, dynamic>>() ?? [];

            return SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Select Delivery Address',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 24),
                      if (addresses.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text('No addresses saved yet', style: TextStyle(color: Colors.grey[600])),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: addresses.length,
                          itemBuilder: (context, index) {
                            final address = addresses[index];
                            final detailedAddress = [
                              if (address['flat'] != null && address['flat'] != '') 'Flat ${address['flat']}',
                              if (address['floor'] != null && address['floor'] != '') 'Floor ${address['floor']}',
                              if (address['building'] != null && address['building'] != '') 'Building ${address['building']}',
                              if (address['street'] != null && address['street'] != '') 'Street ${address['street']}',
                              if (address['city'] != null && address['city'] != '') address['city'],
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue[50],
                                  child: Icon(
                                    address['label'] == 'Home' ? Icons.home : Icons.work,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                                title: Text(address['label'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(detailedAddress, style: const TextStyle(color: Colors.black54)),
                                trailing: address['isDefault'] == true ? const Icon(Icons.check_circle, color: Colors.green) : null,
                                onTap: () async {
                                  final currentUser = FirebaseAuth.instance.currentUser;
                                  if (currentUser == null || currentUser.email == null) return;

                                  final updated = addresses.map((a) {
                                    final isThis = const MapEquality().equals(a, address);
                                    return {...a, 'isDefault': isThis};
                                  }).toList();

                                  await FirebaseFirestore.instance.collection('Users').doc(currentUser.email).update({'address': updated});

                                  final newDetailedAddress = [
                                    if (address['flat'] != null && address['flat'] != '') 'Flat ${address['flat']}',
                                    if (address['floor'] != null && address['floor'] != '') 'Floor ${address['floor']}',
                                    if (address['building'] != null && address['building'] != '') 'Building ${address['building']}',
                                    if (address['street'] != null && address['street'] != '') 'Street ${address['street']}',
                                    if (address['city'] != null && address['city'] != '') address['city'],
                                  ].join(', ');

                                  Navigator.pop(context);
                                  onAddressSelected(address['label'] ?? 'Unnamed', newDetailedAddress);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${address['label']} selected for delivery')),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SavedAddressesScreen()),
                            );
                          },
                          child: const Text('Manage Addresses', style: TextStyle(fontSize: 16, color: Colors.white)),
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

    final RenderBox? scrollBox = context.findRenderObject() as RenderBox?;
    if (scrollBox == null) return;

    final topGlobal = scrollBox.localToGlobal(Offset.zero).dy;
    final Map<String, double> newOffsets = {};

    for (final c in _categories) {
      final key = _sectionKeys[c.id];
      if (key?.currentContext == null) continue;

      final box = key!.currentContext!.findRenderObject() as RenderBox?;
      if (box == null) continue;

      final dy = box.localToGlobal(Offset.zero, ancestor: scrollBox).dy;
      final offset = _mainScrollController.offset + dy;
      newOffsets[c.id] = offset;
    }
    _sectionOffsets
      ..clear()
      ..addAll(newOffsets);
  }


  void _onMainScroll() {
    if (_isAnimatingToSection || _sectionOffsets.isEmpty || _categories.isEmpty) return;

    final currentOffset = _mainScrollController.offset + (kToolbarHeight) + 52;
    int? bestIndex;
    double smallestDistance = double.infinity;

    for (int i = 0; i < _categories.length; i++) {
      final categoryId = _categories[i].id;
      final sectionOffset = _sectionOffsets[categoryId];

      if (sectionOffset != null) {
        if(currentOffset >= sectionOffset) {
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
    final targetOffset = (index * (estChipWidth + 8.0)) - (screenWidth / 2) + (estChipWidth / 2);

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
    if (_categories.isEmpty || index >= _categories.length) return;

    _activeCategoryIndexNotifier.value = index;
    final id = _categories[index].id;
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
      if(mounted) {
        _isAnimatingToSection = false;
      }
    });
  }


  Widget _buildCartAndOrderBar() {
    final pageController = PageController();
    return StreamBuilder<Order?>(
      stream: _orderStream,
      builder: (context, orderSnapshot) {
        Widget? orderBar;
        if (orderSnapshot.connectionState == ConnectionState.waiting) {
          orderBar = null;
        } else if (orderSnapshot.hasError) {
          orderBar = _buildOrderErrorWidget();
        } else if (orderSnapshot.data != null) {
          final order = orderSnapshot.data!;
          _orderStatusMessage = _getStatusMessage(order.status);
          final currentProgress = _getProgressValue(order.status);

          if (_previousStatus != order.status) {
            _previousProgress = currentProgress;
            _previousStatus = order.status;
          }
          orderBar = _buildOrderStatusWidget(order);
        } else {
          _previousStatus = null;
          _previousProgress = null;
          orderBar = null;
        }

        return Consumer<CartService>(
          builder: (context, cart, _) {
            Widget? cartBar;
            if (cart.itemCount > 0) {
              cartBar = _buildPersistentCartBar(cart);
            }

            final pages = [
              if (orderBar != null) orderBar,
              if (cartBar != null) cartBar,
            ];

            if (pages.isEmpty) {
              return const SizedBox.shrink();
            }

            if (pages.length == 1) {
              return pages.first;
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 100, // Fixed height for PageView
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
    return Container(
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
                  _orderStatusMessage,
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
                    width: MediaQuery.of(context).size.width * 0.6 * (_previousProgress ?? 0),
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
              '${((_previousProgress ?? 0) * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderErrorWidget() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.red.shade400, Colors.red.shade600]),
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
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double mainNavBarHeight = 64.0 + MediaQuery.of(context).padding.bottom;
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
                          if(mounted) {
                            setState(() {
                              _userAddressLabel = selectedLabel;
                              _userAddress = selectedAddr;
                            });
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.12), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue, size: 18),
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
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black),
                                  ),
                                  Text(
                                    _userAddress,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.timer_outlined, size: 16, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    _estimatedTime,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blue),
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
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Builder(
                      builder: (context) {
                        final userEmail = FirebaseAuth.instance.currentUser?.email;
                        if (userEmail == null) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.75),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.12), width: 1.5),
                                  ),
                                  child: const CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Color(0x261E88E5),
                                    child: Icon(Icons.person, color: Colors.blue, size: 18),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('Users').doc(userEmail).snapshots(),
                          builder: (context, snap) {
                            String? imageUrl;
                            if (snap.hasData && snap.data!.exists) {
                              final data = snap.data!.data() as Map<String, dynamic>?;
                              imageUrl = data?['imageUrl'] as String?;
                            }
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.75),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.12), width: 1.5),
                                    ),
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.blue.withOpacity(0.15),
                                      backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? CachedNetworkImageProvider(imageUrl) : null,
                                      child: (imageUrl == null || imageUrl.isEmpty) ? const Icon(Icons.person, color: Colors.blue, size: 18) : null,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              // Carousel
              SliverToBoxAdapter(
                child: Padding(
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
                            margin: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: _carouselImages[index],
                                fit: BoxFit.cover,
                                fadeInDuration: const Duration(milliseconds: 150),
                                fadeOutDuration: const Duration(milliseconds: 150),
                                filterQuality: FilterQuality.low,
                                placeholder: (_, __) => Container(color: Colors.grey.shade300),
                                errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
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
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: Colors.white.withOpacity(0.1),
                        alignment: Alignment.center,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 40,
                              color: Colors.white.withOpacity(0.55),
                              child: ListView.builder(
                                controller: _categoryBarController,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                itemCount: _categories.length,
                                itemBuilder: (context, index) {
                                  final category = _categories[index];
                                  return ValueListenableBuilder<int>(
                                    valueListenable: _activeCategoryIndexNotifier,
                                    builder: (context, activeIndex, _) {
                                      final isActive = activeIndex == index;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: GestureDetector(
                                          onTap: () => _onCategoryTap(index),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isActive ? kChipActive.withOpacity(0.85) : Colors.white.withOpacity(0.55),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isActive ? kChipActive : Colors.white.withOpacity(0.7),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (category.imageUrl.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(right: 6),
                                                    child: ClipOval(
                                                      child: CachedNetworkImage(
                                                        imageUrl: category.imageUrl,
                                                        width: 16,
                                                        height: 16,
                                                        fit: BoxFit.cover,
                                                        errorWidget: (_, __, ___) => Icon(
                                                          Icons.fastfood_rounded,
                                                          size: 16,
                                                          color: isActive ? Colors.white : Colors.black54,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                Text(
                                                  category.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    height: 1.2,
                                                    fontWeight: FontWeight.w700,
                                                    color: isActive ? Colors.white : Colors.black87,
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
                child: _isLoading
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(),
                  ),
                )
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
            child: _buildCartAndOrderBar(),
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
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
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
                            '${cart.itemCount}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'View Cart',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            Text(
                              '${cart.itemCount} item${cart.itemCount > 1 ? 's' : ''}',
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'QAR ${cart.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                          ),
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
      return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text(_errorMessage!)));
    }
    if (_categories.isEmpty && !_isLoading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No categories available')));
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

  Widget _buildPopularItemsSection(List<MenuItem> items, double cardW, double imgH) {
    // Precache images for popular items
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted) _precachePopular(items, cardW, imgH);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('Popular Items', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
              return _PopularItemCard(item: item, cardWidth: cardW, imageHeight: imgH);
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildGroupedMenuSections() {
    final List<Widget> children = [];
    for (int i = 0; i < _categories.length; i++) {
      final cat = _categories[i];
      final list = _groupedMenuItems[cat.id] ?? const [];

      if (_searchQuery.isNotEmpty && list.isEmpty) continue;

      children.add(
        _CategorySection(
          key: _sectionKeys[cat.id],
          title: cat.name,
          items: list,
        ),
      );
    }

    if (_searchQuery.isNotEmpty && children.isEmpty) {
      return const Column(
        children: [
          SizedBox(height: 32),
          Icon(Icons.search_off, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text('No items found', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('Try adjusting your search', style: TextStyle(color: Colors.grey, fontSize: 14)),
          SizedBox(height: 32),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
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
  const _CategorySection({
    Key? key,
    required this.title,
    required this.items,
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
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
              itemBuilder: (_, index) => MenuItemCard(item: items[index]),
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
  }) : super(key: key);

  final MenuItem item;
  final double cardWidth;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      width: cardWidth,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 150),
                      fadeOutDuration: const Duration(milliseconds: 150),
                      filterQuality: FilterQuality.low,
                      placeholder: (_, __) => Container(color: Colors.grey.shade200),
                      errorWidget: (_, __, ___) => const Icon(Icons.fastfood, color: Colors.grey),
                    ),
                  ),
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
                              final cart = context.read<CartService>();
                              cart.addToCart(item);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${item.name} added to cart'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: const Row(
                                children: [
                                  Text('ADD', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w800, fontSize: 13)),
                                  SizedBox(width: 2),
                                  Icon(Icons.add_rounded, color: AppColors.primaryBlue, size: 20),
                                ],
                              ),
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
                item.name,
                textAlign: TextAlign.left,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'QAR ${item.price.toStringAsFixed(2)}',
                textAlign: TextAlign.left,
                style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            const SizedBox(height: 4),
            if (item.tags['isSpicy'] == true)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: Colors.red, size: 16),
                    SizedBox(width: 4),
                    Text('Spicy', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12.5)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
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
  const MenuItemCard({Key? key, required this.item}) : super(key: key);

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
        setState(() => _isFavorite = !_isFavorite); // Revert on error
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
        content: Text('${item.name} added to cart'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  int _getItemCount(CartService cartService) {
    final index =
    cartService.items.indexWhere((cartItem) => cartItem.id == widget.item.id);
    return index != -1 ? cartService.items[index].quantity : 0;
  }

  @override
  Widget build(BuildContext context) {
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
                                      widget.item.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // This container ensures the icon button has a fixed size
                                  // and aligns correctly to the top.
                                  Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      splashRadius: 20,
                                      iconSize: 22,
                                      onPressed: _toggleFavorite,
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
                              // **FIX:** Reduced the gap between title and description.
                              const SizedBox(height: 4),
                              Text(
                                widget.item.description,
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
                                  Text(
                                    'QAR ${widget.item.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (widget.item.offerText != null &&
                                      widget.item.offerText!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                        AppColors.primaryBlue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
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
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: widget.item.imageUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey.shade200),
                            errorWidget: (context, url, error) => const Icon(
                                Icons.fastfood,
                                color: Colors.grey,
                                size: 30),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 8,
                child: itemCount > 0
                    ? Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
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
                        onTap: () =>
                            _updateQuantity(itemCount - 1, cartService),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child:
                          Icon(Icons.remove, color: Colors.white, size: 18),
                        ),
                      ),
                      Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          itemCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            _updateQuantity(itemCount + 1, cartService),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child:
                          Icon(Icons.add, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                )
                    : Container(
                  constraints:
                  const BoxConstraints(minWidth: 132, minHeight: 44),
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
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: Text(
                            'ADD TO CART',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
  const DishDetailsBottomSheet({Key? key, required this.item}) : super(key: key);

  @override
  _DishDetailsBottomSheetState createState() => _DishDetailsBottomSheetState();
}

class _DishDetailsBottomSheetState extends State<DishDetailsBottomSheet> {
  late int quantity;

  @override
  void initState() {
    super.initState();
    // Set initial quantity. Will be updated in build if already in cart.
    quantity = 1;
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final index = cart.items.indexWhere((cartItem) => cartItem.id == widget.item.id);
    final existingQty = index != -1 ? cart.items[index].quantity : 0;

    // Sync local quantity state on first build if item is in cart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && existingQty > 0 && quantity == 1) {
        setState(() {
          quantity = existingQty;
        });
      }
    });

    // FIX: Replaced DraggableScrollableSheet with a content-wrapping layout
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Make column wrap its content
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
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

            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: CachedNetworkImage(
                imageUrl: widget.item.imageUrl,
                fit: BoxFit.cover,
                height: 250,
                placeholder: (c, u) => Container(height: 250, color: Colors.grey.shade200),
                errorWidget: (c, u, e) => const Icon(Icons.fastfood, color: Colors.grey, size: 40),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                widget.item.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                widget.item.description.isNotEmpty
                    ? widget.item.description
                    : 'No description available.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),

            // Bottom Action Bar (Quantity and Add/Update button)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.black87),
                          onPressed: () {
                            if (quantity > 1) {
                              setState(() {
                                quantity--;
                              });
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        ),
                        SizedBox(
                          width: 40,
                          child: Center(
                            child: Text(
                              quantity.toString(),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.black87),
                          onPressed: () {
                            setState(() {
                              quantity++;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
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
                              '${quantity}x ${widget.item.name} ${existingQty == 0 ? "added" : "updated"}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        existingQty == 0 ? 'ADD ITEM' : 'UPDATE ITEM',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Padding for bottom safe area
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

class RestaurantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> getEstimatedTime(String branchId) async {
    try {
      final doc = await _firestore.collection('Branch').doc(branchId).get();
      if (doc.exists) {
        final data = doc.data();
        return '${data?['estimatedTime'] ?? 40} minutes';
      }
      return '40 minutes';
    } catch (e) {
      debugPrint('Error getting estimated time: $e');
      return '40 minutes';
    }
  }
}

class MenuItem {
  final String id;
  final String branchId;
  final String categoryId;
  final String description;
  final String imageUrl;
  final bool isAvailable;
  final bool isPopular;
  final String name;
  final double price;
  final int sortOrder;
  final Map<String, dynamic> tags;
  final Map<String, dynamic>? variants;
  final String? offerText;

  MenuItem({
    required this.id,
    required this.branchId,
    required this.categoryId,
    required this.description,
    required this.imageUrl,
    required this.isAvailable,
    required this.isPopular,
    required this.name,
    required this.price,
    required this.sortOrder,
    required this.tags,
    this.variants,
    this.offerText,
  });

  factory MenuItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MenuItem(
      id: doc.id,
      branchId: data['branchId'] ?? '',
      categoryId: data['categoryId'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      isAvailable: data['isAvailable'] ?? false,
      isPopular: data['isPopular'] ?? false,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      sortOrder: data['sortOrder'] ?? 0,
      tags: data['tags'] ?? {},
      variants: data['variants'],
      offerText: data['offerText'],
    );
  }
}

class MenuCategory {
  final String id;
  final String branchId;
  final String imageUrl;
  final bool isActive;
  final String name;
  final int sortOrder;

  MenuCategory({
    required this.id,
    required this.branchId,
    required this.imageUrl,
    required this.isActive,
    required this.name,
    required this.sortOrder,
  });

  factory MenuCategory.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MenuCategory(
      id: doc.id,
      branchId: data['branchId'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      isActive: data['isActive'] ?? false,
      name: data['name'] ?? '',
      sortOrder: data['sortOrder'] ?? 0,
    );
  }
}
