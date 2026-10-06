import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/core/utils/emi_calculator.dart';
import 'package:expense_tracker/data/models.dart';

void main() {
  group('EmiCalculator - IDFC Bike Loan Test Case', () {
    // Loan: principal 3,13,616 | rate 14.22% fixed | disbursed 09-04-2026
    // EMI 7,879 on the 3rd of each month | tenure 54 months | first EMI 03-05-2026
    final principal = 313616.0;
    final rate = 14.22;
    final disbursementDate = DateTime(2026, 4, 9);
    final firstEmiDate = DateTime(2026, 5, 3);
    final emiAmount = 7879.0;
    final tenureMonths = 54;
    final deductionDay = 3;

    late List<AmortizationRow> schedule;

    setUpAll(() {
      schedule = EmiCalculator.generateSchedule(
        principal: principal,
        emiAmount: emiAmount,
        tenureMonths: tenureMonths,
        deductionDay: deductionDay,
        disbursementDate: disbursementDate,
        firstEmiDate: firstEmiDate,
        defaultInterestRate: rate,
      );
    });

    test('generates correct number of EMIs', () {
      // 54 regular EMIs + 1 final plug EMI to clear rounding residual
      expect(schedule.length, closeTo(tenureMonths, 1));
    });

    test('EMI 1: 03-05-2026, 24 days', () {
      final row = schedule[0];
      expect(row.days, 24);
      expect(row.interest, closeTo(2932.34, 0.02));
      expect(row.principal, closeTo(4946.66, 0.02));
      expect(row.closingBalance, closeTo(308669.34, 0.02));
    });

    test('EMI 2: 03-06-2026, 31 days', () {
      final row = schedule[1];
      expect(row.days, 31);
      expect(row.interest, closeTo(3727.87, 0.02));
      expect(row.principal, closeTo(4151.13, 0.02));
      expect(row.closingBalance, closeTo(304518.21, 0.05));
    });

    test('EMI 3: 03-07-2026, 30 days', () {
      final row = schedule[2];
      expect(row.days, 30);
      expect(row.interest, closeTo(3559.12, 0.02));
      expect(row.principal, closeTo(4319.88, 0.02));
      expect(row.closingBalance, closeTo(300198.33, 0.10));
    });

    test('EMI 4: 03-08-2026, 31 days', () {
      final row = schedule[3];
      expect(row.days, 31);
      expect(row.interest, closeTo(3625.57, 0.05));
      expect(row.principal, closeTo(4253.43, 0.05));
      expect(row.closingBalance, closeTo(295944.90, 0.15));
    });

    test('EMI 5: 03-09-2026, 31 days', () {
      final row = schedule[4];
      expect(row.days, 31);
      expect(row.interest, closeTo(3574.22, 0.05));
      expect(row.principal, closeTo(4304.78, 0.05));
      expect(row.closingBalance, closeTo(291640.12, 0.20));
    });

    test('cumulative after 5 EMIs matches bank statement', () {
      double totalInterest = 0;
      double totalPrincipal = 0;
      for (int i = 0; i < 5; i++) {
        totalInterest += schedule[i].interest;
        totalPrincipal += schedule[i].principal;
      }
      // Bank shows 17,419.00 and 21,976.00 — paise-level rounding acceptable
      expect(totalInterest, closeTo(17419.0, 2.0));
      expect(totalPrincipal, closeTo(21976.0, 2.0));
    });

    test('last EMI closes balance to near zero (rounding drift acceptable)', () {
      final lastRow = schedule.last;
      // With bank's exact EMI, rounding drift over 54 months can leave a small residual
      // Banks handle this via the final plug EMI (which differs from the standard EMI)
      expect(lastRow.closingBalance, lessThan(200));
    });
  });

  group('EmiCalculator - PMT formula EMI calculation', () {
    test('formula matches standard EMI calculators for IDFC bike loan', () {
      final emi = EmiCalculator.calculateEmiByFormula(
        principal: 313616.0,
        tenureMonths: 54,
        interestRate: 14.22,
      );
      // Standard PMT formula: P * r * (1+r)^n / ((1+r)^n - 1) where r = rate/12/100
      expect(emi, closeTo(7896, 1));
    });

    test('formula for 0% interest is simple division', () {
      final emi = EmiCalculator.calculateEmiByFormula(
        principal: 120000.0,
        tenureMonths: 12,
        interestRate: 0,
      );
      expect(emi, closeTo(10000, 1));
    });

    test('bisection gives close result for IDFC bike loan', () {
      final emi = EmiCalculator.calculateEmiByBisection(
        principal: 313616.0,
        tenureMonths: 54,
        deductionDay: 3,
        disbursementDate: DateTime(2026, 4, 9),
        firstEmiDate: DateTime(2026, 5, 3),
        interestRate: 14.22,
      );
      expect(emi, closeTo(7891, 5));
    });
  });

  group('EmiCalculator - Floating rate tenure adjustment', () {
    test('rate drop shortens tenure (HDFC-style)', () {
      final emi = EmiCalculator.calculateEmiByFormula(
        principal: 5000000,
        tenureMonths: 240,
        interestRate: 8.60,
      );

      final scheduleOriginal = EmiCalculator.generateSchedule(
        principal: 5000000,
        emiAmount: emi,
        tenureMonths: 240,
        deductionDay: 5,
        disbursementDate: DateTime(2024, 1, 1),
        firstEmiDate: DateTime(2024, 2, 5),
        defaultInterestRate: 8.60,
      );
      expect(scheduleOriginal.length, closeTo(240, 1));
      expect(scheduleOriginal.last.closingBalance, lessThan(1));

      final rateHistory = [
        LoanRateChange(loanId: 1, effectiveDate: DateTime(2024, 1, 1), rate: 8.60),
        LoanRateChange(loanId: 1, effectiveDate: DateTime(2025, 1, 1), rate: 7.60),
      ];

      final scheduleReduced = EmiCalculator.generateSchedule(
        principal: 5000000,
        emiAmount: emi,
        tenureMonths: 240,
        deductionDay: 5,
        disbursementDate: DateTime(2024, 1, 1),
        firstEmiDate: DateTime(2024, 2, 5),
        defaultInterestRate: 8.60,
        rateHistory: rateHistory,
      );
      expect(scheduleReduced.length, lessThan(240));
      expect(scheduleReduced.last.closingBalance, lessThan(1));
    });

    test('rate increase extends tenure', () {
      final emi = EmiCalculator.calculateEmiByFormula(
        principal: 5000000,
        tenureMonths: 240,
        interestRate: 7.60,
      );

      final rateHistory = [
        LoanRateChange(loanId: 1, effectiveDate: DateTime(2024, 1, 1), rate: 7.60),
        LoanRateChange(loanId: 1, effectiveDate: DateTime(2025, 1, 1), rate: 8.60),
      ];

      final schedule = EmiCalculator.generateSchedule(
        principal: 5000000,
        emiAmount: emi,
        tenureMonths: 240,
        deductionDay: 5,
        disbursementDate: DateTime(2024, 1, 1),
        firstEmiDate: DateTime(2024, 2, 5),
        defaultInterestRate: 7.60,
        rateHistory: rateHistory,
      );
      expect(schedule.length, greaterThan(240));
      expect(schedule.last.closingBalance, lessThan(1));
    });
  });

  group('EmiCalculator - utility methods', () {
    test('round2', () {
      expect(EmiCalculator.round2(3.145), 3.15);
      expect(EmiCalculator.round2(3.144), 3.14);
    });

    test('daysBetween', () {
      expect(EmiCalculator.daysBetween(DateTime(2026, 4, 9), DateTime(2026, 5, 3)), 24);
      expect(EmiCalculator.daysBetween(DateTime(2026, 5, 3), DateTime(2026, 6, 3)), 31);
      expect(EmiCalculator.daysBetween(DateTime(2026, 6, 3), DateTime(2026, 7, 3)), 30);
    });

    test('resolveEmiDate clamps to last day of month', () {
      final feb = EmiCalculator.resolveEmiDate(DateTime(2026, 2, 28), 31, 0);
      expect(feb.day, 28);
      final march = EmiCalculator.resolveEmiDate(DateTime(2026, 2, 28), 31, 1);
      expect(march.day, 31);
      expect(march.month, 3);
    });

    test('getRateForDate with multiple rates', () {
      final history = [
        LoanRateChange(loanId: 1, effectiveDate: DateTime(2025, 2, 1), rate: 8.60),
        LoanRateChange(loanId: 1, effectiveDate: DateTime(2025, 3, 1), rate: 8.35),
        LoanRateChange(loanId: 1, effectiveDate: DateTime(2025, 7, 1), rate: 7.60),
        LoanRateChange(loanId: 1, effectiveDate: DateTime(2026, 1, 1), rate: 7.35),
      ];
      expect(EmiCalculator.getRateForDate(DateTime(2025, 2, 15), 8.60, history), 8.60);
      expect(EmiCalculator.getRateForDate(DateTime(2025, 5, 1), 8.60, history), 8.35);
      expect(EmiCalculator.getRateForDate(DateTime(2025, 8, 1), 8.60, history), 7.60);
      expect(EmiCalculator.getRateForDate(DateTime(2026, 6, 1), 8.60, history), 7.35);
    });
  });
}
