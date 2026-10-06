import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models.dart';
import '../../core/utils/emi_calculator.dart';

class LoanRepository {
  Future<Database> get _db => AppDatabase.database;

  Future<List<LoanRateChange>> getRateChanges(int loanId) async {
    final db = await _db;
    final maps = await db.query('loan_rate_changes',
        where: 'loanId = ?', whereArgs: [loanId], orderBy: 'effectiveDate ASC');
    return maps.map((m) => LoanRateChange.fromMap(m)).toList();
  }

  Future<int> insertRateChange(LoanRateChange rateChange) async {
    final db = await _db;
    return db.insert('loan_rate_changes', rateChange.toMap());
  }

  Future<void> deleteRateChange(int id) async {
    final db = await _db;
    await db.delete('loan_rate_changes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteRateChangesForLoan(int loanId) async {
    final db = await _db;
    await db.delete('loan_rate_changes', where: 'loanId = ?', whereArgs: [loanId]);
  }

  Future<Loan> _loadWithRateHistory(Map<String, dynamic> map) async {
    final loan = Loan.fromMap(map);
    if (loan.id != null) {
      final rateChanges = await getRateChanges(loan.id!);
      return loan.copyWith(rateHistory: rateChanges);
    }
    return loan;
  }

  Future<List<Loan>> getAll() async {
    final db = await _db;
    final maps = await db.query('loans', orderBy: 'isActive DESC, name ASC');
    final loans = <Loan>[];
    for (final m in maps) {
      loans.add(await _loadWithRateHistory(m));
    }
    return loans;
  }

  Future<List<Loan>> getActive() async {
    final db = await _db;
    final maps = await db.query('loans', where: 'isActive = 1', orderBy: 'name ASC');
    final loans = <Loan>[];
    for (final m in maps) {
      loans.add(await _loadWithRateHistory(m));
    }
    return loans;
  }

  Future<Loan?> getById(int id) async {
    final db = await _db;
    final maps = await db.query('loans', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return _loadWithRateHistory(maps.first);
  }

  Future<int> insert(Loan loan) async {
    final db = await _db;
    final id = await db.transaction((txn) async {
      final loanId = await txn.insert('loans', loan.toMap());
      if (loan.rateHistory.isEmpty) {
        await txn.insert('loan_rate_changes', {
          'loanId': loanId,
          'effectiveDate': loan.effectiveDisbursementDate.millisecondsSinceEpoch,
          'rate': loan.interestRate,
        });
      } else {
        for (final rc in loan.rateHistory) {
          await txn.insert('loan_rate_changes', {
            'loanId': loanId,
            'effectiveDate': rc.effectiveDate.millisecondsSinceEpoch,
            'rate': rc.rate,
          });
        }
      }
      return loanId;
    });
    // Run auto-deductions after the transaction commits; it is its own logic.
    await processAutoDeductions();
    return id;
  }

  Future<void> update(Loan loan) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update('loans', loan.toMap(), where: 'id = ?', whereArgs: [loan.id]);
      if (loan.id != null) {
        await txn.delete('loan_rate_changes', where: 'loanId = ?', whereArgs: [loan.id]);
        if (loan.rateHistory.isEmpty) {
          await txn.insert('loan_rate_changes', {
            'loanId': loan.id,
            'effectiveDate': loan.effectiveDisbursementDate.millisecondsSinceEpoch,
            'rate': loan.interestRate,
          });
        } else {
          for (final rc in loan.rateHistory) {
            await txn.insert('loan_rate_changes', {
              'loanId': loan.id,
              'effectiveDate': rc.effectiveDate.millisecondsSinceEpoch,
              'rate': rc.rate,
            });
          }
        }
      }
    });
  }

  Future<void> deactivate(int id) async {
    final db = await _db;
    await db.update('loans', {'isActive': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> activate(int id) async {
    final db = await _db;
    await db.update('loans', {'isActive': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.transaction((txn) async {
      final payments = await txn.query(
        'loan_payments',
        columns: ['expenseId'],
        where: 'loanId = ? AND expenseId IS NOT NULL',
        whereArgs: [id],
      );
      final expenseIds = payments
          .map((p) => p['expenseId'] as int?)
          .where((eid) => eid != null)
          .toList();

      await txn.delete('loan_payments', where: 'loanId = ?', whereArgs: [id]);

      for (final eid in expenseIds) {
        await txn.delete('expenses', where: 'id = ?', whereArgs: [eid]);
      }

      await txn.delete('loan_rate_changes', where: 'loanId = ?', whereArgs: [id]);
      await txn.delete('loans', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<LoanPayment>> getPayments(int loanId) async {
    final db = await _db;
    final maps = await db.query('loan_payments', where: 'loanId = ?', whereArgs: [loanId], orderBy: 'paymentDate DESC');
    return maps.map((m) => LoanPayment.fromMap(m)).toList();
  }

  Future<int> addPayment(LoanPayment payment) async {
    final db = await _db;
    return db.insert('loan_payments', payment.toMap());
  }

  Future<void> deletePayment(int paymentId) async {
    final db = await _db;
    await db.transaction((txn) async {
      final payment = await txn.query('loan_payments', where: 'id = ?', whereArgs: [paymentId]);
      if (payment.isNotEmpty) {
        final expenseId = payment.first['expenseId'] as int?;
        await txn.delete('loan_payments', where: 'id = ?', whereArgs: [paymentId]);
        if (expenseId != null) {
          await txn.delete('expenses', where: 'id = ?', whereArgs: [expenseId]);
        }
      }
    });
  }

  Future<void> updatePayment(LoanPayment payment) async {
    final db = await _db;
    await db.update('loan_payments', payment.toMap(), where: 'id = ?', whereArgs: [payment.id]);
  }

  Future<bool> hasPaymentForMonth(int loanId, int year, int month) async {
    final db = await _db;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM loan_payments WHERE loanId = ? AND paymentDate >= ? AND paymentDate < ? AND isExtraPayment = 0',
      [loanId, start, end],
    );
    return (result.first['count'] as int) > 0;
  }

  Future<double> getTotalPaid(int loanId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(principal), 0) as total FROM loan_payments WHERE loanId = ?',
      [loanId],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<int> processAutoDeductions() async {
    final activeLoans = await getActive();
    final now = DateTime.now();
    int processedCount = 0;

    final db = await _db;

    final pmResult = await db.query('payment_methods', limit: 1);
    final defaultPmId = pmResult.isNotEmpty ? pmResult.first['id'] as int : 1;

    for (final loan in activeLoans) {
      if (loan.id == null) continue;

      int startYear = loan.startDate.year;
      int startMonth = loan.startDate.month;

      int year = startYear;
      int month = startMonth;

      while (year < now.year || (year == now.year && month <= now.month)) {
        final lastDay = DateTime(year, month + 1, 0).day;
        final dayToUse = loan.deductionDay.clamp(1, lastDay);
        final deductionDate = DateTime(year, month, dayToUse);

        if (now.isAfter(deductionDate) || (year == now.year && month == now.month && now.day >= dayToUse)) {
          // Stop booking EMIs once the loan is paid off.
          final paidSoFar = await getTotalPaid(loan.id!);
          if ((loan.totalAmount - paidSoFar) <= 0.01) {
            break;
          }
          final alreadyPaid = await hasPaymentForMonth(loan.id!, year, month);
          if (!alreadyPaid) {
            await db.transaction((txn) async {
              final expenseId = await txn.insert('expenses', {
                'amount': loan.emiAmount,
                'categoryId': loan.categoryId,
                'paymentMethodId': defaultPmId,
                'note': 'Auto EMI Debit: ${loan.name}',
                'date': deductionDate.millisecondsSinceEpoch,
                'createdAt': DateTime.now().millisecondsSinceEpoch,
                'type': 'EXPENSE',
                'currency': loan.currency,
              });

              final totalPrincipalResult = await txn.rawQuery(
                'SELECT COALESCE(SUM(principal), 0) as total FROM loan_payments WHERE loanId = ?',
                [loan.id],
              );
              final totalPrincipalPaid = (totalPrincipalResult.first['total'] as num).toDouble();
              final principalBalance = (loan.totalAmount - totalPrincipalPaid).clamp(0.0, loan.totalAmount);

              // Actual/365 day-count interest
              final lastPaymentResult = await txn.rawQuery(
                'SELECT MAX(paymentDate) as lastDate FROM loan_payments WHERE loanId = ? AND isExtraPayment = 0',
                [loan.id],
              );
              final lastPaymentTs = lastPaymentResult.first['lastDate'] as int?;
              final DateTime prevDate;
              if (lastPaymentTs != null) {
                prevDate = DateTime.fromMillisecondsSinceEpoch(lastPaymentTs);
              } else {
                final oneMonthBefore = EmiCalculator.resolveEmiDate(loan.startDate, loan.deductionDay, -1);
                prevDate = loan.effectiveDisbursementDate.isAfter(oneMonthBefore)
                    ? loan.effectiveDisbursementDate
                    : oneMonthBefore;
              }

              final days = EmiCalculator.daysBetween(prevDate, deductionDate);
              final applicableRate = EmiCalculator.getRateForDate(
                  deductionDate, loan.interestRate, loan.rateHistory);
              final dailyRate = applicableRate / 100.0 / 365.0;
              final interestPart = EmiCalculator.round2(principalBalance * dailyRate * (days > 0 ? days : 0));
              // Cap principal to the remaining balance so a final EMI does not
              // overshoot the outstanding principal.
              final principalPart = EmiCalculator.round2(
                  (loan.emiAmount - interestPart).clamp(0.0, principalBalance));

              await txn.insert('loan_payments', {
                'loanId': loan.id,
                'amount': loan.emiAmount,
                'principal': principalPart,
                'interest': interestPart,
                'paymentDate': deductionDate.millisecondsSinceEpoch,
                'isExtraPayment': 0,
                'expenseId': expenseId,
                'currency': loan.currency,
              });
            });
            processedCount++;
          }
        }

        month++;
        if (month > 12) {
          month = 1;
          year++;
        }
      }
    }
    return processedCount;
  }
}
