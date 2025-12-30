import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:geolocator/geolocator.dart';
import 'package:myfatoorah_flutter/MFModels.dart';
import 'package:provider/provider.dart';
import '../Screens/HomeScreen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Widgets/bottom_nav.dart';
import 'CouponsScreen.dart';
import 'Profile.dart';
import '../Widgets/models.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Services/PaymentService.dart';
import '../Services/language_provider.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);
  @override
  _CartScreenState createState() => _CartScreenState();
}

class BranchDistance {
  final String id;
  final String name;
  final double distance;
  final bool isOpen;
  final bool isInRange;

  BranchDistance(this.id, this.name, this.distance, this.isOpen, this.isInRange);
}

class _CartScreenState extends State<CartScreen> {
  final RestaurantService _restaurantService = RestaurantService();
  final Set<String> _notifiedOutOfStockItems = {};

  Set<String> get notifiedOutOfStockItems => _notifiedOutOfStockItems;

  String _estimatedTime = 'Loading...';
  List<MFPaymentMethod> _mfPaymentMethods = [];
  MFPaymentMethod? _selectedMfPaymentMethod;
  bool _isLoadingPaymentMethods = false;
  double deliveryFee = 0;
  bool _isFindingNearestBranch = false;
  List<String> _currentBranchIds = ['OldAirport'];
  List<Map<String, String>> _allBranches = [];
  List<String> _nearestBranchIds = [];
  bool _isDefaultNearest = true;
  final TextEditingController _notesController = TextEditingController();
  List<MenuItem> _drinksItems = [];
  bool _isLoadingDrinks = true;
  bool _isCheckingOut = false;
  bool _isValidatingStock = false;
  String _orderType = 'delivery';
  String _paymentType = 'Cash on Delivery';
  bool _isInitialized = false;

  Map<String, dynamic>? _cachedAddress;
  bool _isLoadingAddress = false;

  double _freeDeliveryRange = 0;
  double _noDeliveryRange = 0;
  bool _isOutOfDeliveryRange = false;
  double _distanceToBranch = 0;

  List<CartModel> _outOfStockItems = [];
  bool _isCheckingStock = false;
  bool _isFirstStockCheck = true;

  // --- NEW STATE VARIABLES ---
  bool _areAllBranchesClosed = false;
  bool _noDeliveryAvailable = false;
  bool _isFallbackBranch = false;
  String _closedNearestBranchName = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
    CartService().addListener(_onCartChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      PaymentService.init();
      CartService().startStockMonitoring(_currentBranchIds);
      _checkForOutOfStockItems();
    });
  }

  @override
  void dispose() {
    CartService().removeListener(_onCartChanged);
    CartService().stopStockMonitoring();
    _notesController.dispose();
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() {});
      _checkForOutOfStockItems();
    }
  }

  Future<void> _checkForOutOfStockItems() async {
    if (_isCheckingStock) return;
    setState(() => _isCheckingStock = true);

    try {
      final outOfStockItems = await CartService().getOutOfStockItems(_currentBranchIds);

      if (mounted) {
        setState(() {
          _outOfStockItems = outOfStockItems;
        });
      }

      final newOutOfStockItems = outOfStockItems.where(
              (item) => !_notifiedOutOfStockItems.contains(item.id)
      ).toList();

      if (newOutOfStockItems.isNotEmpty && mounted && !_isFirstStockCheck) {
        _showOutOfStockPopup(newOutOfStockItems);
        for (final item in newOutOfStockItems) {
          _notifiedOutOfStockItems.add(item.id);
        }
      }

      _notifiedOutOfStockItems.removeWhere(
              (itemId) => !outOfStockItems.any((item) => item.id == itemId)
      );

      _isFirstStockCheck = false;

    } catch (e) {
      debugPrint('Error checking out-of-stock items: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingStock = false);
      }
    }
  }

  void _showOutOfStockPopup(List<CartModel> outOfStockItems) {
    if (outOfStockItems.isEmpty || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            Text(AppStrings.get('item_unavailable_title', context), style: AppTextStyles.headline2),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.get('items_no_longer_available', context),
              style: AppTextStyles.bodyText1,
            ),
            const SizedBox(height: 12),
            ...outOfStockItems.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.close, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item.name} (Qty: ${item.quantity})',
                      style: AppTextStyles.bodyText1.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
            Text(
              AppStrings.get('remove_items_question', context),
              style: AppTextStyles.bodyText2.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              for (final item in outOfStockItems) {
                _notifiedOutOfStockItems.add(item.id);
              }
              Navigator.pop(context);
            },
            child: Text(
              AppStrings.get('keep_items', context),
              style: AppTextStyles.bodyText1.copyWith(color: AppColors.darkGrey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _removeOutOfStockItems(outOfStockItems);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.get('remove_all', context), style: AppTextStyles.buttonText),
          ),
        ],
      ),
    );
  }

  void _removeOutOfStockItems(List<CartModel> outOfStockItems) {
    final cartService = CartService();
    for (final item in outOfStockItems) {
      cartService.removeFromCart(item.id);
      _notifiedOutOfStockItems.remove(item.id);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outOfStockItems.length == 1
              ? '${outOfStockItems.first.name} ${AppStrings.get('removed_out_of_stock', context)}'
              : '${outOfStockItems.length} ${AppStrings.get('items_removed_out_of_stock', context)}',
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );

    if (mounted) {
      setState(() {
        _outOfStockItems.clear();
      });
    }
  }

  Future<void> _initializeData() async {
    try {
      await _loadAvailableBranches();
      await _setNearestBranch();

      await Future.wait([
        _loadDrinks(),
      ]);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _loadAvailableBranches() async {
    final snap = await FirebaseFirestore.instance
        .collection('Branch')
        .where('isActive', isEqualTo: true)
        .get();

    _allBranches = snap.docs
        .map((d) => {
      'id': d.id,
      'name': d['name'] as String? ?? d.id,
    })
        .toList();
  }

  // --- SMART BRANCH SELECTION LOGIC ---
  Future<void> _setNearestBranch() async {
    if (!mounted) return;
    setState(() => _isFindingNearestBranch = true);

    try {
      // 1. Get User Location (Address or GPS)
      GeoPoint? userLocation;
      if (_orderType == 'delivery') {
        userLocation = await _getUserLocationFromAddress();
      } else {
        final pos = await _getCurrentLocation();
        if (pos != null) userLocation = GeoPoint(pos.latitude, pos.longitude);
      }

      if (userLocation == null) throw Exception("Location not found");

      // 2. Fetch ALL Active Branches
      final branchesSnapshot = await FirebaseFirestore.instance
          .collection('Branch')
          .where('isActive', isEqualTo: true)
          .get();

      if (branchesSnapshot.docs.isEmpty) throw Exception("No active branches");

      // 3. Calculate Stats for Every Branch
      List<BranchDistance> sortedBranches = [];

      for (final doc in branchesSnapshot.docs) {
        final data = doc.data();
        final addressData = data['address'] as Map<String, dynamic>?;

        if (addressData != null && addressData['geolocation'] != null) {
          final branchGeo = addressData['geolocation'] as GeoPoint;
          final double distance = _calculateDistance(
            userLocation.latitude,
            userLocation.longitude,
            branchGeo.latitude,
            branchGeo.longitude,
          );

          final bool isOpen = data['isOpen'] ?? true;
          final String name = data['name'] ?? doc.id;

          // Check Delivery Range
          final double noDeliveryRange = (data['noDeliveryRange'] ?? 0).toDouble();

          // STRICT RULE: If delivery, range matters. If pickup, range doesn't matter.
          final bool isInRange = _orderType == 'pickup'
              ? true
              : (noDeliveryRange > 0 && distance <= noDeliveryRange);

          sortedBranches.add(BranchDistance(doc.id, name, distance, isOpen, isInRange));
        }
      }

      if (sortedBranches.isEmpty) throw Exception("No branches with location data");

      // --- FILTERING FOR DELIVERY ---
      if (_orderType == 'delivery') {
        // If it's delivery, we STRICTLY remove any branch that is out of range.
        sortedBranches.removeWhere((b) => !b.isInRange);

        if (sortedBranches.isEmpty) {
          // NO BRANCHES DELIVER HERE
          setState(() {
            _noDeliveryAvailable = true;
            _isFindingNearestBranch = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showNoDeliveryDialog();
          });
          return;
        }
      }

      // 4. SORTING
      // Order: Open > Closest
      sortedBranches.sort((a, b) {
        if (a.isOpen != b.isOpen) {
          return a.isOpen ? -1 : 1; // Open first
        }
        return a.distance.compareTo(b.distance); // Closest first
      });

      // 5. Select the Best Branch
      BranchDistance selectedBranch = sortedBranches.first;

      // Determine UI State variables
      final bool allClosed = sortedBranches.every((b) => !b.isOpen);

      // Check if we skipped a closer branch because it was closed
      // Note: We only check against other *valid* (in-range) branches
      final geometricNearest = sortedBranches.reduce((curr, next) => curr.distance < next.distance ? curr : next);

      bool fellBack = false;
      if (selectedBranch.id != geometricNearest.id && !geometricNearest.isOpen) {
        fellBack = true;
        _closedNearestBranchName = geometricNearest.name;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showFallbackBranchDialog(geometricNearest.name, selectedBranch.name);
        });
      }

      if (allClosed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showAllBranchesClosedDialog();
        });
      }

      // 6. Apply State
      if (mounted) {
        setState(() {
          _currentBranchIds = [selectedBranch.id];
          _nearestBranchIds = [selectedBranch.id];
          _isDefaultNearest = !fellBack;
          _areAllBranchesClosed = allClosed;
          _noDeliveryAvailable = false;
          _isFindingNearestBranch = false;
          _distanceToBranch = selectedBranch.distance;
          _isOutOfDeliveryRange = false;
        });

        CartService().updateCurrentBranchIds([selectedBranch.id]);
        CartService().startStockMonitoring([selectedBranch.id]);

        await loadDeliveryFee(selectedBranch.id);
        await _loadEstimatedTime();
        _loadDrinks();
      }

    } catch (e) {
      debugPrint('Error setting branch: $e');
      if (mounted) {
        setState(() {
          _currentBranchIds = ['Old_Airport']; // Fallback
          _isFindingNearestBranch = false;
        });
      }
    }
  }

  void _showNoDeliveryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.location_off, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text(AppStrings.get('location_not_serviceable', context), style: AppTextStyles.headline2)),
          ],
        ),
        content: Text(
          AppStrings.get('no_delivery_available_msg', context),
          style: AppTextStyles.bodyText1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: AppTextStyles.buttonText.copyWith(color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }

  void _showAllBranchesClosedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.access_time_filled, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text(AppStrings.get('we_are_closed', context), style: AppTextStyles.headline2)),
          ],
        ),
        content: Text(
          AppStrings.get('all_branches_closed_msg', context),
          style: AppTextStyles.bodyText1,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainApp(initialIndex: 0)),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(AppStrings.get('back_to_home', context), style: AppTextStyles.buttonText.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFallbackBranchDialog(String closedBranch, String openBranch) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text(AppStrings.get('branch_update', context), style: AppTextStyles.headline2)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${AppStrings.get('switched_to', context)} $openBranch.",
              style: AppTextStyles.bodyText1.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "${AppStrings.get('nearest_branch', context)} ($closedBranch) ${AppStrings.get('is_currently', context)} ${AppStrings.get('closed', context)}.",
              style: AppTextStyles.bodyText2,
            ),
            SizedBox(height: 12),
            Text(
              AppStrings.get('delivery_updated_msg', context),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: AppTextStyles.buttonText.copyWith(color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }

  void _refreshBranchSelection() => _setNearestBranch();

  Future<void> _loadEstimatedTime() async {
    final time = await _restaurantService.getDynamicEtaForUser(
      _currentBranchIds.first,
      orderType: _orderType,
    );
    if (mounted) {
      setState(() {
        _estimatedTime = time;
      });
    }
  }

  Future<void> _loadDrinks() async {
    if (!mounted) return;
    setState(() => _isLoadingDrinks = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('menu_items')
          .where('categoryId', isEqualTo: 'Drinks')
          .where('isAvailable', isEqualTo: true)
          .limit(10)
          .get();

      final allDrinks = snap.docs.map((d) {
        final data = d.data();
        final branchIds = List<String>.from(data['branchIds'] ?? []);
        final outOfStockBranches = List<String>.from(data['outOfStockBranches'] ?? []);

        return MenuItem(
          id: d.id,
          name: data['name'] ?? 'Unknown Drink',
          nameAr: data['name_ar'] ?? '',
          price: (data['price'] ?? 0).toDouble(),
          discountedPrice: data['discountedPrice']?.toDouble(),
          imageUrl: data['imageUrl'] ?? '',
          description: data['description'] ?? '',
          descriptionAr: data['description_ar'] ?? '',
          categoryId: data['categoryId'] ?? '',
          branchIds: branchIds,
          isAvailable: data['isAvailable'] ?? true,
          isPopular: data['isPopular'] ?? false,
          sortOrder: data['sortOrder'] ?? 0,
          variants: (data['variants'] is Map) ? Map.from(data['variants']) : const {},
          tags: (data['tags'] is Map) ? Map.from(data['tags']) : const {},
          outOfStockBranches: outOfStockBranches,
        );
      }).toList();

      final availableDrinks = allDrinks.where((item) {
        return item.isAvailableInBranch(_currentBranchIds.first);
      }).toList();

      if (mounted) {
        setState(() {
          _drinksItems = availableDrinks;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading drinks: $e');
      if (mounted) {
        setState(() {
          _drinksItems = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDrinks = false);
      }
    }
  }

  Future<void> loadDeliveryFee(String branchId) async {
    final snap = await FirebaseFirestore.instance
        .collection('Branch')
        .doc(branchId)
        .get();

    if (!mounted) return;

    final data = snap.data();
    setState(() {
      deliveryFee = (data?['deliveryFee'] ?? 0).toDouble();
      _freeDeliveryRange = (data?['freeDeliveryRange'] ?? 0).toDouble();
      _noDeliveryRange = (data?['noDeliveryRange'] ?? 0).toDouble();
    });

    await _calculateAndUpdateDeliveryFee();
  }

  Future<void> _calculateAndUpdateDeliveryFee() async {
    if (_orderType != 'delivery') return;

    try {
      final userGeoPoint = await _getUserLocationFromAddress();
      if (userGeoPoint == null) return;

      final branchSnap = await FirebaseFirestore.instance
          .collection('Branch')
          .doc(_currentBranchIds.first)
          .get();

      final branchData = branchSnap.data();
      if (branchData == null || branchData['address'] == null) return;

      final branchAddress = branchData['address'] as Map<String, dynamic>;
      final branchGeoPoint = branchAddress['geolocation'] as GeoPoint?;

      if (branchGeoPoint == null) return;

      final distance = _calculateDistance(
        userGeoPoint.latitude,
        userGeoPoint.longitude,
        branchGeoPoint.latitude,
        branchGeoPoint.longitude,
      );

      if (mounted) {
        setState(() {
          _distanceToBranch = distance;
          // Note: _isOutOfDeliveryRange is mostly handled by _setNearestBranch now,
          // but we keep this for dynamic updates.
          _isOutOfDeliveryRange = distance > _noDeliveryRange;

          if (distance <= _freeDeliveryRange) {
            deliveryFee = 0;
          } else {
            deliveryFee = (branchData['deliveryFee'] ?? 0).toDouble();
          }
        });
      }
    } catch (e) {
      debugPrint('Error calculating delivery fee: $e');
    }
  }

  Future<GeoPoint?> _getUserLocationFromAddress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) return null;

      Map<String, dynamic>? address = _cachedAddress;
      if (address == null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.email)
            .get();

        if (!userDoc.exists) return null;

        final userData = userDoc.data() as Map<String, dynamic>;
        final addresses = (userData['address'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];

        try {
          address = addresses.firstWhere((a) => a['isDefault'] == true);
        } catch (e) {
          address = addresses.isNotEmpty ? addresses.first : null;
        }

        if (address != null) {
          _cachedAddress = address;
        }
      }

      if (address?['geolocation'] != null) {
        return address!['geolocation'] as GeoPoint;
      }

      final Position? currentPosition = await _getCurrentLocation();
      if (currentPosition != null) {
        return GeoPoint(currentPosition.latitude, currentPosition.longitude);
      }

      return null;
    } catch (e) {
      debugPrint('Error getting user location from address: $e');
      return null;
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  String _getPaymentTypeDisplay(BuildContext context, String paymentType) {
    switch (paymentType) {
      case 'Cash on Delivery':
        return AppStrings.get('cash_on_delivery', context);
      case 'Online Payment':
        return AppStrings.get('online_payment', context);
      default:
        return paymentType;
    }
  }

  Future<void> _loadUserAddress(String userEmail) async {
    if (_isLoadingAddress) return;

    setState(() => _isLoadingAddress = true);

    try {
      final address = await _getUserAddressFuture(userEmail);
      if (mounted) {
        setState(() {
          _cachedAddress = address;
          _isLoadingAddress = false;
        });
      }
      await _calculateAndUpdateDeliveryFee();
    } catch (e) {
      debugPrint('Error loading user address: $e');
      if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _getUserAddressFuture(String userEmail) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userEmail)
          .get();

      if (!doc.exists) return null;

      final userData = doc.data() as Map<String, dynamic>?;
      final addresses = (userData?['address'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];

      Map<String, dynamic>? defaultAddress;
      try {
        defaultAddress = addresses.firstWhere((a) => a['isDefault'] == true);
      } catch (e) {
        defaultAddress = addresses.isNotEmpty ? addresses.first : null;
      }

      return defaultAddress;
    } catch (e) {
      debugPrint('Error fetching address: $e');
      return null;
    }
  }

  Future<void> _proceedToCheckout() async {
    // --- 1. NEW: FINAL SAFETY CHECK (Real-Time) ---
    // Fetch the latest status of the selected branch right now
    if (_currentBranchIds.isNotEmpty) {
      final freshBranchSnap = await FirebaseFirestore.instance
          .collection('Branch')
          .doc(_currentBranchIds.first)
          .get();

      final bool isBranchOpen = freshBranchSnap.data()?['isOpen'] ?? true;

      if (!isBranchOpen) {
        // If it closed while they were looking at the screen:
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(AppStrings.get('restaurant_just_closed', context), style: AppTextStyles.headline2),
              content: Text(
                AppStrings.get('branch_closed_msg', context),
                style: AppTextStyles.bodyText1,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _setNearestBranch(); // Refresh logic to find next best branch
                  },
                  child: Text("OK", style: AppTextStyles.buttonText.copyWith(color: AppColors.primaryBlue)),
                ),
              ],
            ),
          );
        }
        return; // Stop checkout
      }
    }
    // ----------------------------------

    // 2. Basic Validations
    if (_orderType == 'delivery' && (_isOutOfDeliveryRange || _noDeliveryAvailable)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${AppStrings.get('delivery_range_error', context)} $_noDeliveryRange ${AppStrings.get('km', context)}.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    if (_areAllBranchesClosed) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.get('all_branches_closed_msg', context)),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final String notes = _notesController.text.trim();
    if (!mounted) return;

    setState(() {
      _isCheckingOut = true;
      _isValidatingStock = true;
    });

    try {
      final cartService = CartService();

      final outOfStockItems = await cartService.getOutOfStockItems(_currentBranchIds);
      if (outOfStockItems.isNotEmpty) {
        setState(() {
          _isCheckingOut = false;
          _isValidatingStock = false;
        });
        _showOutOfStockPopup(outOfStockItems);
        return;
      }

      await cartService.validateCartStock(_currentBranchIds);
      setState(() => _isValidatingStock = false);

      if (cartService.items.isEmpty) throw Exception(AppStrings.get("your_cart_empty", context));

      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) throw Exception(AppStrings.get("user_not_authenticated", context));

      Map<String, dynamic>? defaultAddress;
      if (_orderType == 'delivery') {
        final userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.email).get();
        if (!userDoc.exists) throw Exception(AppStrings.get("user_doc_not_found", context));

        final userData = userDoc.data() as Map<String, dynamic>;
        final addresses = ((userData['address'] as List?) ?? []).map((a) => Map<String, dynamic>.from(a as Map)).toList();

        if (addresses.isEmpty) throw Exception(AppStrings.get("no_delivery_address", context));
        defaultAddress = addresses.firstWhere((a) => a['isDefault'] == true, orElse: () => addresses[0]);
      }

      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.email).get();
      final userData = userDoc.data() as Map<String, dynamic>;
      final String userName = userData['name'] ?? 'Customer';
      final String userPhone = userData['phone'] ?? '12345678';

      final orderDoc = await _createOrderInFirestore(
        user: user,
        cartService: cartService,
        notes: notes,
        defaultAddress: defaultAddress,
        userName: userName,
        userPhone: userPhone,
        orderType: _orderType,
      );

      final double totalForPayment = cartService.totalAfterDiscount + (_orderType == 'delivery' ? deliveryFee : 0.0);

      if (_paymentType == 'Cash on Delivery' || _selectedMfPaymentMethod == null) {
        final paymentMeta = _composePaymentMeta(totalForPayment);
        await orderDoc.update(paymentMeta);

        await _handleSuccessfulPayment(orderDoc, {
          'id': 'cod_transaction',
          'amount': totalForPayment,
        });

        _showOrderConfirmationDialog();

      } else {

        if (_selectedMfPaymentMethod?.paymentMethodId == null) {
          throw Exception(AppStrings.get("invalid_payment_method", context));
        }

        await PaymentService.executePayment(
          paymentMethodId: _selectedMfPaymentMethod!.paymentMethodId!,
          amount: totalForPayment,
          customerName: userName,
          customerEmail: user.email!,
          customerMobile: userPhone,
          onSuccess: (String invoiceId) async {
            debugPrint("Payment Success! Invoice: $invoiceId");

            await orderDoc.update({
              'paymentType': _paymentType,
              'paymentStatus': 'paid',
              'transactionId': invoiceId,
              'paymentDate': FieldValue.serverTimestamp(),
              'paymentDetails': {
                'method': _selectedMfPaymentMethod?.paymentMethodEn,
                'amount': totalForPayment,
                'gateway': 'MyFatoorah',
                'invoiceId': invoiceId
              },
            });

            await _handleSuccessfulPayment(orderDoc, {
              'id': invoiceId,
              'amount': totalForPayment,
            });

            if (mounted) _showOrderConfirmationDialog();
          },
          onFailure: (String errorMessage) async {
            debugPrint("Payment Failed/Cancelled: $errorMessage");
            await orderDoc.delete();

            if (mounted) {
              _showPaymentFailedDialog(errorMessage);
            }
          },
        );
      }
    } catch (e, st) {
      debugPrint('Checkout error → $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Checkout failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingOut = false;
          _isValidatingStock = false;
        });
      }
    }
  }

  Widget _buildYouMightAlsoLikeSection() {
    if (_isLoadingDrinks) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.get('you_might_also_like', context), style: AppTextStyles.headline2.copyWith(color: AppColors.darkGrey)),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                itemBuilder: (context, index) => Container(
                  width: 160,
                  margin: EdgeInsets.only(right: 16, left: index == 0 ? 0 : 0),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.lightGrey,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                              color: AppColors.lightGrey,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 60,
                              height: 14,
                              color: AppColors.lightGrey,
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
      );
    }

    if (_drinksItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.get('you_might_also_like', context), style: AppTextStyles.headline2.copyWith(color: AppColors.darkGrey)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                AppStrings.get('no_drinks_available', context),
                style: AppTextStyles.bodyText1,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Text(AppStrings.get('you_might_also_like', context), style: AppTextStyles.headline2.copyWith(color: AppColors.darkGrey)),
        ),
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _drinksItems.length,
            itemBuilder: (_, i) => _DrinkCard(drink: _drinksItems[i],currentBranchIds: _currentBranchIds),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationSection() {
    if (_orderType != 'pickup' || _distanceToBranch <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const Divider(height: 24, thickness: 0.5),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              const Icon(Icons.navigation_outlined, color: AppColors.primaryBlue, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.get('distance_to_branch', context),
                      style: AppTextStyles.bodyText2.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_distanceToBranch.toStringAsFixed(1)} km',
                      style: AppTextStyles.bodyText1.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildNavigationButton(),
            ],
          ),
        ),
      ],
    );
  }

  void _showPaymentFailedDialog(String errorMessage) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text(AppStrings.get('payment_failed', context), style: AppTextStyles.headline2),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your payment could not be processed.',
              style: AppTextStyles.bodyText1.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage.replaceAll('Payment Cancelled', 'The payment was cancelled.'),
              style: AppTextStyles.bodyText2.copyWith(color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Try Again',
              style: AppTextStyles.buttonText.copyWith(color: AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton() {
    return PopupMenuButton<String>(
      onSelected: (value) => _openNavigationApp(value),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'googlemaps',
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset('assets/googlemaps.png', width: 28, height: 28, fit: BoxFit.contain),

                ),
              ),
              const SizedBox(width: 12),
              const Text('Google Maps', style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'applemaps',
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300, width: 0.5),
                ),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset('assets/applemaps.png', width: 28, height: 28, fit: BoxFit.cover)
                ),
              ),
              const SizedBox(width: 12),
              const Text('Apple Maps', style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.navigation, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              'Navigate',
              style: AppTextStyles.bodyText2.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNavigationApp(String app) async {
    try {
      final branchId = _currentBranchIds.first;
      final branchDoc = await FirebaseFirestore.instance
          .collection('Branch')
          .doc(branchId)
          .get();

      if (!branchDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('branch_info_not_found', context))),
        );
        return;
      }

      final branchData = branchDoc.data()!;
      final addressData = branchData['address'] as Map<String, dynamic>?;

      if (addressData == null || addressData['geolocation'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('branch_location_unavailable', context))),
        );
        return;
      }

      final geoPoint = addressData['geolocation'] as GeoPoint;
      final double lat = geoPoint.latitude;
      final double lng = geoPoint.longitude;

      String url;

      if (app == 'apple_maps') {
        url = 'https://maps.apple.com/?q=$lat,$lng';
      } else {
        url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
      }

      if (await canLaunch(url)) {
        await launch(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('could_not_open_maps', context))),
        );
      }
    } catch (e) {
      debugPrint('Error opening navigation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.get('error_opening_navigation', context))),
      );
    }
  }

  void _onOrderTypeChanged(String newType) async {
    if (newType != _orderType) {
      setState(() => _orderType = newType);
      await _setNearestBranch();

      if (newType == 'pickup') {
        await _calculateDistanceForPickup();
      } else {
        await _calculateAndUpdateDeliveryFee();
      }
    }
  }

  String _getBranchDisplayName(String branchId) {
    switch (branchId) {
      case 'Old_Airport':
        return 'Old Airport Branch';
      case 'Mansoura':
        return 'Mansoura Branch';
      case 'West_Bay':
        return 'West Bay Branch';
      default:
        return branchId.replaceAll('_', ' ') + ' Branch';
    }
  }

  String _getBranchesDisplayName(List<String> branchIds) {
    if (branchIds.isEmpty) return 'No branch selected';
    if (branchIds.length == 1) return _getBranchDisplayName(branchIds.first);
    return '${_getBranchDisplayName(branchIds.first)} + ${branchIds.length - 1} more';
  }

  @override
  Widget build(BuildContext context) {
    final cartService = CartService();

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: _buildAppBar(cartService),
      body: !_isInitialized
          ? _buildLoadingShimmer()
          : cartService.items.isEmpty
          ? _buildEmptyCartView()
          : _buildCartContent(cartService),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildShimmerCard(height: 200),
        const SizedBox(height: 24),
        _buildShimmerCard(height: 80),
        const SizedBox(height: 16),
        ...List.generate(3, (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildShimmerCard(height: 100),
        )),
        const SizedBox(height: 16),
        _buildShimmerCard(height: 120),
        const SizedBox(height: 16),
        _buildShimmerCard(height: 200),
      ],
    );
  }

  Widget _buildShimmerCard({double height = 100}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildCartContent(CartService cartService) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(bottom: 16 + bottomInset),
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildDeliveryInfoCard(),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  AppStrings.get('your_items', context),
                  style: AppTextStyles.headline2.copyWith(color: AppColors.darkGrey),
                ),
              ),
              const SizedBox(height: 8),
              _buildCartItemsSection(cartService),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildNotesSection(),
              ),
              const SizedBox(height: 16),
              _buildYouMightAlsoLikeSection(),
              const SizedBox(height: 24),
              _buildCartTotalsSection(cartService),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildPlaceOrderButton(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCartItemsSection(CartService cartService) {
    return ListenableBuilder(
      listenable: cartService,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.separated(
            itemCount: cartService.items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _CartItemWidget(
              item: cartService.items[i],
              cartService: cartService,
              onRemove: (item) {
                cartService.removeFromCart(item.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${item.name} ${AppStrings.get('item_removed_from_cart', context)}.'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    action: SnackBarAction(
                      label: 'UNDO',
                      textColor: AppColors.accentBlue,
                      onPressed: () {
                        cartService.addToCart(
                          MenuItem(
                            id: item.id,
                            name: item.name,
                            imageUrl: item.imageUrl,
                            price: item.price,
                            discountedPrice: item.discountedPrice,
                            description: '',
                            branchIds: _currentBranchIds,
                            categoryId: '',
                            isAvailable: true,
                            isPopular: false,
                            sortOrder: 0,
                            tags: {},
                            variants: {},
                            outOfStockBranches: [],
                          ),
                          quantity: item.quantity,
                        );
                      },
                    ),
                  ),
                );
              },
              notifiedOutOfStockItems: _notifiedOutOfStockItems,
              onItemNotified: (itemId) {
                if (mounted) {
                  setState(() {
                    _notifiedOutOfStockItems.add(itemId);
                  });
                }
              },
            ),
          ),
        );
      },
    );
  }
  Widget _buildCartTotalsSection(CartService cartService) {
    return ListenableBuilder(
      listenable: cartService,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCouponSection(cartService),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildBillRow(AppStrings.get('subtotal', context), cartService.totalAmount),
            ),
            if (_orderType == 'delivery' && deliveryFee > 0 && cartService.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildBillRow(AppStrings.get('delivery_fee', context), deliveryFee),
              ),
            if (cartService.couponDiscount > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildBillRow(AppStrings.get('discount', context), -cartService.couponDiscount, isDiscount: true),
              ),
              const Divider(height: 24, thickness: 0.5),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildBillRow(
                AppStrings.get('total', context),
                cartService.items.isEmpty
                    ? 0.0
                    : (cartService.totalAfterDiscount + (_orderType == 'delivery' ? deliveryFee : 0.0))
                    .clamp(0, double.infinity),
                isTotal: true,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlaceOrderButton() {
    final cartService = CartService();
    final bool isCartEmpty = cartService.items.isEmpty;

    bool hasUnavailableItems = _outOfStockItems.isNotEmpty;

    final bool isDisabled = _isCheckingOut || _isValidatingStock ||
        isCartEmpty || hasUnavailableItems ||
        _areAllBranchesClosed || _noDeliveryAvailable ||
        (_orderType == 'delivery' && _isOutOfDeliveryRange);

    String buttonText = AppStrings.get('checkout', context);

    if (_noDeliveryAvailable) {
      buttonText = AppStrings.get('location_not_serviceable', context);
    } else if (_areAllBranchesClosed) {
      buttonText = AppStrings.get('restaurant_closed', context);
    } else if (_isValidatingStock) {
      buttonText = AppStrings.get('checking_stock', context);
    } else if (_orderType == 'delivery' && _isOutOfDeliveryRange) {
      buttonText = AppStrings.get('outside_delivery_range', context);
    } else if (hasUnavailableItems) {
      buttonText = AppStrings.get('unavailable_items_in_cart', context);
    }

    return SizedBox(
      width: double.infinity,
      child: _isCheckingOut || _isValidatingStock
          ? ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue.withOpacity(0.7),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _isValidatingStock ? AppStrings.get('checking_stock', context) : AppStrings.get('processing', context),
              style: AppTextStyles.buttonText.copyWith(color: AppColors.white),
            ),
          ],
        ),
      )
          : ElevatedButton(
        onPressed: isDisabled ? null : _proceedToCheckout,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? Colors.grey : AppColors.primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          buttonText,
          style: AppTextStyles.buttonText.copyWith(
            color: AppColors.white,
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(CartService cartService) {
    return AppBar(
      title: Text(AppStrings.get('cart_title', context), style: AppTextStyles.headline2.copyWith(color: AppColors.darkGrey)),
      backgroundColor: AppColors.white,
      elevation: 0,
      centerTitle: true,
      actions: [
        if (cartService.items.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _showClearCartDialog(cartService),
          ),
        IconButton(
          icon: Icon(Icons.refresh, color: AppColors.primaryBlue),
          onPressed: _refreshBranchSelection,
          tooltip: 'Refresh nearest branch',
        ),
      ],
    );
  }

  Widget _buildEmptyCartView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 120, color: AppColors.primaryBlue.withOpacity(0.15)),
            const SizedBox(height: 24),
            Text(AppStrings.get('cart_empty', context),
                style: AppTextStyles.headline1.copyWith(color: AppColors.darkGrey, fontSize: 24)),
            const SizedBox(height: 12),
            Text(
              AppStrings.get('cart_empty_sub', context),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText1.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.restaurant_menu, color: Colors.white),
              label: Text(
                'Browse Menu',
                style: AppTextStyles.buttonText.copyWith(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                BottomNavController.index.value = 0;
                Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildOrderTypeToggle(),
          const SizedBox(height: 16),
          _orderType == 'delivery' ? _buildAddressSection() : buildPickupInfo(),

          if (_orderType == 'delivery' && _distanceToBranch > 0) ...[
            const Divider(height: 16, thickness: 0.5),
            buildDeliveryRangeInfo(),
          ],

          const Divider(height: 24, thickness: 0.5),
          _buildTimeEstimate(),
          const Divider(height: 24, thickness: 0.5),
          _buildPaymentSection(),
        ],
      ),
    );
  }

  Widget buildDeliveryRangeInfo() {
    String statusText;
    Color statusColor;

    if (_isOutOfDeliveryRange) {
      statusText = "${AppStrings.get('delivery_range_error', context)} $_noDeliveryRange ${AppStrings.get('km', context)}";
      statusColor = Colors.red;
    } else if (deliveryFee == 0) {
      statusText = "${AppStrings.get('free_delivery_within', context)} $_freeDeliveryRange ${AppStrings.get('kms', context)}";
      statusColor = Colors.green;
    } else {
      statusText = "${_distanceToBranch.toStringAsFixed(1)} ${AppStrings.get('km', context)} ${AppStrings.get('from branch', context)}";
      statusColor = AppColors.darkGrey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            _isOutOfDeliveryRange ? Icons.error_outline : Icons.local_shipping,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: AppTextStyles.bodyText2.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPaymentSection() {
    return InkWell(
      onTap: _showPaymentMethodsBottomSheet,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            const Icon(Icons.payments_outlined, color: AppColors.primaryBlue, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.get('payment_method', context),
                    style: AppTextStyles.bodyText2.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _paymentType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText1.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.darkGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _onOrderTypeChanged('delivery'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: _orderType == 'delivery' ? AppColors.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppStrings.get('delivery', context),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyText1.copyWith(
                    color: _orderType == 'delivery' ? AppColors.white : AppColors.darkGrey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _onOrderTypeChanged('pickup'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: _orderType == 'pickup' ? AppColors.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppStrings.get('pickup', context),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyText1.copyWith(
                    color: _orderType == 'pickup' ? AppColors.white : AppColors.darkGrey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPickupInfo() {
    return Column(
      children: [
        InkWell(
          onTap: _showBranchSelectionBottomSheet,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                _isFindingNearestBranch
                    ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
                    : const Icon(Icons.storefront_outlined, color: AppColors.primaryBlue, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.get('pick_up_from', context),
                          style: AppTextStyles.bodyText2.copyWith(
                              fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        _isFindingNearestBranch
                            ? AppStrings.get('finding_nearest_branch_loading', context)
                            : _getBranchesDisplayName(_currentBranchIds),
                        style: AppTextStyles.bodyText1.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGrey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_isDefaultNearest && !_isFindingNearestBranch)
                        Text(
                          AppStrings.get('nearest_to_address', context),
                          style: AppTextStyles.bodyText2.copyWith(color: Colors.green, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.darkGrey),
              ],
            ),
          ),
        ),
        _buildNavigationSection(),
      ],
    );
  }

  Widget _buildAddressSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      return  Text(AppStrings.get('please_login_address', context));;
    }

    if (_cachedAddress == null && !_isLoadingAddress) {
      _loadUserAddress(user.email!);
    }

    if (_isLoadingAddress) {
      return _buildAddressLoading();
    }

    if (_cachedAddress == null) {
      return _buildAddressError();
    }

    return _buildAddressContent(_cachedAddress!);
  }

  Widget _buildAddressLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: AppColors.primaryBlue, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.get('deliver_to', context),
                  style: AppTextStyles.bodyText2.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.get('loading_address', context),
                  style: AppTextStyles.bodyText1.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressError() {
    return InkWell(
      onTap: () => _showAddressBottomSheet((label, fullAddress) {
        setState(() {});
        _setNearestBranch();
        _loadEstimatedTime();
      }),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, color: AppColors.primaryBlue, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.get('deliver_to', context),
                    style: AppTextStyles.bodyText2.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.get('set_delivery_address', context),
                    style: AppTextStyles.bodyText1.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGrey
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.darkGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressContent(Map<String, dynamic> defaultAddress) {
    final addressText = [
      if (defaultAddress['flat']?.isNotEmpty ?? false) 'Flat ${defaultAddress['flat']}',
      if (defaultAddress['floor']?.isNotEmpty ?? false) 'Floor ${defaultAddress['floor']}',
      if (defaultAddress['building']?.isNotEmpty ?? false) 'Building ${defaultAddress['building']}',
      if (defaultAddress['street']?.isNotEmpty ?? false) defaultAddress['street'],
      if (defaultAddress['city']?.isNotEmpty ?? false) defaultAddress['city'],
    ].join(', ');

    return InkWell(
      onTap: () => _showAddressBottomSheet((label, fullAddress) {
        setState(() {});
        _setNearestBranch();
        _loadEstimatedTime();
      }),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, color: AppColors.primaryBlue, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.get('deliver_to', context),
                    style: AppTextStyles.bodyText2.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    addressText,
                    style: AppTextStyles.bodyText1.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGrey
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.darkGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeEstimate() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.primaryBlue, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${AppStrings.get('est', context)} ${_orderType == 'delivery' ? AppStrings.get('delivery', context) : AppStrings.get('pickup', context)} ${AppStrings.get('time', context)}",
                  style: AppTextStyles.bodyText2.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _estimatedTime,
                  style: AppTextStyles.bodyText1.copyWith(fontWeight: FontWeight.w600, color: AppColors.darkGrey),
                ),
                if (_orderType == 'pickup' && !_isFindingNearestBranch)
                  Text(
                    "${AppStrings.get('from', context)} ${_getBranchesDisplayName(_currentBranchIds)}",
                    style: AppTextStyles.bodyText2.copyWith(
                      color: Colors.green,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.get('special_instructions', context),
          style: AppTextStyles.headline2.copyWith(
            fontSize: 18,
            color: AppColors.darkGrey,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: AppStrings.get('notes_placeholder', context),
            hintStyle: AppTextStyles.bodyText2,
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildCouponSection(CartService cartService) {
    if (cartService.appliedCoupon != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Coupon "${cartService.appliedCoupon!.code}" applied!',
                style: AppTextStyles.bodyText1.copyWith(color: Colors.green.shade800, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => cartService.removeCoupon(),
              child: Text('Remove', style: AppTextStyles.bodyText2.copyWith(color: Colors.red)),
            ),
          ],
        ),
      );
    } else {
      return InkWell(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => CouponsScreen(cartService: cartService)));
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
              color: AppColors.accentBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentBlue.withOpacity(0.3))),
          child: Row(
            children: [
              const Icon(Icons.discount_outlined, color: AppColors.primaryBlue),
              const SizedBox(width: 12),
              Expanded(child: Text(AppStrings.get('apply_coupon', context), style: AppTextStyles.bodyText1.copyWith(fontWeight: FontWeight.w500, color: AppColors.primaryBlue))),
              const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primaryBlue),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildBillRow(String label, double amount, {bool isTotal = false, bool isDiscount = false}) {
    final style = AppTextStyles.bodyText1.copyWith(
        color: isDiscount ? Colors.green.shade700 : (isTotal ? AppColors.darkGrey : Colors.grey.shade600),
        fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
        fontSize: isTotal ? 18 : 16);

    String amountText;
    if (label == AppStrings.get('delivery_fee', context) && amount == 0) {
      amountText = AppStrings.get('free', context).toUpperCase();
    } else {
      amountText = isDiscount ? '- QAR ${amount.abs().toStringAsFixed(2)}' : 'QAR ${amount.toStringAsFixed(2)}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            amountText,
            style: style.copyWith(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: label == AppStrings.get('delivery_fee', context) && amount == 0 ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog(CartService cartService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppStrings.get('clear_cart_title', context),
          style: AppTextStyles.headline2,
        ),
        content: Text(
          AppStrings.get('clear_cart_message', context),
          style: AppTextStyles.bodyText1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppStrings.get('cancel', context),
              style: AppTextStyles.bodyText1.copyWith(color: AppColors.darkGrey),
            ),
          ),
          TextButton(
            onPressed: () {
              cartService.clearCart();
              notifiedOutOfStockItems.clear();
              Navigator.pop(context);
            },
            child: Text(
              AppStrings.get('clear', context),
              style: AppTextStyles.bodyText1.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _showPaymentMethodsBottomSheet() {
    final cartService = CartService();
    final double currentTotal = cartService.totalAfterDiscount +
        (_orderType == 'delivery' ? deliveryFee : 0.0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (_mfPaymentMethods.isEmpty && !_isLoadingPaymentMethods) {
              _isLoadingPaymentMethods = true;
              PaymentService.getPaymentMethods(currentTotal).then((methods) {
                if (mounted) {
                  setSheetState(() {
                    _mfPaymentMethods = methods;
                    _isLoadingPaymentMethods = false;
                  });
                  setState(() {});
                }
              }).catchError((e) {
                if (mounted) {
                  setSheetState(() => _isLoadingPaymentMethods = false);
                }
                debugPrint("Error loading methods: $e");
              });
            }

            return Container(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  left: 16,
                  right: 16,
                  top: 12
              ),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)
                      )
                  ),
                  const SizedBox(height: 20),
                  Text(AppStrings.get('select_payment_method', context), style: AppTextStyles.headline2),
                  const SizedBox(height: 16),

                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.lightGrey,
                      child: Icon(Icons.money_outlined, color: AppColors.primaryBlue),
                    ),
                    title: Text(
                        'Cash on Delivery',
                        style: AppTextStyles.bodyText1.copyWith(
                            fontWeight: _paymentType == 'Cash on Delivery'
                                ? FontWeight.bold
                                : FontWeight.normal
                        )
                    ),
                    trailing: _paymentType == 'Cash on Delivery'
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        _paymentType = 'Cash on Delivery';
                        _selectedMfPaymentMethod = null;
                      });
                      Navigator.pop(context);
                    },
                  ),

                  const Divider(),

                  if (_isLoadingPaymentMethods)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_mfPaymentMethods.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("No online payment methods available",
                          style: AppTextStyles.bodyText2),
                    )
                  else
                    ..._mfPaymentMethods.map((method) {
                      final isSelected = _selectedMfPaymentMethod?.paymentMethodId == method.paymentMethodId;
                      return ListTile(
                        leading: SizedBox(
                          width: 40,
                          height: 40,
                          child: CachedNetworkImage(
                            imageUrl: method.imageUrl ?? '',
                            errorWidget: (_, __, ___) => const Icon(Icons.credit_card),
                            placeholder: (_, __) => const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        title: Text(
                            method.paymentMethodEn ?? 'Unknown',
                            style: AppTextStyles.bodyText1.copyWith(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                            )
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        onTap: () {
                          setState(() {
                            _paymentType = method.paymentMethodEn ?? 'Card';
                            _selectedMfPaymentMethod = method;
                          });
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method) {
      case 'Cash on Delivery': return Icons.money_outlined;
      case 'Card': return Icons.credit_card_outlined;
      case 'Apple Pay': return Icons.phone_iphone_outlined;
      case 'Google Pay': return Icons.android_outlined;
      default: return Icons.payments_outlined;
    }
  }

  void _showBranchSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 16, right: 16, top: 12),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(
              AppStrings.get('select_pickup_branch', context),
              style: AppTextStyles.headline2,
            ),
            const SizedBox(height: 16),
            if (_allBranches.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Text(
                AppStrings.get('no_branches_available', context),
                style: AppTextStyles.bodyText2,
              ),)
            else
              ..._allBranches.map((branch) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade100,
                  child: Icon(_currentBranchIds.contains(branch['id']) ? Icons.store : Icons.storefront_outlined, color: Colors.blue.shade800),
                ),
                title: Text(branch['name']!, style: AppTextStyles.bodyText1.copyWith(
                  fontWeight: _currentBranchIds.contains(branch['id']) ? FontWeight.bold : FontWeight.normal,
                )),
                trailing: _currentBranchIds.contains(branch['id']) ? const Icon(Icons.check_circle, color: Colors.green) : null,
                onTap: () async {

                  final branchDoc = await FirebaseFirestore.instance.collection('Branch').doc(branch['id']).get();
                  final bool isOpen = branchDoc.data()?['isOpen'] ?? true;

                  if (!isOpen) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("${branch['name']} is currently closed for pickup."),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
                    ));
                    return;
                  }

                  setState(() {
                    _currentBranchIds = [branch['id']!];
                    _isDefaultNearest = false;
                    _areAllBranchesClosed = false;
                    _notifiedOutOfStockItems.clear();
                    _isFirstStockCheck = true;
                  });

                  await _loadDrinks();
                  await _loadEstimatedTime();
                  await loadDeliveryFee(branch['id']!);

                  if (_orderType == 'pickup') {
                    await _calculateDistanceForPickup();
                  }

                  Navigator.pop(context);
                },
              )),
          ],
        ),
      ),
    );
  }

  Future<void> _calculateDistanceForPickup() async {
    if (_orderType != 'pickup') return;

    try {
      final userPosition = await _getCurrentLocation();
      if (userPosition == null) return;

      final branchSnap = await FirebaseFirestore.instance
          .collection('Branch')
          .doc(_currentBranchIds.first)
          .get();

      final branchData = branchSnap.data();
      if (branchData == null || branchData['address'] == null) return;

      final branchAddress = branchData['address'] as Map<String, dynamic>;
      final branchGeoPoint = branchAddress['geolocation'] as GeoPoint?;

      if (branchGeoPoint == null) return;

      final distance = _calculateDistance(
        userPosition.latitude,
        userPosition.longitude,
        branchGeoPoint.latitude,
        branchGeoPoint.longitude,
      );

      if (mounted) {
        setState(() {
          _distanceToBranch = distance;
        });
      }
    } catch (e) {
      debugPrint('Error calculating pickup distance: $e');
    }
  }

  void _showAddressBottomSheet(Function(String label, String fullAddress) onAddressSelected) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Users').doc(user.email).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final userData = (snapshot.data!.data() as Map<String, dynamic>?) ?? {};
          final List<Map<String, dynamic>> addresses = ((userData['address'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

          return StatefulBuilder(builder: (context, setModalState) {
            Future<void> _setDefaultAddress(int index) async {
              if (addresses.isEmpty || index < 0 || index >= addresses.length) return;
              for (int i = 0; i < addresses.length; i++) {
                addresses[i]['isDefault'] = i == index;
              }
              setModalState(() {});
              await FirebaseFirestore.instance.collection('Users').doc(user.email).update({'address': addresses});
              final selected = addresses[index];
              final detailed = [
                if ((selected['flat'] ?? '').toString().isNotEmpty) 'Flat ${selected['flat']}',
                if ((selected['floor'] ?? '').toString().isNotEmpty) 'Floor ${selected['floor']}',
                if ((selected['building'] ?? '').toString().isNotEmpty) 'Building ${selected['building']}',
                if ((selected['street'] ?? '').toString().isNotEmpty) selected['street'],
                if ((selected['city'] ?? '').toString().isNotEmpty) selected['city'],
              ].join(', ');

              if (mounted) {
                setState(() {
                  _cachedAddress = selected;
                });
              }

              onAddressSelected((selected['label'] ?? 'Home').toString(), detailed);
              await _calculateAndUpdateDeliveryFee();

              if (Navigator.canPop(context)) Navigator.pop(context);
            }

            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 16, right: 16, top: 12),
              decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text(
                    AppStrings.get('select_delivery_address', context),
                    style: AppTextStyles.headline2,
                  ),
                  const SizedBox(height: 16),
                  if (addresses.isEmpty)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Text(
                      AppStrings.get('no_addresses_saved', context),
                      style: AppTextStyles.bodyText2,
                    ),)
                  else
                    ...addresses.asMap().entries.map((entry) {
                      final address = entry.value;
                      final detailedAddress = [
                        if ((address['flat'] ?? '').isNotEmpty) 'Flat ${address['flat']}',
                        if ((address['floor'] ?? '').isNotEmpty) 'Floor ${address['floor']}',
                        if ((address['building'] ?? '').isNotEmpty) 'Building ${address['building']}',
                        if ((address['street'] ?? '').isNotEmpty) address['street'],
                        if ((address['city'] ?? '').isNotEmpty) address['city'],
                      ].join(', ');
                      final isDefault = address['isDefault'] == true;
                      final label = address['label'] ?? 'Home';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.lightGrey,
                          child: Icon(label == 'Home' ? Icons.home_outlined : Icons.work_outline, color: AppColors.primaryBlue),
                        ),
                        title: Text(label, style: AppTextStyles.bodyText1.copyWith(fontWeight: FontWeight.bold)),
                        subtitle: Text(detailedAddress, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: isDefault ? const Icon(Icons.check_circle, color: Colors.green) : null,
                        onTap: () => _setDefaultAddress(entry.key),
                      );
                    }),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedAddressesScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBlue.withOpacity(0.15),
                        foregroundColor: AppColors.primaryBlue,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Manage Addresses', style: AppTextStyles.buttonText.copyWith(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          });
        },
      ),
    );
  }

  Map<String, dynamic> _composePaymentMeta(double amountQar) {
    switch (_paymentType) {
      case 'Cash on Delivery':
        return {
          'paymentType': 'Cash on Delivery',
          'paymentStatus': 'pending',
          'transactionId': 'no_payment',
          'paymentDate': FieldValue.serverTimestamp(),
          'paymentDetails': {'method': 'cod', 'amount': amountQar, 'gateway': 'none', 'note': 'COD placeholder'},
        };
      case 'Card':
        return {
          'paymentType': 'Card',
          'paymentStatus': 'pending',
          'transactionId': 'pending',
          'paymentDate': FieldValue.serverTimestamp(),
          'paymentDetails': {'method': 'card', 'amount': amountQar, 'gateway': 'placeholder', 'note': 'Card placeholder'},
        };
      case 'Apple Pay':
        return {
          'paymentType': 'Apple Pay',
          'paymentStatus': 'pending',
          'transactionId': 'pending',
          'paymentDate': FieldValue.serverTimestamp(),
          'paymentDetails': {'method': 'apple_pay', 'amount': amountQar, 'gateway': 'placeholder', 'note': 'Apple Pay placeholder'},
        };
      default:
        return {
          'paymentType': 'Google Pay',
          'paymentStatus': 'pending',
          'transactionId': 'pending',
          'paymentDate': FieldValue.serverTimestamp(),
          'paymentDetails': {'method': 'google_pay', 'amount': amountQar, 'gateway': 'placeholder', 'note': 'Google Pay placeholder'},
        };
    }
  }

  Future<DocumentReference> _createOrderInFirestore({
    required User user,
    required CartService cartService,
    required String notes,
    required Map<String, dynamic>? defaultAddress,
    required String userName,
    required String userPhone,
    required String orderType,
  }) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final counterRef = FirebaseFirestore.instance.collection('daily_counters').doc(today);
    final orderDoc = FirebaseFirestore.instance.collection('Orders').doc();

    return await FirebaseFirestore.instance.runTransaction((transaction) async {
      final counterSnap = await transaction.get(counterRef);
      int dailyCount = counterSnap.exists ? (counterSnap.get('count') as int) + 1 : 1;
      final paddedOrderNumber = dailyCount.toString().padLeft(3, '0');
      final String orderId = 'FD-$today-$paddedOrderNumber';

      if (counterSnap.exists) {
        transaction.update(counterRef, {'count': dailyCount});
      } else {
        transaction.set(counterRef, {'count': 1});
      }

      final items = cartService.items.map((item) {
        return {
          'itemId': item.id,
          'name': item.name,
          'name_ar': item.nameAr,
          'quantity': item.quantity,
          'price': item.price,
          'discountedPrice': item.discountedPrice,
          'finalPrice': item.finalPrice,
          'variants': item.variants,
          'addons': item.addons,
          'total': item.finalPrice * item.quantity,
          if (item.couponCode != null) 'couponCode': item.couponCode,
          if (item.couponDiscount != null) 'couponDiscount': item.couponDiscount,
          if (item.couponId != null) 'couponId': item.couponId,
        };
      }).toList();
      final subtotal = cartService.totalAmount;
      final riderPaymentAmount = orderType == 'delivery' ? deliveryFee : 0;
      final total = cartService.totalAfterDiscount + riderPaymentAmount;

      final orderData = {
        'orderId': orderId,
        'dailyOrderNumber': dailyCount,
        'date': today,
        'customerId': user.email,
        'items': items,
        'customerName': userName,
        'customerPhone': userPhone,
        'notes': notes,
        'status': 'pending_payment',
        'subtotal': subtotal,
        'totalAmount': total.clamp(0, double.infinity),
        'timestamp': FieldValue.serverTimestamp(),
        'Order_type': orderType,
        'deliveryAddress': defaultAddress,
        'paymentStatus': 'pending',
        'riderPaymentAmount': riderPaymentAmount,
        'branchIds': _currentBranchIds,
        if (cartService.appliedCoupon != null) 'couponCode': cartService.appliedCoupon!.code,
        if (cartService.appliedCoupon != null) 'couponDiscount': cartService.couponDiscount,
        if (cartService.appliedCoupon != null) 'couponId': cartService.appliedCoupon!.id,
      };

      transaction.set(orderDoc, orderData);
      return orderDoc;
    });
  }

  Future<void> _handleSuccessfulPayment(DocumentReference orderDoc, Map<String, dynamic> paymentVerification) async {
    await orderDoc.update({
      'status': 'pending',
      'paymentStatus': 'paid',
      'paymentDate': FieldValue.serverTimestamp(),
      'paymentDetails.transactionId': paymentVerification['id'],
    });

    final cartService = CartService();
    if (cartService.appliedCoupon != null && FirebaseAuth.instance.currentUser?.email != null) {
      await FirebaseFirestore.instance.collection('coupon_usage').add({
        'couponId': cartService.appliedCoupon!.id,
        'userId': FirebaseAuth.instance.currentUser!.email,
        'orderId': orderDoc.id,
        'usedAt': FieldValue.serverTimestamp(),
        'discountAmount': cartService.couponDiscount,
      });
    }

    await cartService.clearCart();
    _notesController.clear();
    _notifiedOutOfStockItems.clear();
  }

  void _showOrderConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.primaryBlue, size: 60),
            const SizedBox(height: 16),
            Text(AppStrings.get('order_confirmed', context), style: AppTextStyles.headline2),
            const SizedBox(height: 8),
            Text('Your order has been placed successfully', textAlign: TextAlign.center, style: AppTextStyles.bodyText1),
            const SizedBox(height: 8),
            Text(
              'Order will be prepared at ${_getBranchesDisplayName(_currentBranchIds)}',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText2.copyWith(color: Colors.green),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainApp(initialIndex: 0)),
                        (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Back to Menu', style: AppTextStyles.buttonText.copyWith(color: AppColors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemWidget extends StatefulWidget {
  final CartModel item;
  final CartService cartService;
  final Function(CartModel) onRemove;
  final Set<String> notifiedOutOfStockItems;
  final Function(String) onItemNotified;

  const _CartItemWidget({
    Key? key,
    required this.item,
    required this.cartService,
    required this.onRemove,
    required this.notifiedOutOfStockItems,
    required this.onItemNotified,
  }) : super(key: key);

  @override
  State<_CartItemWidget> createState() => _CartItemWidgetState();
}

class _CartItemWidgetState extends State<_CartItemWidget> {
  bool _isItemAvailable = true;
  String _imageUrl = '';
  bool _isCheckingAvailability = false;
  bool _hasShownDialog = false;

  @override
  void initState() {
    super.initState();
    _loadItemData();
  }

  Future<void> _loadItemData() async {
    try {
      if (mounted) {
        setState(() => _isCheckingAvailability = true);
      }

      final menuItemSnap = await FirebaseFirestore.instance
          .collection('menu_items')
          .doc(widget.item.id)
          .get();

      if (!mounted) return;

      if (menuItemSnap.exists) {
        final data = menuItemSnap.data()!;
        _imageUrl = data['imageUrl'] ?? '';

        final outOfStockBranches = List<String>.from(data['outOfStockBranches'] ?? []);
        final isAvailable = data['isAvailable'] ?? true;
        final isAvailableInBranch = isAvailable &&
            !outOfStockBranches.contains(widget.cartService.currentBranchIds.first);

        if (mounted) {
          setState(() {
            _isItemAvailable = isAvailableInBranch;
            _isCheckingAvailability = false;
          });
        }

        if (!isAvailableInBranch &&
            widget.item.quantity > 0 &&
            mounted &&
            !widget.notifiedOutOfStockItems.contains(widget.item.id) &&
            !_hasShownDialog) {

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_hasShownDialog) {
              _showOutOfStockDialog();
              _hasShownDialog = true;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() => _isCheckingAvailability = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading item data: $e');
      if (mounted) {
        setState(() => _isCheckingAvailability = false);
      }
    }
  }

  void _showOutOfStockDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            Text(AppStrings.get('item_unavailable_title', context), style: AppTextStyles.headline2),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.item.name} is currently out of stock in the selected branch.',
              style: AppTextStyles.bodyText1,
            ),
            const SizedBox(height: 8),
            Text(
              'Would you like to remove it from your cart?',
              style: AppTextStyles.bodyText2.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onItemNotified(widget.item.id);
              _hasShownDialog = true;
              Navigator.pop(context);
            },
            child: Text('Keep in Cart', style: AppTextStyles.bodyText1),
          ),
          ElevatedButton(
            onPressed: () {
              widget.cartService.removeFromCart(widget.item.id);
              widget.onItemNotified(widget.item.id);
              _hasShownDialog = true;
              Navigator.pop(context);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${widget.item.name} removed from cart'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Remove', style: AppTextStyles.buttonText),
          ),
        ],
      ),
    );
  }

  void _handleOutOfStockTap() {
    if (!mounted) return;
    _showOutOfStockDialog();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final bool hasDiscount = item.discountedPrice != null;
    final double displayPrice = hasDiscount ? item.discountedPrice! : item.price;
    final isArabic = Provider.of<LanguageProvider>(context, listen: false).isArabic;
    final itemName = isArabic && (item.nameAr.isNotEmpty ?? false)
        ? item.nameAr
        : item.name;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => widget.onRemove(item),
      background: Container(
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.red.shade200, Colors.red.shade500],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: const Icon(Icons.delete_sweep_outlined, color: Colors.white, size: 32),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isItemAvailable ? AppColors.white : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: _isItemAvailable
              ? null
              : Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5),
          boxShadow: _isItemAvailable
              ? [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 70,
                    height: 70,
                    child: _imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: _imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.lightGrey,
                        child: const Icon(Icons.fastfood_outlined, color: Colors.grey),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.lightGrey,
                        child: const Icon(Icons.fastfood_outlined, color: Colors.grey),
                      ),
                    )
                        : Container(
                      color: AppColors.lightGrey,
                      child: const Icon(Icons.fastfood_outlined, color: Colors.grey),
                    ),
                  ),
                ),
                if (!_isItemAvailable)
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.block,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          itemName,
                          style: AppTextStyles.bodyText1.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _isItemAvailable ? AppColors.darkGrey : Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isCheckingAvailability)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                          ),
                        )
                      else if (!_isItemAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'OUT OF STOCK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (item.addons != null && item.addons!.isNotEmpty)
                    Text(
                      'Add-ons: ${item.addons!.join(', ')}',
                      style: AppTextStyles.bodyText2.copyWith(
                        fontSize: 12,
                        color: _isItemAvailable ? null : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  if (hasDiscount)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'QAR ${displayPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _isItemAvailable ? Colors.green : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'QAR ${item.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (_isItemAvailable) const SizedBox(height: 4),
                        if (_isItemAvailable)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Save QAR ${(item.price - displayPrice).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    Text(
                      'QAR ${displayPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isItemAvailable ? AppColors.primaryBlue : Colors.grey,
                      ),
                    ),
                  if (!_isItemAvailable) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _handleOutOfStockTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Tap for options',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildQuantityControl(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControl() {
    final item = widget.item;

    if (!_isItemAvailable) {
      return InkWell(
        onTap: _handleOutOfStockTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              if (item.quantity > 1) {
                widget.cartService.updateQuantity(item.id, item.quantity - 1);
              } else {
                widget.cartService.removeFromCart(item.id);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Icon(
                Icons.remove,
                size: 20,
                color: item.quantity > 1 ? AppColors.primaryBlue : Colors.grey,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              item.quantity.toString(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGrey,
              ),
            ),
          ),
          InkWell(
            onTap: () => widget.cartService.updateQuantity(item.id, item.quantity + 1),
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(6.0),
              child: Icon(Icons.add, size: 20, color: AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrinkCard extends StatefulWidget {
  final MenuItem drink;
  final List<String> currentBranchIds;

  const _DrinkCard({
    Key? key,
    required this.drink,
    required this.currentBranchIds,
  }) : super(key: key);

  @override
  State<_DrinkCard> createState() => _DrinkCardState();
}

class _DrinkCardState extends State<_DrinkCard> {
  void updateDrinkQuantity(int change) {
    final cartService = CartService();
    final currentItem = cartService.items.firstWhere(
          (item) => item.id == widget.drink.id,
      orElse: () => CartModel(
        id: widget.drink.id,
        name: widget.drink.name,
        nameAr: widget.drink.nameAr,
        imageUrl: widget.drink.imageUrl,
        price: widget.drink.price,
        discountedPrice: widget.drink.discountedPrice,
        quantity: 0,
      ),
    );

    final isAvailable = widget.drink.isAvailableInBranch(widget.currentBranchIds.first);
    if (!isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${widget.drink.name} is not available in selected branch"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int newQuantity = currentItem.quantity + change;
    if (newQuantity > 0) {
      if (currentItem.quantity == 0) {
        cartService.addToCart(widget.drink, quantity: 1);
      } else {
        cartService.updateQuantity(widget.drink.id, newQuantity);
      }
    } else {
      cartService.removeFromCart(widget.drink.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartService(),
      builder: (context, child) {
        final cartService = CartService();
        final cartItem = cartService.items.firstWhere(
              (item) => item.id == widget.drink.id,
          orElse: () => CartModel(
            id: widget.drink.id,
            name: '',
            imageUrl: '',
            price: 0,
            discountedPrice: widget.drink.discountedPrice,
            quantity: 0,
          ),
        );

        int quantity = cartItem.quantity;
        final isAvailable = widget.drink.isAvailableInBranch(widget.currentBranchIds.first);

        final drinkName = widget.drink.getLocalizedName(context);

        return Container(
          width: 160,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.darkGrey.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    children: [
                      Opacity(
                        opacity: isAvailable ? 1.0 : 0.6,
                        child: CachedNetworkImage(
                          imageUrl: widget.drink.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => Container(color: AppColors.lightGrey),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.local_drink_outlined,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      if (!isAvailable)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Text(
                              "Out of Stock",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      if (!isAvailable && quantity > 0)
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: Colors.red.withOpacity(0.9),
                            child: const Text(
                              "Remove from cart",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (widget.drink.discountedPrice != null && isAvailable)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "OFFER",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drinkName,
                      style: AppTextStyles.bodyText1.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? AppColors.darkGrey : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (widget.drink.discountedPrice != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QAR ${widget.drink.discountedPrice!.toStringAsFixed(2)}',
                            style: AppTextStyles.bodyText1.copyWith(
                              color: isAvailable ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'QAR ${widget.drink.price.toStringAsFixed(2)}',
                            style: AppTextStyles.bodyText2.copyWith(
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'QAR ${widget.drink.price.toStringAsFixed(2)}',
                        style: AppTextStyles.bodyText1.copyWith(
                          color: isAvailable ? AppColors.primaryBlue : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (!isAvailable && quantity > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          AppStrings.get('item_unavailable', context),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _buildAddButton(
                  widget.drink,
                  widget.currentBranchIds.first,
                  updateDrinkQuantity,
                  quantity,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddButton(
      MenuItem item,
      String currentBranchId,
      Function(int) onUpdateQuantity,
      int currentQuantity,
      ) {
    final isAvailable = item.isAvailableInBranch(currentBranchId);

    if (!isAvailable) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          child: Text(
            'Unavailable',
            style: AppTextStyles.buttonText.copyWith(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return currentQuantity == 0
        ? SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => onUpdateQuantity(1),
        icon: const Icon(Icons.add_shopping_cart, size: 18),
        label: Text(
          'Add',
          style: AppTextStyles.buttonText.copyWith(fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    )
        : Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => onUpdateQuantity(-1),
            icon: const Icon(Icons.remove),
            color: AppColors.white,
            iconSize: 20,
          ),
          Text(
            currentQuantity.toString(),
            style: AppTextStyles.buttonText.copyWith(color: AppColors.white),
          ),
          IconButton(
            onPressed: () => onUpdateQuantity(1),
            icon: const Icon(Icons.add),
            color: AppColors.white,
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}

class CartService extends ChangeNotifier {
  static CartService? _instance;

  static CartService get instance {
    _instance ??= CartService._internal();
    return _instance!;
  }

  CartService._internal() {
    _loadCartFromPrefs();
  }

  factory CartService() => instance;

  final List<CartModel> _items = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  CouponModel? _appliedCoupon;
  double _couponDiscount = 0;
  List<String> _currentBranchIds = ['Old_Airport'];
  Timer? _stockMonitorTimer;

  List<CartModel> get items => _items;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      _items.fold(0, (sum, item) => sum + (item.finalPrice * item.quantity));

  double get totalAfterDiscount {
    double subtotal = totalAmount;
    double finalTotal = subtotal - _couponDiscount;
    return finalTotal.clamp(0, double.infinity);
  }

  CouponModel? get appliedCoupon => _appliedCoupon;
  double get couponDiscount => _couponDiscount;
  List<String> get currentBranchIds => _currentBranchIds;

  Future<void> _loadCartFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_items');
      if (cartJson != null) {
        final Map<String, dynamic> cartData = json.decode(cartJson);
        _items.clear();
        if (cartData['items'] != null) {
          _items.addAll((cartData['items'] as List)
              .map((item) => CartModel.fromMap(item as Map<String, dynamic>)));
        }

        if (cartData['coupon'] != null) {
          _appliedCoupon = CouponModel.fromMap(
              cartData['coupon'] as Map<String, dynamic>,
              cartData['coupon']['id'] ?? '');
          _couponDiscount = cartData['couponDiscount']?.toDouble() ?? 0;
        }

        if (cartData['branchIds'] != null) {
          _currentBranchIds = List<String>.from(cartData['branchIds']);
        } else if (cartData['branchId'] != null) {
          _currentBranchIds = [cartData['branchId'] as String];
        } else {
          _currentBranchIds = ['Old_Airport'];
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart from SharedPreferences: $e');
    }
  }

  Future<void> _saveCartToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = json.encode({
        'items': _items.map((item) => item.toMap()).toList(),
        'coupon': _appliedCoupon?.toMap(),
        'couponDiscount': _couponDiscount,
        'branchIds': _currentBranchIds,
      });
      await prefs.setString('cart_items', cartJson);
    } catch (e) {
      debugPrint('Error saving cart to SharedPreferences: $e');
    }
  }

  Future<void> addToCartWithStockCheck(
      MenuItem menuItem, {
        int quantity = 1,
        required String branchId,
        Map<String, dynamic>? variants,
        List<String>? addons,
      }) async {
    if (!menuItem.isAvailableInBranch(branchId)) {
      throw Exception('${menuItem.name} is not available in the selected branch');
    }

    await addToCart(
        menuItem,
        quantity: quantity,
        variants: variants,
        addons: addons
    );
  }

  Future<void> addToCart(
      MenuItem menuItem, {
        int quantity = 1,
        Map<String, dynamic>? variants,
        List<String>? addons,
      }) async {
    final existingIndex = _items.indexWhere((item) => item.id == menuItem.id);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartModel(
        id: menuItem.id,
        name: menuItem.name,
        nameAr: menuItem.nameAr,
        imageUrl: menuItem.imageUrl,
        price: menuItem.price,
        discountedPrice: menuItem.discountedPrice,
        quantity: quantity,
        variants: variants ?? {},
        addons: addons,
      ));
    }
    notifyListeners();
    await _saveCartToPrefs();
  }

  Future<List<CartModel>> getOutOfStockItems(List<String> branchIds) async {
    final List<CartModel> outOfStockItems = [];

    for (final item in _items) {
      try {
        final menuItemSnap = await FirebaseFirestore.instance
            .collection('menu_items')
            .doc(item.id)
            .get();

        if (!menuItemSnap.exists) {
          outOfStockItems.add(item);
          continue;
        }

        final menuItemData = menuItemSnap.data()!;
        final outOfStockBranches = List<String>.from(menuItemData['outOfStockBranches'] ?? []);
        final isAvailable = menuItemData['isAvailable'] as bool? ?? true;

        bool isAvailableInAnyBranch = false;
        for (final branchId in branchIds) {
          if (isAvailable && !outOfStockBranches.contains(branchId)) {
            isAvailableInAnyBranch = true;
            break;
          }
        }

        if (!isAvailableInAnyBranch) {
          outOfStockItems.add(item);
        }
      } catch (e) {
        debugPrint('Error checking stock for ${item.name}: $e');
        outOfStockItems.add(item);
      }
    }

    return outOfStockItems;
  }

  Future<void> removeOutOfStockItems(List<CartModel> outOfStockItems) async {
    for (final item in outOfStockItems) {
      _items.removeWhere((cartItem) => cartItem.id == item.id);
    }
    notifyListeners();
    await _saveCartToPrefs();
  }

  Future<void> validateCartStock(List<String> branchIds) async {
    for (final item in _items) {
      try {
        final menuItemSnap = await FirebaseFirestore.instance
            .collection('menu_items')
            .doc(item.id)
            .get();

        if (!menuItemSnap.exists) {
          throw Exception('${item.name} is no longer available');
        }

        final menuItemData = menuItemSnap.data()!;
        final outOfStockBranches = List<String>.from(menuItemData['outOfStockBranches'] ?? []);
        final isAvailable = menuItemData['isAvailable'] as bool? ?? true;

        bool isAvailableInAnyBranch = false;
        for (final branchId in branchIds) {
          if (isAvailable && !outOfStockBranches.contains(branchId)) {
            isAvailableInAnyBranch = true;
            break;
          }
        }

        if (!isAvailableInAnyBranch) {
          throw Exception('${item.name} is out of stock in all selected branches');
        }

      } catch (e) {
        debugPrint('Stock validation error for ${item.name}: $e');
        rethrow;
      }
    }
  }

  void startStockMonitoring(List<String> branchIds) {
    _stockMonitorTimer?.cancel();

    _stockMonitorTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final outOfStockItems = await getOutOfStockItems(branchIds);
      if (outOfStockItems.isNotEmpty) {
        notifyListeners();
      }
    });
  }

  void stopStockMonitoring() {
    _stockMonitorTimer?.cancel();
    _stockMonitorTimer = null;
  }

  Future<void> removeFromCart(String itemId) async {
    _items.removeWhere((item) => item.id == itemId);
    notifyListeners();
    await _saveCartToPrefs();
  }

  Future<void> updateQuantity(String itemId, int newQuantity) async {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      if (newQuantity > 0) {
        _items[index].quantity = newQuantity;
      } else {
        _items.removeAt(index);
      }
    }
    notifyListeners();
    await _saveCartToPrefs();
  }

  Future<void> clearCart() async {
    _items.clear();
    _appliedCoupon = null;
    _couponDiscount = 0;
    notifyListeners();
    await _saveCartToPrefs();
  }

  Future<void> applyCoupon(String couponCode) async {
    try {
      final user = _auth.currentUser;
      final userId = user?.email;
      final snapshot = await FirebaseFirestore.instance
          .collection('coupons')
          .where('code', isEqualTo: couponCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) throw Exception('Coupon not found');
      final couponDoc = snapshot.docs.first;
      final coupon = CouponModel.fromMap(couponDoc.data(), couponDoc.id);

      if (!coupon.isValidForUser(userId, _currentBranchIds.first, 'delivery')) {
        throw Exception('Coupon not valid for this order');
      }

      if (totalAmount < coupon.minSubtotal) {
        throw Exception(
            'Minimum order amount of QAR ${coupon.minSubtotal} not met');
      }

      if (coupon.maxUsesPerUser > 0 && userId != null) {
        final userUsage = await FirebaseFirestore.instance
            .collection('coupon_usage')
            .where('userId', isEqualTo: userId)
            .where('couponId', isEqualTo: coupon.id)
            .get();
        if (userUsage.docs.length >= coupon.maxUsesPerUser) {
          throw Exception(
              'You have already used this coupon the maximum number of times');
        }
      }

      double discount = 0;
      if (coupon.type == 'percentage') {
        discount = totalAmount * (coupon.value / 100);
        if (coupon.maxDiscount > 0 && discount > coupon.maxDiscount) {
          discount = coupon.maxDiscount;
        }
      } else {
        discount = coupon.value;
      }

      final totalBeforeDiscount = totalAmount;

      if (totalBeforeDiscount > 0) {
        for (var item in _items) {
          final itemPercentage =
              (item.finalPrice * item.quantity) / totalBeforeDiscount;
          item.couponDiscount = discount * itemPercentage;
          item.couponCode = coupon.code;
          item.couponId = coupon.id;
        }
      }

      _appliedCoupon = coupon;
      _couponDiscount = discount;
      notifyListeners();
      await _saveCartToPrefs();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeCoupon() async {
    for (var item in _items) {
      item.couponDiscount = null;
      item.couponCode = null;
      item.couponId = null;
    }
    _appliedCoupon = null;
    _couponDiscount = 0;
    notifyListeners();
    await _saveCartToPrefs();
  }

  void updateCurrentBranchIds(List<String> branchIds) {
    _currentBranchIds = branchIds;
    notifyListeners();
    _saveCartToPrefs();
  }

  bool isItemInCart(String itemId) {
    return _items.any((item) => item.id == itemId);
  }

  int getItemQuantity(String itemId) {
    final item = _items.firstWhere(
          (item) => item.id == itemId,
      orElse: () => CartModel(
        id: '',
        name: '',
        imageUrl: '',
        price: 0,
        quantity: 0,
      ),
    );
    return item.quantity;
  }

  CartModel? getCartItem(String itemId) {
    try {
      return _items.firstWhere((item) => item.id == itemId);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _stockMonitorTimer?.cancel();
    super.dispose();
  }
}