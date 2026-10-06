import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models.dart';
import '../utils/date_utils.dart';

/// Wraps flutter_local_notifications + timezone for due-date reminders.
///
/// Static methods only (matches DriveBackupService style). Everything is wrapped
/// in try/catch + debugPrint so a missing permission or an unsupported platform
/// never crashes the app.
///
/// NOTE: this file targets flutter_local_notifications ^17.x and timezone ^0.9.x.
/// If you bump those packages, re-verify the plugin APIs flagged with
/// `// TODO: verify against installed version` below.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Local notifications are not supported on web; all methods no-op there so
  /// the plugin's uninitialized web instance is never touched.
  static bool get _supported => !kIsWeb;

  static const String _channelId = 'due_reminders';
  static const String _channelName = 'Due-date reminders';
  static const String _channelDescription =
      'Reminders for upcoming recurring expenses and loan EMIs';

  static Future<void> init() async {
    if (!_supported || _initialized) return;
    try {
      tzdata.initializeTimeZones();
      // We cannot reliably read the device IANA zone without an extra plugin, so
      // keep the tz default (UTC). zonedSchedule below converts local DateTimes
      // via tz.local, which remains correct for relative "X days before" offsets.
      // TODO: verify against installed version — optionally set tz.setLocalLocation()
      // using flutter_timezone if exact wall-clock accuracy across zones matters.

      const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _plugin.initialize(initSettings);
      await _requestPermissions();
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService.init error: $e');
    }
  }

  static Future<void> _requestPermissions() async {
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Android 13+ runtime notification permission.
      await androidImpl?.requestNotificationsPermission();

      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('NotificationService._requestPermissions error: $e');
    }
  }

  static NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    return const NotificationDetails(android: android, iOS: ios);
  }

  /// Schedule a one-off reminder at [when] (local time). Past times are skipped.
  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (!_supported) return;
    try {
      if (!_initialized) await init();
      if (when.isBefore(DateTime.now())) return;
      final tzWhen = tz.TZDateTime.from(when, tz.local);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzWhen,
        _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('NotificationService.scheduleReminder error: $e');
    }
  }

  static Future<void> cancel(int id) async {
    if (!_supported) return;
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('NotificationService.cancel error: $e');
    }
  }

  static Future<void> cancelAll() async {
    if (!_supported) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('NotificationService.cancelAll error: $e');
    }
  }

  /// Cancel all pending reminders and re-schedule one per active recurring
  /// (next due date) and per active loan (next EMI deduction day), each fired
  /// [leadDays] before the due date at 9am local.
  static Future<void> rescheduleAll(
    List<RecurringExpense> recurrings,
    List<Loan> loans,
    int leadDays, {
    String currencySymbol = '',
  }) async {
    if (!_supported) return;
    try {
      if (!_initialized) await init();
      await cancelAll();

      final now = DateTime.now();
      // Use distinct id ranges so recurrings and loans never collide.
      int recId = 1000;
      for (final re in recurrings) {
        if (!re.isActive) continue;
        final due = _nextRecurringDue(re, now);
        if (due == null) continue;
        final fireAt = _remindAt(due, leadDays);
        if (fireAt.isBefore(now)) continue;
        await scheduleReminder(
          id: recId++,
          title: 'Upcoming recurring payment',
          body:
              '${re.note?.isNotEmpty == true ? re.note : 'Recurring expense'} of $currencySymbol${re.amount.toStringAsFixed(2)} is due on ${_fmt(due)}.',
          when: fireAt,
        );
      }

      int loanId = 5000;
      for (final loan in loans) {
        if (!loan.isActive) continue;
        final due = _nextLoanDeduction(loan, now);
        if (due == null) continue;
        final fireAt = _remindAt(due, leadDays);
        if (fireAt.isBefore(now)) continue;
        await scheduleReminder(
          id: loanId++,
          title: 'Upcoming EMI',
          body:
              '${loan.name} EMI of $currencySymbol${loan.emiAmount.toStringAsFixed(2)} is due on ${_fmt(due)}.',
          when: fireAt,
        );
      }
    } catch (e) {
      debugPrint('NotificationService.rescheduleAll error: $e');
    }
  }

  // --- helpers ---

  static DateTime _remindAt(DateTime due, int leadDays) {
    final d = DateTime(due.year, due.month, due.day)
        .subtract(Duration(days: leadDays < 0 ? 0 : leadDays));
    return DateTime(d.year, d.month, d.day, 9, 0);
  }

  static String _fmt(DateTime d) => AppDateUtils.formatRelativeDate(
      DateTime(d.year, d.month, d.day));

  /// Next due date for a recurring expense on/after [from].
  static DateTime? _nextRecurringDue(RecurringExpense re, DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    DateTime candidate = DateTime(re.startDate.year, re.startDate.month, re.startDate.day);
    if (re.lastProcessedDate != null) {
      candidate = _stepFrequency(
          DateTime(re.lastProcessedDate!.year, re.lastProcessedDate!.month,
              re.lastProcessedDate!.day),
          re.frequency,
          re.startDate);
    }
    // Advance until we reach today or later (bounded to avoid infinite loops).
    int guard = 0;
    while (candidate.isBefore(today) && guard < 1000) {
      candidate = _stepFrequency(candidate, re.frequency, re.startDate);
      guard++;
    }
    if (re.endDate != null && candidate.isAfter(re.endDate!)) return null;
    return candidate;
  }

  static DateTime _stepFrequency(DateTime from, String frequency, DateTime startDate) {
    switch (frequency) {
      case 'daily':
        return DateTime(from.year, from.month, from.day + 1);
      case 'weekly':
        return DateTime(from.year, from.month, from.day + 7);
      case 'yearly':
        final nextYear = from.year + 1;
        final lastDay = DateTime(nextYear, startDate.month + 1, 0).day;
        final day = startDate.day > lastDay ? lastDay : startDate.day;
        return DateTime(nextYear, startDate.month, day);
      case 'monthly':
      default:
        final nextMonth = from.month + 1;
        final nextYear = from.year + (nextMonth > 12 ? 1 : 0);
        final actualMonth = nextMonth > 12 ? nextMonth - 12 : nextMonth;
        final lastDay = DateTime(nextYear, actualMonth + 1, 0).day;
        final day = startDate.day > lastDay ? lastDay : startDate.day;
        return DateTime(nextYear, actualMonth, day);
    }
  }

  /// Next EMI deduction date for a loan on/after today (this month if the day
  /// hasn't passed, else next month), clamped to the month length.
  static DateTime? _nextLoanDeduction(Loan loan, DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    int year = from.year;
    int month = from.month;
    for (int i = 0; i < 2; i++) {
      final lastDay = DateTime(year, month + 1, 0).day;
      final day = loan.deductionDay.clamp(1, lastDay);
      final candidate = DateTime(year, month, day);
      if (!candidate.isBefore(today)) return candidate;
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
    return null;
  }
}
