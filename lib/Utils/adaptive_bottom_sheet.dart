// Adaptive bottom sheet helpers for platform-specific action sheets
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'platform_utils.dart';

/// Action item for adaptive action sheets
class AdaptiveAction {
  final String title;
  final VoidCallback onPressed;
  final bool isDestructive;
  final bool isDefault;
  final IconData? icon;

  const AdaptiveAction({
    required this.title,
    required this.onPressed,
    this.isDestructive = false,
    this.isDefault = false,
    this.icon,
  });
}

/// Shows a platform-adaptive action sheet.
/// Uses CupertinoActionSheet on iOS and showModalBottomSheet on Android.
Future<T?> showAdaptiveActionSheet<T>({
  required BuildContext context,
  String? title,
  String? message,
  required List<AdaptiveAction> actions,
  String? cancelText,
}) {
  if (PlatformUtils.isIOS) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: title != null ? Text(title) : null,
        message: message != null ? Text(message) : null,
        actions: actions
            .map(
              (action) => CupertinoActionSheetAction(
                isDestructiveAction: action.isDestructive,
                isDefaultAction: action.isDefault,
                onPressed: () {
                  Navigator.of(context).pop();
                  action.onPressed();
                },
                child: Text(action.title),
              ),
            )
            .toList(),
        cancelButton: cancelText != null
            ? CupertinoActionSheetAction(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(cancelText),
              )
            : null,
      ),
    );
  }

  // Material bottom sheet for Android
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (title != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 8),
            ...actions.map(
              (action) => ListTile(
                leading: action.icon != null
                    ? Icon(
                        action.icon,
                        color: action.isDestructive ? Colors.red : null,
                      )
                    : null,
                title: Text(
                  action.title,
                  style: TextStyle(
                    color: action.isDestructive ? Colors.red : null,
                    fontWeight: action.isDefault ? FontWeight.bold : null,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  action.onPressed();
                },
              ),
            ),
            if (cancelText != null) ...[
              const Divider(),
              ListTile(
                title: Text(
                  cancelText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Shows a platform-adaptive modal bottom sheet with custom content.
Future<T?> showAdaptiveBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
}) {
  if (PlatformUtils.isIOS) {
    return showCupertinoModalPopup<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: backgroundColor ??
              CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(child: builder(context)),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(child: builder(context)),
    ),
  );
}
