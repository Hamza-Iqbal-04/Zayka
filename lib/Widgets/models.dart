import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Services/language_provider.dart';

class CouponModel {
  final String id;
  final String code;
  final String type;
  final double value;
  final double maxDiscount;
  final double minSubtotal;
  final DateTime validFrom;
  final DateTime validUntil;
  final bool active;
  final List<String> allowedUsers;
  final List<String> branchIds;
  final List<String> categoryIds;
  final List<String> itemIds;
  final int maxUsesPerUser;
  final String scope;
  final String? userRestriction;
  final String? description;
  final String? descriptionAr;

  CouponModel({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.maxDiscount,
    required this.minSubtotal,
    required this.validFrom,
    required this.validUntil,
    required this.active,
    required this.allowedUsers,
    required this.branchIds,
    required this.categoryIds,
    required this.itemIds,
    required this.maxUsesPerUser,
    required this.scope,
    this.userRestriction,
    this.description,
    this.descriptionAr,
  });

  factory CouponModel.fromMap(Map<String, dynamic> map, String id) {
    // Helper function to convert to List<String>
    List<String> _convertToList(dynamic value) {
      if (value == null) return [];
      if (value is String) return value.isNotEmpty ? [value] : [];
      if (value is List) return List<String>.from(value);
      return [];
    }

    return CouponModel(
      id: id,
      code: map['code'] ?? '',
      type: map['type'] ?? 'percentage',
      value: (map['value'] as num).toDouble(),
      maxDiscount: (map['max_discount'] as num?)?.toDouble() ?? 0,
      minSubtotal: (map['min_subtotal'] as num?)?.toDouble() ?? 0,
      validFrom: (map['valid_from'] as Timestamp).toDate(),
      validUntil: (map['valid_until'] as Timestamp).toDate(),
      active: map['active'] ?? false,
      allowedUsers: _convertToList(map['allowed_users']),
      branchIds: _convertToList(map['branch_ids']),
      categoryIds: _convertToList(map['category_ids']),
      itemIds: _convertToList(map['item_ids']),
      maxUsesPerUser: map['maxUsesPerUser'] ?? 1,
      scope: map['scope'] ?? 'all',
      userRestriction: map['user_restriction'],
      description: map['description'],
      descriptionAr: map['description_ar'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'type': type,
      'value': value,
      'max_discount': maxDiscount,
      'min_subtotal': minSubtotal,
      'valid_from': validFrom,
      'valid_until': validUntil,
      'active': active,
      'allowed_users': allowedUsers,
      'branch_ids': branchIds,
      'category_ids': categoryIds,
      'item_ids': itemIds,
      'maxUsesPerUser': maxUsesPerUser,
      'scope': scope,
      'user_restriction': userRestriction,
      'description': description,
      'description_ar': descriptionAr,
    };
  }

  bool isValidForUser(String? userId, String branchId, String orderType) {
    final now = DateTime.now();

    // Basic validity checks
    if (!active) return false;
    if (now.isBefore(validFrom)) return false;
    if (now.isAfter(validUntil)) return false;

    // Scope check
    if (scope != 'all' && scope != orderType) return false;

    // Branch restriction check
    if (branchIds.isNotEmpty && !branchIds.contains(branchId)) return false;

    // User restriction checks
    if (allowedUsers.isNotEmpty &&
        (userId == null || !allowedUsers.contains(userId))) {
      return false;
    }

    if (userRestriction == 'new_user') {
      // Implement your new user check logic here
      return false;
    }

    return true;
  }
}

class CartModel {
  final String id;
  final String name;
  final String nameAr;
  final String imageUrl;
  final double price;
  final double? discountedPrice;
  int quantity;
  final Map<String, dynamic> variants;
  final List<String>? addons;
  String? couponCode;
  String? couponId;
  double? couponDiscount;

  CartModel({
    required this.id,
    required this.name,
    this.nameAr = '',
    required this.imageUrl,
    required this.price,
    required this.quantity,
    this.discountedPrice,
    this.variants = const {},
    this.addons,
    this.couponCode,
    this.couponId,
    this.couponDiscount,
  });

  String getLocalizedName(BuildContext context) {
    final isArabic =
        Provider.of<LanguageProvider>(context, listen: false).isArabic;
    return isArabic && (nameAr.isNotEmpty) ? nameAr : name;
  }

  // CORRECTED: This getter should use discountedPrice when available
  double get finalPrice {
    return discountedPrice ?? price;
  }

  // CORRECTED: This should use finalPrice for total calculation
  double get total {
    double baseTotal = finalPrice * quantity;
    // Subtract coupon discount if applied
    if (couponDiscount != null) {
      baseTotal -= couponDiscount!;
    }
    return baseTotal.clamp(0, double.infinity);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameAr': nameAr,
      'imageUrl': imageUrl,
      'price': price,
      'discountedPrice': discountedPrice,
      'quantity': quantity,
      'variants': variants,
      'addons': addons,
      'couponCode': couponCode,
      'couponId': couponId,
      'couponDiscount': couponDiscount,
    };
  }

  factory CartModel.fromMap(Map<String, dynamic> map) {
    return CartModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      nameAr: map['nameAr'],
      imageUrl: map['imageUrl'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      discountedPrice: map['discountedPrice']?.toDouble(),
      quantity: map['quantity'] ?? 1,
      variants: Map<String, dynamic>.from(map['variants'] ?? {}),
      addons: map['addons'] != null ? List<String>.from(map['addons']) : null,
      couponCode: map['couponCode'],
      couponId: map['couponId'],
      couponDiscount: map['couponDiscount']?.toDouble(),
    );
  }
}

class AppColors {
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color accentBlue = Color(0xFF64B5F6);
  static const Color white = Colors.white;
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color darkGrey = Color(0xFF333333);
}

class AppTextStyles {
  static final headline1 =
      TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2);
  static final headline2 = TextStyle(fontSize: 22, fontWeight: FontWeight.w600);
  static final bodyText1 = TextStyle(fontSize: 16);
  static final bodyText2 = TextStyle(fontSize: 14, color: AppColors.darkGrey);
  static final buttonText =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
}

class Branch {
  final String id;
  final String name;
  final bool isActive;
  final GeoPoint? geolocation;

  Branch({
    required this.id,
    required this.name,
    required this.isActive,
    this.geolocation,
  });
}
