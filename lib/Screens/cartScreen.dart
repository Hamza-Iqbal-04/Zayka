import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:geolocator/geolocator.dart';
import '../Services/BranchService.dart'; // adjust path if needed
import 'package:provider/provider.dart'; // already used elsewhere
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

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);
  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // ─────────────────────────── data ───────────────────────────
  final RestaurantService _restaurantService = RestaurantService();
  String _estimatedTime = 'Loading...';
  double deliveryFee = 0;
  bool _isFindingNearestBranch = false;
  String _currentBranchId = 'OldAirport';
  List<Map<String, String>> _allBranches = []; // ← new
  String _nearestBranchId = ''; // last result from BranchLocator
  bool _isDefaultNearest = true;
  final TextEditingController _notesController = TextEditingController();
  List<MenuItem> _drinksItems = [];
  bool _isLoadingDrinks = true;
  bool _isCheckingOut = false;
  String _orderType = 'delivery';// 'delivery' | 'pickup'
  String _paymentType = 'Cash on Delivery'; // 'Cash on Delivery' | 'Card' | 'Apple Pay' | 'Google Pay'


  // ─────────────────────────── lifecycle ───────────────────────────
  @override
  void initState() {
    super.initState();
    _loadAvailableBranches(); // ← fetch list once
    _setNearestBranch(); // ← keep your existing nearest-logic
    _loadInitialData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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

    setState(() {}); // rebuild PopupMenu once data arrives
  }

  // ─────────────────────────── branch selection ───────────────────────────
  Future<void> _setNearestBranch() async {
    if (!mounted) return;
    setState(() => _isFindingNearestBranch = true);

    try {
      // BranchLocator already knows the closest branch to the user’s default address
      final branchId = context.read<BranchLocator>().branchId ?? 'OldAirport';

      if (mounted) {
        setState(() {
          _currentBranchId = branchId;
          _nearestBranchId = branchId;
          _isDefaultNearest = true;
          _isFindingNearestBranch = false;
        });
        // reload UI pieces that depend on the branch
        _loadDrinks();
        await loadDeliveryFee(branchId);
        _loadEstimatedTime();
      }
    } catch (e) {
      debugPrint('Error setting nearest branch: $e');
      if (mounted) setState(() => _isFindingNearestBranch = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Using default branch.')),
      );
    }
  }

  void _refreshBranchSelection() => _setNearestBranch();

  // ─────────────────────────── initial loads ───────────────────────────
  void _loadInitialData() {
    _loadEstimatedTime();
    _loadDrinks();
  }

  Future<void> _loadEstimatedTime() async {
    final time = await _restaurantService.getDynamicEtaForUser(
      _currentBranchId,
      orderType: _orderType,
    );
    if (mounted) setState(() => _estimatedTime = time);
  }

  Future<void> _loadDrinks() async {
    if (!mounted) return;
    setState(() => _isLoadingDrinks = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('menu_items')
          .where('categoryId', isEqualTo: 'Drinks')
          .where('branchId', isEqualTo: _currentBranchId)
          .orderBy('sortOrder')
          .limit(10)
          .get();

      _drinksItems = snap.docs.map((d) {
        final data = d.data();
        return MenuItem(
          id: d.id,
          name: data['name'] ?? 'Unknown Drink',
          price: (data['price'] ?? 0).toDouble(),
          discountedPrice: data['discountedPrice']?.toDouble(),
          imageUrl: data['imageUrl'] ?? '',
          description: data['description'] ?? '',
          categoryId: data['categoryId'] ?? '',
          branchId: data['branchId'] ?? _currentBranchId,
          isAvailable: data['isAvailable'] ?? true,
          isPopular: data['isPopular'] ?? false,
          sortOrder: data['sortOrder'] ?? 0,
          variants:
          (data['variants'] is Map) ? Map.from(data['variants']) : const {},
          tags: (data['tags'] is Map) ? Map.from(data['tags']) : const {},
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading drinks: $e');
      _drinksItems = [];
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load drink suggestions.')),
      );
    }

    if (mounted) setState(() => _isLoadingDrinks = false);
  }

  Future<void> loadDeliveryFee(String branchId) async {
    final snap = await FirebaseFirestore.instance
        .collection('Branch')
        .doc(branchId)
        .get();

    if (!mounted) return;
    setState(() {
      deliveryFee = (snap.data()?['deliveryFee'] ?? 0).toDouble();
    });
  }


  // ─────────────────────────── UI helpers (unchanged) ───────────────────────────
  void _onOrderTypeChanged(String newType) {
    if (newType != _orderType) {
      setState(() => _orderType = newType);
      _setNearestBranch(); // ensure branch & ETA are current
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

  String _getBranchAddress(String branchId) {
    switch (branchId) {
      case 'Old_Airport':
        return '123 Old Airport Road\nDoha, Qatar';
      case 'City_Center':
        return '456 City Center Mall\nDoha, Qatar';
      case 'West_Bay':
        return '789 West Bay Area\nDoha, Qatar';
      default:
        return 'Unknown Location';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    return ListenableBuilder(
      listenable: CartService(),
      builder: (_, __) {
        final cartService = CartService();
        return Scaffold(
          backgroundColor: AppColors.lightGrey,
          appBar: _buildAppBar(cartService),
          body: cartService.items.isEmpty
              ? _buildEmptyCartView()
              : ListView(
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
                  'Your Items',
                  style: AppTextStyles.headline2.copyWith(color: AppColors.darkGrey),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.separated(
                  itemCount: cartService.items.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _buildCartItem(cartService.items[i], cartService),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildNotesSection(),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildYouMightAlsoLikeSection(),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildCouponSection(cartService),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildBillRow('Subtotal', cartService.totalAmount),
              ),
              if (_orderType == 'delivery' && deliveryFee > 0 && cartService.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildBillRow('Delivery Fee', deliveryFee),
                ),
              if (cartService.couponDiscount > 0) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildBillRow('Coupon Discount', -cartService.couponDiscount, isDiscount: true),
                ),
                const Divider(height: 24, thickness: 0.5),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildBillRow(
                  'Total Amount',
                  cartService.items.isEmpty
                      ? 0.0
                      : (cartService.totalAfterDiscount + (_orderType == 'delivery' ? deliveryFee : 0.0))
                      .clamp(0, double.infinity),
                  isTotal: true,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _proceedToCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('PLACE ORDER', style: AppTextStyles.buttonText.copyWith(color: AppColors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(CartService cartService) {
    return AppBar(
      title: Text('My Cart',
          style: AppTextStyles.headline2.copyWith(color: AppColors.darkGrey)),
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

  Widget _buildBody(CartService cartService) {
    if (cartService.items.isEmpty) {
      return _buildEmptyCartView();
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 340),
      children: [
        const SizedBox(height: 16),
        _buildDeliveryInfoCard(),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text("Your Items",
              style:
              AppTextStyles.headline2.copyWith(color: AppColors.darkGrey)),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          itemCount: cartService.items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildCartItem(cartService.items[index], cartService);
          },
        ),
        const SizedBox(height: 16),
        _buildNotesSection(),
        const SizedBox(height: 16),
        _buildYouMightAlsoLikeSection(),
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
            Text('Your Cart is Empty',
                style: AppTextStyles.headline1
                    .copyWith(color: AppColors.darkGrey, fontSize: 24)),
            const SizedBox(height: 12),
            Text(
              'Looks like you haven\'t added anything to your cart yet.',
              textAlign: TextAlign.center,
              style:
              AppTextStyles.bodyText1.copyWith(color: Colors.grey.shade600),
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
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                BottomNavController.index.value = 0; // Home tab
                Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfoCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
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
            _orderType == 'delivery'
                ? _buildAddressSection()
                : buildPickupInfo(),
            const Divider(height: 24, thickness: 0.5),
            _buildTimeEstimate(),
            const Divider(height: 24, thickness: 0.5),
            _buildPaymentSection(),
          ],
        ),
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
                  Text('PAYMENT METHOD',
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

  Map<String, dynamic> _composePaymentMeta(double amountQar) {
    switch (_paymentType) {
      case 'Cash on Delivery':
        return {
          'paymentType': 'Cash on Delivery',
          'paymentStatus': 'pending',               // per provided structure
          'transactionId': 'no_payment',         // per provided structure
          'paymentDate': FieldValue.serverTimestamp(),
          'paymentDetails': {
            'method': 'cod',
            'amount': amountQar,
            'gateway': 'none',
            'note': 'COD placeholder',
          },
        };
      case 'Card':
        return {
          'paymentType': 'Card',
          'paymentStatus': 'pending',            // placeholder for gateway flow
          'transactionId': 'pending',
          'paymentDate': FieldValue.serverTimestamp(),
          'paymentDetails': {
            'method': 'card',
            'amount': amountQar,
            'gateway': 'placeholder',
            'note': 'Card placeholder',
          },
        };
      case 'Apple Pay':
        return {
          'paymentType': 'Apple Pay',
          'paymentStatus': 'pending',
          'transactionId': 'pending',
          'paymentDate': FieldValue.serverTimestamp(),
          'paymentDetails': {
            'method': 'apple_pay',
            'amount': amountQar,
            'gateway': 'placeholder',
            'note': 'Apple Pay placeholder',
          },
        };
      case 'Google Pay':
      default:
        return {
          'paymentType': 'Google Pay',
          'paymentStatus': 'pending',
          'transactionId': 'pending',
          'paymentDate': FieldValue.serverTimestamp(),
          'paymentDetails': {
            'method': 'google_pay',
            'amount': amountQar,
            'gateway': 'placeholder',
            'note': 'Google Pay placeholder',
          },
        };
    }
  }

  void _showPaymentMethodsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final options = [
              {'label': 'Cash on Delivery', 'icon': Icons.money_outlined},
              {'label': 'Card', 'icon': Icons.credit_card_outlined},
              {'label': 'Apple Pay', 'icon': Icons.phone_iphone_outlined},
              {'label': 'Google Pay', 'icon': Icons.android_outlined},
            ];

            return Container(
              padding: EdgeInsets.only(
                top: 12,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Select Payment Method', style: AppTextStyles.headline2),
                  const SizedBox(height: 16),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final opt = options[i];
                      final sel = opt['label'] as String;
                      final isSelected = _paymentType == sel;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.lightGrey,
                          child: Icon(opt['icon'] as IconData, color: AppColors.primaryBlue),
                        ),
                        title: Text(
                          sel,
                          style: AppTextStyles.bodyText1.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                        onTap: () {
                          setState(() => _paymentType = sel);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$sel selected')),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
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
                padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: _orderType == 'delivery'
                      ? AppColors.primaryBlue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Delivery',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyText1.copyWith(
                    color: _orderType == 'delivery'
                        ? AppColors.white
                        : AppColors.darkGrey,
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
                padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: _orderType == 'pickup'
                      ? AppColors.primaryBlue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Pickup',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyText1.copyWith(
                    color: _orderType == 'pickup'
                        ? AppColors.white
                        : AppColors.darkGrey,
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

  // ADD THIS ENTIRE FUNCTION TO YOUR _CartScreenState
  void _showBranchSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 12,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white, // Or your AppColors.white
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Select Pickup Branch', style: AppTextStyles.headline2), // Use your text style
                  const SizedBox(height: 16),
                  if (_allBranches.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text('No active branches available', style: AppTextStyles.bodyText2), // Use your text style
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _allBranches.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final branch = _allBranches[index];
                          final bool isSelected = branch['id'] == _currentBranchId;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey.shade100, // Or your AppColors.lightGrey
                              child: Icon(
                                isSelected ? Icons.store : Icons.storefront_outlined,
                                color: Colors.blue.shade800, // Or your AppColors.primaryBlue
                              ),
                            ),
                            title: Text(
                              branch['name']!,
                              style: AppTextStyles.bodyText1.copyWith( // Use your text style
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null,
                            onTap: () {
                              setState(() {
                                _currentBranchId = branch['id']!;
                                _isDefaultNearest = (_currentBranchId == _nearestBranchId);
                              });
                              _loadDrinks();
                              _loadEstimatedTime();
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  // DELETE YOUR OLD buildPickupInfo() AND REPLACE IT WITH THIS
  Widget buildPickupInfo() {
    return InkWell(
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
                : const Icon(Icons.storefront_outlined, color: AppColors.primaryBlue, size: 28), // Use your color
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PICK UP FROM',
                      style: AppTextStyles.bodyText2.copyWith( // Use your text style
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    _isFindingNearestBranch
                        ? 'Finding nearest branch…'
                        : _getBranchDisplayName(_currentBranchId),
                    style: AppTextStyles.bodyText1.copyWith( // Use your text style
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGrey), // Use your color
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isDefaultNearest && !_isFindingNearestBranch)
                    Text(
                      'Nearest to your address',
                      style: AppTextStyles.bodyText2.copyWith(color: Colors.green, fontSize: 11), // Use your text style
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.darkGrey), // Use your color
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      return const Text('Please log in to set an address.');
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .doc(user.email)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Text("Loading Address..."));
        }
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return const Text('No address data found.');
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final addresses = (userData?['address'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
            [];

        Map<String, dynamic>? defaultAddress;
        try {
          defaultAddress = addresses.firstWhere((a) => a['isDefault'] == true);
        } catch (e) {
          defaultAddress = addresses.isNotEmpty ? addresses.first : null;
        }

        final addressText = defaultAddress == null
            ? 'Set Delivery Address'
            : [
          if (defaultAddress['flat']?.isNotEmpty ?? false)
            'Flat ${defaultAddress['flat']}',
          if (defaultAddress['floor']?.isNotEmpty ?? false)
            'Floor ${defaultAddress['floor']}',
          if (defaultAddress['building']?.isNotEmpty ?? false)
            'Building ${defaultAddress['building']}',
          if (defaultAddress['street']?.isNotEmpty ?? false)
            defaultAddress['street'],
          if (defaultAddress['city']?.isNotEmpty ?? false)
            defaultAddress['city'],
        ].join(', ');

        return InkWell(
          onTap: () {
            _showAddressBottomSheet((label, fullAddress) {
              setState(() {});
              _setNearestBranch();
              _loadEstimatedTime();
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    color: AppColors.primaryBlue, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DELIVER TO',
                          style: AppTextStyles.bodyText2.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        addressText,
                        style: AppTextStyles.bodyText1.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGrey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios,
                    size: 16, color: AppColors.darkGrey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeEstimate() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined,
              color: AppColors.primaryBlue, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EST. ${_orderType.toUpperCase()} TIME',
                    style: AppTextStyles.bodyText2.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  _estimatedTime,
                  style: AppTextStyles.bodyText1.copyWith(
                      fontWeight: FontWeight.w600, color: AppColors.darkGrey),
                ),
                if (_orderType == 'pickup' && !_isFindingNearestBranch)
                  Text(
                    'from ${_getBranchDisplayName(_currentBranchId)}',
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

  Widget _buildCartItem(CartModel item, CartService cartService) {
    final bool hasDiscount = item.discountedPrice != null;
    final double displayPrice =
    hasDiscount ? item.discountedPrice! : item.price;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        cartService.removeFromCart(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} removed from cart.'),
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      branchId: '',
                      categoryId: '',
                      isAvailable: true,
                      isPopular: false,
                      sortOrder: 0,
                      tags: {},
                      variants: {}),
                  quantity: item.quantity,
                );
              },
            ),
          ),
        );
      },
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
        child: const Icon(Icons.delete_sweep_outlined,
            color: Colors.white, size: 32),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start, // Changed to start for better alignment
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: Colors.grey.shade100),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade100,
                  child: Icon(Icons.fastfood_outlined,
                      color: Colors.grey.shade400),
                ),
              ),
            ),
            const SizedBox(width: 12), // Reduced from 16 to 12
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppTextStyles.bodyText1.copyWith(
                        fontWeight: FontWeight.bold, color: AppColors.darkGrey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (item.addons != null && item.addons!.isNotEmpty)
                    Text(
                      'Add-ons: ${item.addons!.join(', ')}',
                      style: AppTextStyles.bodyText2.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),

                  // FIXED: Better layout that prevents overflow
                  if (hasDiscount)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // First row: Current price and original price
                        Row(
                          children: [
                            Text(
                              'QAR ${displayPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              // Use Flexible instead of Expanded
                              child: Text(
                                'QAR ${item.price.toStringAsFixed(2)}',
                                style: const TextStyle(
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
                        const SizedBox(height: 4),
                        // Second row: Savings badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(
                width: 8), // Added spacing between content and quantity control
            _buildQuantityControl(item, cartService),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControl(CartModel item, CartService cartService) {
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
                cartService.updateQuantity(item.id, item.quantity - 1);
              } else {
                _showRemoveConfirmationDialog(item, cartService);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Icon(Icons.remove,
                  size: 20,
                  color:
                  item.quantity > 1 ? AppColors.primaryBlue : Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              item.quantity.toString(),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGrey),
            ),
          ),
          InkWell(
            onTap: () => cartService.updateQuantity(item.id, item.quantity + 1),
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

  void _showRemoveConfirmationDialog(CartModel item, CartService cartService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            const SizedBox(width: 12),
            Text('Remove Item?',
                style: AppTextStyles.headline2.copyWith(fontSize: 20)),
          ],
        ),
        content: Text(
            'Are you sure you want to remove ${item.name} from your cart?',
            style: AppTextStyles.bodyText1),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: AppTextStyles.bodyText1
                    .copyWith(color: AppColors.darkGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              cartService.removeFromCart(item.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Remove',
                style: AppTextStyles.buttonText.copyWith(fontSize: 14)),
          ),
        ],
        actionsPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildYouMightAlsoLikeSection() {
    if (_isLoadingDrinks) {
      return const SizedBox.shrink();
    }
    if (_drinksItems.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Text('You might also like',
              style:
              AppTextStyles.headline2.copyWith(color: AppColors.darkGrey)),
        ),
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _drinksItems.length,
            itemBuilder: (_, i) => _DrinkCard(drink: _drinksItems[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Special Instructions',
              style: AppTextStyles.headline2
                  .copyWith(fontSize: 18, color: AppColors.darkGrey)),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g. "No onions", "Extra spicy"...',
              hintStyle: AppTextStyles.bodyText2,
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                const BorderSide(color: AppColors.primaryBlue, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar(CartService cartService) {
    // UPDATED: These now use the corrected calculations from CartService
    final double subtotal = cartService.totalAmount; // Includes item discounts
    final double total = cartService.totalAfterDiscount + (_orderType == 'delivery' ? deliveryFee : 0); // Includes item + coupon discounts

    // DEBUG: Print cart details
    debugPrint('CartScreen - Checkout Bar:');
    debugPrint('  Subtotal: $subtotal');
    debugPrint('  Coupon Discount: ${cartService.couponDiscount}');
    debugPrint('  Total After Discount: $total');
    debugPrint('  Items count: ${cartService.items.length}');
    for (var item in cartService.items) {
      debugPrint(
          '    ${item.name}: ${item.finalPrice} x ${item.quantity} = ${item.finalPrice * item.quantity}');
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(
            color: AppColors.white.withOpacity(0.8),
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCouponSection(cartService),
              const SizedBox(height: 16),
              _buildBillRow('Subtotal', subtotal),
              if (cartService.couponDiscount > 0)
                _buildBillRow('Coupon Discount', -cartService.couponDiscount,
                    isDiscount: true),
              const Divider(height: 24, thickness: 0.5),
              _buildBillRow('Total Amount', total, isTotal: true),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCheckingOut ? null : _proceedToCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isCheckingOut
                      ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3))
                      : Text('PLACE ORDER',
                      style: AppTextStyles.buttonText
                          .copyWith(color: AppColors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
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
                style: AppTextStyles.bodyText1.copyWith(
                    color: Colors.green.shade800, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => cartService.removeCoupon(),
              child: Text('Remove',
                  style: AppTextStyles.bodyText2.copyWith(color: Colors.red)),
            ),
          ],
        ),
      );
    } else {
      return InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CouponsScreen(cartService: cartService)),
          );
          if (result == 'go_to_cart') {
            // Already on Cart tab; optionally refresh totals or show a toast
          }
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
              Expanded(
                child: Text('Apply Coupon',
                    style: AppTextStyles.bodyText1.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryBlue)),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppColors.primaryBlue),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildBillRow(String label, double amount,
      {bool isTotal = false, bool isDiscount = false}) {
    final style = AppTextStyles.bodyText1.copyWith(
        color: isDiscount
            ? Colors.green.shade700
            : (isTotal ? AppColors.darkGrey : Colors.grey.shade600),
        fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
        fontSize: isTotal ? 18 : 16);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            isDiscount
                ? '- QAR ${amount.abs().toStringAsFixed(2)}'
                : 'QAR ${amount.toStringAsFixed(2)}',
            style: style.copyWith(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w600),
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
        title: Text('Clear Cart?', style: AppTextStyles.headline2),
        content: Text('This will remove all items from your cart.',
            style: AppTextStyles.bodyText1),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: AppTextStyles.bodyText1
                    .copyWith(color: AppColors.darkGrey)),
          ),
          TextButton(
            onPressed: () {
              cartService.clearCart();
              Navigator.pop(context);
            },
            child: Text('Clear',
                style: AppTextStyles.bodyText1
                    .copyWith(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
              return const Center(child: CircularProgressIndicator());
            }

            final userDoc = snapshot.data!;
            final userData = (userDoc.data() as Map<String, dynamic>?) ?? {};
            final List<Map<String, dynamic>> addresses =
            ((userData['address'] as List?) ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();

            return StatefulBuilder(
              builder: (context, setModalState) {
                Future<void> _setDefaultAddress(int index) async {
                  if (addresses.isEmpty ||
                      index < 0 ||
                      index >= addresses.length) return;

                  for (int i = 0; i < addresses.length; i++) {
                    addresses[i]['isDefault'] = i == index;
                  }
                  setModalState(() {});

                  await FirebaseFirestore.instance
                      .collection('Users')
                      .doc(user.email)
                      .update({'address': addresses});

                  final selected = addresses[index];
                  final detailed = [
                    if ((selected['flat'] ?? '').toString().isNotEmpty)
                      'Flat ${selected['flat']}',
                    if ((selected['floor'] ?? '').toString().isNotEmpty)
                      'Floor ${selected['floor']}',
                    if ((selected['building'] ?? '').toString().isNotEmpty)
                      'Building ${selected['building']}',
                    if ((selected['street'] ?? '').toString().isNotEmpty)
                      selected['street'],
                    if ((selected['city'] ?? '').toString().isNotEmpty)
                      selected['city'],
                  ].join(', ');

                  onAddressSelected(
                      (selected['label'] ?? 'Home').toString(), detailed);

                  if (Navigator.canPop(context)) Navigator.pop(context);
                }

                return Container(
                  padding: EdgeInsets.only(
                    top: 12,
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Select Delivery Address',
                          style: AppTextStyles.headline2),
                      const SizedBox(height: 16),
                      if (addresses.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text('No addresses saved yet',
                              style: AppTextStyles.bodyText2),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: addresses.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final address = addresses[index];
                            final detailedAddress = [
                              if ((address['flat'] ?? '').isNotEmpty)
                                'Flat ${address['flat']}',
                              if ((address['floor'] ?? '').isNotEmpty)
                                'Floor ${address['floor']}',
                              if ((address['building'] ?? '').isNotEmpty)
                                'Building ${address['building']}',
                              if ((address['street'] ?? '').isNotEmpty)
                                address['street'],
                              if ((address['city'] ?? '').isNotEmpty)
                                address['city'],
                            ].join(', ');
                            final isDefault = address['isDefault'] == true;
                            final label = address['label'] ?? 'Home';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.lightGrey,
                                child: Icon(
                                  label == 'Home'
                                      ? Icons.home_outlined
                                      : Icons.work_outline,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                              title: Text(label,
                                  style: AppTextStyles.bodyText1
                                      .copyWith(fontWeight: FontWeight.bold)),
                              subtitle: Text(detailedAddress,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: isDefault
                                  ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                                  : null,
                              onTap: () => _setDefaultAddress(index),
                            );
                          },
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                    const SavedAddressesScreen()));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            AppColors.accentBlue.withOpacity(0.15),
                            foregroundColor: AppColors.primaryBlue,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Manage Addresses',
                              style: AppTextStyles.buttonText
                                  .copyWith(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _proceedToCheckout() async {
    final String notes = _notesController.text.trim();
    if (!mounted) return;
    setState(() => _isCheckingOut = true);
    try {
      final cartService = CartService();
      if (cartService.items.isEmpty) throw Exception("Your cart is empty");

      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) throw Exception("User not authenticated");

      Map<String, dynamic>? defaultAddress;
      if (_orderType == 'delivery') {
        final userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.email).get();
        if (!userDoc.exists) throw Exception("User document not found");
        final userData = userDoc.data() as Map<String, dynamic>;
        final addresses = ((userData['address'] as List?) ?? []).map((a) => Map<String, dynamic>.from(a as Map)).toList();
        if (addresses.isEmpty) throw Exception("No delivery address set");
        defaultAddress = addresses.firstWhere((a) => a['isDefault'] == true, orElse: () => addresses[0]);
      }

      // Load user profile fields needed for order
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.email).get();
      final userData = userDoc.data() as Map<String, dynamic>;
      final String userName = userData['name'] ?? 'Customer';
      final String userPhone = userData['phone'] ?? 'No phone provided';

      // Create order (existing method)
      final orderDoc = await _createOrderInFirestore(
        user: user,
        cartService: cartService,
        notes: notes,
        defaultAddress: defaultAddress,
        userName: userName,
        userPhone: userPhone,
        orderType: _orderType,
      );

      // Update payment fields (matches provided structure)
      final double totalForPayment = cartService.totalAfterDiscount + (_orderType == 'delivery' ? deliveryFee : 0.0);
      final paymentMeta = _composePaymentMeta(totalForPayment);
      await orderDoc.update(paymentMeta);

      // Optional: keep this if something else relies on it
      await _handleSuccessfulPayment(orderDoc, {
        'id': paymentMeta['transactionId'] ?? 'no_payment',
        'amount': totalForPayment,
      });

      _showOrderConfirmationDialog();
    } catch (e, st) {
      debugPrint('Checkout error → $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
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
    final counterRef =
    FirebaseFirestore.instance.collection('daily_counters').doc(today);
    final orderDoc = FirebaseFirestore.instance.collection('Orders').doc();

    return await FirebaseFirestore.instance.runTransaction((transaction) async {
      final counterSnap = await transaction.get(counterRef);
      int dailyCount =
      counterSnap.exists ? (counterSnap.get('count') as int) + 1 : 1;
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
          'quantity': item.quantity,
          'price': item.price,
          'discountedPrice':
          item.discountedPrice, // Add discounted price to order
          'finalPrice': item.finalPrice, // Add final price to order
          'variants': item.variants,
          'addons': item.addons,
          'total': item.finalPrice * item.quantity, // Use finalPrice for total
          if (item.couponCode != null) 'couponCode': item.couponCode,
          if (item.couponDiscount != null)
            'couponDiscount': item.couponDiscount,
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
        'branchId': _currentBranchId, // Add branch ID to order
        if (cartService.appliedCoupon != null)
          'couponCode': cartService.appliedCoupon!.code,
        if (cartService.appliedCoupon != null)
          'couponDiscount': cartService.couponDiscount,
        if (cartService.appliedCoupon != null)
          'couponId': cartService.appliedCoupon!.id,
      };

      transaction.set(orderDoc, orderData);
      return orderDoc;
    });
  }

  Future<void> _handleSuccessfulPayment(DocumentReference orderDoc,
      Map<String, dynamic> paymentVerification) async {
    await orderDoc.update({
      'status': 'pending',
      'paymentStatus': 'paid',
      'paymentDate': FieldValue.serverTimestamp(),
      'paymentDetails.transactionId': paymentVerification['id'],
    });

    final cartService = CartService();
    if (cartService.appliedCoupon != null &&
        FirebaseAuth.instance.currentUser?.email != null) {
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
            const Icon(Icons.check_circle,
                color: AppColors.primaryBlue, size: 60),
            const SizedBox(height: 16),
            Text('Order Confirmed!', style: AppTextStyles.headline2),
            const SizedBox(height: 8),
            Text('Your order has been placed successfully',
                textAlign: TextAlign.center, style: AppTextStyles.bodyText1),
            const SizedBox(height: 8),
            Text(
              'Order will be prepared at ${_getBranchDisplayName(_currentBranchId)}',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText2.copyWith(color: Colors.green),
            ),
            const SizedBox(height: 24),
            // In cartScreen.dart → inside _showOrderConfirmationDialog()
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const MainApp(initialIndex: 0),
                    ),
                        (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Back to Menu',
                  style: AppTextStyles.buttonText.copyWith(color: AppColors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrinkCard extends StatefulWidget {
  final MenuItem drink;
  const _DrinkCard({Key? key, required this.drink}) : super(key: key);
  @override
  State<_DrinkCard> createState() => _DrinkCardState();
}

class _DrinkCardState extends State<_DrinkCard> {
  void _updateDrinkQuantity(int change) {
    final cartService = CartService();
    final currentItem = cartService.items.firstWhere(
          (item) => item.id == widget.drink.id,
      orElse: () => CartModel(
        id: widget.drink.id,
        name: widget.drink.name,
        imageUrl: widget.drink.imageUrl,
        price: widget.drink.price,
        discountedPrice: widget.drink.discountedPrice,
        quantity: 0,
      ),
    );

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
                quantity: 0));
        int quantity = cartItem.quantity;

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
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
                  child: CachedNetworkImage(
                    imageUrl: widget.drink.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) =>
                        Container(color: AppColors.lightGrey),
                    errorWidget: (context, url, error) => const Icon(
                        Icons.local_drink_outlined,
                        size: 40,
                        color: Colors.grey),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.drink.name,
                      style: AppTextStyles.bodyText1.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkGrey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // UPDATED: Show discounted price for drinks too
                    if (widget.drink.discountedPrice != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QAR ${widget.drink.discountedPrice!.toStringAsFixed(2)}',
                            style: AppTextStyles.bodyText1.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.w600),
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
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: quantity == 0
                    ? SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _updateDrinkQuantity(1),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: Text('Add',
                        style: AppTextStyles.buttonText
                            .copyWith(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
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
                        onPressed: () => _updateDrinkQuantity(-1),
                        icon: const Icon(Icons.remove,
                            color: AppColors.white, size: 20),
                      ),
                      Text(
                        quantity.toString(),
                        style: AppTextStyles.buttonText
                            .copyWith(color: AppColors.white),
                      ),
                      IconButton(
                        onPressed: () => _updateDrinkQuantity(1),
                        icon: const Icon(Icons.add,
                            color: AppColors.white, size: 20),
                      ),
                    ],
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

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;

  CartService._internal() {
    _loadCartFromPrefs();
  }

  final List<CartModel> _items = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  CouponModel? _appliedCoupon;
  double _couponDiscount = 0;
  String _currentBranchId = 'Old_Airport'; // Made mutable

  List<CartModel> get items => _items;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  // UPDATED: Calculate subtotal using finalPrice (includes item discounts)
  double get totalAmount =>
      _items.fold(0, (sum, item) => sum + (item.finalPrice * item.quantity));

  // UPDATED: Calculate total after coupon discount
  double get totalAfterDiscount {
    double subtotal = totalAmount;
    double finalTotal = subtotal - _couponDiscount;
    return finalTotal.clamp(0, double.infinity);
  }

  CouponModel? get appliedCoupon => _appliedCoupon;
  double get couponDiscount => _couponDiscount;
  String get currentBranchId => _currentBranchId;

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

        // Load saved branch ID
        _currentBranchId = cartData['branchId'] ?? 'Old_Airport';
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
        'branchId': _currentBranchId, // Save branch ID
      });
      await prefs.setString('cart_items', cartJson);
    } catch (e) {
      debugPrint('Error saving cart to SharedPreferences: $e');
    }
  }

  Future<String> _findNearestBranch() async {
    try {
      // Get user's current location
      Position userPosition = await _getUserLocation();

      // Get all active branches
      final branchesSnapshot = await FirebaseFirestore.instance
          .collection('Branch')
          .where('isActive', isEqualTo: true)
          .get();

      if (branchesSnapshot.docs.isEmpty) {
        return 'Old_Airport'; // fallback
      }

      String nearestBranchId = 'Old_Airport';
      double shortestDistance = double.infinity;

      for (final branchDoc in branchesSnapshot.docs) {
        final branchData = branchDoc.data();
        final addressData = branchData['address'] as Map<String, dynamic>?;

        if (addressData != null && addressData['geolocation'] != null) {
          final geoPoint = addressData['geolocation'] as GeoPoint;
          final branchLat = geoPoint.latitude;
          final branchLng = geoPoint.longitude;

          final distance = _calculateDistance(
            userPosition.latitude,
            userPosition.longitude,
            branchLat,
            branchLng,
          );

          if (distance < shortestDistance) {
            shortestDistance = distance;
            nearestBranchId = branchDoc.id;
          }
        }
      }

      debugPrint(
          'Nearest branch: $nearestBranchId, Distance: ${shortestDistance.toStringAsFixed(2)} km');
      return nearestBranchId;
    } catch (e) {
      debugPrint('Error finding nearest branch: $e');
      return 'Old_Airport'; // fallback
    }
  }

  Future<Position> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location service is enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    // Get current position
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: Duration(seconds: 10),
    );
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // kilometers

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Existing cart methods
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
        imageUrl: menuItem.imageUrl,
        price: menuItem.price,
        discountedPrice: menuItem.discountedPrice, // Store discounted price
        quantity: quantity,
        variants: variants ?? {},
        addons: addons,
      ));
    }
    notifyListeners();
    await _saveCartToPrefs();
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

      if (!coupon.isValidForUser(userId, _currentBranchId, 'delivery')) {
        throw Exception('Coupon not valid for this order');
      }

      // Use the updated totalAmount that considers discounted prices
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

      // UPDATED COUPON DISTRIBUTION LOGIC - Use finalPrice instead of price
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
}
