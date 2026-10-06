import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyFormatter {
  static String _currencySymbol = '₹';
  static String _currencyCode = 'INR';
  static const String _prefKey = 'currency_symbol';
  static const String _codePrefKey = 'currency_code';

  static final Map<String, String> availableCurrencies = {
    '₹': 'Indian Rupee (INR)',
    '\$': 'US Dollar (USD)',
    '€': 'Euro (EUR)',
    '£': 'British Pound (GBP)',
    '¥': 'Japanese Yen (JPY)',
    'A\$': 'Australian Dollar (AUD)',
    'C\$': 'Canadian Dollar (CAD)',
    'CHF': 'Swiss Franc (CHF)',
    'S\$': 'Singapore Dollar (SGD)',
    'AED': 'UAE Dirham (AED)',
  };

  static const Map<String, String> codeToSymbol = {
    'INR': '₹',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'CHF': 'CHF',
    'SGD': 'S\$',
    'AED': 'AED',
  };

  static const Map<String, String> codeToName = {
    'INR': 'Indian Rupee',
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'GBP': 'British Pound',
    'JPY': 'Japanese Yen',
    'AUD': 'Australian Dollar',
    'CAD': 'Canadian Dollar',
    'CHF': 'Swiss Franc',
    'SGD': 'Singapore Dollar',
    'AED': 'UAE Dirham',
  };

  static String get symbol => _currencySymbol;
  static String get defaultCurrencyCode => _currencyCode;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currencySymbol = prefs.getString(_prefKey) ?? '₹';
    _currencyCode = prefs.getString(_codePrefKey) ?? 'INR';
  }

  static Future<void> setCurrency(String symbol) async {
    _currencySymbol = symbol;
    final code = codeToSymbol.entries
        .where((e) => e.value == symbol)
        .map((e) => e.key)
        .firstOrNull ?? 'INR';
    _currencyCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, symbol);
    await prefs.setString(_codePrefKey, code);
  }

  static String symbolFor(String currencyCode) {
    return codeToSymbol[currencyCode] ?? currencyCode;
  }

  static String format(double amount) {
    final formatter = NumberFormat('#,##,##0.00', 'en_IN');
    if (_currencySymbol == '₹') {
      return '₹${formatter.format(amount)}';
    }
    final intlFormatter = NumberFormat('#,##0.00');
    return '$_currencySymbol${intlFormatter.format(amount)}';
  }

  static String formatWithCurrency(double amount, String currencyCode) {
    final sym = symbolFor(currencyCode);
    if (currencyCode == 'INR') {
      final formatter = NumberFormat('#,##,##0.00', 'en_IN');
      return '$sym${formatter.format(amount)}';
    }
    if (currencyCode == 'JPY') {
      final formatter = NumberFormat('#,##0', 'en_US');
      return '$sym${formatter.format(amount)}';
    }
    final formatter = NumberFormat('#,##0.00');
    return '$sym${formatter.format(amount)}';
  }

  static String formatGrouped(Map<String, double> amounts) {
    if (amounts.isEmpty) return format(0);
    if (amounts.length == 1) {
      final entry = amounts.entries.first;
      return formatWithCurrency(entry.value, entry.key);
    }
    final defaultCode = defaultCurrencyCode;
    final parts = <String>[];
    if (amounts.containsKey(defaultCode) && amounts[defaultCode]!.abs() > 0.005) {
      parts.add(formatWithCurrency(amounts[defaultCode]!, defaultCode));
    }
    for (final entry in amounts.entries) {
      if (entry.key != defaultCode && entry.value.abs() > 0.005) {
        parts.add(formatWithCurrency(entry.value, entry.key));
      }
    }
    if (parts.isEmpty) {
      // All entries are effectively zero: format 0 in the dominant (largest
      // magnitude) entry's currency rather than falling back to the default.
      final dominant = amounts.entries
          .reduce((a, b) => b.value.abs() > a.value.abs() ? b : a);
      return formatWithCurrency(0, dominant.key);
    }
    return parts.join(' + ');
  }

  static String formatGroupedAbs(Map<String, double> amounts) {
    final absAmounts = amounts.map((k, v) => MapEntry(k, v.abs()));
    return formatGrouped(absAmounts);
  }

  static double groupedTotal(Map<String, double> amounts) {
    return amounts.values.fold(0.0, (sum, v) => sum + v);
  }

  static String formatCompact(double amount) {
    if (_currencySymbol == '₹') {
      if (amount >= 10000000) {
        return '$_currencySymbol${(amount / 10000000).toStringAsFixed(1)}Cr';
      } else if (amount >= 100000) {
        return '$_currencySymbol${(amount / 100000).toStringAsFixed(1)}L';
      } else if (amount >= 1000) {
        return '$_currencySymbol${(amount / 1000).toStringAsFixed(1)}K';
      }
    } else {
      if (amount >= 1000000000) {
        return '$_currencySymbol${(amount / 1000000000).toStringAsFixed(1)}B';
      } else if (amount >= 1000000) {
        return '$_currencySymbol${(amount / 1000000).toStringAsFixed(1)}M';
      } else if (amount >= 1000) {
        return '$_currencySymbol${(amount / 1000).toStringAsFixed(1)}K';
      }
    }
    return format(amount);
  }
}
