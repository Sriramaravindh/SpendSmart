import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/core/utils/emi_calculator.dart';
import 'package:expense_tracker/data/models.dart';

void main() {
  group('EmiCalculator.round2', () {
    test('rounds half up at the paise boundary', () {
      expect(EmiCalculator.round2(3.145), 3.15);
      expect(EmiCalculator.round2(3.144), 3.14);
    });

    test('leaves already-2dp values unchanged', () {
      expect(EmiCalculator.round2(100.00), 100.0);
      expect(EmiCalculator.round2(0.0), 0.0);
    });

    test('rounds up a long decimal', () {
      expect(EmiCalculator.round2(2932.336), 2932.34);
    });

    test('handles negative values', () {
      // (-3.145 * 100) = -314.5 -> roundToDouble() -> -314.0 (round half to even/away varies),
      // assert it stays within 2dp precision bounds.
      final r = EmiCalculator.round2(-3.156);
      expect(r, closeTo(-3.16, 0.0001));
    });
  });

  group('EmiCalculator.getRateForDate', () {
    test('returns defaultRate when history is empty', () {
      expect(
        EmiCalculator.getRateForDate(DateTime(2025, 1, 1), 9.5, const []),
        9.5,
      );
    });

    test('picks the correct rate by date across several changes', () {
      final history = [
        LoanRateChange(loanId: 1, effectiveDate: DateTime(2025, 2, 1), rate: 8.60),
        LoanRateChange(loanId: 1, effectiveDate: DateTime(2025, 3, 1), rate: 8.35),
        LoanRateChange(loanId: 1, effectiveDate: DateTime(2025, 7, 1), rate: 7.60),
      ];
      // Before any change -> default.
      expect(EmiCalculator.getRateForDate(DateTime(2025, 1, 15), 9.0, history), 9.0);
      // On/after first change.
      expect(EmiCalculator.getRateForDate(DateTime(2025, 2, 1), 9.0, history), 8.60);
      expect(EmiCalculator.getRateForDate(DateTime(2025, 2, 28), 9.0, history), 8.60);
      // After second.
      expect(EmiCalculator.getRateForDate(DateTime(2025, 5, 1), 9.0, history), 8.35);
      // After third.
      expect(EmiCalculator.getRateForDate(DateTime(2025, 8, 1), 9.0, history), 7.60);
    });

    test('normalizes effective date to date-only (time of day ignored)', () {
      // Rate effective 2025-01-01 but stored with a 10:30 time component.
      final history = [
        LoanRateChange(
          loanId: 1,
          effectiveDate: DateTime(2025, 1, 1, 10, 30),
          rate: 7.0,
        ),
      ];
      // A midnight EMI date on 2025-01-01 must still get the new rate,
      // even though midnight is "before" 10:30 on the same calendar day.
      expect(
        EmiCalculator.getRateForDate(DateTime(2025, 1, 1), 9.0, history),
        7.0,
      );
    });
  });

  group('EmiCalculator.generateSchedule', () {
    test('a normal loan fully amortizes to ~0 closing balance', () {
      final emi = EmiCalculator.calculateEmiByFormula(
        principal: 120000,
        tenureMonths: 12,
        interestRate: 10.0,
      );
      final schedule = EmiCalculator.generateSchedule(
        principal: 120000,
        emiAmount: emi,
        tenureMonths: 12,
        deductionDay: 5,
        disbursementDate: DateTime(2025, 1, 1),
        firstEmiDate: DateTime(2025, 2, 5),
        defaultInterestRate: 10.0,
      );
      expect(schedule, isNotEmpty);
      expect(schedule.length, closeTo(12, 1));
      expect(schedule.last.closingBalance, lessThanOrEqualTo(0.01));
    });

    test('residual-plug fix: too-small EMI still closes to ~0 via final row', () {
      // Deliberately pick an EMI far below the amount needed to amortize a
      // large loan within tenure. The schedule should NOT be left with a
      // residual; a final plug row must drive closingBalance to ~0.
      final schedule = EmiCalculator.generateSchedule(
        principal: 500000,
        emiAmount: 1000, // way too small to clear 5L
        tenureMonths: 12,
        deductionDay: 5,
        disbursementDate: DateTime(2025, 1, 1),
        firstEmiDate: DateTime(2025, 2, 5),
        defaultInterestRate: 10.0,
      );
      expect(schedule, isNotEmpty);
      // The final row must close the balance to effectively zero.
      expect(schedule.last.closingBalance, lessThanOrEqualTo(0.01));
    });

    test('empty schedule guard: zero principal produces no residual crash', () {
      final schedule = EmiCalculator.generateSchedule(
        principal: 0,
        emiAmount: 1000,
        tenureMonths: 12,
        deductionDay: 5,
        disbursementDate: DateTime(2025, 1, 1),
        firstEmiDate: DateTime(2025, 2, 5),
        defaultInterestRate: 10.0,
      );
      // With no balance there is nothing to amortize beyond the guard; the
      // closing balance (if any rows) must be <= 0.01.
      if (schedule.isNotEmpty) {
        expect(schedule.last.closingBalance, lessThanOrEqualTo(0.01));
      }
    });
  });
}
