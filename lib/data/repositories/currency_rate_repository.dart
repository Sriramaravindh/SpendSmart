import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models.dart';

class CurrencyRateRepository {
  Future<Database> get _db => AppDatabase.database;

  Future<List<CurrencyRate>> getAll() async {
    final db = await _db;
    final maps = await db.query('currency_rates', orderBy: 'fromCurrency, toCurrency');
    return maps.map((m) => CurrencyRate.fromMap(m)).toList();
  }

  Future<CurrencyRate?> getRate(String from, String to) async {
    final db = await _db;
    final maps = await db.query(
      'currency_rates',
      where: 'fromCurrency = ? AND toCurrency = ?',
      whereArgs: [from, to],
    );
    if (maps.isEmpty) return null;
    return CurrencyRate.fromMap(maps.first);
  }

  Future<void> upsertRate(String from, String to, double rate) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'currency_rates',
      {
        'fromCurrency': from,
        'toCurrency': to,
        'rate': rate,
        'updatedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Also store the inverse rate
    await db.insert(
      'currency_rates',
      {
        'fromCurrency': to,
        'toCurrency': from,
        'rate': 1.0 / rate,
        'updatedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<double?> convert(double amount, String from, String to) async {
    if (from == to) return amount;
    final rateObj = await getRate(from, to);
    if (rateObj == null) return null;
    return amount * rateObj.rate;
  }

  Future<Map<String, double>> getRateMapToDefault() async {
    final db = await _db;
    final defaultCurrency = (await _getDefaultCurrency());
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

  static Future<String> _getDefaultCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('currency_code') ?? 'INR';
  }

  static double convertAmount(double amount, String currency, String defaultCurrency, Map<String, double> rateMap) {
    if (currency == defaultCurrency) return amount;
    if (rateMap.containsKey(currency)) return amount * rateMap[currency]!;
    // No rate available: exclude this foreign amount from the converted total
    // instead of silently mixing currencies by returning the raw amount.
    debugPrint('WARNING: missing rate for $currency, excluded from converted total');
    return 0.0;
  }

  /// Returns the converted amount, or null when no rate is available for a
  /// non-default currency. Lets callers decide how to handle missing rates.
  static double? tryConvert(double amount, String currency, String defaultCurrency, Map<String, double> rateMap) {
    if (currency == defaultCurrency) return amount;
    if (rateMap.containsKey(currency)) return amount * rateMap[currency]!;
    return null;
  }

  Future<void> delete(String from, String to) async {
    final db = await _db;
    await db.delete(
      'currency_rates',
      where: 'fromCurrency = ? AND toCurrency = ?',
      whereArgs: [from, to],
    );
    await db.delete(
      'currency_rates',
      where: 'fromCurrency = ? AND toCurrency = ?',
      whereArgs: [to, from],
    );
  }
}
