// Adaptive dialog helpers for platform-specific dialogs
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'platform_utils.dart';

/// Shows a platform-adaptive alert dialog.
/// Uses CupertinoAlertDialog on iOS and AlertDialog on Android.
Future<T?> showAdaptiveDialog<T>({
  required BuildContext context,
  required String title,
  required String content,
  String? confirmText,
  String? cancelText,
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
  bool isDestructive = false,
  Color? confirmColor,
}) {
  if (PlatformUtils.isIOS) {
    return showCupertinoDialog<T>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          if (cancelText != null)
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(context).pop();
                onCancel?.call();
              },
              child: Text(cancelText),
            ),
          if (confirmText != null)
            CupertinoDialogAction(
              isDestructiveAction: isDestructive,
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm?.call();
              },
              child: Text(confirmText),
            ),
        ],
      ),
    );
  }

  // Material dialog for Android
  return showDialog<T>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
      ),
      content: Text(
        content,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
      actions: [
        if (cancelText != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onCancel?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
            child: Text(
              cancelText,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        if (confirmText != null)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor ??
                  (isDestructive ? Colors.red : Theme.of(context).primaryColor),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              confirmText,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    ),
  );
}

/// Shows a platform-adaptive dialog with custom content widget.
Future<T?> showAdaptiveCustomDialog<T>({
  required BuildContext context,
  required Widget child,
  bool barrierDismissible = true,
}) {
  if (PlatformUtils.isIOS) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => child,
    );
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => child,
  );
}
