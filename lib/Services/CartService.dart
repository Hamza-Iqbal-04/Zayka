// import 'package:flutter/material.dart';
// import '../Screens/DineInScreen.dart';
// import 'models.dart'; // Make sure this path is correct
//
// enum OrderType { delivery, takeaway }
//
// class CartService extends ChangeNotifier {
//   final List<CartModel> _items = [];
//   OrderType _orderType = OrderType.delivery; // Default order type
//
//   List<CartModel> get items => _items;
//   OrderType get orderType => _orderType;
//
//   int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
//   double get totalAmount => _items.fold(0, (sum, item) => sum + item.totalPrice);
//
//   void setOrderType(OrderType type) {
//     if (_orderType != type) {
//       _orderType = type;
//       // If you want to clear the cart when switching types, uncomment the next line
//       // clearCart();
//       notifyListeners();
//     }
//   }
//
//   Future<void> addToCart(MenuItem menuItem, {int quantity = 1}) async {
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
//       ));
//     }
//     notifyListeners();
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
//       notifyListeners();
//     }
//   }
//
//   Future<void> removeFromCart(String itemId) async {
//     _items.removeWhere((item) => item.id == itemId);
//     notifyListeners();
//   }
//
//   Future<void> clearCart() async {
//     _items.clear();
//     notifyListeners();
//   }
// }
