// Adaptive app bar widget
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../Utils/platform_utils.dart';

/// A platform-adaptive app bar.
/// Uses CupertinoNavigationBar (with glassmorphism) on iOS and AppBar on Android.
class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final double? elevation;
  final bool centerTitle;

  const AdaptiveAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.elevation,
    this.centerTitle = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        PlatformUtils.isIOS ? 44.0 : kToolbarHeight,
      );

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoNavigationBar(
        // Glassmorphism effect - translucent background with blur
        backgroundColor: backgroundColor?.withOpacity(0.9) ??
            CupertinoColors.systemBackground
                .resolveFrom(context)
                .withOpacity(0.9),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.0, // One physical pixel
          ),
        ),
        middle: titleWidget ??
            (title != null
                ? Text(
                    title!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null),
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        trailing: actions != null && actions!.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: actions!,
              )
            : null,
      );
    }

    // Material AppBar for Android
    return AppBar(
      title: titleWidget ??
          (title != null
              ? Text(
                  title!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )
              : null),
      leading: leading,
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor ?? Colors.white,
      elevation: elevation ?? 0,
      centerTitle: centerTitle,
      foregroundColor: Colors.black87,
    );
  }
}

/// A platform-adaptive sliver app bar for use in CustomScrollView.
/// Uses CupertinoSliverNavigationBar on iOS and SliverAppBar on Android.
class AdaptiveSliverAppBar extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final String? largeTitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final bool pinned;
  final bool floating;
  final double? expandedHeight;
  final Widget? flexibleSpace;

  const AdaptiveSliverAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.largeTitle,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.pinned = true,
    this.floating = false,
    this.expandedHeight,
    this.flexibleSpace,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoSliverNavigationBar(
        // Glassmorphism effect
        backgroundColor: backgroundColor?.withOpacity(0.9) ??
            CupertinoColors.systemBackground
                .resolveFrom(context)
                .withOpacity(0.9),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.0,
          ),
        ),
        largeTitle: Text(
          largeTitle ?? title ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        middle: titleWidget ??
            (title != null
                ? Text(
                    title!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  )
                : null),
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        trailing: actions != null && actions!.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: actions!,
              )
            : null,
      );
    }

    // Material SliverAppBar for Android
    return SliverAppBar(
      title: titleWidget ??
          (title != null
              ? Text(
                  title!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )
              : null),
      leading: leading,
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor ?? Colors.white,
      pinned: pinned,
      floating: floating,
      expandedHeight: expandedHeight,
      flexibleSpace: flexibleSpace,
      foregroundColor: Colors.black87,
      elevation: 0,
    );
  }
}
