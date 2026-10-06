import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/icon_map.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models.dart';
import '../../providers/providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final processed = await ref.read(loanRepoProvider).processAutoDeductions();
        if (processed > 0 && mounted) {
          ref.read(expenseRefreshProvider.notifier).state++;
          ref.read(loanRefreshProvider.notifier).state++;
        }
      } catch (_) {}
      try {
        final recurringProcessed = await ref.read(recurringRepoProvider).processRecurringExpenses();
        if (recurringProcessed > 0 && mounted) {
          ref.read(expenseRefreshProvider.notifier).state++;
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAppBar(context, textTheme, colorScheme),
              const SizedBox(height: 20),
              _buildSummaryCards(context, ref, colorScheme, textTheme),
              const SizedBox(height: 24),
              _buildBudgetProgress(context, ref, colorScheme, textTheme),
              const SizedBox(height: 24),
              _buildWeeklyChart(context, ref, colorScheme, textTheme),
              const SizedBox(height: 24),
              _buildRecentExpenses(context, ref, colorScheme, textTheme),
              const SizedBox(height: 24),
              _buildSavingsGoalsOverview(context, ref, colorScheme, textTheme),
              const SizedBox(height: 24),
              _buildQuickActions(context, colorScheme, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  // -- App Bar --

  Widget _buildAppBar(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SpendSmart',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$greeting!',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () => context.push('/settings'),
            icon: Icon(Icons.settings_outlined, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  // -- Summary Cards --

  Widget _buildSummaryCards(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final monthIncomeGrouped = ref.watch(monthIncomeGroupedProvider);
    final monthExpenseGrouped = ref.watch(monthExpenseGroupedProvider);

    return Column(
      children: [
        // Balance Card
        _BalanceCard(
          incomeGroupedAsync: monthIncomeGrouped,
          expenseGroupedAsync: monthExpenseGrouped,
        ),
        const SizedBox(height: 12),
        // Income & Expense Row
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: "INCOME",
                groupedAsync: monthIncomeGrouped,
                accentColor: AppColors.income,
                iconData: Icons.arrow_upward_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: "EXPENSES",
                groupedAsync: monthExpenseGrouped,
                accentColor: AppColors.expense,
                iconData: Icons.arrow_downward_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -- Savings Goals Overview --

  Widget _buildSavingsGoalsOverview(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final goalsAsync = ref.watch(savingsGoalsProvider);

    return Card(
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SAVINGS GOALS',
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.2,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/savings-goals'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            goalsAsync.when(
              data: (goals) {
                if (goals.isEmpty) {
                  return InkWell(
                    onTap: () => context.push('/savings-goals'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Text('Set your first savings goal', style: textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  );
                }
                final topGoal = goals.first;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(topGoal.name, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          Text('${(topGoal.progress * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: Color(topGoal.color))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: topGoal.progress,
                          minHeight: 8,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(Color(topGoal.color)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${CurrencyFormatter.format(topGoal.savedAmount)} saved', style: textTheme.bodySmall),
                          Text('Target: ${CurrencyFormatter.format(topGoal.targetAmount)}', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final weekExpenses = ref.watch(weekExpensesProvider);

    return Card(
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WEEKLY OVERVIEW',
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: weekExpenses.when(
                data: (dailyTotals) =>
                    _WeeklyBarChart(dailyTotals: dailyTotals),
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Could not load chart',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Budget Progress --

  Widget _buildBudgetProgress(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final budgetAsync = ref.watch(overallBudgetProvider);
    final monthTotal = ref.watch(monthExpenseTotalProvider);

    return Card(
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: budgetAsync.when(
          data: (budget) {
            if (budget == null) {
              return InkWell(
                onTap: () => context.push('/budgets'),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add_chart_rounded,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set a Monthly Budget',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Track your spending against a target',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              );
            }

            return monthTotal.when(
              data: (spent) {
                final budgetAmount = budget.amount;
                final progress = budgetAmount > 0
                    ? (spent / budgetAmount).clamp(0.0, 1.0)
                    : 0.0;
                final remaining = budgetAmount - spent;
                final isOverBudget = remaining < 0;

                final progressColor = progress < 0.6
                    ? colorScheme.primary
                    : progress < 0.85
                        ? Colors.orange
                        : colorScheme.error;

                return Row(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 8,
                              strokeCap: StrokeCap.round,
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              valueColor:
                                  AlwaysStoppedAnimation(progressColor),
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: progressColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_rounded,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Monthly Budget',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _BudgetInfoRow(
                            label: 'Budget',
                            value: CurrencyFormatter.format(budgetAmount),
                            color: colorScheme.onSurface,
                          ),
                          const SizedBox(height: 4),
                          _BudgetInfoRow(
                            label: 'Spent',
                            value: CurrencyFormatter.format(spent),
                            color: progressColor,
                          ),
                          const SizedBox(height: 4),
                          _BudgetInfoRow(
                            label: isOverBudget ? 'Over' : 'Remaining',
                            value: CurrencyFormatter.format(
                                remaining.abs()),
                            color: isOverBudget
                                ? colorScheme.error
                                : colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (e, _) => Text(
                'Could not load spending data',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, _) => Text(
            'Could not load budget',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
          ),
        ),
      ),
    );
  }

  // -- Recent Expenses --

  Widget _buildRecentExpenses(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final expensesAsync = ref.watch(monthExpensesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT EXPENSES',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.2,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/history'),
                child: const Text('See all'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        expensesAsync.when(
          data: (expenses) {
            if (expenses.isEmpty) {
              return Card(
                color: colorScheme.surface,
                surfaceTintColor: colorScheme.surfaceTint,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 16,
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: colorScheme.onSurfaceVariant
                              .withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No expenses this month',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap + to add your first expense',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant
                                .withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final recentExpenses = expenses.toList()
              ..sort((a, b) => b.date.compareTo(a.date));
            final displayExpenses = recentExpenses.take(5).toList();

            return categoriesAsync.when(
              data: (categories) {
                final categoryMap = {
                  for (final c in categories) c.id: c,
                };

                return paymentMethodsAsync.when(
                  data: (paymentMethods) {
                    final pmMap = {
                      for (final pm in paymentMethods) pm.id: pm,
                    };

                    return Card(
                      color: colorScheme.surface,
                      surfaceTintColor: colorScheme.surfaceTint,
                      child: Column(
                        children: [
                          for (int i = 0;
                              i < displayExpenses.length;
                              i++) ...[
                            _ExpenseTile(
                              expense: displayExpenses[i],
                              category:
                                  categoryMap[displayExpenses[i].categoryId],
                              paymentMethod: pmMap[
                                  displayExpenses[i].paymentMethodId],
                              onTap: () => context.push(
                                '/edit-expense/${displayExpenses[i].id}',
                              ),
                              onDelete: () async {
                                final deleted = displayExpenses[i];
                                await ref.read(expenseRepoProvider).delete(deleted.id!);
                                refreshExpenses(ref);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Expense deleted'),
                                      action: SnackBarAction(
                                        label: 'Undo',
                                        onPressed: () async {
                                          await ref.read(expenseRepoProvider).insert(deleted);
                                          refreshExpenses(ref);
                                        },
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            if (i < displayExpenses.length - 1)
                              Divider(
                                height: 1,
                                indent: 72,
                                endIndent: 16,
                                color: colorScheme.outlineVariant
                                    .withOpacity(0.5),
                              ),
                          ],
                        ],
                      ),
                    );
                  },
                  loading: () => const _ShimmerList(),
                  error: (e, _) => const SizedBox.shrink(),
                );
              },
              loading: () => const _ShimmerList(),
              error: (e, _) => const SizedBox.shrink(),
            );
          },
          loading: () => const _ShimmerList(),
          error: (e, _) => Card(
            color: colorScheme.surface,
            surfaceTintColor: colorScheme.surfaceTint,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Could not load expenses',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // -- Quick Actions --

  Widget _buildQuickActions(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'QUICK ACTIONS',
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.receipt_long_rounded,
                label: 'STATEMENTS',
                onTap: () => context.push('/statements'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.savings_rounded,
                label: 'SAVINGS',
                onTap: () => context.push('/savings-goals'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.account_balance_rounded,
                label: 'LOANS',
                onTap: () => context.push('/loans'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Extracted widgets
// ---------------------------------------------------------------------------

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.incomeGroupedAsync,
    required this.expenseGroupedAsync,
  });

  final AsyncValue<Map<String, double>> incomeGroupedAsync;
  final AsyncValue<Map<String, double>> expenseGroupedAsync;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final incomeMap = incomeGroupedAsync.valueOrNull ?? {};
    final expenseMap = expenseGroupedAsync.valueOrNull ?? {};
    final income = CurrencyFormatter.groupedTotal(incomeMap);
    final expense = CurrencyFormatter.groupedTotal(expenseMap);
    final balance = income - expense;
    final isPositive = balance >= 0;
    final isLoading = incomeGroupedAsync.isLoading || expenseGroupedAsync.isLoading;

    final allCurrencies = {...incomeMap.keys, ...expenseMap.keys};
    final isMixed = allCurrencies.length > 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'MONTHLY BALANCE',
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPositive ? 'Surplus' : 'Deficit',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          isLoading
              ? SizedBox(
                  height: 36,
                  width: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : isMixed
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Income: ${CurrencyFormatter.formatGrouped(incomeMap)}',
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Expense: ${CurrencyFormatter.formatGrouped(expenseMap)}',
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      CurrencyFormatter.format(balance.abs()),
                      style: textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
          const SizedBox(height: 6),
          if (!isLoading && !isMixed)
            Text(
              isPositive
                  ? 'You saved ${CurrencyFormatter.format(balance)} this month'
                  : 'You overspent by ${CurrencyFormatter.format(balance.abs())} this month',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.75),
              ),
            ),
          if (!isLoading && isMixed)
            Text(
              'Multiple currencies — set exchange rates for a unified total',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.75),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.groupedAsync,
    required this.accentColor,
    required this.iconData,
  });

  final String label;
  final AsyncValue<Map<String, double>> groupedAsync;
  final Color accentColor;
  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppColors.premiumCardDecoration(
        brightness: Theme.of(context).brightness,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(iconData, color: accentColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          groupedAsync.when(
            data: (amounts) => Text(
              CurrencyFormatter.formatGrouped(amounts),
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            loading: () => SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(accentColor),
              ),
            ),
            error: (_, __) => Text(
              '--',
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.dailyTotals});

  final List<DailyTotal> dailyTotals;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Build a map of last 7 days, filling in zeros for missing days.
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = DateTime(now.year, now.month, now.day - 6 + i);
      return d;
    });

    final totalMap = <String, double>{};
    for (final dt in dailyTotals) {
      final key =
          '${dt.date.year}-${dt.date.month}-${dt.date.day}';
      totalMap[key] = dt.total;
    }

    final barValues = days.map((d) {
      final key = '${d.year}-${d.month}-${d.day}';
      return totalMap[key] ?? 0.0;
    }).toList();

    final maxVal = barValues.isEmpty
        ? 100.0
        : barValues.reduce(max).clamp(1.0, double.infinity);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.2,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            getTooltipColor: (_) =>
                colorScheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final actualValue = barValues[group.x.toInt()];
              return BarTooltipItem(
                CurrencyFormatter.format(actualValue),
                textTheme.bodySmall?.copyWith(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                    ) ??
                    const TextStyle(),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= days.length) {
                  return const SizedBox.shrink();
                }
                final isToday = index == days.length - 1;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    AppDateUtils.formatDayName(days[index]),
                    style: textTheme.labelSmall?.copyWith(
                      color: isToday
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight:
                          isToday ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(barValues.length, (i) {
          final isToday = i == barValues.length - 1;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: barValues[i] == 0 ? 0.5 : barValues[i],
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                gradient: isToday
                    ? const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: AppColors.accentGradient,
                      )
                    : LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          colorScheme.onSurfaceVariant.withOpacity(0.15),
                          colorScheme.onSurfaceVariant.withOpacity(0.05),
                        ],
                      ),
              ),
            ],
          );
        }),
      ),
      swapAnimationDuration: const Duration(milliseconds: 600),
      swapAnimationCurve: Curves.easeInOut,
    );
  }
}

class _BudgetInfoRow extends StatelessWidget {
  const _BudgetInfoRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.category,
    required this.paymentMethod,
    required this.onTap,
    this.onDelete,
  });

  final Expense expense;
  final Category? category;
  final PaymentMethod? paymentMethod;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final catColor =
        category != null ? Color(category!.color) : colorScheme.primary;
    final catIcon =
        category != null ? getIconData(category!.icon) : Icons.category;
    final title = category?.name ?? 'Expense';
    final noteText = (expense.note != null && expense.note!.isNotEmpty) ? expense.note! : null;
    final subtitle = [
      if (noteText != null) noteText,
      if (paymentMethod != null) paymentMethod!.name,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      onLongPress: onDelete != null ? () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Expense?'),
            content: Text('Delete ${CurrencyFormatter.formatWithCurrency(expense.amount, expense.currency)} for "$title"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) onDelete!();
      } : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(catIcon, color: catColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${expense.isIncome ? '+' : '-'}${CurrencyFormatter.formatWithCurrency(expense.amount, expense.currency)}',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: expense.isIncome ? AppColors.income : colorScheme.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppDateUtils.formatRelativeDate(expense.date),
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colorScheme.primary, size: 26),
              const SizedBox(height: 10),
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1.0,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: List.generate(
            3,
            (i) => Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 120,
                          height: 14,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 80,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 60,
                        height: 14,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 40,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
