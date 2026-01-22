// Adaptive loading indicator widget
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../Utils/platform_utils.dart';

/// A platform-adaptive loading indicator.
/// Uses CupertinoActivityIndicator on iOS and CircularProgressIndicator on Android.
class AdaptiveLoadingIndicator extends StatelessWidget {
  final double? radius;
  final Color? color;
  final double? strokeWidth;

  const AdaptiveLoadingIndicator({
    super.key,
    this.radius,
    this.color,
    this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoActivityIndicator(
        radius: radius ?? 10.0,
        color: color,
      );
    }

    return SizedBox(
      width: (radius ?? 10.0) * 2,
      height: (radius ?? 10.0) * 2,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth ?? 2.5,
        valueColor:
            color != null ? AlwaysStoppedAnimation<Color>(color!) : null,
      ),
    );
  }
}

/// A centered adaptive loading indicator for full-screen loading states.
class AdaptiveLoadingScreen extends StatelessWidget {
  final Color? color;
  final String? message;

  const AdaptiveLoadingScreen({
    super.key,
    this.color,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdaptiveLoadingIndicator(radius: 14, color: color),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
