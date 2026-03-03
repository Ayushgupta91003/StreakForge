import 'package:intl/intl.dart';

extension DateTimeExtension on DateTime {
  /// Returns date-only DateTime (strips time)
  DateTime get dateOnly => DateTime(year, month, day);

  /// Returns true if this date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Returns true if this date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Returns true if same day as other
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// Returns formatted date string
  String get formatted => DateFormat('MMM d, yyyy').format(this);

  /// Returns short date string
  String get shortFormatted => DateFormat('MMM d').format(this);

  /// Returns day of week name
  String get dayName => DateFormat('EEEE').format(this);

  /// Returns short day name
  String get shortDayName => DateFormat('EEE').format(this);

  /// Returns the start of the week (Monday)
  DateTime get startOfWeek {
    final diff = weekday - 1;
    return subtract(Duration(days: diff)).dateOnly;
  }

  /// Returns the end of the week (Sunday)
  DateTime get endOfWeek {
    final diff = 7 - weekday;
    return add(Duration(days: diff)).dateOnly;
  }

  /// Returns the start of the month
  DateTime get startOfMonth => DateTime(year, month, 1);

  /// Returns the end of the month
  DateTime get endOfMonth => DateTime(year, month + 1, 0);

  /// Returns the start of the year
  DateTime get startOfYear => DateTime(year, 1, 1);

  /// Returns number of days in this month
  int get daysInMonth => DateTime(year, month + 1, 0).day;

  /// Returns a list of all dates in this month
  List<DateTime> get datesInMonth {
    final count = daysInMonth;
    return List.generate(count, (i) => DateTime(year, month, i + 1));
  }

  /// Difference in calendar days (ignoring time)
  int daysDifference(DateTime other) {
    return dateOnly.difference(other.dateOnly).inDays;
  }
}

extension DateTimeNullableExtension on DateTime? {
  /// Returns formatted string or fallback
  String formattedOr(String fallback) {
    if (this == null) return fallback;
    return this!.formatted;
  }
}
