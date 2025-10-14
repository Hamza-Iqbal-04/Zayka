// bottom_nav.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mitra_da_dhaba/Screens/Profile.dart';
import 'package:provider/provider.dart';
import 'package:mitra_da_dhaba/Screens/CouponsScreen.dart';
import 'package:mitra_da_dhaba/Screens/HomeScreen.dart';
import 'package:mitra_da_dhaba/Screens/OrderScreen.dart';
import 'package:mitra_da_dhaba/Screens/cartScreen.dart';
import 'models.dart';

class BottomNavController {
  static final ValueNotifier<int> index = ValueNotifier<int>(0);
}

class MainApp extends StatefulWidget {
  final int? initialIndex;
  const MainApp({Key? key, this.initialIndex}) : super(key: key);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late int _currentIndex;
  final String _currentBranchId = 'Old_Airport';
  bool _isRestaurantOpen = true;
  bool _isLoading = true;
  int _cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;

    // Don't set the value here to avoid the setState during build
    // BottomNavController.index.value = _currentIndex;

    _checkRestaurantStatus();
    _setupCartListener();

    // Add listener after initialization is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BottomNavController.index.addListener(_handleExternalIndexChange);
    });
  }

  void _setupCartListener() {
    final cartService = CartService();
    cartService.addListener(() {
      if (mounted) {
        setState(() {
          _cartItemCount = cartService.itemCount;
        });
      }
    });
  }

  void _checkRestaurantStatus() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Branch')
          .doc(_currentBranchId)
          .get();

      if (mounted) {
        setState(() {
          _isRestaurantOpen = snapshot.data()?['isOpen'] ?? true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestaurantOpen = true;
          _isLoading = false;
        });
      }
    }
  }

  void _handleExternalIndexChange() {
    if (BottomNavController.index.value != _currentIndex && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentIndex = BottomNavController.index.value;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    BottomNavController.index.removeListener(_handleExternalIndexChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isRestaurantOpen) {
      return const ClosedRestaurantScreen();
    }

    return Consumer<CartService>(
      builder: (context, cart, child) {
        return PopScope(
          canPop: _currentIndex == 0,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (didPop) return;

            if (_currentIndex != 0) {
              setState(() => _currentIndex = 0);
              BottomNavController.index.value = 0;
              return;
            }

            SystemNavigator.pop();
          },
          child: Scaffold(
            extendBody: true,
            body: IndexedStack(
              index: _currentIndex,
              children: [
                const HomeScreen(),
                const OrdersScreen(),
                CouponsScreen(cartService: cart),
                const CartScreen(),
                const ProfileScreen(),
              ],
            ),
            bottomNavigationBar: _buildBottomNav(cart),
          ),
        );
      },
    );
  }

  void _setupRestaurantStatusListener() {
    FirebaseFirestore.instance
        .collection('Branch')
        .doc(_currentBranchId)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        final isOpen = snapshot.data()?['isOpen'] ?? true;
        if (isOpen != _isRestaurantOpen) {
          setState(() {
            _isRestaurantOpen = isOpen;
          });
        }
      }
    });
  }

  Widget _buildBottomNav(CartService cart) {
    return ConvexAppBar(
      style: TabStyle.fixedCircle,
      height: 64,
      curveSize: 90,
      top: -28,
      cornerRadius: 20,
      backgroundColor: Colors.white,
      color: Colors.grey,
      activeColor: AppColors.primaryBlue,
      items: [
        const TabItem(icon: Icons.home_outlined, title: 'Home'),
        const TabItem(icon: Icons.newspaper_outlined, title: 'Orders'),
        TabItem(
          title: 'Offers',
          icon: _offersIcon(),
          activeIcon: _offersIcon(),
        ),
        TabItem(
          icon: _cartIconWithBadge(_cartItemCount),
          title: 'Cart',
        ),
        const TabItem(icon: Icons.person, title: 'Profile'),
      ],
      initialActiveIndex: _currentIndex,
      onTap: (i) {
        if (_currentIndex == i) return;
        setState(() => _currentIndex = i);
        BottomNavController.index.value = i;
      },
    );
  }

  Widget _offersIcon() => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.primaryBlue,
      border: Border.all(color: Colors.white, width: 6),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
      ],
    ),
    child: const Icon(Icons.local_offer, color: Colors.white, size: 22),
  );

  Widget _cartIconWithBadge(int itemCount) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.shopping_cart, size: 24),
        if (itemCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                itemCount > 9 ? '9+' : itemCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class ClosedRestaurantScreen extends StatelessWidget {
  const ClosedRestaurantScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryBlue.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_clock_rounded,
                  size: 80,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(height: 24),
                Text(
                  'We\'re Currently Closed',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Our restaurant is closed right now. Please check back during our operating hours or try again later.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const MainApp()),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}