// import 'dart:convert';
// import 'dart:ui';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:intl/intl.dart';
// import '../Widgets/models.dart';
// import 'DineInScreen.dart';
//
//
// class TakeAwayScreen extends StatefulWidget {
//   const TakeAwayScreen({Key? key}) : super(key: key);
//
//   @override
//   State<TakeAwayScreen> createState() => _TakeAwayScreenState();
// }
//
// class _TakeAwayScreenState extends State<TakeAwayScreen> {
//   final RestaurantService _restaurantService = RestaurantService();
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final String _currentBranchId = 'Old_Airport';
//   String _estimatedTime = '...';
//   int _selectedCategoryIndex = 0;
//   List<MenuCategory> _categories = [];
//   bool _isLoading = true;
//   String? _errorMessage;
//   final TakeAwayCartService _takeAwayCartService = TakeAwayCartService();
//
//   @override
//   void initState() {
//     super.initState();
//     _loadInitialData();
//   }
//
//   Future<void> _loadInitialData() async {
//     // Parallel loading for a faster UI response
//     await Future.wait([
//       _loadCategories(),
//       _loadEstimatedTime(),
//       _takeAwayCartService.loadCartFromPrefs(),
//     ]);
//   }
//
//   Future<void> _loadEstimatedTime() async {
//     try {
//       final time = await _restaurantService.getEstimatedTime(_currentBranchId);
//       if (mounted) setState(() => _estimatedTime = time);
//     } catch (e) {
//       if (mounted) setState(() => _estimatedTime = '25 min');
//     }
//   }
//
//   Future<void> _loadCategories() async {
//     try {
//       if (mounted) {
//         setState(() {
//           _isLoading = true;
//           _errorMessage = null;
//         });
//       }
//       final querySnapshot = await _firestore
//           .collection('menu_categories')
//           .where('branchId', isEqualTo: _currentBranchId)
//           .where('isActive', isEqualTo: true)
//           .orderBy('sortOrder')
//           .get();
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
//           _errorMessage = 'Failed to load menu. Please try again.';
//           _isLoading = false;
//         });
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // This value represents the approximate height of your main app's bottom navigation bar.
//     // Adjust it if your main navigation bar's height is different.
//     const double mainAppBottomNavBarHeight = 80.0;
//
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: const Text('Order for Pick Up',
//             style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
//         centerTitle: false,
//         backgroundColor: Colors.white,
//         elevation: 0,
//         surfaceTintColor: Colors.white,
//       ),
//       body: Stack(
//         children: [
//           Column(
//             children: [
//               _buildHeader(),
//               _buildCategorySelector(),
//               Expanded(
//                 child: _isLoading
//                     ? _buildLoadingState()
//                     : _errorMessage != null
//                     ? _buildErrorState()
//                     : _categories.isEmpty
//                     ? _buildEmptyState('No categories found')
//                     : _buildMenuGrid(),
//               ),
//             ],
//           ),
//           // Positioned Cart Bar at the bottom
//           Positioned(
//             bottom: mainAppBottomNavBarHeight + 16,
//             left: 16,
//             right: 16,
//             child: ListenableBuilder(
//               listenable: _takeAwayCartService,
//               builder: (context, child) {
//                 return _takeAwayCartService.items.isEmpty
//                     ? const SizedBox.shrink()
//                     : _buildTakeAwayCartBar();
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildHeader() {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
//       decoration: const BoxDecoration(color: Colors.white),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         decoration: BoxDecoration(
//           color: AppColors.primaryBlue.withOpacity(0.05),
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.timer_outlined, color: AppColors.primaryBlue, size: 20),
//             const SizedBox(width: 8),
//             Text(
//               'Ready for pickup in approx. ',
//               style: TextStyle(
//                 fontWeight: FontWeight.w500,
//                 color: Colors.grey.shade700,
//                 fontSize: 14,
//               ),
//             ),
//             Text(
//               _estimatedTime,
//               style: const TextStyle(
//                 fontWeight: FontWeight.w700,
//                 color: AppColors.primaryBlue,
//                 fontSize: 14,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildCategorySelector() {
//     if (_isLoading || _categories.length < 2) return const SizedBox.shrink();
//
//     return Container(
//       height: 50,
//       color: Colors.white,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.symmetric(horizontal: 16),
//         itemCount: _categories.length,
//         itemBuilder: (context, index) {
//           final category = _categories[index];
//           final bool isSelected = _selectedCategoryIndex == index;
//           return Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 4.0),
//             child: GestureDetector(
//               onTap: () => setState(() => _selectedCategoryIndex = index),
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 250),
//                 curve: Curves.easeInOut,
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 decoration: BoxDecoration(
//                   color: isSelected ? AppColors.primaryBlue : Colors.grey.shade100,
//                   borderRadius: BorderRadius.circular(25),
//                   border: Border.all(
//                     color: isSelected ? Colors.transparent : Colors.grey.shade300,
//                     width: 1.5,
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     if (category.imageUrl.isNotEmpty)
//                       Padding(
//                         padding: const EdgeInsets.only(right: 8.0),
//                         child: CircleAvatar(
//                           radius: 12,
//                           backgroundColor: Colors.white.withOpacity(isSelected ? 0.2 : 1.0),
//                           backgroundImage: NetworkImage(category.imageUrl),
//                         ),
//                       ),
//                     Text(
//                       category.name,
//                       style: TextStyle(
//                         color: isSelected ? Colors.white : Colors.black87,
//                         fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
//                         fontSize: 14,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildMenuGrid() {
//     const double bottomNavBarHeight = 80.0;
//     const double cartBarHeight = 80.0;
//     const double totalBottomPadding = bottomNavBarHeight + cartBarHeight;
//
//     if (_categories.isEmpty) return _buildEmptyState('No items to show');
//
//     return StreamBuilder<QuerySnapshot>(
//       stream: _firestore
//           .collection('menu_items')
//           .where('branchId', isEqualTo: _currentBranchId)
//           .where('categoryId', isEqualTo: _categories[_selectedCategoryIndex].id)
//           .where('isAvailable', isEqualTo: true)
//           .orderBy('sortOrder')
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return _buildLoadingState();
//         }
//         if (snapshot.hasError) {
//           return _buildErrorState('Error loading items.');
//         }
//         final items = snapshot.data!.docs
//             .map((doc) => MenuItem.fromFirestore(doc))
//             .toList();
//         if (items.isEmpty) {
//           return _buildEmptyState('No items in this category');
//         }
//
//         return GridView.builder(
//           physics: const BouncingScrollPhysics(),
//           padding: const EdgeInsets.fromLTRB(16, 16, 16, totalBottomPadding),
//           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: 2,
//             childAspectRatio: 0.68,
//             crossAxisSpacing: 12,
//             mainAxisSpacing: 12,
//           ),
//           itemCount: items.length,
//           itemBuilder: (context, index) =>
//               _buildModernMenuItemCard(items[index]),
//         );
//       },
//     );
//   }
//
//   // New, modern menu item card
//   Widget _buildModernMenuItemCard(MenuItem item) {
//     return ListenableBuilder(
//       listenable: _takeAwayCartService,
//       builder: (context, child) {
//         final cartItem = _takeAwayCartService.items.firstWhere(
//               (cartItem) => cartItem.id == item.id,
//           orElse: () => CartModel(id: '', name: '', imageUrl: '', price: 0, quantity: 0),
//         );
//         final quantity = cartItem.id == item.id ? cartItem.quantity : 0;
//
//         return GestureDetector(
//           onTap: () => _showItemDetails(item),
//           child: Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(color: Colors.grey.shade200, width: 1),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.04),
//                   blurRadius: 10,
//                   offset: const Offset(0, 4),
//                 ),
//               ],
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 Expanded(
//                   flex: 3,
//                   child: ClipRRect(
//                     borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
//                     child: CachedNetworkImage(
//                       imageUrl: item.imageUrl,
//                       fit: BoxFit.cover,
//                       placeholder: (context, url) => Container(color: Colors.grey[200]),
//                       errorWidget: (context, url, error) => Container(
//                         color: Colors.grey[200],
//                         child: const Icon(Icons.fastfood, color: Colors.grey),
//                       ),
//                     ),
//                   ),
//                 ),
//                 Expanded(
//                   flex: 2,
//                   child: Padding(
//                     padding: const EdgeInsets.all(10),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           item.name,
//                           style: const TextStyle(
//                             fontWeight: FontWeight.w700,
//                             fontSize: 15,
//                           ),
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           crossAxisAlignment: CrossAxisAlignment.end,
//                           children: [
//                             Text(
//                               'QAR ${item.price.toStringAsFixed(2)}',
//                               style: const TextStyle(
//                                 color: AppColors.primaryBlue,
//                                 fontWeight: FontWeight.w800,
//                                 fontSize: 16,
//                               ),
//                             ),
//                             quantity == 0
//                                 ? _buildAddButton(item)
//                                 : _buildQuantityControl(item, quantity),
//                           ],
//                         ),
//                       ],
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
//   Widget _buildAddButton(MenuItem item) {
//     return GestureDetector(
//       onTap: () {
//         _takeAwayCartService.addToCart(item);
//         _showFeedbackSnackbar('${item.name} added to order');
//       },
//       child: Container(
//         padding: const EdgeInsets.all(6),
//         decoration: BoxDecoration(
//           color: AppColors.primaryBlue.withOpacity(0.1),
//           shape: BoxShape.circle,
//         ),
//         child: const Icon(Icons.add_rounded, color: AppColors.primaryBlue, size: 20),
//       ),
//     );
//   }
//
//   Widget _buildQuantityControl(MenuItem item, int quantity) {
//     return Container(
//       height: 32,
//       decoration: BoxDecoration(
//         color: AppColors.primaryBlue,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Row(
//         children: [
//           SizedBox(
//             width: 30,
//             child: IconButton(
//               padding: EdgeInsets.zero,
//               icon: const Icon(Icons.remove, color: Colors.white, size: 16),
//               onPressed: () => _takeAwayCartService.updateQuantity(item.id, quantity - 1),
//             ),
//           ),
//           Text(
//             quantity.toString(),
//             style: const TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//               fontSize: 14,
//             ),
//           ),
//           SizedBox(
//             width: 30,
//             child: IconButton(
//               padding: EdgeInsets.zero,
//               icon: const Icon(Icons.add, color: Colors.white, size: 16),
//               onPressed: () => _takeAwayCartService.updateQuantity(item.id, quantity + 1),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // Modern Cart Bar
//   Widget _buildTakeAwayCartBar() {
//     return TweenAnimationBuilder<double>(
//       duration: const Duration(milliseconds: 300),
//       tween: Tween(begin: 0.0, end: 1.0),
//       curve: Curves.easeOutCubic,
//       builder: (context, value, child) {
//         return Transform.translate(
//           offset: Offset(0, 30 * (1 - value)),
//           child: Opacity(opacity: value, child: child),
//         );
//       },
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         decoration: BoxDecoration(
//           gradient: const LinearGradient(
//             colors: [Color(0xFF3383FF), Color(0xFF00B4DB)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//           borderRadius: BorderRadius.circular(20),
//           boxShadow: [
//             BoxShadow(
//               color: AppColors.primaryBlue.withOpacity(0.3),
//               blurRadius: 20,
//               offset: const Offset(0, 8),
//             ),
//           ],
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(10),
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.2),
//                     shape: BoxShape.circle,
//                   ),
//                   child: Text(
//                     '${_takeAwayCartService.itemCount}',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.w900,
//                       fontSize: 16,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Take Away Order',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w500,
//                         fontSize: 12,
//                       ),
//                     ),
//                     Text(
//                       'QAR ${_takeAwayCartService.totalAmount.toStringAsFixed(2)}',
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 18,
//                       ),
//                     ),
//                   ],
//                 )
//               ],
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => TakeAwayCartScreen(cartService: _takeAwayCartService),
//                   ),
//                 );
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.white,
//                 foregroundColor: AppColors.primaryBlue,
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//               ),
//               child: const Row(
//                 children: [
//                   Text('View Order', style: TextStyle(fontWeight: FontWeight.w700)),
//                   SizedBox(width: 8),
//                   Icon(Icons.arrow_forward_ios, size: 14),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Refreshed Item Details Bottom Sheet
//   void _showItemDetails(MenuItem item) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) {
//         return ListenableBuilder(
//           listenable: _takeAwayCartService,
//           builder: (context, _) {
//             final cartItem = _takeAwayCartService.items.firstWhere(
//                   (i) => i.id == item.id,
//               orElse: () => CartModel(id: '', name: '', imageUrl: '', price: 0, quantity: 0),
//             );
//             final bool isInCart = cartItem.id.isNotEmpty;
//
//             return DraggableScrollableSheet(
//               initialChildSize: 0.6,
//               minChildSize: 0.4,
//               maxChildSize: 0.9,
//               builder: (_, controller) {
//                 return Container(
//                   decoration: const BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//                   ),
//                   child: Column(
//                     children: [
//                       Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 12.0),
//                         child: Container(
//                           width: 40,
//                           height: 4,
//                           decoration: BoxDecoration(
//                             color: Colors.grey[300],
//                             borderRadius: BorderRadius.circular(2),
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         child: ListView(
//                           controller: controller,
//                           padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
//                           children: [
//                             ClipRRect(
//                               borderRadius: BorderRadius.circular(16),
//                               child: CachedNetworkImage(
//                                 imageUrl: item.imageUrl,
//                                 height: 220,
//                                 width: double.infinity,
//                                 fit: BoxFit.cover,
//                               ),
//                             ),
//                             const SizedBox(height: 20),
//                             Row(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Expanded(
//                                   child: Text(
//                                     item.name,
//                                     style: const TextStyle(
//                                       fontSize: 24,
//                                       fontWeight: FontWeight.w800,
//                                     ),
//                                   ),
//                                 ),
//                                 const SizedBox(width: 16),
//                                 Text(
//                                   'QAR ${item.price.toStringAsFixed(2)}',
//                                   style: const TextStyle(
//                                     fontSize: 22,
//                                     color: AppColors.primaryBlue,
//                                     fontWeight: FontWeight.w800,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             if (item.tags['isSpicy'] == true) ...[
//                               const SizedBox(height: 8),
//                               Row(
//                                 children: [
//                                   Icon(Icons.local_fire_department, size: 18, color: Colors.red[600]),
//                                   const SizedBox(width: 6),
//                                   Text(
//                                     'Spicy',
//                                     style: TextStyle(
//                                       color: Colors.red[700],
//                                       fontWeight: FontWeight.w600,
//                                       fontSize: 14,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                             const SizedBox(height: 16),
//                             Text(
//                               item.description.isNotEmpty ? item.description : 'No description available.',
//                               style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5),
//                             ),
//                             const SizedBox(height: 80), // Space for button
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             );
//           },
//         );
//       },
//     );
//   }
//
//   void _showFeedbackSnackbar(String message) {
//     ScaffoldMessenger.of(context).hideCurrentSnackBar();
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
//         backgroundColor: AppColors.primaryBlue,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         margin: const EdgeInsets.only(bottom: 180, left: 16, right: 16),
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }
//
//   // --- Helper Widgets for States ---
//   Widget _buildLoadingState() => const Center(
//     child: CircularProgressIndicator(color: AppColors.primaryBlue),
//   );
//
//   Widget _buildErrorState([String? message]) => Center(
//     child: Padding(
//       padding: const EdgeInsets.all(32.0),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(Icons.cloud_off_rounded, color: Colors.grey, size: 60),
//           const SizedBox(height: 16),
//           Text(
//             message ?? 'Something went wrong',
//             style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 8),
//           const Text(
//             'Please check your connection and try again.',
//             style: TextStyle(color: Colors.grey),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     ),
//   );
//
//   Widget _buildEmptyState(String message) => Center(
//     child: Padding(
//       padding: const EdgeInsets.all(32.0),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(Icons.fastfood_outlined, color: Colors.grey, size: 60),
//           const SizedBox(height: 16),
//           Text(
//             message,
//             style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     ),
//   );
// }
//
// class TakeAwayMenuItemCard extends StatefulWidget {
//   final MenuItem item;
//   final TakeAwayCartService cartService;
//
//   const TakeAwayMenuItemCard({
//     Key? key,
//     required this.item,
//     required this.cartService,
//   }) : super(key: key);
//
//   @override
//   State<TakeAwayMenuItemCard> createState() => _TakeAwayMenuItemCardState();
// }
//
// class _TakeAwayMenuItemCardState extends State<TakeAwayMenuItemCard> {
//   bool _isFavorite = false;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//   @override
//   void initState() {
//     super.initState();
//     _checkIfFavorite();
//   }
//
//   Future<void> _checkIfFavorite() async {
//     final user = _auth.currentUser;
//     if (user == null || user.email == null) return;
//
//     try {
//       final doc = await _firestore.collection('Users').doc(user.email).get();
//       if (doc.exists && mounted) {
//         final favorites =
//             doc.data()?['favorites'] as Map<String, dynamic>? ?? {};
//         setState(() {
//           _isFavorite = favorites.containsKey(widget.item.id);
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error checking favorites: ${e.toString()}')),
//         );
//       }
//     }
//   }
//
//   Future<void> _toggleFavorite() async {
//     final user = _auth.currentUser;
//     if (user == null || user.email == null) return;
//
//     setState(() {
//       _isFavorite = !_isFavorite;
//     });
//
//     try {
//       await _firestore.collection('Users').doc(user.email).set({
//         'favorites': {
//           widget.item.id:
//               _isFavorite ? _createFavoriteItemMap() : FieldValue.delete(),
//         },
//       }, SetOptions(merge: true));
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _isFavorite = !_isFavorite; // Revert on error
//         });
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error updating favorites: ${e.toString()}')),
//         );
//       }
//     }
//   }
//
//   Map<String, dynamic> _createFavoriteItemMap() {
//     return {
//       'id': widget.item.id,
//       'name': widget.item.name,
//       'imageUrl': widget.item.imageUrl,
//       'price': widget.item.price,
//       'description': widget.item.description,
//       'isSpicy': widget.item.tags['isSpicy'] ?? false,
//       'addedAt': FieldValue.serverTimestamp(),
//     };
//   }
//
//   void _updateQuantity(int newQuantity) {
//     if (newQuantity > 0) {
//       widget.cartService.updateQuantity(widget.item.id, newQuantity);
//     } else {
//       widget.cartService.removeFromCart(widget.item.id);
//     }
//   }
//
//   void _addItemToCart(MenuItem item) {
//     widget.cartService.addToCart(item);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('${item.name} added to take away order'),
//         duration: const Duration(seconds: 1),
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//         margin: EdgeInsets.only(
//           bottom: MediaQuery.of(context).size.height * 0.1,
//           left: 16,
//           right: 16,
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final index =
//         widget.cartService.items.indexWhere((i) => i.id == widget.item.id);
//     final itemCount =
//         index != -1 ? widget.cartService.items[index].quantity : 0;
//
//     return Card(
//       margin: const EdgeInsets.only(bottom: 16),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(16),
//         onTap: () {},
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         if (widget.item.tags['isSpicy'] == true)
//                           const Row(
//                             children: [
//                               Padding(
//                                 padding: EdgeInsets.only(bottom: 4),
//                                 child: Icon(
//                                   Icons.local_fire_department_rounded,
//                                   color: Colors.red,
//                                   size: 20,
//                                 ),
//                               ),
//                               SizedBox(width: 4),
//                               Text(
//                                 'Spicy',
//                                 style: TextStyle(
//                                   color: Colors.red,
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         Text(
//                           widget.item.name,
//                           style: const TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.black,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           'QAR ${widget.item.price.toStringAsFixed(2)}',
//                           style: const TextStyle(
//                             fontSize: 15,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.blue,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           widget.item.description,
//                           style: const TextStyle(
//                             color: Colors.black87,
//                             fontSize: 12,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(width: 16),
//                   Column(
//                     children: [
//                       if (widget.item.imageUrl.isNotEmpty)
//                         Stack(
//                           children: [
//                             Container(
//                               width: 150,
//                               height: 140,
//                               decoration: BoxDecoration(
//                                 borderRadius: BorderRadius.circular(8),
//                                 image: DecorationImage(
//                                   image: NetworkImage(widget.item.imageUrl),
//                                   fit: BoxFit.cover,
//                                 ),
//                               ),
//                             ),
//                             Positioned(
//                               bottom: 0,
//                               left: 0,
//                               right: 0,
//                               child: Container(
//                                 height: 40,
//                                 decoration: BoxDecoration(
//                                   color: Colors.white,
//                                   borderRadius: const BorderRadius.only(
//                                     bottomLeft: Radius.circular(8),
//                                     bottomRight: Radius.circular(8),
//                                   ),
//                                   boxShadow: [
//                                     BoxShadow(
//                                       color: Colors.black.withOpacity(0.1),
//                                       blurRadius: 6,
//                                       offset: const Offset(0, 2),
//                                     ),
//                                   ],
//                                 ),
//                                 child: itemCount > 0
//                                     ? Row(
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.center,
//                                         children: [
//                                           IconButton(
//                                             icon: const Icon(Icons.remove),
//                                             iconSize: 20,
//                                             onPressed: () {
//                                               _updateQuantity(itemCount - 1);
//                                             },
//                                           ),
//                                           Text(
//                                             itemCount.toString(),
//                                             style: const TextStyle(
//                                               fontWeight: FontWeight.bold,
//                                               fontSize: 16,
//                                             ),
//                                           ),
//                                           IconButton(
//                                             icon: const Icon(Icons.add),
//                                             iconSize: 20,
//                                             onPressed: () {
//                                               _updateQuantity(itemCount + 1);
//                                             },
//                                           ),
//                                         ],
//                                       )
//                                     : ElevatedButton(
//                                         style: ElevatedButton.styleFrom(
//                                           backgroundColor:
//                                               AppColors.primaryBlue,
//                                           shape: RoundedRectangleBorder(
//                                             borderRadius:
//                                                 BorderRadius.circular(8),
//                                           ),
//                                           padding: const EdgeInsets.symmetric(
//                                             horizontal: 12,
//                                             vertical: 6,
//                                           ),
//                                         ),
//                                         onPressed: () {
//                                           _addItemToCart(widget.item);
//                                         },
//                                         child: const Text(
//                                           'ADD',
//                                           style: TextStyle(
//                                             color: Colors.white,
//                                             fontWeight: FontWeight.bold,
//                                           ),
//                                         ),
//                                       ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       const SizedBox(height: 5),
//                       const Text(
//                         'customisable',
//                         style: TextStyle(
//                           color: Colors.black87,
//                           fontSize: 10,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//               Padding(
//                 padding: const EdgeInsets.only(top: 0),
//                 child: Row(
//                   children: [
//                     IconButton(
//                       iconSize: 20,
//                       padding: const EdgeInsets.all(4),
//                       icon: Icon(
//                         _isFavorite ? Icons.favorite : Icons.favorite_border,
//                         color: _isFavorite ? Colors.red : AppColors.primaryBlue,
//                       ),
//                       onPressed: _toggleFavorite,
//                     ),
//                     IconButton(
//                       iconSize: 20,
//                       padding: const EdgeInsets.all(4),
//                       icon: Icon(Icons.share, color: AppColors.primaryBlue),
//                       onPressed: () {
// // Handle share action
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class TakeAwayCartService extends ChangeNotifier {
//   final List<CartModel> _items = [];
//   CouponModel? _appliedCoupon;
//   double _couponDiscount = 0;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final String _currentBranchId = 'Old_Airport';
//   static const String _prefsKey = 'takeaway_cart_items';
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
//       debugPrint('Error loading takeaway cart from SharedPreferences: $e');
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
//       debugPrint('Error saving takeaway cart to SharedPreferences: $e');
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
//       if (!coupon.isValidForUser(userId, _currentBranchId, 'take_away')) {
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
// class TakeAwayCartScreen extends StatefulWidget {
//   final TakeAwayCartService cartService;
//
//   const TakeAwayCartScreen({Key? key, required this.cartService})
//       : super(key: key);
//
//   @override
//   State<TakeAwayCartScreen> createState() => _TakeAwayCartScreenState();
// }
//
// class _TakeAwayCartScreenState extends State<TakeAwayCartScreen> {
//   final RestaurantService _restaurantService = RestaurantService();
//   String _estimatedTime = 'Loading...';
//   final String _currentBranchId = 'Old_Airport';
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//   bool _isLoading = false;
//   bool _isCheckingOut = false;
//   bool _isApplyingCoupon = false;
//   String? _couponError;
//   String? _selectedPickupType;
//   TextEditingController _carNumberController = TextEditingController();
//   TextEditingController _carModelController = TextEditingController();
//   TextEditingController _carColorController = TextEditingController();
//   TextEditingController _notesController = TextEditingController();
//   final TextEditingController _couponController = TextEditingController();
//   Color? _selectedCarColor;
//
// // The list we’ll show in the picker
//   final List<Map<String, dynamic>> _carColorOptions = [
//     {'name': 'White', 'color': Colors.white},
//     {'name': 'Black', 'color': Colors.black},
//     {'name': 'Silver', 'color': Colors.grey},
//     {'name': 'Blue', 'color': Colors.blue},
//     {'name': 'Red', 'color': Colors.red},
//     {'name': 'Green', 'color': Colors.green},
//     {'name': 'Yellow', 'color': Colors.yellow},
//     {'name': 'Brown', 'color': Colors.brown},
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     _loadEstimatedTime();
//     _selectedPickupType = 'walk_in'; // Default to walk-in
//   }
//
//   Future<void> _loadEstimatedTime() async {
//     final time = await _restaurantService.getEstimatedTime(_currentBranchId);
//     if (mounted) {
//       setState(() => _estimatedTime = time);
//     }
//   }
//
//   @override
//   void dispose() {
//     _notesController.dispose();
//     _carNumberController.dispose();
//     _carModelController.dispose();
//     _carColorController.dispose();
//     _couponController.dispose();
//     super.dispose();
//   }
//
//   Widget _buildTimeEstimate() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: Row(
//         children: [
//           Text(
//             'Estimated preparation: $_estimatedTime',
//             style: const TextStyle(fontSize: 16),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildCouponSection() {
//     return Column(
//       children: [
//         if (widget.cartService.appliedCoupon != null)
//           Padding(
//             padding: const EdgeInsets.symmetric(vertical: 8),
//             child: Container(
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.05),
//                     blurRadius: 8,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(12),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Row(
//                       children: [
//                         Icon(Icons.discount, color: Colors.green, size: 24),
//                         const SizedBox(width: 12),
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Coupon Applied',
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 color: Colors.grey.shade600,
//                               ),
//                             ),
//                             Text(
//                               widget.cartService.appliedCoupon!.code,
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                                 color: AppColors.primaryBlue,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                     TextButton(
//                       onPressed: () {
//                         widget.cartService.removeCoupon();
//                         setState(() {
//                           _couponError = null;
//                         });
//                       },
//                       child: Text(
//                         'Remove',
//                         style: TextStyle(
//                           color: Colors.red,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           )
//         else
//           GestureDetector(
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => TakeAwayCouponsScreen(
//                     cartService: widget.cartService,
//                   ),
//                 ),
//               );
//             },
//             child: Container(
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.05),
//                     blurRadius: 8,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Row(
//                   children: [
//                     Icon(Icons.discount, color: AppColors.primaryBlue),
//                     const SizedBox(width: 12),
//                     const Expanded(
//                       child: Text(
//                         'Apply Coupon',
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ),
//                     Icon(Icons.arrow_forward_ios,
//                         size: 16, color: Colors.grey.shade500),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         if (widget.cartService.appliedCoupon != null)
//           Padding(
//             padding: const EdgeInsets.only(top: 8),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   'Coupon Discount',
//                   style: TextStyle(
//                     color: Colors.grey.shade600,
//                   ),
//                 ),
//                 Text(
//                   '-QAR ${widget.cartService.couponDiscount.toStringAsFixed(2)}',
//                   style: TextStyle(
//                     color: Colors.green,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//       ],
//     );
//   }
//
//   Future<void> _applyCoupon() async {
//     final couponCode = _couponController.text.trim();
//     if (couponCode.isEmpty) return;
//
//     setState(() {
//       _isApplyingCoupon = true;
//       _couponError = null;
//     });
//
//     try {
//       await widget.cartService.applyCoupon(couponCode);
//     } catch (e) {
//       setState(() {
//         _couponError = e.toString();
//       });
//     } finally {
//       setState(() {
//         _isApplyingCoupon = false;
//       });
//     }
//   }
//
//   Future<void> _openCarColorPicker() async {
//     final picked = await showModalBottomSheet<Map<String, dynamic>>(
//       context: context,
//       backgroundColor: Colors.white,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//       ),
//       builder: (_) => DraggableScrollableSheet(
//         expand: false,
//         initialChildSize: 0.45,
//         minChildSize: 0.30,
//         maxChildSize: 0.80,
//         builder: (_, controller) => Column(
//           children: [
//             const SizedBox(height: 12),
//             Container(                      // little grab handle
//               width: 40,
//               height: 4,
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade400,
//                 borderRadius: BorderRadius.circular(2),
//               ),
//             ),
//             const SizedBox(height: 16),
//             const Text('Select Car Colour',
//                 style: TextStyle(
//                     fontSize: 18, fontWeight: FontWeight.w700)),
//             const SizedBox(height: 16),
//             Expanded(
//               child: GridView.builder(
//                 controller: controller,
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 gridDelegate:
//                 const SliverGridDelegateWithFixedCrossAxisCount(
//                   crossAxisCount: 4,
//                   mainAxisSpacing: 24,
//                   crossAxisSpacing: 24,
//                   childAspectRatio: 0.8,
//                 ),
//                 itemCount: _carColorOptions.length,
//                 itemBuilder: (_, i) {
//                   final opt = _carColorOptions[i];
//                   return InkWell(
//                     borderRadius: BorderRadius.circular(12),
//                     onTap: () => Navigator.pop(context, opt),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Container(
//                           width: 36,
//                           height: 36,
//                           decoration: BoxDecoration(
//                             color: opt['color'],
//                             shape: BoxShape.circle,
//                             border: Border.all(
//                                 color: Colors.grey.shade300, width: 1),
//                           ),
//                         ),
//                         const SizedBox(height: 6),
//                         Text(opt['name'],
//                             style: const TextStyle(fontSize: 12)),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 24),
//           ],
//         ),
//       ),
//     );
//
//     if (picked != null) {
//       setState(() {
//         _selectedCarColor = picked['color'] as Color;
//         _carColorController.text = picked['name'] as String;
//       });
//     }
//   }
//
//   // Paste anywhere inside the state class, above build():
//   InputDecoration _dropdownDecoration(IconData icon) {
//     return InputDecoration(
//       prefixIcon: Icon(icon, color: Colors.grey.shade500),
//       filled: true,
//       fillColor: Colors.grey.shade50,
//       contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(10),
//         borderSide: BorderSide.none,
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(10),
//         borderSide: const BorderSide(
//           color: AppColors.primaryBlue,
//           width: 1.5,
//         ),
//       ),
//     );
//   }
//
//
//
//   Widget _buildPickupTypeSection() {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'SELECT PICKUP METHOD',
//             style: TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.w600,
//               color: Colors.grey,
//               letterSpacing: 0.5,
//             ),
//           ),
//           const SizedBox(height: 12),
//           Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.05),
//                   blurRadius: 10,
//                   offset: const Offset(0, 4),
//                 ),
//               ],
//             ),
//             child: Column(
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.all(12),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: InkWell(
//                           borderRadius: BorderRadius.circular(8),
//                           onTap: () {
//                             setState(() {
//                               _selectedPickupType = 'walk_in';
//                             });
//                           },
//                           child: AnimatedContainer(
//                             duration: const Duration(milliseconds: 200),
//                             curve: Curves.easeInOut,
//                             height: 48,
//                             decoration: BoxDecoration(
//                               color: _selectedPickupType == 'walk_in'
//                                   ? AppColors.primaryBlue
//                                   : Colors.grey.shade100,
//                               borderRadius: BorderRadius.circular(8),
//                               border: _selectedPickupType == 'walk_in'
//                                   ? Border.all(
//                                       color: AppColors.primaryBlue
//                                           .withOpacity(0.2),
//                                       width: 2)
//                                   : null,
//                             ),
//                             child: Center(
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     Icons.directions_walk,
//                                     color: _selectedPickupType == 'walk_in'
//                                         ? Colors.white
//                                         : Colors.grey.shade700,
//                                     size: 20,
//                                   ),
//                                   const SizedBox(width: 8),
//                                   Text(
//                                     'WALK-IN',
//                                     style: TextStyle(
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w600,
//                                       color: _selectedPickupType == 'walk_in'
//                                           ? Colors.white
//                                           : Colors.grey.shade700,
//                                       letterSpacing: 0.5,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: InkWell(
//                           borderRadius: BorderRadius.circular(8),
//                           onTap: () {
//                             setState(() {
//                               _selectedPickupType = 'by_car';
//                             });
//                           },
//                           child: AnimatedContainer(
//                             duration: const Duration(milliseconds: 200),
//                             curve: Curves.easeInOut,
//                             height: 48,
//                             decoration: BoxDecoration(
//                               color: _selectedPickupType == 'by_car'
//                                   ? AppColors.primaryBlue
//                                   : Colors.grey.shade100,
//                               borderRadius: BorderRadius.circular(8),
//                               border: _selectedPickupType == 'by_car'
//                                   ? Border.all(
//                                       color: AppColors.primaryBlue
//                                           .withOpacity(0.2),
//                                       width: 2)
//                                   : null,
//                             ),
//                             child: Center(
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     Icons.directions_car,
//                                     color: _selectedPickupType == 'by_car'
//                                         ? Colors.white
//                                         : Colors.grey.shade700,
//                                     size: 20,
//                                   ),
//                                   const SizedBox(width: 8),
//                                   Text(
//                                     'BY CAR',
//                                     style: TextStyle(
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w600,
//                                       color: _selectedPickupType == 'by_car'
//                                           ? Colors.white
//                                           : Colors.grey.shade700,
//                                       letterSpacing: 0.5,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 if (_selectedPickupType == 'by_car')
//                   SingleChildScrollView(
//                     child: AnimatedContainer(
//                       duration: const Duration(milliseconds: 300),
//                       curve: Curves.easeInOut,
//                       padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
//                       child: Column(
//                         children: [
//                           const Divider(height: 1),
//                           const SizedBox(height: 16),
//                           const Align(
//                             alignment: Alignment.centerLeft,
//                             child: Padding(
//                               padding: EdgeInsets.only(left: 8),
//                               child: Text(
//                                 'CAR DETAILS',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.w600,
//                                   color: Colors.grey,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 12),
//                           _buildStyledTextField(
//                             controller: _carNumberController,
//                             label: 'Car Number Plate',
//                             icon: Icons.confirmation_number,
//                             isRequired: true,
//                           ),
//                           const SizedBox(height: 12),
//                           _buildStyledTextField(
//                             controller: _carModelController,
//                             label: 'Car Model',
//                             icon: Icons.directions_car,
//                             isRequired: true,
//                           ),
//                           const SizedBox(height: 12),
//                           // ─── Car Colour ─────────────────────────────────────────
//                           GestureDetector(
//                             onTap: _openCarColorPicker,
//                             child: AbsorbPointer(            // keeps the keyboard from showing up
//                               child: TextFormField(
//                                 controller: _carColorController,
//                                 validator: (_) =>
//                                 _carColorController.text.isEmpty ? 'Car colour is required' : null,
//                                 decoration: _dropdownDecoration(Icons.color_lens).copyWith(
//                                   hintText: 'Car Color',
//                                   suffixIcon: _selectedCarColor == null
//                                       ? null
//                                       : Padding(
//                                     padding: const EdgeInsets.all(12),
//                                     child: Container(
//                                       width: 20,
//                                       height: 20,
//                                       decoration: BoxDecoration(
//                                         color: _selectedCarColor,
//                                         shape: BoxShape.circle,
//                                         border: Border.all(color: Colors.grey.shade300),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return ListenableBuilder(
//       listenable: widget.cartService,
//       builder: (context, child) {
//         return Scaffold(
//           backgroundColor: Colors.white,
//           appBar: AppBar(
//             title: const Text('Take Away Order',
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 )),
//             backgroundColor: AppColors.primaryBlue,
//             elevation: 0,
//             centerTitle: true,
//             leading: IconButton(
//               icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
//               onPressed: () => Navigator.pop(context),
//             ),
//             actions: [
//               if (widget.cartService.items.isNotEmpty)
//                 IconButton(
//                   icon: const Icon(Icons.delete_outline, color: Colors.white),
//                   onPressed: () => _showClearCartDialog(),
//                 ),
//             ],
//           ),
//           body: _buildBody(),
//           bottomNavigationBar:
//               widget.cartService.items.isNotEmpty ? _buildCheckoutBar() : null,
//         );
//       },
//     );
//   }
//
//   Widget _buildBody() {
//     if (_isLoading) {
//       return Center(
//         child: CircularProgressIndicator(
//           color: AppColors.primaryBlue,
//         ),
//       );
//     }
//
//     if (widget.cartService.items.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.shopping_cart_outlined,
//                 size: 100, color: AppColors.primaryBlue.withOpacity(0.3)),
//             const SizedBox(height: 24),
//             Text(
//               'Your Take Away Order is Empty',
//               style: TextStyle(
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold,
//                 color: AppColors.primaryBlue,
//               ),
//             ),
//             const SizedBox(height: 12),
//             const Padding(
//               padding: EdgeInsets.symmetric(horizontal: 40),
//               child: Text(
//                 'Browse our menu and add delicious items to get started',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 16,
//                   color: Colors.grey,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 32),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: AppColors.primaryBlue,
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 elevation: 2,
//               ),
//               child: const Text(
//                 'View Menu',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       );
//     }
//
//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
//           ),
//           child: Row(
//             children: [
//               Icon(Icons.access_time, color: AppColors.primaryBlue),
//               const SizedBox(width: 12),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildTimeEstimate(),
//                 ],
//               ),
//             ],
//           ),
//         ),
//         _buildPickupTypeSection(),
//         Expanded(
//           child: ListView(
//             padding: const EdgeInsets.only(bottom: 100, top: 8),
//             children: [
//               ListView.separated(
//                 physics: NeverScrollableScrollPhysics(),
//                 shrinkWrap: true,
//                 itemCount: widget.cartService.items.length,
//                 separatorBuilder: (context, index) =>
//                     const Divider(height: 1, indent: 16, endIndent: 16),
//                 itemBuilder: (context, index) {
//                   final item = widget.cartService.items[index];
//                   return _buildCartItem(item);
//                 },
//               ),
//               _buildNotesSection(),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
// // Add this to your _TakeAwayCartScreenState class
//   Widget _buildStyledTextField({
//     required TextEditingController controller,
//     required String label,
//     required IconData icon,
//     bool isRequired = false,
//   }) {
//     return TextField(
//       controller: controller,
//       decoration: InputDecoration(
//         labelText: isRequired ? '$label *' : label,
//         prefixIcon: Icon(icon, size: 20),
//         filled: true,
//         fillColor: Colors.grey.shade50,
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(10),
//           borderSide: BorderSide.none,
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(10),
//           borderSide: BorderSide.none,
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(10),
//           borderSide: const BorderSide(
//             color: AppColors.primaryBlue,
//             width: 1.5,
//           ),
//         ),
//         contentPadding: const EdgeInsets.symmetric(
//           vertical: 16,
//           horizontal: 16,
//         ),
//       ),
//     );
//   }
//
//   Widget _buildCartItem(CartModel item) {
//     return Dismissible(
//       key: Key(item.id),
//       direction: DismissDirection.endToStart,
//       background: Container(
//         margin: const EdgeInsets.symmetric(vertical: 8),
//         alignment: Alignment.centerRight,
//         padding: const EdgeInsets.only(right: 20),
//         decoration: BoxDecoration(
//           color: Colors.red,
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: const Icon(Icons.delete, color: Colors.white),
//       ),
//       onDismissed: (direction) {
//         widget.cartService.removeFromCart(item.id);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('${item.name} removed from order'),
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(8),
//             ),
//             action: SnackBarAction(
//               label: 'UNDO',
//               textColor: Colors.white,
//               onPressed: () {
//                 widget.cartService.addToCart(
//                   MenuItem(
//                     id: item.id,
//                     branchId: '',
//                     categoryId: '',
//                     description: '',
//                     imageUrl: item.imageUrl,
//                     isAvailable: true,
//                     isPopular: false,
//                     name: item.name,
//                     price: item.price,
//                     sortOrder: 0,
//                     tags: {},
//                     variants: {},
//                   ),
//                   quantity: item.quantity,
//                 );
//               },
//             ),
//           ),
//         );
//       },
//       child: Container(
//         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.05),
//               blurRadius: 8,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
// // Item Image
//               Container(
//                 width: 80,
//                 height: 80,
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(8),
//                   color: Colors.grey[100],
//                 ),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(8),
//                   child: CachedNetworkImage(
//                     imageUrl: item.imageUrl,
//                     fit: BoxFit.cover,
//                     placeholder: (context, url) => Center(
//                       child: CircularProgressIndicator(
//                         color: AppColors.primaryBlue,
//                       ),
//                     ),
//                     errorWidget: (context, url, error) => Icon(
//                       Icons.fastfood,
//                       color: AppColors.primaryBlue.withOpacity(0.3),
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 16),
//
// // Item details
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             item.name,
//                             style: const TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                         Text(
//                           'QAR ${item.totalPrice.toStringAsFixed(2)}',
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                             color: AppColors.primaryBlue,
//                           ),
//                         ),
//                       ],
//                     ),
//
//                     const SizedBox(height: 8),
//
//                     if (item.addons != null && item.addons!.isNotEmpty) ...[
//                       Text(
//                         'Add-ons: ${item.addons!.join(', ')}',
//                         style: const TextStyle(
//                           color: Colors.grey,
//                           fontSize: 13,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                     ],
//
// // Quantity selector
//                     Row(
//                       children: [
//                         Container(
//                           decoration: BoxDecoration(
//                             border: Border.all(color: AppColors.primaryBlue),
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                           child: IconButton(
//                             icon: Icon(Icons.remove,
//                                 size: 18, color: AppColors.primaryBlue),
//                             onPressed: () {
//                               if (item.quantity > 1) {
//                                 widget.cartService
//                                     .updateQuantity(item.id, item.quantity - 1);
//                               } else {
//                                 widget.cartService.removeFromCart(item.id);
//                               }
//                             },
//                           ),
//                         ),
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 12),
//                           child: Text(
//                             item.quantity.toString(),
//                             style: const TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                         Container(
//                           decoration: BoxDecoration(
//                             border: Border.all(color: AppColors.primaryBlue),
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                           child: IconButton(
//                             icon: Icon(Icons.add,
//                                 size: 18, color: AppColors.primaryBlue),
//                             onPressed: () {
//                               widget.cartService
//                                   .updateQuantity(item.id, item.quantity + 1);
//                             },
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildNotesSection() {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Special Instructions',
//             style: TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//               color: Colors.black87,
//             ),
//           ),
//           const SizedBox(height: 8),
//           TextField(
//             controller: _notesController,
//             maxLines: 3,
//             decoration: InputDecoration(
//               hintText:
//                   'Add notes for the restaurant (allergies, preferences, etc.)',
//               hintStyle: TextStyle(color: Colors.grey.shade500),
//               filled: true,
//               fillColor: Colors.grey.shade50,
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide(
//                   color: AppColors.primaryBlue.withOpacity(0.3),
//                   width: 1,
//                 ),
//               ),
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide(
//                   color: AppColors.primaryBlue.withOpacity(0.3),
//                   width: 1,
//                 ),
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide(
//                   color: AppColors.primaryBlue,
//                   width: 1.5,
//                 ),
//               ),
//               contentPadding: const EdgeInsets.all(16),
//             ),
//           ),
//           const SizedBox(height: 8),
//           const Text(
//             'e.g. "No onions", "Extra spicy", "Allergy: peanuts"',
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.grey,
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
//     final double total = (subtotal + tax) - (widget.cartService.couponDiscount);
//
//     return Container(
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         border: Border(top: BorderSide(color: Colors.grey.shade200)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 10,
//             offset: const Offset(0, -5),
//           ),
//         ],
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           _buildCouponSection(),
//           InkWell(
//             onTap: () => _showOrderSummary(),
//             child: Padding(
//               padding: const EdgeInsets.symmetric(vertical: 8),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     '${widget.cartService.itemCount} ITEMS IN ORDER',
//                     style: const TextStyle(
//                       fontSize: 14,
//                       color: Colors.grey,
//                     ),
//                   ),
//                   Row(
//                     children: [
//                       Text(
//                         'QAR ${subtotal.toStringAsFixed(2)}',
//                         style: const TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       const Icon(Icons.keyboard_arrow_down, size: 20),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           if (_notesController.text.isNotEmpty) ...[
//             Padding(
//               padding: const EdgeInsets.symmetric(vertical: 8),
//               child: Row(
//                 children: [
//                   Icon(Icons.note, size: 16, color: AppColors.primaryBlue),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'Note: ${_notesController.text}',
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: AppColors.primaryBlue,
//                         fontStyle: FontStyle.italic,
//                       ),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const Divider(height: 1),
//           ],
//           Padding(
//             padding: const EdgeInsets.symmetric(vertical: 12),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text(
//                   'Total Amount',
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 Text(
//                   'QAR ${total.toStringAsFixed(2)}',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: AppColors.primaryBlue,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton(
//               onPressed: _isCheckingOut ? null : _proceedToCheckout,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: AppColors.primaryBlue,
//                 padding: const EdgeInsets.symmetric(vertical: 16),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 elevation: 0,
//               ),
//               child: _isCheckingOut
//                   ? const SizedBox(
//                       width: 20,
//                       height: 20,
//                       child: CircularProgressIndicator(
//                         color: Colors.white,
//                         strokeWidth: 2,
//                       ),
//                     )
//                   : const Text(
//                       'PLACE TAKE AWAY ORDER',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ─────────────────────────────────────────────────────────────
// //  _proceedToCheckout  –  FULL REPLACEMENT
// // ─────────────────────────────────────────────────────────────
//   Future<void> _proceedToCheckout() async {
//     /* --------------------------------------------------------
//    * 1. BASIC FORM VALIDATION
//    * ------------------------------------------------------ */
//     if (_selectedPickupType == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please select a pickup method')),
//       );
//       return;
//     }
//
//     if (_selectedPickupType == 'by_car' &&
//         (_carNumberController.text.trim().isEmpty ||
//             _carModelController.text.trim().isEmpty  ||
//             _carColorController.text.trim().isEmpty)) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please fill in all car details')),
//       );
//       return;
//     }
//
//     if (widget.cartService.items.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Your cart is empty')),
//       );
//       return;
//     }
//
//     /* --------------------------------------------------------
//    * 2. START CHECKOUT
//    * ------------------------------------------------------ */
//     setState(() => _isCheckingOut = true);
//
//     try {
//       /* 2.1  Make sure any coupon that was applied is still valid */
//       final couponStillValid =
//       await widget.cartService.validateCouponAtCheckout();
//       if (!couponStillValid && mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Coupon removed – no longer valid.'),
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }
//
//       /* 2.2  Prepare order-level numbers & data                        */
//       final cartItems  = widget.cartService.items;
//       final subtotal   = widget.cartService.totalAmount;
//       final tax        = subtotal * 0.10;            // 10 % flat tax
//       final total      = (subtotal + tax) -
//           widget.cartService.couponDiscount;
//
//       final user = _auth.currentUser;
//       if (user == null || user.email == null) {
//         throw Exception('User not authenticated.');
//       }
//
//       /* --------------------------------------------------------
//      * 3. FIRESTORE TRANSACTION
//      *      • increment daily counter
//      *      • generate pretty orderId
//      *      • write order document
//      * ------------------------------------------------------ */
//       final String today       = DateFormat('yyyy-MM-dd').format(DateTime.now());
//       final counterRef         = _firestore
//           .collection('daily_counters')
//           .doc(today);
//       final orderRef           = _firestore
//           .collection('Orders')
//           .doc();
//
//       await _firestore.runTransaction((txn) async {
//         // 3.1   daily counter
//         final counterSnap = await txn.get(counterRef);
//         int dailyCount = 1;
//         if (counterSnap.exists) {
//           dailyCount = (counterSnap.get('count') as int) + 1;
//           txn.update(counterRef, {'count': dailyCount});
//         } else {
//           txn.set(counterRef, {'count': 1});
//         }
//
//         // 3.2   human-friendly order id  e.g. TA-2025-08-12-004
//         final orderId =
//             'TA-$today-${dailyCount.toString().padLeft(3, '0')}';
//
//         // 3.3   serialise cart items
//         final items = cartItems.map((c) => {
//           'itemId'        : c.id,
//           'name'          : c.name,
//           'quantity'      : c.quantity,
//           'price'         : c.price,
//           'variants'      : c.variants,
//           'addons'        : c.addons,
//           'total'         : c.totalPrice,
//           if (c.couponCode     != null) 'couponCode'     : c.couponCode,
//           if (c.couponDiscount != null) 'couponDiscount' : c.couponDiscount,
//           if (c.couponId       != null) 'couponId'       : c.couponId,
//         }).toList();
//
//         // 3.4   pickup details
//         final pickupDetails = {
//           'type': _selectedPickupType,
//           if (_selectedPickupType == 'by_car') ...{
//             'carNumber' : _carNumberController.text.trim(),
//             'carModel'  : _carModelController.text.trim(),
//             'carColor'  : _carColorController.text.trim(),
//           }
//         };
//
//         // 3.5   assemble order data
//         final coupon = widget.cartService.appliedCoupon;
//         final orderData = {
//           'orderId'          : orderId,
//           'dailyOrderNumber' : dailyCount,
//           'date'             : today,
//           'customerId'       : user.email,
//           'items'            : items,
//           'notes'            : _notesController.text.trim(),
//           'status'           : 'pending',
//           'subtotal'         : subtotal,
//           'tax'              : tax,
//           'totalAmount'      : total,
//           'timestamp'        : FieldValue.serverTimestamp(),
//           'order_type'       : 'take_away',
//           'pickupDetails'    : pickupDetails,
//           if (coupon != null) ...{
//             'couponCode'     : coupon.code,
//             'couponDiscount' : widget.cartService.couponDiscount,
//             'couponId'       : coupon.id,
//           },
//         };
//
//         // 3.6   write the order
//         txn.set(orderRef, orderData);
//       });
//
//       /* --------------------------------------------------------
//      * 4. SUCCESS  – clear UI, pop back, show toast
//      * ------------------------------------------------------ */
//       if (!mounted) return;
//
//       widget.cartService.clearCart();
//       _notesController.clear();
//       _carNumberController.clear();
//       _carModelController.clear();
//       _carColorController.clear();
//       _couponController.clear();
//
//       setState(() {
//         _selectedPickupType = 'walk_in';
//         _couponError        = null;
//       });
//
//       // show feedback BEFORE leaving current Scaffold
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Take-away order placed successfully!'),
//           duration: Duration(seconds: 2),
//         ),
//       );
//
//       // then navigate back to home/root
//       Navigator.popUntil(context, (route) => route.isFirst);
//     }
//
//     /* --------------------------------------------------------
//    * 5. FAILURE  – show error, stay on screen
//    * ------------------------------------------------------ */
//     catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed to place order: $e')),
//         );
//       }
//     }
//
//     /* --------------------------------------------------------
//    * 6. ALWAYS  – stop spinner
//    * ------------------------------------------------------ */
//     finally {
//       if (mounted) setState(() => _isCheckingOut = false);
//     }
//   }
//
//
//   void _showOrderSummary() {
//     final double subtotal = widget.cartService.totalAmount;
//     final double tax = subtotal * 0.10;
//     final double total = (subtotal + tax) - (widget.cartService.couponDiscount);
//
//     showModalBottomSheet(
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (context) {
//         return Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Center(
//                 child: Container(
//                   width: 40,
//                   height: 4,
//                   margin: const EdgeInsets.only(bottom: 16),
//                   decoration: BoxDecoration(
//                     color: Colors.grey,
//                     borderRadius: BorderRadius.circular(2),
//                   ),
//                 ),
//               ),
//               const Text(
//                 'Take Away Order Summary',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               _buildBillRow('Subtotal', subtotal),
//               _buildBillRow('Tax (10%)', tax),
//               if (widget.cartService.appliedCoupon != null)
//                 _buildBillRow(
//                   'Coupon Discount (${widget.cartService.appliedCoupon!.code})',
//                   -widget.cartService.couponDiscount,
//                 ),
//               const Divider(height: 24),
//               _buildBillRow('Total Amount', total, isTotal: true),
//               const SizedBox(height: 16),
//               const Text(
//                 'Pickup Details:',
//                 style: TextStyle(
//                   fontWeight: FontWeight.bold,
//                   fontSize: 14,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 'Method: ${_selectedPickupType == 'walk_in' ? 'Walk-In' : 'By Car'}',
//                 style: const TextStyle(fontSize: 14),
//               ),
//               if (_selectedPickupType == 'by_car') ...[
//                 Text(
//                   'Car Number: ${_carNumberController.text}',
//                   style: const TextStyle(fontSize: 14),
//                 ),
//                 Text(
//                   'Car Model: ${_carModelController.text}',
//                   style: const TextStyle(fontSize: 14),
//                 ),
//                 Text(
//                   'Car Color: ${_carColorController.text}',
//                   style: const TextStyle(fontSize: 14),
//                 ),
//               ],
//               if (_notesController.text.isNotEmpty) ...[
//                 const SizedBox(height: 16),
//                 const Text(
//                   'Special Instructions:',
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 14,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   _notesController.text,
//                   style: const TextStyle(fontSize: 14),
//                 ),
//               ],
//               const SizedBox(height: 24),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildBillRow(String label, double amount, {bool isTotal = false}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               fontSize: 14,
//               color: isTotal ? Colors.black : Colors.grey,
//               fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
//             ),
//           ),
//           Text(
//             'QAR ${amount.toStringAsFixed(2)}',
//             style: TextStyle(
//               fontSize: 14,
//               color: isTotal ? Colors.black : Colors.grey,
//               fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showClearCartDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Clear Order?'),
//         content: const Text(
//             'Are you sure you want to remove all items from your take away order?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               widget.cartService.clearCart();
//               Navigator.pop(context);
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   content: Text('Take away order cleared'),
//                   behavior: SnackBarBehavior.floating,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//               );
//             },
//             child: Text(
//               'Clear',
//               style: TextStyle(color: AppColors.primaryBlue),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class TakeAwayCouponsScreen extends StatefulWidget {
//   final TakeAwayCartService
//       cartService; // Changed from CartService to TakeAwayCartService
//
//   const TakeAwayCouponsScreen({Key? key, required this.cartService})
//       : super(key: key);
//
//   @override
//   _TakeAwayCouponsScreenState createState() => _TakeAwayCouponsScreenState();
// }
//
// class _TakeAwayCouponsScreenState extends State<TakeAwayCouponsScreen> {
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
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.white,
//                               ),
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
// // Additional validation for takeaway specific coupons if needed
//     return coupon.isValidForUser(
//       _auth.currentUser?.email,
//       _currentBranchId,
//       'take_away',
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
//
//
//
