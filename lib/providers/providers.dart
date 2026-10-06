import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/services/auth_service.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/payment_method_repository.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/loan_repository.dart';
import '../data/repositories/recurring_expense_repository.dart';
import '../data/repositories/savings_goal_repository.dart';
import '../data/repositories/tag_repository.dart';
import '../data/repositories/currency_rate_repository.dart';
import '../data/models.dart';
import '../core/utils/date_utils.dart';

// Repositories
final expenseRepoProvider = Provider((_) => ExpenseRepository());
final categoryRepoProvider = Provider((_) => CategoryRepository());
final paymentMethodRepoProvider = Provider((_) => PaymentMethodRepository());
final budgetRepoProvider = Provider((_) => BudgetRepository());
final loanRepoProvider = Provider((_) => LoanRepository());
final recurringRepoProvider = Provider((_) => RecurringExpenseRepository());
final savingsGoalRepoProvider = Provider((_) => SavingsGoalRepository());
final tagRepoProvider = Provider((_) => TagRepository());
final currencyRateRepoProvider = Provider((_) => CurrencyRateRepository());

// Currency rate map (fromCurrency -> rate to default currency)
final currencyRateMapProvider = FutureProvider<Map<String, double>>((ref) {
  return ref.read(currencyRateRepoProvider).getRateMapToDefault();
});

// Theme
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());

// Google Auth User
final authUserProvider = StateNotifierProvider<AuthNotifier, GoogleSignInAccount?>((ref) => AuthNotifier());

class AuthNotifier extends StateNotifier<GoogleSignInAccount?> {
  AuthNotifier() : super(null) {
    _init();
  }

  Future<void> _init() async {
    final user = await AuthService.signInSilently();
    state = user;
  }

  Future<AuthResult> signIn() async {
    final result = await AuthService.signIn();
    state = result.user;
    return result;
  }

  Future<void> signOut() async {
    await AuthService.signOut();
    state = null;
  }
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  bool _userSet = false;

  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('theme_mode') ?? 'system';
    if (_userSet) return;
    state = mode == 'dark' ? ThemeMode.dark : mode == 'light' ? ThemeMode.light : ThemeMode.system;
  }

  Future<void> setMode(ThemeMode mode) async {
    _userSet = true;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system');
  }
}

// Refresh triggers - bump these to invalidate data providers
final expenseRefreshProvider = StateProvider<int>((ref) => 0);
final categoryRefreshProvider = StateProvider<int>((ref) => 0);
final paymentMethodRefreshProvider = StateProvider<int>((ref) => 0);
final budgetRefreshProvider = StateProvider<int>((ref) => 0);
final loanRefreshProvider = StateProvider<int>((ref) => 0);
final recurringRefreshProvider = StateProvider<int>((ref) => 0);
final savingsGoalRefreshProvider = StateProvider<int>((ref) => 0);
final tagRefreshProvider = StateProvider<int>((ref) => 0);

// Categories
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  ref.watch(categoryRefreshProvider);
  return ref.read(categoryRepoProvider).getAll();
});

// Payment methods
final paymentMethodsProvider = FutureProvider<List<PaymentMethod>>((ref) {
  ref.watch(paymentMethodRefreshProvider);
  return ref.read(paymentMethodRepoProvider).getAll();
});

// Tags
final tagsProvider = FutureProvider<List<Tag>>((ref) {
  ref.watch(tagRefreshProvider);
  return ref.read(tagRepoProvider).getAll();
});

// Expenses for current month
final monthExpensesProvider = FutureProvider<List<Expense>>((ref) {
  ref.watch(expenseRefreshProvider);
  return ref.read(expenseRepoProvider).getByDateRange(AppDateUtils.monthStart(), AppDateUtils.monthEnd());
});

// Today's total
final todayTotalProvider = FutureProvider<double>((ref) {
  ref.watch(expenseRefreshProvider);
  return ref.read(expenseRepoProvider).getTotalByDateRange(AppDateUtils.todayStart(), AppDateUtils.todayEnd());
});

// Month total
final monthTotalProvider = FutureProvider<double>((ref) {
  ref.watch(expenseRefreshProvider);
  return ref.read(expenseRepoProvider).getTotalByDateRange(AppDateUtils.monthStart(), AppDateUtils.monthEnd());
});

// Month Income Total
final monthIncomeTotalProvider = FutureProvider<double>((ref) {
  ref.watch(expenseRefreshProvider);
  return ref.read(expenseRepoProvider).getTotalIncomeByDateRange(AppDateUtils.monthStart(), AppDateUtils.monthEnd());
});

// Month Expense Total
final monthExpenseTotalProvider = FutureProvider<double>((ref) {
  ref.watch(expenseRefreshProvider);
  return ref.read(expenseRepoProvider).getTotalExpenseByDateRange(AppDateUtils.monthStart(), AppDateUtils.monthEnd());
});

// Month Net Balance (Income - Expense)
final monthNetBalanceProvider = FutureProvider<double>((ref) async {
  ref.watch(expenseRefreshProvider);
  final repo = ref.read(expenseRepoProvider);
  final income = await repo.getTotalIncomeByDateRange(AppDateUtils.monthStart(), AppDateUtils.monthEnd());
  final expense = await repo.getTotalExpenseByDateRange(AppDateUtils.monthStart(), AppDateUtils.monthEnd());
  return income - expense;
});

// Grouped totals (per-currency maps) for multi-currency display
final monthIncomeGroupedProvider = FutureProvider<Map<String, double>>((ref) {
  ref.watch(expenseRefreshProvider);
  return ref.read(expenseRepoProvider).getTotalIncomeGrouped(AppDateUtils.monthStart(), AppDateUtils.monthEnd());
});

final monthExpenseGroupedProvider = FutureProvider<Map<String, double>>((ref) {
  ref.watch(expenseRefreshProvider);
  return ref.read(expenseRepoProvider).getTotalExpenseGrouped(AppDateUtils.monthStart(), AppDateUtils.monthEnd());
});

// Week expenses (for chart)
final weekExpensesProvider = FutureProvider<List<DailyTotal>>((ref) {
  ref.watch(expenseRefreshProvider);
  return ref.read(expenseRepoProvider).getDailyTotals(AppDateUtils.weekStart(), AppDateUtils.todayEnd());
});

// Category totals for month
final monthCategoryTotalsProvider = FutureProvider<List<CategoryTotal>>((ref) {
  ref.watch(expenseRefreshProvider);
  return ref.read(expenseRepoProvider).getCategoryTotals(AppDateUtils.monthStart(), AppDateUtils.monthEnd());
});

// Payment method totals for month
final monthPaymentMethodTotalsProvider = FutureProvider<List<PaymentMethodTotal>>((ref) {
  ref.watch(expenseRefreshProvider);
  return ref.read(expenseRepoProvider).getPaymentMethodTotals(AppDateUtils.monthStart(), AppDateUtils.monthEnd());
});

// All expenses (history) — limited to most recent 500 for performance
final allExpensesProvider = FutureProvider<List<Expense>>((ref) {
  ref.watch(expenseRefreshProvider);
  return ref.read(expenseRepoProvider).getAll(limit: 500);
});

// --- History search & date-range (fix #48: push search/filtering into SQL) ---

// Debounced search query for the History screen (set by the search field).
final historySearchQueryProvider = StateProvider<String>((ref) => '');

// Optional date range for the History screen filter sheet.
final historyDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

// Source list for History: runs an indexed SQL search when a query is present,
// a date-range query when a range is set, otherwise the most-recent 500. This
// replaces the old in-memory filter over a 500-row cap.
final historyExpensesProvider = FutureProvider<List<Expense>>((ref) async {
  ref.watch(expenseRefreshProvider);
  final query = ref.watch(historySearchQueryProvider).trim();
  final range = ref.watch(historyDateRangeProvider);
  final repo = ref.read(expenseRepoProvider);

  if (query.isNotEmpty) {
    final results = await repo.search(query);
    if (range != null) {
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
      return results
          .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
          .toList();
    }
    return results;
  }

  if (range != null) {
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
    return repo.getByDateRange(start, end);
  }

  return repo.getAll(limit: 500);
});

// Budgets for current month
final currentBudgetsProvider = FutureProvider<List<Budget>>((ref) {
  ref.watch(budgetRefreshProvider);
  return ref.read(budgetRepoProvider).getByMonth(AppDateUtils.currentYearMonth());
});

// Overall budget for current month
final overallBudgetProvider = FutureProvider<Budget?>((ref) {
  ref.watch(budgetRefreshProvider);
  return ref.read(budgetRepoProvider).getOverallBudget(AppDateUtils.currentYearMonth());
});

// Loans
final loansProvider = FutureProvider<List<Loan>>((ref) {
  ref.watch(loanRefreshProvider);
  return ref.read(loanRepoProvider).getAll();
});

final activeLoansProvider = FutureProvider<List<Loan>>((ref) {
  ref.watch(loanRefreshProvider);
  return ref.read(loanRepoProvider).getActive();
});

// Recurring expenses
final recurringExpensesProvider = FutureProvider<List<RecurringExpense>>((ref) {
  ref.watch(recurringRefreshProvider);
  return ref.read(recurringRepoProvider).getAll();
});

// Savings goals
final savingsGoalsProvider = FutureProvider<List<SavingsGoal>>((ref) {
  ref.watch(savingsGoalRefreshProvider);
  return ref.read(savingsGoalRepoProvider).getAll();
});

// Helper to refresh all data
void refreshAll(WidgetRef ref) {
  ref.read(expenseRefreshProvider.notifier).state++;
  ref.read(budgetRefreshProvider.notifier).state++;
  ref.read(loanRefreshProvider.notifier).state++;
  ref.read(categoryRefreshProvider.notifier).state++;
  ref.read(paymentMethodRefreshProvider.notifier).state++;
  ref.read(recurringRefreshProvider.notifier).state++;
  ref.read(savingsGoalRefreshProvider.notifier).state++;
  ref.read(tagRefreshProvider.notifier).state++;
}

void refreshExpenses(WidgetRef ref) {
  ref.read(expenseRefreshProvider.notifier).state++;
  ref.read(budgetRefreshProvider.notifier).state++;
}
