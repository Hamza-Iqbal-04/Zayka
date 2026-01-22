// Platform detection utility for adaptive UI
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Utility class for platform detection to enable adaptive UI.
/// Use these getters to conditionally render Cupertino widgets on iOS
/// and Material widgets on Android.
class PlatformUtils {
  /// Returns true if running on iOS (not web)
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Returns true if running on Android (not web)
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Returns true if running on mobile (iOS or Android)
  static bool get isMobile => isIOS || isAndroid;

  /// Returns true if running on web
  static bool get isWeb => kIsWeb;

  /// Returns true if running on desktop (Windows, macOS, Linux)
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
}
