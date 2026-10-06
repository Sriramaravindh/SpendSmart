// Real-browser (Chrome) end-to-end smoke + add-expense flow. This is the
// harness-validation test; feature-specific flows live in the other
// integration_test/*_test.dart files.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';

import 'package:expense_tracker/app.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SpendSmart smoke + add expense (real Chrome)', () {
    testWidgets('app boots to Home', (tester) async {
      await initAppForTest();
      await tester.pumpWidget(const ProviderScope(child: App()));
      await settle(tester);

      // Home shell chrome is present.
      expect(find.text('Add'), findsWidgets, reason: 'Add FAB on home shell');
      expect(find.text('Home'), findsWidgets, reason: 'bottom nav Home');
      expect(find.text('Settings'), findsWidgets, reason: 'bottom nav Settings');
    });

    testWidgets('user adds an expense and sees it on Home', (tester) async {
      await initAppForTest();
      await tester.pumpWidget(const ProviderScope(child: App()));
      await settle(tester);

      await tapAndSettle(tester, find.text('Add'), reason: 'open Add Expense');
      expect(find.text('Save Expense'), findsOneWidget);

      await enterInto(
          tester, find.widgetWithText(TextField, '0'), '150');
      await tapAndSettle(tester, find.text('Save Expense'));

      // Back on Home, the amount renders somewhere.
      expect(find.textContaining('150'), findsWidgets,
          reason: 'saved amount shows on Home');
    });
  });
}
