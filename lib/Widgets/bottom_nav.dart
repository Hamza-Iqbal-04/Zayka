import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mitra_da_dhaba/Screens/CouponsScreen.dart';
import 'package:mitra_da_dhaba/Screens/DineInScreen.dart';
import 'package:mitra_da_dhaba/Screens/HomeScreen.dart';
import 'package:mitra_da_dhaba/Screens/OrderScreen.dart';
import 'package:mitra_da_dhaba/Screens/Takeaway Screen.dart';
import 'package:mitra_da_dhaba/Screens/cartScreen.dart';
import 'models.dart';

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;
  final String _currentBranchId = 'Old_Airport';

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartService>(context, listen: false);   // OK here

    final screens = <Widget>[
      HomeScreen(),
      const OrdersScreen(),
      CouponsScreen(cartService: cart),                               // Offers
      const TakeAwayScreen(),
      const DineInScreen(),
    ];

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Branch')
          .doc(_currentBranchId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text('Branch not found')));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final bool isOpen = data['isOpen'] ?? true;
        if (!isOpen) return const ClosedRestaurantScreen();

        return Scaffold(
          extendBody: true, // let body show under the bulged center [4]
          body: IndexedStack(index: _currentIndex, children: screens),
          // IMPORTANT: no ClipRRect around the bar [16]
          bottomNavigationBar: ConvexAppBar(
            style: TabStyle.fixedCircle,                          // center bulge [29]
            height: 64,
            curveSize: 90,
            top: -28,
            cornerRadius: 20,                                      // rounded top, no ClipRRect [29]
            backgroundColor: Colors.white,
            color: Colors.grey,                               // other tabs (unselected) [7]
            activeColor: AppColors.primaryBlue,                    // other tabs (selected) [7]
            items: [
              const TabItem(icon: Icons.home_outlined, title: 'Home'),
              const TabItem(icon: Icons.newspaper_outlined, title: 'Orders'),
              // Center tab: always-blue circle
              TabItem(
                title: 'Offers',
                icon: _offersIcon(),            // same for both states -> always blue [29]
                activeIcon: _offersIcon(),      // prevent tint change [29]
              ),
              const TabItem(icon: Icons.takeout_dining_outlined, title: 'Pick Up'),
              const TabItem(icon: Icons.local_restaurant_outlined, title: 'Dine In'),
            ],
            initialActiveIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
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
      color: AppColors.primaryBlue,                       // always blue
      border: Border.all(color: Colors.white, width: 6),  // white ring
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
    ),
    child: const Icon(Icons.local_offer, color: Colors.white, size: 22),
  );

  Widget _decoratedIcon(IconData icon, int index) {
    final isActive = _currentIndex == index;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isActive ? AppColors.primaryBlue.withOpacity(0.2) : Colors.transparent,
      ),
      child: Icon(icon, size: 24, color: isActive ? AppColors.primaryBlue : null),
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
                  Icons.lock_clock_rounded, // Modern closed icon
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
                    // Refresh the app or re-check status (forces a rebuild)
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

