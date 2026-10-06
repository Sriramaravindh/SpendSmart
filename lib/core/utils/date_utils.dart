import 'package:intl/intl.dart';

class AppDateUtils {
  static DateTime todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime todayEnd() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  static DateTime monthStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  static DateTime monthEnd() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
  }

  static DateTime weekStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - 6);
  }

  static int currentYearMonth() {
    final now = DateTime.now();
    return now.year * 100 + now.month;
  }

  static int elapsedDaysInMonth() {
    final now = DateTime.now();
    return now.day;
  }

  static int daysInMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0).day;
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatShortDate(DateTime date) {
    return DateFormat('dd MMM').format(date);
  }

  static String formatDayName(DateTime date) {
    return DateFormat('EEE').format(date);
  }

  static String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date);
    return DateFormat('dd MMM yyyy').format(date);
  }
}
