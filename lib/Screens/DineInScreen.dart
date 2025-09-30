// import 'dart:convert';
// import 'dart:ui';
// import '../Widgets/models.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:intl/intl.dart';
// import 'package:flutter/services.dart';
//
// class RestaurantService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   Future<String> getEstimatedTime(String branchId) async {
//     try {
//       final doc = await _firestore
//           .collection('restaurant_settings')
//           .doc(branchId)
//           .get();
//       if (doc.exists && doc.data()!.containsKey('estimatedDineInTime')) {
//         return doc.data()!['estimatedDineInTime'] as String;
//       }
//       return '25-30 min'; // Default if not found
//     } catch (e) {
//       debugPrint('Error fetching estimated time: $e');
//       return '25-30 min'; // Fallback on error
//     }
//   }
// }
//
// class MenuCategory {
//   final String id;
//   final String name;
//   final String imageUrl;
//   final int sortOrder;
//   final bool isActive;
//
//   MenuCategory({
//     required this.id,
//     required this.name,
//     required this.imageUrl,
//     required this.sortOrder,
//     required this.isActive,
//   });
//
//   factory MenuCategory.fromFirestore(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>;
//     return MenuCategory(
//       id: doc.id,
//       name: data['name'] ?? '',
//       imageUrl: data['imageUrl'] ?? '',
//       sortOrder: data['sortOrder'] ?? 0,
//       isActive: data['isActive'] ?? false,
//     );
//   }
// }
//
// class MenuItem {
//   final String id;
//   final String name;
//   final String description;
//   final double price;
//   final String imageUrl;
//   final String categoryId;
//   final String branchId;
//   final bool isAvailable;
//   final bool isPopular;
//   final int sortOrder;
//   final Map<String, dynamic> tags;
//   final Map<String, dynamic> variants;
//
//   MenuItem({
//     required this.id,
//     required this.name,
//     required this.description,
//     required this.price,
//     required this.imageUrl,
//     required this.categoryId,
//     required this.branchId,
//     required this.isAvailable,
//     required this.isPopular,
//     required this.sortOrder,
//     required this.tags,
//     required this.variants,
//   });
//
//   factory MenuItem.fromFirestore(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>;
//     return MenuItem(
//       id: doc.id,
//       name: data['name'] ?? '',
//       description: data['description'] ?? '',
//       price: (data['price'] as num?)?.toDouble() ?? 0.0,
//       imageUrl: data['imageUrl'] ?? '',
//       categoryId: data['categoryId'] ?? '',
//       branchId: data['branchId'] ?? '',
//       isAvailable: data['isAvailable'] ?? false,
//       isPopular: data['isPopular'] ?? false,
//       sortOrder: data['sortOrder'] ?? 0,
//       tags: Map<String, dynamic>.from(data['tags'] ?? {}),
//       variants: Map<String, dynamic>.from(data['variants'] ?? {}),
//     );
//   }
// }
//
// class DineInScreen extends StatefulWidget {
//   const DineInScreen({Key? key}) : super(key: key);
//
//   @override
//   State<DineInScreen> createState() => _DineInScreenState();
// }
//
// class _DineInScreenState extends State<DineInScreen> {
//   final RestaurantService _restaurantService = RestaurantService();
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
// // Assuming a fixed branch ID for simplicity, or it could be passed dynamically
//   final String _currentBranchId = 'Old_Airport';
//   String _estimatedTime = 'Loading...'; // For general order preparation time
//
//   int _selectedCategoryIndex = 0;
//   List<MenuCategory> _categories = [];
//   bool _isLoading = true;
//   String? _errorMessage;
//   final DineInCartService _dineInCartService = DineInCartService();
//
//   @override
//   void initState() {
//     super.initState();
//     _loadCategories();
//     _loadEstimatedTime();
//     _dineInCartService.loadCartFromPrefs(); // Load cart on init
//   }
//
//   /// Loads the estimated preparation time for dine-in orders from Firestore.
//   Future<void> _loadEstimatedTime() async {
//     try {
//       final time = await _restaurantService.getEstimatedTime(_currentBranchId);
//       if (mounted) {
//         setState(() => _estimatedTime = time);
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => _estimatedTime = '25-30 min'); // Fallback time
//       }
//     }
//   }
//
//   /// Loads menu categories from Firestore for the current branch.
//   Future<void> _loadCategories() async {
//     try {
//       setState(() {
//         _isLoading = true;
//         _errorMessage = null;
//       });
//
//       final querySnapshot = await _firestore
//           .collection('menu_categories')
//           .where('branchId', isEqualTo: _currentBranchId)
//           .where('isActive', isEqualTo: true)
//           .orderBy('sortOrder')
//           .get();
//
//       if (mounted) {
//         setState(() {
//           _categories = querySnapshot.docs
//               .map((doc) => MenuCategory.fromFirestore(doc))
//               .toList();
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _errorMessage = 'Failed to load categories. Please try again.';
//           _isLoading = false;
//         });
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       // AppBar
//       appBar: AppBar(
//         title: const Text('Dine In',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         centerTitle: true,
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         flexibleSpace: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Color(0xFF3383FF), Color(0xFF00B4DB)],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//       ),
//       body: Stack(
//         children: [
// // Main Content
//           Column(
//             children: [
// // Preparation Time & Category Chips
//               Container(
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.05),
//                       blurRadius: 8,
//                       offset: const Offset(0, 2),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 8),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const Icon(Icons.access_time, size: 18),
//                           const SizedBox(width: 8),
//                           Text(
//                             'Order ready in $_estimatedTime', // General time for dine-in
//                             style: const TextStyle(fontWeight: FontWeight.w500),
//                           ),
//                         ],
//                       ),
//                     ),
//                     SizedBox(
//                       height: 60,
//                       child: ListView.builder(
//                         scrollDirection: Axis.horizontal,
//                         padding: const EdgeInsets.symmetric(horizontal: 16),
//                         itemCount: _categories.length,
//                         itemBuilder: (context, index) {
//                           final category = _categories[index];
//                           return Padding(
//                             padding: const EdgeInsets.all(8.0),
//                             child: ChoiceChip(
//                               label: Text(category.name),
//                               selected: _selectedCategoryIndex == index,
//                               shape: StadiumBorder(
//                                 side: BorderSide(
//                                   color: _selectedCategoryIndex == index
//                                       ? Colors.transparent
//                                       : Colors.grey.shade300,
//                                 ),
//                               ),
//                               elevation: 2,
//                               pressElevation: 4,
//                               selectedColor: const Color(0xFF3383FF),
//                               backgroundColor: Colors.white,
//                               labelStyle: TextStyle(
//                                 color: _selectedCategoryIndex == index
//                                     ? Colors.white
//                                     : Colors.black87,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                               avatar: category.imageUrl.isNotEmpty
//                                   ? CircleAvatar(backgroundImage: NetworkImage(category.imageUrl))
//                                   : null,
//                               onSelected: (_) => setState(() => _selectedCategoryIndex = index),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
// // Menu Items Grid
//               Expanded(
//                 child: _isLoading
//                     ? const Center(child: CircularProgressIndicator())
//                     : _errorMessage != null
//                         ? Center(child: Text(_errorMessage!))
//                         : _categories.isEmpty
//                             ? const Center(
//                                 child: Text('No categories available'))
//                             : _buildMenuGrid(),
//               ),
//             ],
//           ),
//
// // Persistent Cart Bar - Positioned at the bottom
//           Positioned(
//             bottom: 16,
//             left: 16,
//             right: 16,
//             child: ListenableBuilder(
//               listenable: _dineInCartService,
//               builder: (context, child) {
//                 return _dineInCartService.items.isEmpty
//                     ? const SizedBox.shrink()
//                     : _buildDineInCartBar();
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   /// Builds the grid view for menu items based on the selected category.
//   Widget _buildMenuGrid() {
//     if (_categories.isEmpty) {
//       return const Center(child: Text('No categories available.'));
//     }
//
//     return StreamBuilder<QuerySnapshot>(
//       stream: _firestore
//           .collection('menu_items')
//           .where('branchId', isEqualTo: _currentBranchId)
//           .where('categoryId',
//               isEqualTo: _categories[_selectedCategoryIndex].id)
//           .where('isAvailable', isEqualTo: true)
//           .orderBy('sortOrder')
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const Center(child: CircularProgressIndicator());
//         }
//
//         if (snapshot.hasError) {
//           return const Center(child: Text('Error loading menu items'));
//         }
//
//         final items = snapshot.data!.docs
//             .map((doc) => MenuItem.fromFirestore(doc))
//             .toList();
//
//         if (items.isEmpty) {
//           return const Center(child: Text('No items in this category'));
//         }
//
//         return GridView.builder(
//           padding: const EdgeInsets.all(16),
//           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: 2,
//             childAspectRatio: 0.75, // Adjust as needed for better card sizing
//             crossAxisSpacing: 16,
//             mainAxisSpacing: 16,
//           ),
//           itemCount: items.length,
//           itemBuilder: (context, index) => _buildMenuItemCard(items[index]),
//         );
//       },
//     );
//   }
//
//   /// Builds an individual menu item card.
//   Widget _buildMenuItemCard(MenuItem item) {
//     return ListenableBuilder(
//       listenable: _dineInCartService,
//       builder: (context, child) {
//         final cartItem = _dineInCartService.items.firstWhere(
//           (cartItem) => cartItem.id == item.id,
//           orElse: () => CartModel(
//             id: '',
//             name: '',
//             imageUrl: '',
//             price: 0,
//             quantity: 0,
//           ), // Return empty CartModel if not found
//         );
//         final quantity = cartItem.id == item.id ? cartItem.quantity : 0;
//
//         return Card(
//           elevation: 2,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: InkWell(
//             borderRadius: BorderRadius.circular(12),
//             onTap: () => _showItemDetails(item),
//             child: Stack(
//               children: [
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
// // Food Image
//                     Expanded(
//                       child: ClipRRect(
//                         borderRadius: const BorderRadius.vertical(
//                             top: Radius.circular(12)),
//                         child: CachedNetworkImage(
//                           imageUrl: item.imageUrl,
//                           fit: BoxFit.cover,
//                           placeholder: (context, url) => Container(
//                             color: Colors.grey[200],
//                             child: const Center(
//                               child: CircularProgressIndicator(),
//                             ),
//                           ),
//                           errorWidget: (context, url, error) => Container(
//                             color: Colors.grey[200],
//                             child:
//                                 const Icon(Icons.fastfood, color: Colors.grey),
//                           ),
//                         ),
//                       ),
//                     ),
//
// // Food Details
//                     // ─── Food Details ─────────────────────────────────────────
//                     Padding(
//                       padding: const EdgeInsets.all(12),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           // item name
//                           Text(
//                             item.name,
//                             style: const TextStyle(
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                           const SizedBox(height: 4),
//
//                           // price  + optional spicy tag
//                           Row(
//                             children: [
//                               Text(
//                                 'QAR ${item.price.toStringAsFixed(2)}',
//                                 style: TextStyle(
//                                   color: AppColors.primaryBlue,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//
//                               // show “Spicy” only when tagged
//                               if (item.tags['isSpicy'] == true) ...[
//                                 const SizedBox(width: 8),
//                                 Container(
//                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                                   decoration: BoxDecoration(
//                                     color: Colors.red[50],
//                                     borderRadius: BorderRadius.circular(12),
//                                     border: Border.all(color: Colors.red),
//                                   ),
//                                   child: Row(
//                                     mainAxisSize: MainAxisSize.min,
//                                     children: [
//                                       const Icon(Icons.local_fire_department,
//                                           size: 14, color: Colors.red),
//                                       const SizedBox(width: 4),
//                                       Text(
//                                         'Spicy',
//                                         style: TextStyle(
//                                           color: Colors.red[700],
//                                           fontSize: 12,
//                                           fontWeight: FontWeight.bold,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ],
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//
//                   ],
//                 ),
// // Quantity Indicator/Add Button
//                 Positioned(
//                   top: 8,
//                   right: 8,
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(14),
//                     child: BackdropFilter(                       // ← blur background
//                       filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
//                       child: Container(
//                         width: 96,                               // overall size
//                         height: 28,
//                         decoration: BoxDecoration(
//                           color: Colors.blue.withOpacity(0.30),  // frosted tint
//                           borderRadius: BorderRadius.circular(14),
//                           boxShadow: [
//                             BoxShadow(                           // subtle lift
//                               color: Colors.blue.withOpacity(0.15),
//                               blurRadius: 8,
//                               offset: const Offset(0, 2),
//                             ),
//                           ],
//                         ),
//                         // ─── Display buttons or “add” icon ────────────────
//                         child: quantity == 0
//                             ? IconButton(
//                           padding: EdgeInsets.zero,
//                           icon: Icon(Icons.add_circle,
//                               color: Colors.blue.shade700, size: 24),
//                           onPressed: () =>
//                               _dineInCartService.addToCart(item),
//                         )
//                             : Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                           children: [
//                             // minus
//                             SizedBox(
//                               width: 24,
//                               height: 24,
//                               child: IconButton(
//                                 padding: EdgeInsets.zero,
//                                 icon: Icon(Icons.remove,
//                                     size: 18, color: Colors.blue.shade700),
//                                 onPressed: () => _dineInCartService
//                                     .updateQuantity(item.id, quantity - 1),
//                               ),
//                             ),
//                             // count
//                             Text(
//                               quantity.toString(),
//                               style: TextStyle(
//                                 color: Colors.blue.shade800,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 14,
//                               ),
//                             ),
//                             // plus
//                             SizedBox(
//                               width: 24,
//                               height: 24,
//                               child: IconButton(
//                                 padding: EdgeInsets.zero,
//                                 icon: Icon(Icons.add,
//                                     size: 18, color: Colors.blue.shade700),
//                                 onPressed: () => _dineInCartService
//                                     .updateQuantity(item.id, quantity + 1),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   /// Builds the persistent cart bar at the bottom of the screen.
//   Widget _buildDineInCartBar() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 10,
//             offset: const Offset(0, -5),
//           ),
//         ],
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       child: Row(
//         children: [
//           Badge(
//             label: Text('${_dineInCartService.itemCount}'),
//             backgroundColor: AppColors.primaryBlue,
//             textColor: Colors.white,
//             child: const Icon(Icons.restaurant_menu, size: 30), // Dine-in icon
//           ),
//           const SizedBox(width: 12),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Dine In Order',
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               Text(
//                 'QAR ${_dineInCartService.totalAmount.toStringAsFixed(2)}',
//                 style: TextStyle(
//                   color: AppColors.primaryBlue,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           const Spacer(),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => DineInCartScreen(
//                     cartService: _dineInCartService,
//                   ),
//                 ),
//               );
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.primaryBlue,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               padding: const EdgeInsets.symmetric(horizontal: 20),
//             ),
//             child: const Text(
//               'View Order',
//               style: TextStyle(color: Colors.white),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   /// Shows a modal bottom sheet with item details.
//   void _showItemDetails(MenuItem item) {
//     final isInCart =
//         _dineInCartService.items.any((cartItem) => cartItem.id == item.id);
//
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) {
//         return SingleChildScrollView(
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min, // Ensure it takes minimum height
//               children: [
//                 Center(
//                   child: Container(
//                     width: 60,
//                     height: 4,
//                     margin: const EdgeInsets.only(bottom: 16),
//                     decoration: BoxDecoration(
//                       color: Colors.grey[300],
//                       borderRadius: BorderRadius.circular(2),
//                     ),
//                   ),
//                 ),
//                 ClipRRect(
//                   borderRadius: BorderRadius.circular(12),
//                   child: CachedNetworkImage(
//                     imageUrl: item.imageUrl,
//                     height: 200,
//                     width: double.infinity,
//                     fit: BoxFit.cover,
//                     placeholder: (context, url) => Container(
//                       color: Colors.grey[200],
//                       child: const Center(child: CircularProgressIndicator()),
//                     ),
//                     errorWidget: (context, url, error) => Container(
//                       color: Colors.grey[200],
//                       child: const Icon(Icons.fastfood, color: Colors.grey),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         item.name,
//                         style: const TextStyle(
//                           fontSize: 22,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                     if (item.tags['isSpicy'] == true)
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 8, vertical: 4),
//                         decoration: BoxDecoration(
//                           color: Colors.red[50],
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: Colors.red),
//                         ),
//                         child: Row(
//                           children: [
//                             const Icon(Icons.local_fire_department,
//                                 size: 16, color: Colors.red),
//                             const SizedBox(width: 4),
//                             Text(
//                               'Spicy',
//                               style: TextStyle(
//                                 color: Colors.red[700],
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   'QAR ${item.price.toStringAsFixed(2)}',
//                   style: TextStyle(
//                     fontSize: 18,
//                     color: AppColors.primaryBlue,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Text(
//                   'Description',
//                   style: TextStyle(
//                     color: Colors.grey[700],
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   item.description,
//                   style: const TextStyle(fontSize: 16),
//                 ),
//                 const SizedBox(height: 24),
//                 SizedBox(
//                   width: double.infinity,
//                   height: 50,
//                   child: ElevatedButton(
//                     onPressed: () {
//                       if (isInCart) {
//                         _dineInCartService.removeFromCart(item.id);
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(
//                             content: Text('Removed ${item.name} from order'),
//                           ),
//                         );
//                       } else {
//                         _dineInCartService.addToCart(item);
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(
//                             content: Text('Added ${item.name} to order'),
//                           ),
//                         );
//                       }
//                       Navigator.pop(context);
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor:
//                           isInCart ? Colors.red : AppColors.primaryBlue,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                     child: Text(
//                       isInCart ? 'Remove from Order' : 'Add to Dine In Order',
//                       style: const TextStyle(fontSize: 16, color: Colors.white),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
//
// class DineInCartService extends ChangeNotifier {
//   final List<CartModel> _items = [];
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   CouponModel? _appliedCoupon;
//   double _couponDiscount = 0;
//   final String _currentBranchId = 'Old_Airport';
//   static const String _prefsKey = 'dinein_cart_items';
//
//   List<CartModel> get items => _items;
//   int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
//   double get totalAmount =>
//       _items.fold(0, (sum, item) => sum + item.totalPrice);
//   double get totalAfterDiscount =>
//       (totalAmount - _couponDiscount).clamp(0, double.infinity);
//   CouponModel? get appliedCoupon => _appliedCoupon;
//   double get couponDiscount => _couponDiscount;
//
//   Future<void> loadCartFromPrefs() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final cartJson = prefs.getString(_prefsKey);
//
//       if (cartJson != null) {
//         final Map<String, dynamic> cartData = json.decode(cartJson);
//
// // Load items
//         _items.clear();
//         if (cartData['items'] != null) {
//           _items.addAll((cartData['items'] as List)
//               .map((item) => CartModel.fromMap(item)));
//         }
//
// // Load coupon
//         if (cartData['coupon'] != null) {
//           _appliedCoupon = CouponModel.fromMap(
//               cartData['coupon'], cartData['coupon']['id'] ?? '');
//           _couponDiscount = cartData['couponDiscount']?.toDouble() ?? 0;
//         }
//
//         notifyListeners();
//       }
//     } catch (e) {
//       debugPrint('Error loading dine-in cart from SharedPreferences: $e');
//     }
//   }
//
//   Future<void> _saveCartToPrefs() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final cartJson = json.encode({
//         'items': _items.map((item) => item.toMap()).toList(),
//         'coupon': _appliedCoupon?.toMap(),
//         'couponDiscount': _couponDiscount,
//       });
//       await prefs.setString(_prefsKey, cartJson);
//     } catch (e) {
//       debugPrint('Error saving dine-in cart to SharedPreferences: $e');
//     }
//   }
//
//   Future<void> addToCart(
//     MenuItem menuItem, {
//     int quantity = 1,
//     Map<String, dynamic>? variants,
//     List<String>? addons,
//   }) async {
//     final existingIndex = _items.indexWhere((item) => item.id == menuItem.id);
//
//     if (existingIndex >= 0) {
//       _items[existingIndex].quantity += quantity;
//     } else {
//       _items.add(CartModel(
//         id: menuItem.id,
//         name: menuItem.name,
//         imageUrl: menuItem.imageUrl,
//         price: menuItem.price,
//         quantity: quantity,
//         variants: variants ?? {},
//         addons: addons,
//       ));
//     }
//
//     notifyListeners();
//     await _saveCartToPrefs();
//   }
//
//   Future<void> removeFromCart(String itemId) async {
//     _items.removeWhere((item) => item.id == itemId);
//     notifyListeners();
//     await _saveCartToPrefs();
//   }
//
//   Future<void> updateQuantity(String itemId, int newQuantity) async {
//     final index = _items.indexWhere((item) => item.id == itemId);
//     if (index >= 0) {
//       if (newQuantity > 0) {
//         _items[index].quantity = newQuantity;
//       } else {
//         _items.removeAt(index);
//       }
//     }
//     notifyListeners();
//     await _saveCartToPrefs();
//   }
//
//   Future<void> clearCart() async {
//     _items.clear();
//     _appliedCoupon = null;
//     _couponDiscount = 0;
//     notifyListeners();
//     await _saveCartToPrefs();
//   }
//
//   Future<void> applyCoupon(String couponCode) async {
//     try {
//       final user = _auth.currentUser;
//       final userId = user?.email;
//
//       final snapshot = await FirebaseFirestore.instance
//           .collection('coupons')
//           .where('code', isEqualTo: couponCode)
//           .limit(1)
//           .get();
//
//       if (snapshot.docs.isEmpty) throw Exception('Coupon not found');
//
//       final couponDoc = snapshot.docs.first;
//       final coupon = CouponModel.fromMap(couponDoc.data(), couponDoc.id);
//
//       if (!coupon.isValidForUser(userId, _currentBranchId, 'dine_in')) {
//         throw Exception('Coupon not valid for this order');
//       }
//
//       if (totalAmount < coupon.minSubtotal) {
//         throw Exception(
//             'Minimum order amount of QAR ${coupon.minSubtotal} not met');
//       }
//
//       if (coupon.maxUsesPerUser > 0 && userId != null) {
//         final userUsage = await FirebaseFirestore.instance
//             .collection('coupon_usage')
//             .where('userId', isEqualTo: userId)
//             .where('couponId', isEqualTo: coupon.id)
//             .get();
//
//         if (userUsage.docs.length >= coupon.maxUsesPerUser) {
//           throw Exception(
//               'You have already used this coupon the maximum number of times');
//         }
//       }
//
//       double discount = 0;
//       if (coupon.type == 'percentage') {
//         discount = totalAmount * (coupon.value / 100);
//         if (coupon.maxDiscount > 0 && discount > coupon.maxDiscount) {
//           discount = coupon.maxDiscount;
//         }
//       } else {
//         discount = coupon.value;
//       }
//
//       final totalBeforeDiscount = totalAmount;
//       for (var item in _items) {
//         final itemPercentage =
//             (item.price * item.quantity) / totalBeforeDiscount;
//         item.couponDiscount = discount * itemPercentage;
//         item.couponCode = coupon.code;
//         item.couponId = coupon.id;
//       }
//
//       _appliedCoupon = coupon;
//       _couponDiscount = discount;
//       notifyListeners();
//       await _saveCartToPrefs();
//     } catch (e) {
//       rethrow;
//     }
//   }
//
//   Future<void> removeCoupon() async {
//     for (var item in _items) {
//       item.couponDiscount = null;
//       item.couponCode = null;
//       item.couponId = null;
//     }
//
//     _appliedCoupon = null;
//     _couponDiscount = 0;
//     notifyListeners();
//     await _saveCartToPrefs();
//   }
//
//   Future<bool> validateCouponAtCheckout() async {
//     if (_appliedCoupon == null) return true;
//
//     try {
//       await applyCoupon(_appliedCoupon!.code);
//       return true;
//     } catch (e) {
//       await removeCoupon();
//       return false;
//     }
//   }
// }
//
// class DineInCartScreen extends StatefulWidget {
//   final DineInCartService cartService;
//   const DineInCartScreen({Key? key, required this.cartService}) : super(key: key);
//
//   @override
//   State<DineInCartScreen> createState() => _DineInCartScreenState();
// }
//
// class _DineInCartScreenState extends State<DineInCartScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final RestaurantService _restaurantService = RestaurantService();
//   String _estimatedTime = 'Loading...';
//   final String _currentBranchId = 'Old_Airport';
//   bool _isCheckingOut = false;
//   final TextEditingController _notesController = TextEditingController();
//   final TextEditingController _couponController = TextEditingController();
//
//   int? _selectedGuests;
//   int? _selectedNumberOfTables;
//   TimeOfDay? _selectedTime;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadEstimatedTime();
//   }
//
//   @override
//   void dispose() {
//     _notesController.dispose();
//     _couponController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _loadEstimatedTime() async {
//     final time = await _restaurantService.getEstimatedTime(_currentBranchId);
//     if (mounted) setState(() => _estimatedTime = time);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return ListenableBuilder(
//       listenable: widget.cartService,
//       builder: (context, child) {
//         return Scaffold(
//           backgroundColor: AppColors.lightGrey,
//           appBar: AppBar(
//             title: const Text('Your Dine In Order', style: TextStyle(color: AppColors.darkGrey, fontWeight: FontWeight.bold)),
//             backgroundColor: AppColors.white,
//             elevation: 0,
//             centerTitle: true,
//             leading: IconButton(
//               icon: const Icon(Icons.arrow_back_ios, color: AppColors.darkGrey),
//               onPressed: () => Navigator.pop(context),
//             ),
//             actions: [
//               if (widget.cartService.items.isNotEmpty)
//                 IconButton(
//                   icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
//                   onPressed: _showClearCartDialog,
//                 ),
//             ],
//           ),
//           body: Stack(
//             children: [
//               _buildBody(),
//               if (widget.cartService.items.isNotEmpty)
//                 Align(
//                   alignment: Alignment.bottomCenter,
//                   child: _buildCheckoutBar(),
//                 ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildBody() {
//     if (widget.cartService.items.isEmpty) return _buildEmptyCartView();
//
//     return Form(
//       key: _formKey,
//       child: ListView(
//         padding: const EdgeInsets.only(bottom: 280), // Space for checkout bar
//         children: [
//           _buildDineInDetailsSection(),
//           const SizedBox(height: 16),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16.0),
//             child: Text("Your Items", style: AppTextStyles.headline2.copyWith(color: AppColors.darkGrey)),
//           ),
//           const SizedBox(height: 8),
//           ListView.separated(
//             physics: const NeverScrollableScrollPhysics(),
//             shrinkWrap: true,
//             itemCount: widget.cartService.items.length,
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             separatorBuilder: (context, index) => const SizedBox(height: 12),
//             itemBuilder: (context, index) => _buildCartItem(widget.cartService.items[index]),
//           ),
//           const SizedBox(height: 16),
//           _buildNotesSection(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildEmptyCartView() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 40),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.restaurant_menu, size: 120, color: AppColors.primaryBlue.withOpacity(0.15)),
//             const SizedBox(height: 24),
//             Text('Your Order is Empty', style: AppTextStyles.headline1.copyWith(color: AppColors.darkGrey, fontSize: 24)),
//             const SizedBox(height: 12),
//             Text('Browse the menu and add some delicious items to your dine-in order.', textAlign: TextAlign.center, style: AppTextStyles.bodyText1.copyWith(color: Colors.grey.shade600)),
//             const SizedBox(height: 32),
//             ElevatedButton.icon(
//               onPressed: () => Navigator.of(context).pop(),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: AppColors.primaryBlue,
//                 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               ),
//               icon: const Icon(Icons.menu_book, color: AppColors.white),
//               label: Text('Back to Menu', style: AppTextStyles.buttonText.copyWith(color: AppColors.white, fontSize: 16)),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildCartItem(CartModel item) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: AppColors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 4))],
//       ),
//       child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
//         ClipRRect(
//           borderRadius: BorderRadius.circular(12),
//           child: CachedNetworkImage(
//             imageUrl: item.imageUrl,
//             width: 70,
//             height: 70,
//             fit: BoxFit.cover,
//             placeholder: (context, url) => Container(color: Colors.grey.shade100),
//             errorWidget: (context, url, error) => Container(color: Colors.grey.shade100, child: Icon(Icons.fastfood_outlined, color: Colors.grey.shade400)),
//           ),
//         ),
//         const SizedBox(width: 16),
//         Expanded(
//           child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//             Text(item.name, style: AppTextStyles.bodyText1.copyWith(fontWeight: FontWeight.bold, color: AppColors.darkGrey), maxLines: 2, overflow: TextOverflow.ellipsis),
//             const SizedBox(height: 8),
//             Text('QAR ${item.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
//           ]),
//         ),
//         Container(
//           decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(30)),
//           child: Row(children: [
//             InkWell(
//               onTap: () => widget.cartService.updateQuantity(item.id, item.quantity - 1),
//               borderRadius: BorderRadius.circular(20),
//               child: Padding(padding: const EdgeInsets.all(6.0), child: Icon(Icons.remove, size: 20, color: AppColors.primaryBlue)),
//             ),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 8.0),
//               child: Text(item.quantity.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkGrey)),
//             ),
//             InkWell(
//               onTap: () => widget.cartService.updateQuantity(item.id, item.quantity + 1),
//               borderRadius: BorderRadius.circular(20),
//               child: const Padding(padding: const EdgeInsets.all(6.0), child: Icon(Icons.add, size: 20, color: AppColors.primaryBlue)),
//             ),
//           ]),
//         ),
//       ]),
//     );
//   }
//
//   Widget _buildDineInDetailsSection() {
//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text('Dine-In Details', style: AppTextStyles.headline2.copyWith(color: AppColors.darkGrey)),
//           const SizedBox(height: 16),
//           _buildDetailRow(
//             icon: Icons.people_outline,
//             label: 'Number of Guests',
//             value: _selectedGuests != null ? '$_selectedGuests Guests' : 'Select',
//             onTap: () async {
//               final picked = await _showBottomSheetPicker(options: List.generate(10, (i) => i + 1), title: 'Number of Guests', label: (g) => '$g Guests');
//               if (picked != null) setState(() => _selectedGuests = picked);
//             },
//           ),
//           const Divider(height: 24),
//           _buildDetailRow(
//             icon: Icons.table_bar_outlined,
//             label: 'Number of Tables',
//             value: _selectedNumberOfTables != null ? '$_selectedNumberOfTables Tables' : 'Select',
//             onTap: () async {
//               final picked = await _showBottomSheetPicker(options: List.generate(5, (i) => i + 1), title: 'Number of Tables', label: (t) => '$t Tables');
//               if (picked != null) setState(() => _selectedNumberOfTables = picked);
//             },
//           ),
//           const Divider(height: 24),
//           _buildDetailRow(
//             icon: Icons.access_time_outlined,
//             label: 'Arrival Time',
//             value: _selectedTime != null ? _selectedTime!.format(context) : 'Select',
//             onTap: _selectTime,
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDetailRow({required IconData icon, required String label, required String value, required VoidCallback onTap}) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(8),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 8.0),
//         child: Row(
//           children: [
//             Icon(icon, color: AppColors.primaryBlue, size: 28),
//             const SizedBox(width: 16),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(label, style: AppTextStyles.bodyText2.copyWith(color: Colors.grey.shade600)),
//                   const SizedBox(height: 4),
//                   Text(value, style: AppTextStyles.bodyText1.copyWith(fontWeight: FontWeight.w600)),
//                 ],
//               ),
//             ),
//             const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.darkGrey),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<T?> _showBottomSheetPicker<T>({required List<T> options, required String title, required String Function(T) label}) {
//     return showModalBottomSheet<T>(
//       context: context,
//       backgroundColor: Colors.white,
//       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
//       builder: (_) => Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const SizedBox(height: 12),
//           Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
//           Padding(
//             padding: const EdgeInsets.symmetric(vertical: 20),
//             child: Text(title, style: AppTextStyles.headline2.copyWith(fontSize: 20)),
//           ),
//           const Divider(height: 1),
//           Flexible(
//             child: ListView.separated(
//               shrinkWrap: true,
//               itemCount: options.length,
//               separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
//               itemBuilder: (_, i) => ListTile(
//                 title: Center(child: Text(label(options[i]), style: AppTextStyles.bodyText1)),
//                 onTap: () => Navigator.pop(context, options[i]),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future<void> _selectTime() async {
//     final picked = await showTimePicker(
//       context: context,
//       initialTime: _selectedTime ?? TimeOfDay.now(),
//       builder: (context, child) => Theme(
//         data: ThemeData.light().copyWith(
//           colorScheme: const ColorScheme.light(primary: AppColors.primaryBlue),
//           buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
//         ),
//         child: child!,
//       ),
//     );
//     if (picked != null) {
//       HapticFeedback.mediumImpact();
//       setState(() => _selectedTime = picked);
//     }
//   }
//
//   Widget _buildNotesSection() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text('Special Instructions', style: AppTextStyles.headline2.copyWith(fontSize: 18, color: AppColors.darkGrey)),
//           const SizedBox(height: 12),
//           TextField(
//             controller: _notesController,
//             maxLines: 3,
//             decoration: InputDecoration(
//               hintText: 'e.g. "No onions", "Allergy: peanuts"...',
//               hintStyle: AppTextStyles.bodyText2,
//               filled: true,
//               fillColor: AppColors.white,
//               border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
//               enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
//               focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
//               contentPadding: const EdgeInsets.all(16),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildCheckoutBar() {
//     final double subtotal = widget.cartService.totalAmount;
//     final double tax = subtotal * 0.10;
//     final double total = subtotal + tax - widget.cartService.couponDiscount;
//
//     return ClipRRect(
//       child: BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
//         child: Container(
//           padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
//           decoration: BoxDecoration(color: AppColors.white.withOpacity(0.8), border: Border(top: BorderSide(color: Colors.grey.shade200))),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               _buildBillRow('Subtotal', subtotal),
//               _buildBillRow('Tax (10%)', tax),
//               if (widget.cartService.couponDiscount > 0) _buildBillRow('Coupon Discount', -widget.cartService.couponDiscount, isDiscount: true),
//               const Divider(height: 24, thickness: 0.5),
//               _buildBillRow('Total Amount', total, isTotal: true),
//               const SizedBox(height: 16),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: _isCheckingOut ? null : _proceedToCheckout,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.primaryBlue,
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                   ),
//                   child: _isCheckingOut
//                       ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
//                       : Text('PLACE DINE-IN ORDER', style: AppTextStyles.buttonText.copyWith(color: AppColors.white)),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildBillRow(String label, double amount, {bool isTotal = false, bool isDiscount = false}) {
//     final style = AppTextStyles.bodyText1.copyWith(
//         color: isDiscount ? Colors.green.shade700 : (isTotal ? AppColors.darkGrey : Colors.grey.shade600),
//         fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
//         fontSize: isTotal ? 18 : 16);
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label, style: style),
//           Text(isDiscount ? '- QAR ${amount.abs().toStringAsFixed(2)}' : 'QAR ${amount.toStringAsFixed(2)}', style: style.copyWith(fontWeight: isTotal ? FontWeight.bold : FontWeight.w600)),
//         ],
//       ),
//     );
//   }
//
//   void _showClearCartDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.white,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: Text('Clear Order?', style: AppTextStyles.headline2),
//         content: Text('This will remove all items from your dine-in order.', style: AppTextStyles.bodyText1),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: AppTextStyles.bodyText1.copyWith(color: AppColors.darkGrey))),
//           TextButton(
//             onPressed: () {
//               widget.cartService.clearCart();
//               Navigator.pop(context);
//             },
//             child: Text('Clear', style: AppTextStyles.bodyText1.copyWith(color: Colors.red, fontWeight: FontWeight.bold)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future<void> _proceedToCheckout() async {
//     if (!_formKey.currentState!.validate()) {
//       if (_selectedGuests == null) {
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select the number of guests')));
//         return;
//       }
//       if (_selectedNumberOfTables == null) {
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select the number of tables')));
//         return;
//       }
//       if (_selectedTime == null) {
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an arrival time')));
//         return;
//       }
//     }
//
//     setState(() => _isCheckingOut = true);
//
//     try {
//       final isCouponValid = await widget.cartService.validateCouponAtCheckout();
//       if (!isCouponValid && mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your coupon is no longer valid and has been removed')));
//       }
//
//       final user = FirebaseAuth.instance.currentUser;
//       if (user == null) throw Exception("User not authenticated.");
//
//       final orderDoc = FirebaseFirestore.instance.collection('Orders').doc();
//       final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//       final counterRef = FirebaseFirestore.instance.collection('daily_counters').doc(today);
//
//       await FirebaseFirestore.instance.runTransaction((transaction) async {
//         final counterSnap = await transaction.get(counterRef);
//         final dailyCount = (counterSnap.exists ? (counterSnap.get('count') as int) : 0) + 1;
//         final orderId = 'DI-$today-${dailyCount.toString().padLeft(3, '0')}';
//
//         if (counterSnap.exists) {
//           transaction.update(counterRef, {'count': dailyCount});
//         } else {
//           transaction.set(counterRef, {'count': 1});
//         }
//
//         final now = DateTime.now();
//         final orderData = {
//           'orderId': orderId,
//           'dailyOrderNumber': dailyCount,
//           'date': today,
//           'customerId': user.email,
//           'items': widget.cartService.items.map((item) => item.toMap()).toList(),
//           'notes': _notesController.text.trim(),
//           'status': 'pending',
//           'subtotal': widget.cartService.totalAmount,
//           'tax': widget.cartService.totalAmount * 0.10,
//           'totalAmount': widget.cartService.totalAfterDiscount,
//           'timestamp': FieldValue.serverTimestamp(),
//           'Order_type': 'dine_in',
//           'numberOfGuests': _selectedGuests,
//           'numberOfTables': _selectedNumberOfTables,
//           'orderTime': Timestamp.fromDate(DateTime(now.year, now.month, now.day, _selectedTime!.hour, _selectedTime!.minute)),
//           'branchId': _currentBranchId,
//           if (widget.cartService.appliedCoupon != null) 'couponCode': widget.cartService.appliedCoupon!.code,
//           if (widget.cartService.couponDiscount > 0) 'couponDiscount': widget.cartService.couponDiscount,
//           if (widget.cartService.appliedCoupon != null) 'couponId': widget.cartService.appliedCoupon!.id,
//         };
//         transaction.set(orderDoc, orderData);
//       });
//
//       widget.cartService.clearCart();
//       if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
//
//     } catch (e) {
//       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to place order: $e')));
//     } finally {
//       if (mounted) setState(() => _isCheckingOut = false);
//     }
//   }
// }
//
// class DineInCouponsScreen extends StatefulWidget {
//   final DineInCartService cartService;
//
//   const DineInCouponsScreen({Key? key, required this.cartService})
//       : super(key: key);
//
//   @override
//   _DineInCouponsScreenState createState() => _DineInCouponsScreenState();
// }
//
// class _DineInCouponsScreenState extends State<DineInCouponsScreen> {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final String _currentBranchId = 'Old_Airport';
//   List<CouponModel> _availableCoupons = [];
//   bool _isLoading = true;
//   String? _error;
//   CouponModel? _selectedCoupon;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadAvailableCoupons();
//   }
//
//   Future<void> _loadAvailableCoupons() async {
//     try {
//       final user = _auth.currentUser;
//       final userId = user?.email;
//
//       final snapshot = await FirebaseFirestore.instance
//           .collection('coupons')
//           .where('active', isEqualTo: true)
//           .get();
//
//       final now = DateTime.now();
//       final coupons = snapshot.docs.map((doc) {
//         return CouponModel.fromMap(doc.data(), doc.id);
//       }).where((coupon) {
//         return coupon.validFrom.isBefore(now) &&
//             coupon.validUntil.isAfter(now) &&
//             (coupon.allowedUsers.isEmpty ||
//                 (userId != null && coupon.allowedUsers.contains(userId)));
//       }).toList();
//
//       setState(() {
//         _availableCoupons = coupons;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _error = 'Failed to load coupons';
//         _isLoading = false;
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F5F5),
//       appBar: AppBar(
//         title: const Text('Available Coupons'),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//         centerTitle: false,
//         backgroundColor: AppColors.primaryBlue,
//         foregroundColor: Colors.white,
//       ),
//       body: _buildBody(),
//     );
//   }
//
//   Widget _buildBody() {
//     if (_isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }
//
//     if (_error != null) {
//       return Center(child: Text(_error!));
//     }
//
//     if (_availableCoupons.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.discount, size: 60, color: Colors.grey[400]),
//             const SizedBox(height: 16),
//             const Text(
//               'No coupons available',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),
//             const Text(
//               'Check back later for exciting offers!',
//               style: TextStyle(color: Colors.grey),
//             ),
//           ],
//         ),
//       );
//     }
//
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Available Coupons',
//             style: TextStyle(
//               fontSize: 22,
//               fontWeight: FontWeight.bold,
//               color: Colors.black,
//             ),
//           ),
//           const SizedBox(height: 16),
//           ..._availableCoupons.map((coupon) {
//             final isValid = _isCouponValidForCart(coupon);
//             return Padding(
//               padding: const EdgeInsets.only(bottom: 16),
//               child: _buildOfferCard(coupon, isValid),
//             );
//           }),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildOfferCard(CouponModel coupon, bool isValid) {
//     final discountText = coupon.type == 'percentage'
//         ? '${coupon.value.toStringAsFixed(0)}% off'
//         : 'Get ${coupon.value} QAR Off';
//     final minSubtotalText = coupon.minSubtotal > 0
//         ? 'on order above ${coupon.minSubtotal} QAR'
//         : 'on all orders';
//     final validityText =
//         'Valid until ${DateFormat('MMM dd, yyyy').format(coupon.validUntil)}';
//
//     return Stack(
//       children: [
//         Container(
//           margin: const EdgeInsets.symmetric(vertical: 12),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: const [
//               BoxShadow(
//                 color: Color(0x1A000000),
//                 blurRadius: 6,
//                 offset: Offset(0, 3),
//               ),
//             ],
//           ),
//           child: Stack(
//             children: [
//               ClipPath(
//                 clipper: CouponClipper(),
//                 child: Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       _buildFakeDottedBorder(coupon.code),
//                       const SizedBox(height: 8),
//                       Text(
//                         coupon.code,
//                         style: const TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.w800,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         '$discountText $minSubtotalText',
//                         style: const TextStyle(
//                           fontSize: 14,
//                           color: Colors.black87,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       const Divider(height: 24, color: Color(0xFFE0E0E0)),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.end,
//                         children: [
//                           ElevatedButton(
//                             onPressed:
//                                 isValid ? () => _applyCoupon(coupon) : null,
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor:
//                                   isValid ? AppColors.primaryBlue : Colors.grey,
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                             ),
//                             child: const Text(
//                               'APPLY',
//                               style: TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.white),
//                             ),
//                           )
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               Positioned(
//                 top: 12,
//                 right: 12,
//                 child: Row(
//                   children: List.generate(3, (index) {
//                     return Container(
//                       width: 8,
//                       height: 8,
//                       margin: const EdgeInsets.only(left: 4),
//                       decoration: BoxDecoration(
//                         color: AppColors.primaryBlue,
//                         borderRadius: BorderRadius.circular(2),
//                       ),
//                     );
//                   }),
//                 ),
//               ),
//               if (!isValid)
//                 Positioned.fill(
//                   child: Container(
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.7),
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     child: Center(
//                       child: Text(
//                         'Not applicable to current order',
//                         style: TextStyle(
//                           color: Colors.grey[700],
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildFakeDottedBorder(String code) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         border: Border.all(color: AppColors.primaryBlue),
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const Text(
//             'CODE: ',
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               fontSize: 12,
//               color: Colors.black54,
//             ),
//           ),
//           Text(
//             code,
//             style: const TextStyle(
//               fontWeight: FontWeight.bold,
//               fontSize: 12,
//               color: AppColors.primaryBlue,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   bool _isCouponValidForCart(CouponModel coupon) {
//     final cartTotal = widget.cartService.totalAmount;
//     if (coupon.minSubtotal > 0 && cartTotal < coupon.minSubtotal) {
//       return false;
//     }
//
// // Additional validation for dine-in specific coupons if needed
//     return coupon.isValidForUser(
//       _auth.currentUser?.email,
//       _currentBranchId,
//       'dine_in',
//     );
//   }
//
//   Future<void> _applyCoupon(CouponModel coupon) async {
//     try {
//       await widget.cartService.applyCoupon(coupon.code);
//       if (mounted) {
//         Navigator.pop(context);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('${coupon.code} applied successfully'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to apply coupon: ${e.toString()}'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }
// }
//
// class CouponClipper extends CustomClipper<Path> {
//   @override
//   Path getClip(Size size) {
//     const notchRadius = 10.0;
//     final path = Path();
//
//     path.moveTo(0, 0);
//     path.lineTo(0, size.height / 2 - notchRadius);
//     path.arcToPoint(
//       Offset(0, size.height / 2 + notchRadius),
//       radius: const Radius.circular(notchRadius),
//       clockwise: false,
//     );
//     path.lineTo(0, size.height);
//     path.lineTo(size.width, size.height);
//     path.lineTo(size.width, size.height / 2 + notchRadius);
//     path.arcToPoint(
//       Offset(size.width, size.height / 2 - notchRadius),
//       radius: const Radius.circular(notchRadius),
//       clockwise: false,
//     );
//     path.lineTo(size.width, 0);
//     path.close();
//
//     return path;
//   }
//
//   @override
//   bool shouldReclip(CustomClipper<Path> oldClipper) => false;
// }
