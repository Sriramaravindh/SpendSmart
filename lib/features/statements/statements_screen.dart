import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/constants/icon_map.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/pdf_statement_service.dart';
import '../../data/models.dart';
import '../../providers/providers.dart';

class StatementsScreen extends ConsumerStatefulWidget {
  const StatementsScreen({super.key});

  @override
  ConsumerState<StatementsScreen> createState() => _StatementsScreenState();
}

class _StatementsScreenState extends ConsumerState<StatementsScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  String _selectedPreset = 'month';
  int? _selectedCategoryId;
  String? _selectedTag;
  Future<List<Expense>>? _transactionsFuture;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _refreshTransactions();
  }

  void _refreshTransactions() {
    _transactionsFuture = ref.read(expenseRepoProvider).getByDateRange(_startDate, _endDate);
  }

  void _setPreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _selectedPreset = preset;
      if (preset == 'month') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
      } else if (preset == 'last_month') {
        _startDate = DateTime(now.year, now.month - 1, 1);
        _endDate = DateTime(now.year, now.month, 0, 23, 59, 59);
      } else if (preset == 'last_3_months') {
        _startDate = DateTime(now.year, now.month - 3, 1);
        _endDate = now;
      }
      _refreshTransactions();
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _selectedPreset = 'custom';
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _refreshTransactions();
      });
    }
  }

  Future<void> _generateAndExportPdf(
    List<Expense> transactions,
    List<Category> categories,
    List<PaymentMethod> paymentMethods,
    Map<String, double> rateMap,
  ) async {
    setState(() => _isExporting = true);
    try {
      final categoryMap = {for (var c in categories) if (c.id != null) c.id!: c};
      final pmMap = {for (var p in paymentMethods) if (p.id != null) p.id!: p};

      final defaultCurrency = CurrencyFormatter.defaultCurrencyCode;
      final pdfIncomeGrouped = <String, double>{};
      final pdfExpenseGrouped = <String, double>{};
      for (final t in transactions) {
        final target = t.isIncome ? pdfIncomeGrouped : pdfExpenseGrouped;
        if (t.currency == defaultCurrency) {
          target[defaultCurrency] = (target[defaultCurrency] ?? 0) + t.amount;
        } else if (rateMap.containsKey(t.currency)) {
          target[defaultCurrency] = (target[defaultCurrency] ?? 0) + t.amount * rateMap[t.currency]!;
        } else {
          target[t.currency] = (target[t.currency] ?? 0) + t.amount;
        }
      }
      final totalIncome = CurrencyFormatter.groupedTotal(pdfIncomeGrouped);
      final totalExpense = CurrencyFormatter.groupedTotal(pdfExpenseGrouped);

      final selectedCat = categoryMap[_selectedCategoryId];
      final filterParts = <String>[];
      if (selectedCat != null) filterParts.add('Category: ${selectedCat.name}');
      if (_selectedTag != null && _selectedTag!.isNotEmpty) filterParts.add('Group: $_selectedTag');
      final filterName = filterParts.isNotEmpty ? filterParts.join(' | ') : null;

      final pdfBytes = await PdfStatementService.generateStatementPdf(
        startDate: _startDate,
        endDate: _endDate,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        transactions: transactions,
        categoryMap: categoryMap,
        paymentMethodMap: pmMap,
        filterName: filterName,
        rateMap: rateMap,
      );

      final suffix = _selectedTag != null
          ? '_${_selectedTag!.replaceAll(' ', '_')}'
          : (selectedCat != null ? '_${selectedCat.name.replaceAll(' ', '_')}' : '');

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Statement_${DateFormat('yyyyMMdd').format(_startDate)}_${DateFormat('yyyyMMdd').format(_endDate)}$suffix.pdf',
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider);
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statements'),
        centerTitle: true,
      ),
      body: categoriesAsync.when(
        data: (categories) => paymentMethodsAsync.when(
          data: (pms) => _buildBody(categories, pms, colorScheme, theme, ref.watch(currencyRateMapProvider).valueOrNull ?? {}),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error loading data')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading data')),
      ),
    );
  }

  Widget _buildBody(List<Category> categories, List<PaymentMethod> pms, ColorScheme cs, ThemeData theme, Map<String, double> rateMap) {
    final categoryMap = {for (var c in categories) if (c.id != null) c.id!: c};
    final pmMap = {for (var p in pms) if (p.id != null) p.id!: p};
    final dateFormat = DateFormat('dd MMM yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Selection
          _buildPeriodSection(dateFormat, cs, theme),
          const SizedBox(height: 12),

          // Filters
          _buildFilterSection(categories, cs, theme),
          const SizedBox(height: 20),

          // Statement Data
          _buildStatementData(categoryMap, pmMap, categories, pms, cs, theme, rateMap),
        ],
      ),
    );
  }

  Widget _buildPeriodSection(DateFormat dateFormat, ColorScheme cs, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text('Period', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickCustomRange,
                  icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                  label: const Text('Custom'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _periodChip('This Month', 'month', cs),
                _periodChip('Last Month', 'last_month', cs),
                _periodChip('Last 3 Months', 'last_3_months', cs),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FROM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(dateFormat.format(_startDate), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: cs.outlineVariant,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text(dateFormat.format(_endDate), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodChip(String label, String value, ColorScheme cs) {
    final selected = _selectedPreset == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => _setPreset(value),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildFilterSection(List<Category> categories, ColorScheme cs, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text('Filters', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                if (_selectedCategoryId != null || _selectedTag != null) ...[
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedCategoryId = null;
                      _selectedTag = null;
                    }),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: _selectedCategoryId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Category',
                prefixIcon: const Icon(Icons.category_outlined, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: cs.surfaceContainerLowest,
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All Categories')),
                ...categories.map((cat) => DropdownMenuItem<int?>(
                      value: cat.id,
                      child: Row(
                        children: [
                          Icon(getIconData(cat.icon), size: 16, color: Color(cat.color)),
                          const SizedBox(width: 8),
                          Flexible(child: Text(cat.name, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    )),
              ],
              onChanged: (val) => setState(() => _selectedCategoryId = val),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _selectedTag,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Group / Tag',
                prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: cs.surfaceContainerLowest,
              ),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All Groups')),
                ...ref.watch(tagsProvider).whenOrNull(
                  data: (tags) => tags.map((t) => DropdownMenuItem(
                    value: t.name,
                    child: Text(t.name),
                  )),
                ) ?? [],
              ],
              onChanged: (val) => setState(() => _selectedTag = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatementData(
    Map<int, Category> categoryMap,
    Map<int, PaymentMethod> pmMap,
    List<Category> categories,
    List<PaymentMethod> pms,
    ColorScheme cs,
    ThemeData theme,
    Map<String, double> rateMap,
  ) {
    return FutureBuilder<List<Expense>>(
      future: _transactionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Failed to load transactions', style: TextStyle(color: cs.error)),
          ));
        }

        final allTransactions = snapshot.data ?? [];
        final transactions = allTransactions.where((t) {
          if (_selectedCategoryId != null && t.categoryId != _selectedCategoryId) return false;
          if (_selectedTag != null && _selectedTag!.isNotEmpty) {
            final target = _selectedTag!.toLowerCase();
            final matches = (t.tag != null && t.tag!.toLowerCase() == target) ||
                (t.note != null && t.note!.toLowerCase().contains(target)) ||
                (categoryMap[t.categoryId]?.name.toLowerCase() == target);
            if (!matches) return false;
          }
          return true;
        }).toList();

        final defaultCurrency = CurrencyFormatter.defaultCurrencyCode;
        final incomeGrouped = <String, double>{};
        final expenseGrouped = <String, double>{};
        for (final t in transactions) {
          final target = t.isIncome ? incomeGrouped : expenseGrouped;
          if (t.currency == defaultCurrency) {
            target[defaultCurrency] = (target[defaultCurrency] ?? 0) + t.amount;
          } else if (rateMap.containsKey(t.currency)) {
            target[defaultCurrency] = (target[defaultCurrency] ?? 0) + t.amount * rateMap[t.currency]!;
          } else {
            target[t.currency] = (target[t.currency] ?? 0) + t.amount;
          }
        }
        final totalIncome = CurrencyFormatter.groupedTotal(incomeGrouped);
        final totalExpense = CurrencyFormatter.groupedTotal(expenseGrouped);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Row
            Row(
              children: [
                Expanded(child: _summaryTile('Income', incomeGrouped, AppColors.income, Icons.trending_up_rounded, cs)),
                const SizedBox(width: 8),
                Expanded(child: _summaryTile('Expenses', expenseGrouped, cs.error, Icons.trending_down_rounded, cs)),
              ],
            ),
            const SizedBox(height: 16),

            // Export Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: transactions.isEmpty || _isExporting ? null : () => _generateAndExportPdf(transactions, categories, pms, rateMap),
                icon: _isExporting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(_isExporting ? 'Generating...' : 'Download PDF Statement'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Transaction List Header
            Row(
              children: [
                Text('Transactions', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${transactions.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (transactions.isEmpty)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  child: Center(child: Text('No transactions for this period', style: TextStyle(fontSize: 14))),
                ),
              )
            else
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => Divider(height: 1, indent: 56, color: cs.outlineVariant.withOpacity(0.4)),
                  itemBuilder: (context, index) {
                    final t = transactions[index];
                    final cat = categoryMap[t.categoryId];
                    final pm = pmMap[t.paymentMethodId];
                    final isIncome = t.isIncome;

                    return Dismissible(
                      key: ValueKey(t.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: cs.errorContainer,
                        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Transaction?'),
                            content: Text('Delete ${CurrencyFormatter.formatWithCurrency(t.amount, t.currency)} for "${cat?.name ?? 'Uncategorized'}"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: FilledButton.styleFrom(backgroundColor: cs.error),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ) ?? false;
                      },
                      onDismissed: (_) async {
                        await ref.read(expenseRepoProvider).delete(t.id!);
                        ref.read(expenseRefreshProvider.notifier).state++;
                        ref.read(budgetRefreshProvider.notifier).state++;
                        setState(() => _refreshTransactions());
                      },
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: cat != null ? Color(cat.color).withOpacity(0.12) : cs.surfaceContainerHighest,
                          child: Icon(getIconData(cat?.icon ?? ''), color: cat != null ? Color(cat.color) : cs.onSurfaceVariant, size: 18),
                        ),
                        title: Text(cat?.name ?? 'Uncategorized', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text(
                          '${DateFormat('dd MMM yyyy').format(t.date)}${pm != null ? '  ·  ${pm.name}' : ''}${t.note != null && t.note!.isNotEmpty ? '\n${t.note}' : ''}',
                          style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                        ),
                        trailing: Text(
                          '${isIncome ? '+' : '-'} ${CurrencyFormatter.formatWithCurrency(t.amount, t.currency)}',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isIncome ? AppColors.income : cs.error),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _summaryTile(String label, Map<String, double> amounts, Color color, IconData icon, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.formatGrouped(amounts),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
