import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Services/language_provider.dart';
import '../Widgets/bottom_nav.dart';
import '../Widgets/models.dart';
import 'cartScreen.dart';
import '../Widgets/authentication.dart';

class CouponsScreen extends StatefulWidget {
  final CartService cartService;
  const CouponsScreen({Key? key, required this.cartService}) : super(key: key);

  @override
  _CouponsScreenState createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<CouponModel> _availableCoupons = [];
  bool _isLoading = true;
  bool _isApplyingCoupon = false;
  String? _applyingCouponId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAvailableCoupons();
  }

  Future<void> _loadAvailableCoupons() async {
    try {
      final user = _auth.currentUser;
      final userId = user != null ? AuthUtils.getDocId(user) : null;
      final snapshot = await FirebaseFirestore.instance
          .collection('coupons')
          .where('active', isEqualTo: true)
          .get();

      final now = DateTime.now();
      final coupons = snapshot.docs.map((doc) {
        return CouponModel.fromMap(doc.data(), doc.id);
      }).where((coupon) {
        return coupon.validFrom.isBefore(now) &&
            coupon.validUntil.isAfter(now) &&
            (coupon.allowedUsers.isEmpty ||
                (userId != null && coupon.allowedUsers.contains(userId)));
      }).toList();

      setState(() {
        _availableCoupons = coupons;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = AppStrings.get('failed_load_coupons', context);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: Text(
          AppStrings.get('available_coupons_title', context),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: AppColors.primaryBlue,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.get('loading_offers', context),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.get('try_again', context),
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_availableCoupons.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryBlue.withOpacity(0.1),
                      AppColors.primaryBlue.withOpacity(0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_offer_rounded,
                  size: 48,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.get('no_coupons', context),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.get('check_back_later', context),
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.primaryBlue.withOpacity(0.1),
                  AppColors.primaryBlue.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryBlue.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.percent_rounded,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppStrings.get('apply_coupons_msg', context),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ..._availableCoupons.map((coupon) {
            final isValid = _isCouponValidForCart(coupon);
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _buildModernCouponCard(coupon, isValid),
            );
          }),
          const SizedBox(height: 80), // Bottom padding for nav bar
        ],
      ),
    );
  }

  Widget _buildModernCouponCard(CouponModel coupon, bool isValid) {
    // Dynamic Localization Logic
    final isArabic = Provider.of<LanguageProvider>(context).isArabic;
    final locale = isArabic ? 'ar' : 'en';

    // 1. Discount Text
    final formattedValue = AppStrings.formatNumber(
        coupon.type == 'percentage'
            ? coupon.value.toStringAsFixed(0)
            : coupon.value.toString(),
        context);

    final discountText = coupon.type == 'percentage'
        ? '$formattedValue% ${AppStrings.get('off', context)}'
        : '$formattedValue ${AppStrings.get('qar', context)} ${AppStrings.get('off', context)}';

    // 2. Min Subtotal / Description
    String subtotalText;
    // Prefer description if available
    if (isArabic &&
        coupon.descriptionAr != null &&
        coupon.descriptionAr!.isNotEmpty) {
      subtotalText = coupon.descriptionAr!;
    } else if (coupon.description != null && coupon.description!.isNotEmpty) {
      subtotalText = coupon.description!;
    } else {
      // Fallback to constructed string
      if (coupon.minSubtotal > 0) {
        final formattedMin = AppStrings.formatNumber(
            coupon.minSubtotal.toStringAsFixed(0), context);
        subtotalText =
            '${AppStrings.get('on_orders_above', context)} ${AppStrings.get('qar', context)} $formattedMin';
      } else {
        subtotalText = AppStrings.get('on_all_orders', context);
      }
    }

    // 3. Validity Date
    final formattedDate =
        DateFormat('MMM dd, yyyy', locale).format(coupon.validUntil);
    // Explicitly format numbers in date for Arabic if needed (DateFormat usually handles this but good to ensure consistency if mixing)
    // Actually, DateFormat('...', 'ar') will use Arabic digits/months.

    final validityText =
        '${AppStrings.get('valid_until', context)} $formattedDate';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 20),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isValid
                      ? AppColors.primaryBlue.withOpacity(0.15)
                      : Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipPath(
              clipper: ModernCouponClipper(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: isValid
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            AppColors.primaryBlue.withOpacity(0.02),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.grey.shade50,
                            Colors.grey.shade100,
                          ],
                        ),
                  border: Border.all(
                    color: isValid
                        ? AppColors.primaryBlue.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row with discount and badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isValid
                                          ? [
                                              AppColors.primaryBlue,
                                              AppColors.primaryBlue
                                                  .withOpacity(0.8),
                                            ]
                                          : [
                                              Colors.grey.shade400,
                                              Colors.grey.shade500,
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isValid
                                            ? AppColors.primaryBlue
                                                .withOpacity(0.3)
                                            : Colors.grey.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    discountText,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  subtotalText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isValid
                                        ? Colors.black87
                                        : Colors.grey.shade600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Status indicator
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isValid
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isValid
                                  ? Icons.check_circle_rounded
                                  : Icons.info_rounded,
                              color: isValid ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Coupon code section
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isValid
                              ? AppColors.primaryBlue.withOpacity(0.08)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isValid
                                ? AppColors.primaryBlue.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.confirmation_number_rounded,
                              color: isValid
                                  ? AppColors.primaryBlue
                                  : Colors.grey.shade600,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${AppStrings.get('code', context)}: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              coupon.code,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isValid
                                    ? AppColors.primaryBlue
                                    : Colors.grey.shade700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Footer with validity and button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      validityText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (!isValid) ...[
                                  Text(
                                    AppStrings.get('not_applicable', context),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isValid
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primaryBlue
                                            .withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ElevatedButton(
                              onPressed: (isValid && !_isApplyingCoupon)
                                  ? () => _applyCoupon(coupon)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isValid
                                    ? AppColors.primaryBlue
                                    : Colors.grey.shade400,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: (_isApplyingCoupon &&
                                      _applyingCouponId == coupon.id)
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          AppStrings.get('apply', context),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isCouponValidForCart(CouponModel coupon) {
    final cartTotal = widget.cartService.totalAmount;
    if (coupon.minSubtotal > 0 && cartTotal < coupon.minSubtotal) {
      return false;
    }
    return true;
  }

  Future<void> _applyCoupon(CouponModel coupon) async {
    setState(() {
      _isApplyingCoupon = true;
      _applyingCouponId = coupon.id;
    });

    try {
      await widget.cartService.applyCoupon(coupon.code);
      if (!mounted) return;

      await showDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        builder: (ctx) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Coupon Applied!',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Text(
              '${coupon.code} ${AppStrings.get('coupon_applied_msg', context)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop(); // close dialog
                  BottomNavController.index.value = 3; // Cart tab
                  Navigator.of(context, rootNavigator: true)
                      .popUntil((r) => r.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  AppStrings.get('go_to_cart', context),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      // Show user-friendly error message
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (errorMessage.contains('usage limit')) {
        errorMessage = AppStrings.get('coupon_usage_limit_reached', context);
      }

      await showDialog(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  AppStrings.get('coupon_failed', context),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            errorMessage,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                AppStrings.get('ok', context),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingCoupon = false;
          _applyingCouponId = null;
        });
      }
    }
  }
}

class ModernCouponClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const notchRadius = 12.0;
    const cornerRadius = 20.0;

    final path = Path();

    // Start from top-left with rounded corner
    path.moveTo(cornerRadius, 0);
    path.lineTo(size.width - cornerRadius, 0);
    path.arcToPoint(
      Offset(size.width, cornerRadius),
      radius: const Radius.circular(cornerRadius),
    );

    // Right side with notch
    path.lineTo(size.width, size.height / 2 - notchRadius);
    path.arcToPoint(
      Offset(size.width - notchRadius, size.height / 2),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.arcToPoint(
      Offset(size.width, size.height / 2 + notchRadius),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );

    // Continue right side
    path.lineTo(size.width, size.height - cornerRadius);
    path.arcToPoint(
      Offset(size.width - cornerRadius, size.height),
      radius: const Radius.circular(cornerRadius),
    );

    // Bottom side
    path.lineTo(cornerRadius, size.height);
    path.arcToPoint(
      Offset(0, size.height - cornerRadius),
      radius: const Radius.circular(cornerRadius),
    );

    // Left side with notch
    path.lineTo(0, size.height / 2 + notchRadius);
    path.arcToPoint(
      Offset(notchRadius, size.height / 2),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.arcToPoint(
      Offset(0, size.height / 2 - notchRadius),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );

    // Continue left side
    path.lineTo(0, cornerRadius);
    path.arcToPoint(
      Offset(cornerRadius, 0),
      radius: const Radius.circular(cornerRadius),
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
