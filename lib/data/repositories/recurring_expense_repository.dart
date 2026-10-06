import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models.dart';

class RecurringExpenseRepository {
  Future<Database> get _db => AppDatabase.database;

  Future<List<RecurringExpense>> getAll() async {
    final db = await _db;
    final maps = await db.query('recurring_expenses', orderBy: 'isActive DESC, startDate DESC');
    return maps.map((m) => RecurringExpense.fromMap(m)).toList();
  }

  Future<List<RecurringExpense>> getActive() async {
    final db = await _db;
    final maps = await db.query('recurring_expenses', where: 'isActive = 1');
    return maps.map((m) => RecurringExpense.fromMap(m)).toList();
  }

  Future<int> insert(RecurringExpense re) async {
    final db = await _db;
    return db.insert('recurring_expenses', re.toMap());
  }

  Future<void> update(RecurringExpense re) async {
    final db = await _db;
    await db.update('recurring_expenses', re.toMap(), where: 'id = ?', whereArgs: [re.id]);
  }

  Future<void> updateLastProcessed(int id, DateTime date) async {
    final db = await _db;
    await db.update('recurring_expenses', {'lastProcessedDate': date.millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleActive(int id, bool active) async {
    final db = await _db;
    await db.update('recurring_expenses', {'isActive': active ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('recurring_expenses', where: 'id = ?', whereArgs: [id]);
  }

  /// Process all active recurring expenses, creating expense entries for any
  /// that are due. Handles multiple missed periods (e.g., if app wasn't opened
  /// for weeks). Returns the number of expenses created.
  Future<int> processRecurringExpenses() async {
    final db = await _db;
    final activeList = await getActive();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int created = 0;

    for (final re in activeList) {
      // Skip if endDate has passed
      if (re.endDate != null && today.isAfter(re.endDate!)) {
        continue;
      }

      // Determine the starting point for processing
      DateTime nextDue;
      if (re.lastProcessedDate != null) {
        nextDue = _getNextDueDate(re.lastProcessedDate!, re.frequency, re.startDate);
      } else {
        nextDue = DateTime(re.startDate.year, re.startDate.month, re.startDate.day);
      }

      // Create expense entries for each missed period up to today
      DateTime? lastCreated;
      while (!nextDue.isAfter(today)) {
        // Check endDate for each occurrence
        if (re.endDate != null && nextDue.isAfter(re.endDate!)) {
          break;
        }

        final expense = Expense(
          amount: re.amount,
          categoryId: re.categoryId,
          paymentMethodId: re.paymentMethodId,
          note: re.note,
          date: DateTime(nextDue.year, nextDue.month, nextDue.day, now.hour, now.minute),
          type: 'EXPENSE',
        );
        await db.insert('expenses', expense.toMap());
        lastCreated = nextDue;
        created++;

        nextDue = _getNextDueDate(nextDue, re.frequency, re.startDate);
      }

      if (lastCreated != null) {
        await updateLastProcessed(re.id!, lastCreated);
      }
    }

    return created;
  }

  /// Calculate the next due date from a given date, respecting the original
  /// startDate day for monthly/yearly to avoid date drift.
  DateTime _getNextDueDate(DateTime fromDate, String frequency, DateTime startDate) {
    switch (frequency) {
      case 'daily':
        // Calendar-based step avoids DST drift from Duration(days: 1).
        return DateTime(fromDate.year, fromDate.month, fromDate.day + 1);
      case 'weekly':
        // Calendar-based step avoids DST drift from Duration(days: 7).
        return DateTime(fromDate.year, fromDate.month, fromDate.day + 7);
      case 'monthly':
        final nextMonth = fromDate.month + 1;
        final nextYear = fromDate.year + (nextMonth > 12 ? 1 : 0);
        final actualMonth = nextMonth > 12 ? nextMonth - 12 : nextMonth;
        final lastDay = DateTime(nextYear, actualMonth + 1, 0).day;
        final day = startDate.day > lastDay ? lastDay : startDate.day;
        return DateTime(nextYear, actualMonth, day);
      case 'yearly':
        final nextYear = fromDate.year + 1;
        final lastDay = DateTime(nextYear, startDate.month + 1, 0).day;
        final day = startDate.day > lastDay ? lastDay : startDate.day;
        return DateTime(nextYear, startDate.month, day);
      default:
        // Unknown frequency: warn and default to a month-aware calendar step
        // rather than a flat 30-day jump.
        debugPrint('WARNING: unknown recurring frequency "$frequency", defaulting to monthly');
        final nextMonth = fromDate.month + 1;
        final nextYear = fromDate.year + (nextMonth > 12 ? 1 : 0);
        final actualMonth = nextMonth > 12 ? nextMonth - 12 : nextMonth;
        final lastDay = DateTime(nextYear, actualMonth + 1, 0).day;
        final day = startDate.day > lastDay ? lastDay : startDate.day;
        return DateTime(nextYear, actualMonth, day);
    }
  }
}
