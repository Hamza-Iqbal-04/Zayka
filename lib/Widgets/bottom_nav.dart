// bottom_nav.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemNavigator.pop()
import 'package:mitra_da_dhaba/Screens/Profile.dart';
import 'package:provider/provider.dart';
import 'package:mitra_da_dhaba/Screens/CouponsScreen.dart';
import 'package:mitra_da_dhaba/Screens/HomeScreen.dart';
import 'package:mitra_da_dhaba/Screens/OrderScreen.dart';
import 'package:mitra_da_dhaba/Screens/cartScreen.dart';
import 'models.dart';

class MainApp extends StatefulWidget {
  final int? initialIndex;
  const MainApp({Key? key, this.initialIndex}) : super(key: key);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late int _currentIndex;
  final String _currentBranchId = 'Old_Airport';

  @override
  void initState() {
    super.initState();
    // Use initialIndex if provided, otherwise default to 0
    _currentIndex = widget.initialIndex ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final cartService = Provider.of<CartService>(context, listen: false);

    final screens = <Widget>[
      HomeScreen(),
      const OrdersScreen(),
      CouponsScreen(cartService: cartService), // Offers
      const CartScreen(),
      const ProfileScreen(),
    ];

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Branch')
          .doc(_currentBranchId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Branch not found')),
          );
        }

        final data = snapshot.data!.data()!;
        final bool isOpen = data['isOpen'] ?? true;
        if (!isOpen) return const ClosedRestaurantScreen();

        // Wrap main Scaffold with PopScope to handle Android back properly.
        // Behavior:
        // - If not on Home (index != 0): switch to Home and consume back.
        // - If already on Home (index == 0): minimize app to Android launcher.
        return PopScope(
          // Prevent Navigator from popping this route; handle back manually.
          canPop: false,
          onPopInvoked: (didPop) {
            // didPop will be false because canPop is false.
            if (_currentIndex != 0) {
              setState(() => _currentIndex = 0);
              return;
            }
            // Already on Home: send app to background (Android launcher).
            SystemNavigator.pop();
          },
          child: Scaffold(
            extendBody: true,
            body: IndexedStack(index: _currentIndex, children: screens),
            bottomNavigationBar:
            Consumer<CartService>(builder: (context, cart, child) {
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
                  // Center tab: always-blue circle
                  TabItem(
                    title: 'Offers',
                    icon: _offersIcon(),
                    activeIcon: _offersIcon(),
                  ),
                  // Cart tab with badge
                  TabItem(
                    icon: _cartIconWithBadge(cart.itemCount),
                    title: 'Cart',
                  ),
                  const TabItem(icon: Icons.person, title: 'Profile'),
                ],
                initialActiveIndex: _currentIndex,
                onTap: (i) => setState(() => _currentIndex = i),
              );
            }),
          ),
        );
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
                    padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
