// NOTE ON COVERAGE / WHAT IS UNTESTABLE HERE
// -----------------------------------------------------------------------------
// RecurringExpenseRepository._getNextDueDate (the daily/weekly/monthly/yearly
// next-due computation, including the Jan-31 -> Feb-28/29 clamp) is a PRIVATE
// method. It is only reachable through the public processRecurringExpenses(),
// which depends on AppDatabase.database — a singleton backed by
// getDatabasesPath() with a hardcoded path that cannot be injected from a test.
// Standing up that whole path (and the expenses/recurring_expenses schema) just
// to indirectly exercise private date math is out of scope and brittle, so the
// private method itself is NOT tested directly here.
//
// Instead this file exercises the equivalent, PUBLIC, pure month/day-clamp date
// math that IS reachable: EmiCalculator.resolveEmiDate. It applies the same
// "clamp the requested day to the last valid day of the target month" rule that
// the recurring monthly/yearly branches use (day = min(startDate.day, lastDay)),
// so these tests cover the same Jan-31 -> Feb clamp behavior through a real,
// callable API without fabricating any method that does not exist.
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/core/utils/emi_calculator.dart';

void main() {
  group('Month/day clamp via EmiCalculator.resolveEmiDate (public equivalent)', () {
    // resolveEmiDate(firstEmiDate, deductionDay, monthIndex):
    //   target month = firstEmiDate.month + monthIndex
    //   day = deductionDay clamped to [1, lastDayOfTargetMonth]

    test('monthly from the 31st clamps into February (non-leap: 28)', () {
      // From Jan (firstEmi Jan 31), advance one month with deduction day 31.
      final feb = EmiCalculator.resolveEmiDate(DateTime(2026, 1, 31), 31, 1);
      expect(feb.year, 2026);
      expect(feb.month, 2);
      expect(feb.day, 28); // 2026 is not a leap year
    });

    test('monthly from the 31st clamps into February (leap: 29)', () {
      final feb = EmiCalculator.resolveEmiDate(DateTime(2024, 1, 31), 31, 1);
      expect(feb.month, 2);
      expect(feb.day, 29); // 2024 is a leap year
    });

    test('day within range is preserved (monthly, no clamp needed)', () {
      final mar = EmiCalculator.resolveEmiDate(DateTime(2026, 1, 15), 15, 2);
      expect(mar.month, 3);
      expect(mar.day, 15);
    });

    test('rolls over the year boundary correctly', () {
      // firstEmi Dec 2025, +1 month -> Jan 2026.
      final jan = EmiCalculator.resolveEmiDate(DateTime(2025, 12, 10), 10, 1);
      expect(jan.year, 2026);
      expect(jan.month, 1);
      expect(jan.day, 10);
    });

    test('31st clamps to 30 in a 30-day month (April)', () {
      // firstEmi Mar 31, +1 month -> April (30 days) -> clamp to 30.
      final apr = EmiCalculator.resolveEmiDate(DateTime(2026, 3, 31), 31, 1);
      expect(apr.month, 4);
      expect(apr.day, 30);
    });
  });
}
