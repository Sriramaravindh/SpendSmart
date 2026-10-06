import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/data/repositories/currency_rate_repository.dart';

void main() {
  group('CurrencyRateRepository.convertAmount', () {
    const defaultCurrency = 'INR';

    test('same-currency returns the amount unchanged', () {
      expect(
        CurrencyRateRepository.convertAmount(100.0, 'INR', defaultCurrency, const {}),
        100.0,
      );
    });

    test('with a rate returns amount * rate', () {
      final rateMap = {'USD': 83.0};
      expect(
        CurrencyRateRepository.convertAmount(10.0, 'USD', defaultCurrency, rateMap),
        830.0,
      );
    });

    test('missing rate for a foreign currency returns 0.0 (no raw passthrough)', () {
      // Fixed behavior: a foreign amount with no rate is excluded from the
      // converted total rather than silently returned raw.
      expect(
        CurrencyRateRepository.convertAmount(10.0, 'USD', defaultCurrency, const {}),
        0.0,
      );
    });
  });

  group('CurrencyRateRepository.tryConvert', () {
    const defaultCurrency = 'INR';

    test('same-currency returns the amount', () {
      expect(
        CurrencyRateRepository.tryConvert(100.0, 'INR', defaultCurrency, const {}),
        100.0,
      );
    });

    test('returns null when rate missing for a foreign currency', () {
      expect(
        CurrencyRateRepository.tryConvert(10.0, 'USD', defaultCurrency, const {}),
        isNull,
      );
    });

    test('returns converted value when rate present', () {
      final rateMap = {'EUR': 90.0};
      expect(
        CurrencyRateRepository.tryConvert(2.0, 'EUR', defaultCurrency, rateMap),
        180.0,
      );
    });
  });
}
