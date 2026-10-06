import '../../data/models.dart';

class AmortizationRow {
  final int month;
  final DateTime date;
  final int days;
  final double rate;
  final double emi;
  final double principal;
  final double interest;
  final double openingBalance;
  final double closingBalance;
  final bool isPaid;
  final int? paymentId;

  AmortizationRow({
    required this.month,
    required this.date,
    required this.days,
    required this.rate,
    required this.emi,
    required this.principal,
    required this.interest,
    required this.openingBalance,
    required this.closingBalance,
    required this.isPaid,
    this.paymentId,
  });
}

class EmiCalculator {
  static double round2(double value) =>
      (value * 100).roundToDouble() / 100;

  static int daysBetween(DateTime from, DateTime to) =>
      DateTime(to.year, to.month, to.day)
          .difference(DateTime(from.year, from.month, from.day))
          .inDays;

  static DateTime resolveEmiDate(DateTime firstEmiDate, int deductionDay, int monthIndex) {
    final year = firstEmiDate.year;
    final month = firstEmiDate.month + monthIndex;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = deductionDay.clamp(1, lastDay);
    return DateTime(year, month, day);
  }

  static double getRateForDate(
      DateTime date, double defaultRate, List<LoanRateChange> rateHistory) {
    if (rateHistory.isEmpty) return defaultRate;
    final sorted = List<LoanRateChange>.from(rateHistory)
      ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    for (final rc in sorted) {
      // Normalize to date-only so the comparison is not time-of-day sensitive.
      final effective = DateTime(
          rc.effectiveDate.year, rc.effectiveDate.month, rc.effectiveDate.day);
      if (!date.isBefore(effective)) return rc.rate;
    }
    return defaultRate;
  }

  static List<AmortizationRow> generateSchedule({
    required double principal,
    required double emiAmount,
    required int tenureMonths,
    required int deductionDay,
    required DateTime disbursementDate,
    required DateTime firstEmiDate,
    required double defaultInterestRate,
    List<LoanRateChange> rateHistory = const [],
    List<LoanPayment> paidPayments = const [],
    List<LoanPayment> extraPayments = const [],
  }) {
    double balance = principal;
    final rows = <AmortizationRow>[];

    for (final extra in extraPayments) {
      if (!extra.paymentDate.isAfter(disbursementDate)) {
        balance -= extra.amount;
      }
    }
    if (balance < 0) balance = 0;

    final maxMonths = tenureMonths * 3 > 600 ? 600 : tenureMonths * 3;

    for (int i = 0; i < maxMonths; i++) {
      if (balance <= 0 && i >= tenureMonths) break;

      final emiDate = resolveEmiDate(firstEmiDate, deductionDay, i);
      final DateTime prevDate;
      if (i == 0) {
        final oneMonthBefore = resolveEmiDate(firstEmiDate, deductionDay, -1);
        prevDate = disbursementDate.isAfter(oneMonthBefore)
            ? disbursementDate
            : oneMonthBefore;
      } else {
        prevDate = resolveEmiDate(firstEmiDate, deductionDay, i - 1);
      }

      for (final extra in extraPayments) {
        if (extra.paymentDate.isAfter(prevDate) &&
            (extra.paymentDate.isBefore(emiDate) ||
                extra.paymentDate.isAtSameMomentAs(emiDate))) {
          balance -= extra.amount;
        }
      }
      if (balance < 0) balance = 0;

      final openingBalance = balance;

      LoanPayment? matchingPayment;
      for (final p in paidPayments) {
        if ((p.paymentDate.year == emiDate.year &&
                p.paymentDate.month == emiDate.month) ||
            (p.paymentDate.isAfter(prevDate) &&
                (p.paymentDate.isBefore(emiDate) ||
                    p.paymentDate.isAtSameMomentAs(emiDate)))) {
          matchingPayment = p;
          break;
        }
      }

      if (openingBalance <= 0 && matchingPayment == null) break;

      final rate = getRateForDate(emiDate, defaultInterestRate, rateHistory);
      final days = daysBetween(prevDate, emiDate);
      final dailyRate = rate / 100.0 / 365.0;
      final interest = round2(openingBalance * dailyRate * (days < 0 ? 0 : days));

      double emi;
      double princ;

      if (matchingPayment != null) {
        emi = matchingPayment.amount;
        princ = matchingPayment.principal;
      } else {
        emi = emiAmount;
        if (round2(openingBalance + interest) <= emi) {
          emi = round2(openingBalance + interest);
        }
        princ = round2(emi - interest);
      }

      balance = round2(balance - princ);
      if (balance < 0) balance = 0;

      rows.add(AmortizationRow(
        month: i + 1,
        date: emiDate,
        days: days < 0 ? 0 : days,
        rate: rate,
        emi: emi,
        principal: princ,
        interest: matchingPayment != null ? matchingPayment.interest : interest,
        openingBalance: openingBalance,
        closingBalance: balance,
        isPaid: matchingPayment != null,
        paymentId: matchingPayment?.id,
      ));
    }

    // Residual plug: if the loan never fully amortized within maxMonths,
    // append a final row that clears the remaining balance so the schedule
    // shows a complete payoff.
    if (balance > 0.01 && rows.isNotEmpty) {
      final last = rows.last;
      final nextMonth = last.month + 1;
      final emiDate = resolveEmiDate(firstEmiDate, deductionDay, nextMonth - 1);
      final prevDate = last.date;
      final openingBalance = balance;
      final rate = getRateForDate(emiDate, defaultInterestRate, rateHistory);
      final days = daysBetween(prevDate, emiDate);
      final dailyRate = rate / 100.0 / 365.0;
      final interest = round2(openingBalance * dailyRate * (days < 0 ? 0 : days));
      final emi = round2(openingBalance + interest);

      rows.add(AmortizationRow(
        month: nextMonth,
        date: emiDate,
        days: days < 0 ? 0 : days,
        rate: rate,
        emi: emi,
        principal: round2(openingBalance),
        interest: interest,
        openingBalance: openingBalance,
        closingBalance: 0,
        isPaid: false,
      ));
    }

    return rows;
  }

  static double calculateEmiByFormula({
    required double principal,
    required int tenureMonths,
    required double interestRate,
  }) {
    if (interestRate == 0) return round2(principal / tenureMonths);
    final r = interestRate / 12 / 100;
    final n = tenureMonths;
    final emi = principal * r * _pow(1 + r, n) / (_pow(1 + r, n) - 1);
    return round2(emi);
  }

  static double _pow(double base, int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  static double calculateEmiByBisection({
    required double principal,
    required int tenureMonths,
    required int deductionDay,
    required DateTime disbursementDate,
    required DateTime firstEmiDate,
    required double interestRate,
    List<LoanRateChange> rateHistory = const [],
  }) {
    if (interestRate == 0) return round2(principal / tenureMonths);

    // Upper bound: monthly rate * 3 to be generous
    final monthlyRate = interestRate / 100.0 / 12.0;
    double low = principal * monthlyRate;
    double high = principal * (monthlyRate + 1.0 / tenureMonths) * 3;

    for (int iter = 0; iter < 100; iter++) {
      final mid = (low + high) / 2;
      final schedule = generateSchedule(
        principal: principal,
        emiAmount: mid,
        tenureMonths: tenureMonths,
        deductionDay: deductionDay,
        disbursementDate: disbursementDate,
        firstEmiDate: firstEmiDate,
        defaultInterestRate: interestRate,
        rateHistory: rateHistory,
      );

      if (schedule.isEmpty) return round2(mid);

      if (schedule.length >= tenureMonths) {
        final balanceAtTenure = schedule[tenureMonths - 1].closingBalance;
        if (balanceAtTenure.abs() < 0.50) return round2(mid);
        if (balanceAtTenure > 0) {
          low = mid;
        } else {
          high = mid;
        }
      } else {
        high = mid;
      }
    }

    return round2((low + high) / 2);
  }
}
