import 'package:flutter/foundation.dart';

/// Service to handle restaurant working hours logic.
/// Parses Firebase `workingHours` structure and calculates time until closing.
class WorkingHoursService {
  /// Threshold in minutes to show "closing soon" warning
  static const int closingSoonThresholdMinutes = 30;

  /// Day names as stored in Firebase (lowercase)
  static const List<String> _dayNames = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  /// Get the current day name in lowercase (matching Firebase keys)
  static String _getCurrentDayName() {
    final now = DateTime.now();
    // DateTime.weekday: Monday = 1, Sunday = 7
    return _dayNames[now.weekday - 1];
  }

  /// Parse time string "HH:mm" to minutes since midnight
  static int _parseTimeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return 0;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    return hours * 60 + minutes;
  }

  /// Check if restaurant is currently open and get time until closing.
  ///
  /// Returns a [WorkingHoursResult] with:
  /// - `isOpen`: whether the restaurant is currently open
  /// - `timeUntilClose`: Duration until closing (null if closed)
  /// - `isClosingSoon`: true if closing within [closingSoonThresholdMinutes]
  static WorkingHoursResult getClosingInfo(Map<String, dynamic>? workingHours) {
    if (workingHours == null || workingHours.isEmpty) {
      return WorkingHoursResult(
          isOpen: true, timeUntilClose: null, isClosingSoon: false);
    }

    try {
      final dayName = _getCurrentDayName();
      final dayData = workingHours[dayName] as Map<String, dynamic>?;

      if (dayData == null) {
        return WorkingHoursResult(
            isOpen: true, timeUntilClose: null, isClosingSoon: false);
      }

      final isOpen = dayData['isOpen'] as bool? ?? true;
      if (!isOpen) {
        return WorkingHoursResult(
            isOpen: false, timeUntilClose: null, isClosingSoon: false);
      }

      final slots = dayData['slots'] as List<dynamic>?;
      if (slots == null || slots.isEmpty) {
        return WorkingHoursResult(
            isOpen: true, timeUntilClose: null, isClosingSoon: false);
      }

      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;

      // Check each slot to find which one we're currently in
      for (final slot in slots) {
        final slotData = slot as Map<String, dynamic>;
        final openStr = slotData['open'] as String? ?? '00:00';
        final closeStr = slotData['close'] as String? ?? '23:59';

        int openMinutes = _parseTimeToMinutes(openStr);
        int closeMinutes = _parseTimeToMinutes(closeStr);

        // Handle overnight slots (e.g., open "13:00" close "00:00" means midnight)
        // If close is 00:00, treat it as 24:00 (end of day)
        if (closeMinutes == 0 && openMinutes > 0) {
          closeMinutes = 24 * 60; // Midnight = 1440 minutes
        }

        // Handle cases where close < open (overnight spanning to next day)
        // For now, we'll treat close as end of current day if it seems overnight
        if (closeMinutes < openMinutes) {
          // If current time is after open, assume close is next day (midnight + closeMinutes)
          if (currentMinutes >= openMinutes) {
            closeMinutes += 24 * 60;
          } else if (currentMinutes < closeMinutes) {
            // We're in the early morning part of an overnight slot
            // Treat open as previous day
            openMinutes -= 24 * 60;
          }
        }

        // Check if current time is within this slot
        if (currentMinutes >= openMinutes && currentMinutes < closeMinutes) {
          final minutesUntilClose = closeMinutes - currentMinutes;
          final timeUntilClose = Duration(minutes: minutesUntilClose);
          final isClosingSoon =
              minutesUntilClose <= closingSoonThresholdMinutes;

          return WorkingHoursResult(
            isOpen: true,
            timeUntilClose: timeUntilClose,
            isClosingSoon: isClosingSoon,
          );
        }
      }

      // Not within any slot - restaurant is closed during gap
      return WorkingHoursResult(
          isOpen: false, timeUntilClose: null, isClosingSoon: false);
    } catch (e) {
      debugPrint('Error parsing working hours: $e');
      // Fail open - assume open with no countdown
      return WorkingHoursResult(
          isOpen: true, timeUntilClose: null, isClosingSoon: false);
    }
  }

  /// Format duration as "Xh Ym" or "Ym" if less than an hour
  static String formatDuration(Duration duration,
      {bool useArabicNumerals = false}) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    // Use Arabic abbreviations when in Arabic mode
    final String hourUnit = useArabicNumerals ? 'س' : 'h'; // س = ساعة (hour)
    final String minUnit = useArabicNumerals ? 'د' : 'm'; // د = دقيقة (minute)

    String hoursStr = hours.toString();
    String minutesStr = minutes.toString();

    if (useArabicNumerals) {
      hoursStr = _toArabicNumerals(hoursStr);
      minutesStr = _toArabicNumerals(minutesStr);
    }

    if (hours > 0) {
      return '$hoursStr$hourUnit $minutesStr$minUnit';
    } else {
      return '$minutesStr$minUnit';
    }
  }

  /// Convert digits to Arabic numerals
  static String _toArabicNumerals(String str) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    for (int i = 0; i < english.length; i++) {
      str = str.replaceAll(english[i], arabic[i]);
    }
    return str;
  }
}

/// Result of working hours calculation
class WorkingHoursResult {
  final bool isOpen;
  final Duration? timeUntilClose;
  final bool isClosingSoon;

  WorkingHoursResult({
    required this.isOpen,
    required this.timeUntilClose,
    required this.isClosingSoon,
  });
}
