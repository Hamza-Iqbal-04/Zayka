import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import '../Services/language_provider.dart';
import '../Widgets/models.dart';

class RatingPopup extends StatefulWidget {
  final Map<String, dynamic> order;
  final String orderId;

  const RatingPopup({Key? key, required this.order, required this.orderId})
      : super(key: key);

  @override
  State<RatingPopup> createState() => _RatingPopupState();
}

class _RatingPopupState extends State<RatingPopup> {
  int _orderRating = 0;
  int _driverRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitRating() async {
    if (_orderRating == 0 || _driverRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('please_rate_both', context)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final String driverEmail = widget.order['riderId'] ?? '';

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference orderRef =
            FirebaseFirestore.instance.collection('Orders').doc(widget.orderId);

        // 1. Perform all reads first
        DocumentSnapshot? driverSnap;
        DocumentReference? driverRef;
        if (driverEmail.isNotEmpty) {
          driverRef =
              FirebaseFirestore.instance.collection('Drivers').doc(driverEmail);
          driverSnap = await transaction.get(driverRef);
        }

        // 2. Perform all writes
        transaction.update(orderRef, {
          'orderRating': _orderRating,
          'driverRating': _driverRating,
          'ratingComment': _commentController.text,
          'ratingPopUpShown': true,
        });

        if (driverSnap != null && driverSnap.exists && driverRef != null) {
          Map<String, dynamic> driverData =
              driverSnap.data() as Map<String, dynamic>;
          int count = (driverData['ratingCount'] ?? 0) + 1;
          double sum =
              ((driverData['totalRatingSum'] ?? 0.0) as num).toDouble() +
                  _driverRating;
          double average = sum / count;

          transaction.update(driverRef, {
            'ratingCount': count,
            'totalRatingSum': sum,
            'rating': average,
          });
        }
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error submitting rating: $e");
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('error_submitting', context)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _skipRating() async {
    try {
      await FirebaseFirestore.instance
          .collection('Orders')
          .doc(widget.orderId)
          .update({'ratingPopUpShown': true});
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error skipping rating: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryBlue.withOpacity(0.05),
                            AppColors.primaryBlue.withOpacity(0.15)
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28)),
                      ),
                    ),
                    Positioned(
                      top: 24,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.stars_rounded,
                          color: Color(0xFFFFB300),
                          size: 48,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    children: [
                      Text(
                        AppStrings.get('enjoy_your_meal', context),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // NEW: Delivery Time Logic
                      Builder(builder: (context) {
                        final timestamp =
                            widget.order['timestamp'] as Timestamp?;
                        if (timestamp == null) return const SizedBox.shrink();

                        // Priority: use actual delivery timestamp if it exists, otherwise fallback to now
                        final deliveryTimestamp =
                            widget.order['deliveredAt'] as Timestamp? ??
                                widget.order['delivered_at'] as Timestamp? ??
                                widget.order['completedAt'] as Timestamp? ??
                                Timestamp.now();

                        final duration = deliveryTimestamp
                            .toDate()
                            .difference(timestamp.toDate());
                        final minutes = duration.inMinutes;

                        // If the duration is negative or unrealistically long, skip
                        if (minutes < -1 || minutes > 120)
                          return const SizedBox.shrink();

                        String timeText = '';
                        if (minutes < 1) {
                          timeText = AppStrings.get(
                              'reached_you_in_less_than_minute', context);
                        } else {
                          timeText = AppStrings.get(
                                  'reached_you_in_minutes', context)
                              .replaceAll('{minutes}',
                                  AppStrings.formatNumber(minutes, context));
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            timeText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }),
                      Text(
                        AppStrings.get('how_was_your_experience', context),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildRatingRow(
                        title: AppStrings.get('rate_food', context),
                        rating: _orderRating,
                        onChanged: (val) => setState(() => _orderRating = val),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1, thickness: 0.5),
                      ),
                      _buildRatingRow(
                        title: AppStrings.get('rate_driver', context),
                        rating: _driverRating,
                        onChanged: (val) => setState(() => _driverRating = val),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _commentController,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: AppStrings.get('optional_comment', context),
                          hintStyle: TextStyle(
                              fontSize: 14, color: Colors.grey.shade400),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                                color: AppColors.primaryBlue.withOpacity(0.5)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_isSubmitting)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        )
                      else
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _submitRating,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  AppStrings.get('submit', context),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _skipRating,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey.shade500,
                              ),
                              child: Text(
                                AppStrings.get('skip', context),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingRow({
    required String title,
    required int rating,
    required Function(int) onChanged,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final isSelected = index < rating;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onChanged(index + 1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isSelected
                      ? const Color(0xFFFFB300)
                      : Colors.grey.shade300,
                  size: 40,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
