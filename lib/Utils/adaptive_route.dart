// Adaptive page route helper
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'platform_utils.dart';

/// Creates a platform-adaptive page route.
/// Uses CupertinoPageRoute on iOS (with native swipe-back gesture)
/// and MaterialPageRoute on Android.
Route<T> adaptivePageRoute<T>({
  required Widget page,
  RouteSettings? settings,
  bool maintainState = true,
  bool fullscreenDialog = false,
}) {
  if (PlatformUtils.isIOS) {
    return CupertinoPageRoute<T>(
      builder: (context) => page,
      settings: settings,
      maintainState: maintainState,
      fullscreenDialog: fullscreenDialog,
    );
  }

  return MaterialPageRoute<T>(
    builder: (context) => page,
    settings: settings,
    maintainState: maintainState,
    fullscreenDialog: fullscreenDialog,
  );
}

/// Extension on Navigator for easier adaptive navigation
extension AdaptiveNavigator on NavigatorState {
  /// Push a new page using adaptive route
  Future<T?> pushAdaptive<T extends Object?>(Widget page) {
    return push(adaptivePageRoute<T>(page: page));
  }

  /// Push a new page and replace current using adaptive route
  Future<T?> pushReplacementAdaptive<T extends Object?, TO extends Object?>(
    Widget page, {
    TO? result,
  }) {
    return pushReplacement(adaptivePageRoute<T>(page: page), result: result);
  }

  /// Push a new page and remove all previous routes using adaptive route
  Future<T?> pushAndRemoveUntilAdaptive<T extends Object?>(
    Widget page,
    bool Function(Route<dynamic>) predicate,
  ) {
    return pushAndRemoveUntil(adaptivePageRoute<T>(page: page), predicate);
  }
}

/// Extension on BuildContext for easier adaptive navigation
extension AdaptiveNavigatorContext on BuildContext {
  /// Push a new page using adaptive route
  Future<T?> pushAdaptive<T extends Object?>(Widget page) {
    return Navigator.of(this).pushAdaptive(page);
  }

  /// Push a new page and replace current using adaptive route
  Future<T?> pushReplacementAdaptive<T extends Object?, TO extends Object?>(
    Widget page, {
    TO? result,
  }) {
    return Navigator.of(this).pushReplacementAdaptive(page, result: result);
  }
}
