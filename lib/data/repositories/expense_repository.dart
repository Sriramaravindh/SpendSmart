import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models.dart';
import '../../core/utils/currency_formatter.dart';

class ExpenseRepository {
  Future<Database> get _db => AppDatabase.database;

  Future<int> insert(Expense expense) async {
    final db = await _db;
    return db.insert('expenses', expense.toMap());
  }

  Future<void> update(Expense expense) async {
    final db = await _db;
    await db.update('expenses', expense.toMap(), where: 'id = ?', whereArgs: [expense.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<Expense?> getById(int id) async {
    final db = await _db;
    final maps = await db.query('expenses', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Expense.fromMap(maps.first);
  }

  Future<List<Expense>> getByDateRange(DateTime start, DateTime end) async {
    final db = await _db;
    final maps = await db.query(
      'expenses',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'date DESC',
    );
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<List<Expense>> getAll({int? limit, int? offset}) async {
    final db = await _db;
    final maps = await db.query('expenses', orderBy: 'date DESC', limit: limit, offset: offset);
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  // Loads all conversion rates into a map: {fromCurrency -> rate} where rate converts to defaultCurrency
  Future<Map<String, double>> _loadRateMap(Database db) async {
    final defaultCurrency = CurrencyFormatter.defaultCurrencyCode;
    final rates = await db.query('currency_rates');
    final rateMap = <String, double>{};
    for (final r in rates) {
      final from = r['fromCurrency'] as String;
      final to = r['toCurrency'] as String;
      if (to == defaultCurrency) {
        rateMap[from] = (r['rate'] as num).toDouble();
      }
    }
    return rateMap;
  }

  // Returns the amount converted to defaultCurrency, or null when no rate is
  // available for a non-default currency. Folded-sum callers skip nulls so a
  // foreign amount with no rate contributes 0 instead of being added raw.
  double? _convertAmount(double amount, String currency, String defaultCurrency, Map<String, double> rateMap) {
    if (currency == defaultCurrency) return amount;
    if (rateMap.containsKey(currency)) return amount * rateMap[currency]!;
    debugPrint('WARNING: missing rate for $currency, excluded from converted total');
    return null;
  }

  Future<double> getTotalByDateRange(DateTime start, DateTime end, {String? type}) async {
    final db = await _db;
    final defaultCurrency = CurrencyFormatter.defaultCurrencyCode;
    final typeClause = type != null ? ' AND type = ?' : '';
    final List<Object> args = [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch];
    if (type != null) args.add(type);

    final result = await db.rawQuery(
      'SELECT currency, COALESCE(SUM(amount), 0) as total FROM expenses WHERE date >= ? AND date <= ?$typeClause GROUP BY currency',
      args,
    );

    if (result.isEmpty) return 0.0;

    final rateMap = await _loadRateMap(db);
    double grandTotal = 0.0;

    for (final row in result) {
      final currency = (row['currency'] as String?) ?? defaultCurrency;
      final total = (row['total'] as num).toDouble();
      final converted = _convertAmount(total, currency, defaultCurrency, rateMap);
      if (converted == null) continue; // skip currencies with no rate
      grandTotal += converted;
    }
    return grandTotal;
  }

  Future<double> getTotalExpenseByDateRange(DateTime start, DateTime end) async {
    return getTotalByDateRange(start, end, type: 'EXPENSE');
  }

  Future<Map<String, double>> getTotalsByDateRangeGrouped(DateTime start, DateTime end, {String? type}) async {
    final db = await _db;
    final defaultCurrency = CurrencyFormatter.defaultCurrencyCode;
    final typeClause = type != null ? ' AND type = ?' : '';
    final List<Object> args = [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch];
    if (type != null) args.add(type);

    final result = await db.rawQuery(
      'SELECT currency, COALESCE(SUM(amount), 0) as total FROM expenses WHERE date >= ? AND date <= ?$typeClause GROUP BY currency',
      args,
    );

    if (result.isEmpty) return {};

    final rateMap = await _loadRateMap(db);
    final grouped = <String, double>{};

    for (final row in result) {
      final currency = (row['currency'] as String?) ?? defaultCurrency;
      final total = (row['total'] as num).toDouble();
      if (currency == defaultCurrency) {
        grouped[defaultCurrency] = (grouped[defaultCurrency] ?? 0) + total;
      } else if (rateMap.containsKey(currency)) {
        grouped[defaultCurrency] = (grouped[defaultCurrency] ?? 0) + total * rateMap[currency]!;
      } else {
        grouped[currency] = (grouped[currency] ?? 0) + total;
      }
    }
    return grouped;
  }

  Future<Map<String, double>> getTotalExpenseGrouped(DateTime start, DateTime end) async {
    return getTotalsByDateRangeGrouped(start, end, type: 'EXPENSE');
  }

  Future<Map<String, double>> getTotalIncomeGrouped(DateTime start, DateTime end) async {
    return getTotalsByDateRangeGrouped(start, end, type: 'INCOME');
  }

  Future<double> getTotalIncomeByDateRange(DateTime start, DateTime end) async {
    return getTotalByDateRange(start, end, type: 'INCOME');
  }

  Future<List<CategoryTotal>> getCategoryTotals(DateTime start, DateTime end, {String type = 'EXPENSE'}) async {
    final db = await _db;
    final defaultCurrency = CurrencyFormatter.defaultCurrencyCode;
    final rateMap = await _loadRateMap(db);

    final result = await db.rawQuery(
      'SELECT categoryId, currency, SUM(amount) as total FROM expenses WHERE date >= ? AND date <= ? AND type = ? GROUP BY categoryId, currency ORDER BY total DESC',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch, type],
    );

    final merged = <int?, double>{};
    for (final m in result) {
      final catId = m['categoryId'] as int?;
      final currency = (m['currency'] as String?) ?? defaultCurrency;
      final total = (m['total'] as num).toDouble();
      final converted = _convertAmount(total, currency, defaultCurrency, rateMap);
      if (converted == null) continue; // skip currencies with no rate
      merged[catId] = (merged[catId] ?? 0) + converted;
    }

    final list = merged.entries.map((e) => CategoryTotal(categoryId: e.key, total: e.value)).toList();
    list.sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  Future<List<PaymentMethodTotal>> getPaymentMethodTotals(DateTime start, DateTime end, {String type = 'EXPENSE'}) async {
    final db = await _db;
    final defaultCurrency = CurrencyFormatter.defaultCurrencyCode;
    final rateMap = await _loadRateMap(db);

    final result = await db.rawQuery(
      'SELECT paymentMethodId, currency, SUM(amount) as total FROM expenses WHERE date >= ? AND date <= ? AND type = ? GROUP BY paymentMethodId, currency ORDER BY total DESC',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch, type],
    );

    final merged = <int?, double>{};
    for (final m in result) {
      final pmId = m['paymentMethodId'] as int?;
      final currency = (m['currency'] as String?) ?? defaultCurrency;
      final total = (m['total'] as num).toDouble();
      final converted = _convertAmount(total, currency, defaultCurrency, rateMap);
      if (converted == null) continue; // skip currencies with no rate
      merged[pmId] = (merged[pmId] ?? 0) + converted;
    }

    final list = merged.entries.map((e) => PaymentMethodTotal(paymentMethodId: e.key, total: e.value)).toList();
    list.sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  Future<List<DailyTotal>> getDailyTotals(DateTime start, DateTime end, {String type = 'EXPENSE'}) async {
    final db = await _db;
    final defaultCurrency = CurrencyFormatter.defaultCurrencyCode;
    final rateMap = await _loadRateMap(db);

    final maps = await db.query(
      'expenses',
      where: 'date >= ? AND date <= ? AND type = ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch, type],
      orderBy: 'date DESC',
    );
    final expenses = maps.map((m) => Expense.fromMap(m)).toList();
    final Map<String, double> dailyMap = {};
    for (final e in expenses) {
      final key = '${e.date.year}-${e.date.month}-${e.date.day}';
      final converted = _convertAmount(e.amount, e.currency, defaultCurrency, rateMap);
      if (converted == null) continue; // skip currencies with no rate
      dailyMap[key] = (dailyMap[key] ?? 0) + converted;
    }
    return dailyMap.entries.map((entry) {
      final parts = entry.key.split('-');
      return DailyTotal(
        date: DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
        total: entry.value,
      );
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<List<Expense>> search(String query) async {
    final db = await _db;
    // Escape LIKE metacharacters so user input is treated literally.
    final escaped = query
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final maps = await db.query(
      'expenses',
      where: "note LIKE ? ESCAPE '\\'",
      whereArgs: ['%$escaped%'],
      orderBy: 'date DESC',
    );
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<int> getCount() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM expenses');
    return (result.first['count'] as int);
  }

  Future<List<String>> getAllTags() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT DISTINCT tag FROM expenses WHERE tag IS NOT NULL AND tag != "" ORDER BY tag ASC');
    return result.map((r) => r['tag'] as String).toList();
  }
}
