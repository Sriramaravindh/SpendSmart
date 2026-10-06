// Shared helpers for integration_test (real-browser / on-device) UI automation.
//
// Run on real Chrome with:
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_test.dart \
//     -d chrome
//
// (chromedriver must be running on port 4444, matching the installed Chrome.)
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'package:expense_tracker/core/utils/currency_formatter.dart';

/// Initializes the database factory + CurrencyFormatter the same way main()
/// does, so integration tests that call pumpWidget(App()) directly (bypassing
/// main) still have a working DB. On web this wires up the IndexedDB-backed
/// sqflite factory; on native the default factory is already set.
Future<void> initAppForTest() async {
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWebNoWebWorker;
  }
  await CurrencyFormatter.init();
}

/// Lets real async work (DB I/O, provider futures) run, then pumps frames.
/// pumpAndSettle can't be used: the app has perpetual CircularProgressIndicators
/// (loading states / lock splash) that never quiesce.
Future<void> settle(WidgetTester tester, {int rounds = 10}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 120)));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Taps the first match of [finder] after confirming it exists, then settles.
Future<void> tapAndSettle(WidgetTester tester, Finder finder,
    {String? reason, int rounds = 10}) async {
  expect(finder, findsWidgets, reason: reason);
  await tester.tap(finder.first);
  await settle(tester, rounds: rounds);
}

/// Scrolls [scrollable] until [finder] is visible, then returns it. Useful for
/// long forms (e.g. Add Loan) where the Save/field is below the fold.
Future<void> scrollTo(WidgetTester tester, Finder finder,
    {Finder? within}) async {
  final scrollable = within ??
      find.byType(Scrollable).first;
  await tester.scrollUntilVisible(finder, 200, scrollable: scrollable);
  await settle(tester, rounds: 3);
}

/// Enters [text] into the TextField found by its hint or label [match].
Future<void> enterInto(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field.first, text);
  await settle(tester, rounds: 3);
}
