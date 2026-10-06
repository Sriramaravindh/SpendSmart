import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/services/app_lock_service.dart';
import 'core/services/due_processor.dart';
import 'core/services/notification_service.dart';
import 'core/utils/currency_formatter.dart';

import 'providers/providers.dart';
import 'features/home/home_screen.dart';
import 'features/history/history_screen.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/add_expense/add_expense_screen.dart';
import 'features/categories/categories_screen.dart';
import 'features/payment_methods/payment_methods_screen.dart';
import 'features/budgets/budget_screen.dart';
import 'features/loans/loans_screen.dart';
import 'features/loans/loan_detail_screen.dart';
import 'features/loans/add_loan_screen.dart';
import 'features/recurring/recurring_screen.dart';
import 'features/statements/statements_screen.dart';
import 'features/savings/savings_goals_screen.dart';
import 'features/tags/tags_screen.dart';
import 'features/ai_chat/ai_chat_screen.dart';
import 'features/settings/currency_management_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    errorBuilder: (_, __) => const Scaffold(body: Center(child: Text('Not found'))),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/statements', builder: (_, __) => const StatementsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/ai-chat', builder: (_, __) => const AiChatScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
          ]),
        ],
      ),
      GoRoute(path: '/add-expense', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const AddExpenseScreen()),
      GoRoute(
        path: '/edit-expense/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return const Scaffold(body: Center(child: Text('Not found')));
          }
          return AddExpenseScreen(expenseId: id);
        },
      ),
      GoRoute(path: '/categories', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const CategoriesScreen()),
      GoRoute(path: '/payment-methods', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const PaymentMethodsScreen()),
      GoRoute(path: '/tags', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const TagsScreen()),
      GoRoute(path: '/budgets', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const BudgetScreen()),
      GoRoute(path: '/loans', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const LoansScreen()),
      GoRoute(
        path: '/loan/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return const Scaffold(body: Center(child: Text('Not found')));
          }
          return LoanDetailScreen(loanId: id);
        },
      ),
      GoRoute(
        path: '/add-loan',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) {
          final editIdStr = state.uri.queryParameters['editId'];
          final editId = editIdStr != null ? int.tryParse(editIdStr) : null;
          return AddLoanScreen(editLoanId: editId);
        },
      ),
      GoRoute(path: '/recurring', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const RecurringScreen()),
      GoRoute(path: '/savings-goals', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const SavingsGoalsScreen()),
      GoRoute(path: '/currency-rates', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const CurrencyManagementScreen()),
    ],
  );
});

/// Re-locks the app after this long in the background (fix: lock on resume).
const Duration _appLockTimeout = Duration(minutes: 1);

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  // null = still deciding (cold-start lock check in progress).
  bool? _unlocked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Cold-start due processing + reminder refresh (not tab-bound; fix #50).
      await DueProcessor.processAll(ref);
      await _rescheduleReminders();
      await _coldStartLockCheck();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  Future<void> _onResumed() async {
    // Re-run due processing + reschedule reminders whenever the app returns.
    await DueProcessor.processAll(ref);
    await _rescheduleReminders();
    // Re-lock if enabled and the timeout elapsed while backgrounded.
    if (await AppLockService.needsUnlock(_appLockTimeout)) {
      if (mounted) setState(() => _unlocked = false);
    }
  }

  Future<void> _coldStartLockCheck() async {
    final enabled = await AppLockService.isEnabled();
    if (!enabled) {
      if (mounted) setState(() => _unlocked = true);
      return;
    }
    final ok = await AppLockService.authenticate();
    if (mounted) setState(() => _unlocked = ok);
  }

  Future<void> _rescheduleReminders() async {
    try {
      final enabled = await NotificationReminderPrefs.isEnabled();
      if (!enabled) return;
      final leadDays = await NotificationReminderPrefs.leadDays();
      final recurrings = await ref.read(recurringRepoProvider).getAll();
      final loans = await ref.read(loanRepoProvider).getAll();
      await NotificationService.rescheduleAll(
        recurrings,
        loans,
        leadDays,
        currencySymbol: CurrencyFormatter.symbol,
      );
    } catch (_) {
      // Best-effort; NotificationService already logs internally.
    }
  }

  Future<void> _tryUnlock() async {
    final ok = await AppLockService.authenticate();
    if (mounted) setState(() => _unlocked = ok);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SpendSmart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        if (_unlocked == false) {
          return _LockGate(onUnlock: _tryUnlock);
        }
        // While deciding on cold start, show a neutral splash over the router.
        if (_unlocked == null) {
          return const _LockSplash();
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

/// Persisted preferences for due-date reminders (kept here so both the lifecycle
/// hook and the settings screen can read them without a provider).
class NotificationReminderPrefs {
  NotificationReminderPrefs._();
  static const String kEnabled = 'reminders_enabled';
  static const String kLeadDays = 'reminders_lead_days';

  static Future<bool> isEnabled() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(kEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<int> leadDays() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getInt(kLeadDays) ?? 1;
    } catch (_) {
      return 1;
    }
  }
}

class _LockSplash extends StatelessWidget {
  const _LockSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _LockGate extends StatelessWidget {
  final Future<void> Function() onUnlock;
  const _LockGate({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: cs.primary),
              const SizedBox(height: 24),
              Text('SpendSmart is locked',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Authenticate to continue',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = navigationShell.currentIndex;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).navigationBarTheme.backgroundColor,
          border: Border(
            top: BorderSide(
              color: colorScheme.outline.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history_rounded), label: 'History'),
            NavigationDestination(icon: Icon(Icons.picture_as_pdf_outlined), selectedIcon: Icon(Icons.picture_as_pdf_rounded), label: 'Statements'),
            NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics_rounded), label: 'Analytics'),
            NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'AI'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
      floatingActionButton: selectedIndex <= 3
          ? Material(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => context.push('/add-expense'),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: colorScheme.onPrimary, size: 22),
                      const SizedBox(width: 8),
                      Text('Add', style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
