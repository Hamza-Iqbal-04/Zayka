// Adaptive text field widget
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../Utils/platform_utils.dart';

/// A platform-adaptive text field.
/// Uses CupertinoTextField on iOS and TextField on Android.
class AdaptiveTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? placeholder;
  final String? labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool autofocus;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final Widget? prefix;
  final Widget? suffix;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final EdgeInsetsGeometry? padding;
  final InputDecoration? decoration;
  final BoxDecoration? iosDecoration;

  const AdaptiveTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefix,
    this.suffix,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.padding,
    this.decoration,
    this.iosDecoration,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoTextField(
        controller: controller,
        placeholder: placeholder ?? hintText,
        keyboardType: keyboardType,
        obscureText: obscureText,
        autofocus: autofocus,
        enabled: enabled,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        prefix: prefix ??
            (prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: prefixIcon,
                  )
                : null),
        suffix: suffix ??
            (suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: suffixIcon,
                  )
                : null),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: onTap,
        focusNode: focusNode,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: iosDecoration ??
            BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(10),
            ),
        style: const TextStyle(fontSize: 16),
      );
    }

    // Material TextField for Android
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofocus: autofocus,
      enabled: enabled,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      focusNode: focusNode,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      decoration: decoration ??
          InputDecoration(
            labelText: labelText,
            hintText: hintText ?? placeholder,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            prefix: prefix,
            suffix: suffix,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
    );
  }
}
