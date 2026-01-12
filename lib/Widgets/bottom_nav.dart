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
import 'package:mitra_da_dhaba/Services/BranchService.dart';
import 'package:geolocator/geolocator.dart';
import '../Services/language_provider.dart';
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

// 1. Add SingleTickerProviderStateMixin
class _MainAppState extends State<MainApp> with SingleTickerProviderStateMixin {
  late int _currentIndex;
  // 2. Add TabController
  late TabController _tabController;
  // Removed hardcoded _currentBranchId
  bool _isRestaurantOpen = true;
  bool _isLoading = true;
  int _cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;

    // 3. Initialize TabController
    _tabController =
        TabController(length: 5, vsync: this, initialIndex: _currentIndex);

    _checkRestaurantStatus();
    _setupCartListener();

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
      // 1. Get User Location (Fastest possible way)
      GeoPoint? userLocation;
      try {
        // Try getting last known position first for speed
        Position? position = await Geolocator.getLastKnownPosition();
        if (position == null) {
          // If null, try getting current position with timeout
          position = await Geolocator.getCurrentPosition(
            timeLimit: const Duration(seconds: 5),
          );
        }
        if (position != null) {
          userLocation = GeoPoint(position.latitude, position.longitude);
        }
      } catch (e) {
        debugPrint('Error getting location for status check: $e');
      }

      // Fallback location if permission denied or error (e.g. Doha center)
      // This ensures we at least check if *any* branch is open relative to *somewhere*
      // or we can allow the app to open if location fails, assuming user will select address later.
      userLocation ??= const GeoPoint(25.2854, 51.5310);

      // 2. Use BranchService to check availability
      final branchService = BranchService();
      // We check for 'pickup' or 'delivery'. Let's check 'pickup' as it's the most permissive
      // (doesn't require being in range). If they are closed for pickup, they are closed for everything.
      // Wait, user said "delivery range etc". But for the MAIN APP OPEN check,
      // if I strictly check delivery range, I might block users who want to do pickup.
      // The user wants "if nearest branch is closed...".
      // Let's stick to checking if a valid branch exists for *pickup* (open status check basically).
      // Logic: If NO branch is open for pickup, then the restaurant is truly closed.
      final result = await branchService.findBestBranch(
          userLocation: userLocation,
          orderType:
              'pickup' // Check mainly for Open/Closed status regardless of range first
          );

      if (mounted) {
        setState(() {
          // valid branch found AND it's not "allClosed"
          _isRestaurantOpen = !result.allClosed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error checking restaurant status: $e");
      if (mounted) {
        setState(() {
          // Fallback to open if something errors out, don't block user
          _isRestaurantOpen = true;
          _isLoading = false;
        });
      }
    }
  }

  void _handleExternalIndexChange() {
    if (BottomNavController.index.value != _currentIndex && mounted) {
      // 4. Animate controller when external change happens (like from CartScreen)
      _tabController.animateTo(BottomNavController.index.value);

      setState(() {
        _currentIndex = BottomNavController.index.value;
      });
    }
  }

  @override
  void dispose() {
    BottomNavController.index.removeListener(_handleExternalIndexChange);
    // 5. Dispose controller
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Removed blocking ClosedRestaurantScreen as per user request
    // if (!_isRestaurantOpen) {
    //   return const ClosedRestaurantScreen();
    // }

    return Consumer<CartService>(
      builder: (context, cart, child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (didPop) return;

            // 1. If not on Home tab, go to Home
            if (_currentIndex != 0) {
              setState(() => _currentIndex = 0);
              _tabController.animateTo(0);
              BottomNavController.index.value = 0;
              return;
            }

            // 2. If on Home tab, show Exit Confirmation Dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Exit App',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                content: const Text(
                  'Are you sure you want to exit the application?',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                    ),
                    child: const Text(
                      'No, Stay',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => SystemNavigator.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: const Text(
                      'Yes, Exit',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            );
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

  Widget _buildBottomNav(CartService cart) {
    return ConvexAppBar(
      // 6. Provide the controller to the AppBar
      controller: _tabController,
      style: TabStyle.fixedCircle,
      height: 64,
      curveSize: 90,
      top: -28,
      cornerRadius: 20,
      backgroundColor: Colors.white,
      color: Colors.grey,
      activeColor: AppColors.primaryBlue,
      items: [
        TabItem(
            icon: Icons.home_outlined,
            title: AppStrings.get('nav_home', context)),
        TabItem(
            icon: Icons.newspaper_outlined,
            title: AppStrings.get('nav_orders', context)),
        TabItem(
          title: AppStrings.get('nav_offers', context),
          icon: _offersIcon(),
          activeIcon: _offersIcon(),
        ),
        TabItem(
          icon: _cartIconWithBadge(_cartItemCount),
          title: AppStrings.get('nav_cart', context),
        ),
        TabItem(
            icon: Icons.person, title: AppStrings.get('nav_profile', context)),
      ],
      // Remove initialActiveIndex as controller takes precedence
      onTap: (i) {
        if (_currentIndex == i) return;
        // 7. Use animateTo to sync everything on manual tap
        _tabController.animateTo(i);
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
            BoxShadow(
                color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
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
