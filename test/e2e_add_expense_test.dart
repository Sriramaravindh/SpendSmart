// End-to-end UI test: drives the real app the way a user would — opens the
// Add Expense screen, types an amount and note, picks a category/payment method,
// taps "Save Expense", and verifies the expense is persisted and shown on Home.
//
// This runs the FULL stack (widgets -> Riverpod providers -> repositories ->
// sqflite), not mocks. The sqflite C library is swapped for the FFI
// implementation so AppDatabase works under `flutter test` against a temp DB.
//
// Run with: flutter test test/e2e_add_expense_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker/app.dart';
import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/data/database/app_database.dart';

/// Lets real async work (sqflite disk I/O, provider futures) actually run, then
/// pumps frames. pumpAndSettle can't be used because the app has perpetual
/// CircularProgressIndicators (loading states / lock splash) that never quiesce.
/// runAsync yields to the real event loop so DB reads/writes complete.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 120)));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUpAll(() {
    // Use the FFI (desktop/test) sqflite implementation so AppDatabase's
    // getDatabasesPath()/openDatabase work headlessly.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Fresh prefs each test (CurrencyFormatter + feature toggles read these).
    SharedPreferences.setMockInitialValues({});
    await CurrencyFormatter.init();
    // Start from a clean DB so seeded defaults (categories/payment methods) and
    // our added expense are deterministic. Close the cached handle first so the
    // file can be deleted and re-seeded (test isolation).
    await AppDatabase.close();
    final dbPath = await getDatabasesPath();
    try {
      await deleteDatabase('$dbPath/expense_tracker.db');
    } catch (_) {}
  });

  testWidgets('user adds an expense via the UI and it shows up', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));

    // Pump a bounded number of frames instead of pumpAndSettle: the app has
    // perpetual CircularProgressIndicators (loading states / lock splash) that
    // never let pumpAndSettle quiesce. This still advances async DB/provider work.
    await _settle(tester);

    // Default app-lock is OFF, so we should land on Home. Open Add Expense
    // via the "Add" FAB.
    final addFab = find.text('Add');
    expect(addFab, findsWidgets, reason: 'Add FAB should be on the home shell');
    await tester.tap(addFab.first);
    await _settle(tester);

    // We should now be on the Add Expense screen.
    expect(find.text('Save Expense'), findsOneWidget,
        reason: 'Add Expense screen should show the Save button');

    // Type an amount into the amount field (hintText '0').
    final amountField = find.widgetWithText(TextField, '0').first;
    await tester.enterText(amountField, '150');
    await _settle(tester);

    // Tap Save. A default category + payment method are auto-selected by the
    // screen's post-frame auto-select, so a bare amount is saveable.
    await tester.tap(find.text('Save Expense'));
    await _settle(tester);

    // After save the screen pops back to Home. The saved amount (150) should
    // render somewhere on Home (today's total / recent expenses).
    expect(find.textContaining('150'), findsWidgets,
        reason: 'The saved expense amount (150) should render on Home');
  });

  testWidgets('added expense with a note is persisted and shown in History',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await _settle(tester);

    // Add an expense with a distinctive note.
    await tester.tap(find.text('Add').first);
    await _settle(tester);
    await tester.enterText(find.widgetWithText(TextField, '0').first, '275');
    // Note field (hintText 'Add a note (optional)').
    final noteField = find.widgetWithText(TextField, 'Add a note (optional)');
    if (noteField.evaluate().isNotEmpty) {
      await tester.enterText(noteField.first, 'Groceries E2E');
    }
    await _settle(tester);
    await tester.tap(find.text('Save Expense'));
    await _settle(tester);

    // Navigate to the History tab via the bottom nav.
    await tester.tap(find.text('History').first);
    await _settle(tester);

    // The persisted expense should be read back from the DB and listed.
    expect(find.textContaining('275'), findsWidgets,
        reason: 'The saved amount should appear in History');
    expect(find.textContaining('Groceries E2E'), findsWidgets,
        reason: 'The saved note should appear in History');
  });
}
