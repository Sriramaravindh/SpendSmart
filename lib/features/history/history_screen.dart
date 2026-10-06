import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../core/constants/icon_map.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _searchQuery = '';
  int? _selectedCategoryId;
  int? _selectedPaymentMethodId;
  DateTimeRange? _selectedDateRange;
  bool _isSearchExpanded = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Debounce (~300ms) so we issue one SQL search, not one per keystroke.
  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(historySearchQueryProvider.notifier).state = value;
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _searchQuery = '');
    ref.read(historySearchQueryProvider.notifier).state = '';
  }

  // Category and payment-method filters still apply in-memory on top of the
  // SQL-backed result set (search/date-range handled by the provider).
  List<Expense> _applyFilters(List<Expense> expenses) {
    return expenses.where((expense) {
      if (_selectedCategoryId != null &&
          expense.categoryId != _selectedCategoryId) {
        return false;
      }
      if (_selectedPaymentMethodId != null &&
          expense.paymentMethodId != _selectedPaymentMethodId) {
        return false;
      }
      return true;
    }).toList();
  }

  Map<DateTime, List<Expense>> _groupByDate(List<Expense> expenses) {
    final Map<DateTime, List<Expense>> grouped = {};
    for (final expense in expenses) {
      final dateKey = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );
      grouped.putIfAbsent(dateKey, () => []).add(expense);
    }
    return grouped;
  }

  void _showFilterDialog() {
    final categories = ref.read(categoriesProvider).valueOrNull ?? [];
    final paymentMethods = ref.read(paymentMethodsProvider).valueOrNull ?? [];

    int? tempCategoryId = _selectedCategoryId;
    int? tempPaymentMethodId = _selectedPaymentMethodId;
    DateTimeRange? tempDateRange = _selectedDateRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Expenses',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempCategoryId = null;
                            tempPaymentMethodId = null;
                            tempDateRange = null;
                          });
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Category filter
                  Text(
                    'Category',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = tempCategoryId == cat.id;
                      return FilterChip(
                        selected: isSelected,
                        avatar: Icon(
                          getIconData(cat.icon),
                          size: 18,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onSecondaryContainer
                              : Color(cat.color),
                        ),
                        label: Text(cat.name),
                        onSelected: (selected) {
                          setSheetState(() {
                            tempCategoryId = selected ? cat.id : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Payment method filter
                  Text(
                    'Payment Method',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: paymentMethods.map((pm) {
                      final isSelected = tempPaymentMethodId == pm.id;
                      return FilterChip(
                        selected: isSelected,
                        avatar: Icon(
                          _paymentMethodIcon(pm.type),
                          size: 18,
                        ),
                        label: Text(pm.name),
                        onSelected: (selected) {
                          setSheetState(() {
                            tempPaymentMethodId = selected ? pm.id : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Date range filter
                  Text(
                    'Date Range',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(
                            tempDateRange == null
                                ? 'Any date'
                                : '${DateFormat('dd MMM yyyy').format(tempDateRange!.start)} – ${DateFormat('dd MMM yyyy').format(tempDateRange!.end)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(now.year - 10),
                              lastDate: DateTime(now.year + 1, 12, 31),
                              initialDateRange: tempDateRange,
                            );
                            if (picked != null) {
                              setSheetState(() => tempDateRange = picked);
                            }
                          },
                        ),
                      ),
                      if (tempDateRange != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear date range',
                          onPressed: () => setSheetState(() => tempDateRange = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategoryId = tempCategoryId;
                          _selectedPaymentMethodId = tempPaymentMethodId;
                          _selectedDateRange = tempDateRange;
                        });
                        ref.read(historyDateRangeProvider.notifier).state = tempDateRange;
                        Navigator.pop(context);
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _paymentMethodIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cash':
        return Icons.payments_outlined;
      case 'credit_card':
        return Icons.credit_card;
      case 'debit_card':
        return Icons.credit_card_outlined;
      case 'upi':
        return Icons.phone_android;
      case 'bank_transfer':
        return Icons.account_balance;
      case 'wallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.payment;
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final deleted = expense;
    await ref.read(expenseRepoProvider).delete(expense.id!);
    ref.read(expenseRefreshProvider.notifier).state++;
    ref.read(budgetRefreshProvider.notifier).state++;
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Expense deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await ref.read(expenseRepoProvider).insert(deleted);
            ref.read(expenseRefreshProvider.notifier).state++;
            ref.read(budgetRefreshProvider.notifier).state++;
          },
        ),
      ),
    );
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategoryId != null) count++;
    if (_selectedPaymentMethodId != null) count++;
    if (_selectedDateRange != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(historyExpensesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);
    final rateMap = ref.watch(currencyRateMapProvider).valueOrNull ?? {};

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axis: Axis.horizontal,
              axisAlignment: -1.0,
              child: child,
            ),
          ),
          child: _isSearchExpanded
              ? _buildSearchField()
              : const Text('History'),
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearchExpanded ? Icons.close : Icons.search),
            onPressed: () {
              final willExpand = !_isSearchExpanded;
              setState(() => _isSearchExpanded = willExpand);
              if (!willExpand) {
                _clearSearch();
              } else {
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) _searchFocusNode.requestFocus();
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Statements & PDF Export',
            onPressed: () => context.push('/statements'),
          ),
          Badge(
            isLabelVisible: _activeFilterCount > 0,
            label: Text('$_activeFilterCount'),
            child: IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
            ),
          ),
        ],
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to load expenses',
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () =>
                    ref.read(expenseRefreshProvider.notifier).state++,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (expenses) {
          final categories =
              categoriesAsync.valueOrNull ?? [];
          final paymentMethods =
              paymentMethodsAsync.valueOrNull ?? [];

          final categoryMap = {
            for (final c in categories) c.id: c,
          };
          final paymentMethodMap = {
            for (final pm in paymentMethods) pm.id: pm,
          };

          final filtered = _applyFilters(expenses);

          if (filtered.isEmpty) {
            return _buildEmptyState(
              hasFilters: _searchQuery.isNotEmpty ||
                  _selectedCategoryId != null ||
                  _selectedPaymentMethodId != null ||
                  _selectedDateRange != null,
            );
          }

          final grouped = _groupByDate(filtered);
          final sortedDates = grouped.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return _buildGroupedList(
            sortedDates: sortedDates,
            grouped: grouped,
            categoryMap: categoryMap,
            paymentMethodMap: paymentMethodMap,
            rateMap: rateMap,
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      key: const ValueKey('search_field'),
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search expenses...',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.zero,
        prefixIcon: Icon(
          Icons.search,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: _clearSearch,
              )
            : null,
      ),
      style: Theme.of(context).textTheme.bodyLarge,
      textInputAction: TextInputAction.search,
    );
  }

  Widget _buildEmptyState({required bool hasFilters}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters ? Icons.filter_list_off : Icons.receipt_long_outlined,
                size: 40,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasFilters ? 'No matching expenses' : 'No expenses yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try adjusting your search or filters'
                  : 'Start tracking by adding your first expense',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: () {
                  _debounce?.cancel();
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedCategoryId = null;
                    _selectedPaymentMethodId = null;
                    _selectedDateRange = null;
                    _isSearchExpanded = false;
                  });
                  ref.read(historySearchQueryProvider.notifier).state = '';
                  ref.read(historyDateRangeProvider.notifier).state = null;
                },
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, double> _computeDayTotals(List<Expense> dayExpenses, String defaultCurrency, Map<String, double> rateMap) {
    final totals = <String, double>{};
    for (final e in dayExpenses) {
      final sign = e.isIncome ? 1.0 : -1.0;
      final amount = e.amount * sign;
      if (e.currency == defaultCurrency) {
        totals[defaultCurrency] = (totals[defaultCurrency] ?? 0) + amount;
      } else if (rateMap.containsKey(e.currency)) {
        totals[defaultCurrency] = (totals[defaultCurrency] ?? 0) + amount * rateMap[e.currency]!;
      } else {
        totals[e.currency] = (totals[e.currency] ?? 0) + amount;
      }
    }
    return totals;
  }

  Widget _buildGroupedList({
    required List<DateTime> sortedDates,
    required Map<DateTime, List<Expense>> grouped,
    required Map<int?, Category> categoryMap,
    required Map<int?, PaymentMethod> paymentMethodMap,
    required Map<String, double> rateMap,
  }) {
    final defaultCurrency = CurrencyFormatter.defaultCurrencyCode;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dayExpenses = grouped[date]!;
        final dayTotals = _computeDayTotals(dayExpenses, defaultCurrency, rateMap);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(date, dayTotals),
            ...dayExpenses.map((expense) => _buildExpenseItem(
                  expense: expense,
                  category: categoryMap[expense.categoryId],
                  paymentMethod: paymentMethodMap[expense.paymentMethodId],
                )),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(DateTime date, Map<String, double> totals) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final relativeDate = AppDateUtils.formatRelativeDate(date);
    final netTotal = CurrencyFormatter.groupedTotal(totals);
    final isPositive = netTotal >= 0;

    String totalText;
    if (totals.length <= 1) {
      totalText = '${isPositive && netTotal != 0 ? '+' : ''}${CurrencyFormatter.formatGroupedAbs(totals)}${!isPositive ? ' spent' : ''}';
    } else {
      // Multiple currency buckets: show signed per-currency so income vs
      // spending is not mislabeled. No blanket ' spent' suffix.
      final parts = totals.entries.map((e) {
        final sign = e.value > 0 ? '+' : (e.value < 0 ? '-' : '');
        return '$sign${CurrencyFormatter.formatWithCurrency(e.value.abs(), e.key)}';
      }).toList();
      totalText = parts.join(' · ');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            relativeDate,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          Flexible(
            child: Text(
              totalText,
              style: theme.textTheme.titleSmall?.copyWith(
                color: isPositive && netTotal != 0 ? AppColors.income : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseItem({
    required Expense expense,
    Category? category,
    PaymentMethod? paymentMethod,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final catColor =
        category != null ? Color(category.color) : colorScheme.primary;

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: colorScheme.errorContainer,
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Expense?'),
            content: Text('Delete ${CurrencyFormatter.formatWithCurrency(expense.amount, expense.currency)} for "${expense.note?.isNotEmpty == true ? expense.note! : category?.name ?? 'Expense'}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => _deleteExpense(expense),
      child: ListTile(
        onTap: () => context.push('/edit-expense/${expense.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: catColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            getIconData(category?.icon ?? 'more_horiz'),
            color: catColor,
            size: 22,
          ),
        ),
        title: Text(
          category?.name ?? 'Expense',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Row(
          children: [
            if (expense.note?.isNotEmpty == true) ...[
              Flexible(
                child: Text(
                  expense.note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              _dot(),
            ],
            if (paymentMethod != null)
              Text(
                paymentMethod.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            _dot(),
            Text(
              DateFormat.jm().format(expense.date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: Text(
          CurrencyFormatter.formatWithCurrency(expense.amount, expense.currency),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _dot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
