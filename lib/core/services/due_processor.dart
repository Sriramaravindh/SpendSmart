import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/loan_repository.dart';
import '../../data/repositories/recurring_expense_repository.dart';
import '../../providers/providers.dart';

/// Runs due-date processing independently of any screen (fix #50 — previously the
/// only trigger lived in HomeScreen.initState, so loans/recurring were not
/// processed unless Home was visited).
///
/// Repositories are instantiated directly (they use the AppDatabase singleton),
/// so this works with or without a provider container. When a [WidgetRef] is
/// supplied, data providers are refreshed if anything was created.
class DueProcessor {
  DueProcessor._();

  static bool _running = false;

  static Future<void> processAll(WidgetRef? ref) async {
    // Guard against overlapping runs (e.g. cold-start + resume firing together).
    if (_running) return;
    _running = true;
    bool loansChanged = false;
    bool recurringChanged = false;
    try {
      try {
        final processed = await LoanRepository().processAutoDeductions();
        loansChanged = processed > 0;
      } catch (e) {
        debugPrint('DueProcessor loan error: $e');
      }
      try {
        final processed =
            await RecurringExpenseRepository().processRecurringExpenses();
        recurringChanged = processed > 0;
      } catch (e) {
        debugPrint('DueProcessor recurring error: $e');
      }

      if (ref != null && (loansChanged || recurringChanged)) {
        try {
          ref.read(expenseRefreshProvider.notifier).state++;
          ref.read(budgetRefreshProvider.notifier).state++;
          if (loansChanged) ref.read(loanRefreshProvider.notifier).state++;
        } catch (e) {
          debugPrint('DueProcessor refresh error: $e');
        }
      }
    } finally {
      _running = false;
    }
  }
}
