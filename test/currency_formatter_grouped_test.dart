import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/core/utils/currency_formatter.dart';

void main() {
  // CurrencyFormatter.defaultCurrencyCode is backed by shared_preferences via
  // CurrencyFormatter.init(). We set mock prefs so the default resolves to INR
  // deterministically regardless of host state.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CurrencyFormatter.init(); // -> defaults to INR / ₹
  });

  group('CurrencyFormatter.formatGrouped', () {
    test('an entry of exactly 0 in the default currency is skipped', () {
      // Multiple entries so we exercise the grouping branch (single-entry maps
      // short-circuit before the tolerance filter).
      final result = CurrencyFormatter.formatGrouped({
        'INR': 0.0, // default, exactly zero -> dropped by tolerance
        'USD': 10.0, // kept
      });
      // INR 0 must not appear; only the USD part remains.
      expect(result.contains('₹'), isFalse);
      expect(result.contains('\$'), isTrue);
      expect(result.contains('+'), isFalse);
    });

    test('near-zero default entry within tolerance is skipped', () {
      final result = CurrencyFormatter.formatGrouped({
        'INR': 0.004, // below 0.005 tolerance -> dropped
        'USD': 25.0,
      });
      expect(result.contains('₹'), isFalse);
      expect(result.contains('\$'), isTrue);
    });

    test('when ALL entries are ~0, formats 0 in the dominant entry currency', () {
      // No entry survives the tolerance filter. Rather than defaulting to INR,
      // formatGrouped must format 0 in the dominant (largest magnitude) currency.
      final result = CurrencyFormatter.formatGrouped({
        'INR': 0.0,
        'USD': 0.004, // largest magnitude among the (near-)zero entries
      });
      // Dominant is USD, so the zero should be shown with the USD symbol,
      // not the default INR symbol.
      expect(result.contains('\$'), isTrue);
      expect(result.contains('₹'), isFalse);
    });

    test('keeps both non-zero entries joined with +', () {
      final result = CurrencyFormatter.formatGrouped({
        'INR': 100.0,
        'USD': 5.0,
      });
      expect(result.contains('₹'), isTrue);
      expect(result.contains('\$'), isTrue);
      expect(result.contains('+'), isTrue);
    });
  });
}
