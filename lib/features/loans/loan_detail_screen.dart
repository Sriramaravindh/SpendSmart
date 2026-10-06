import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models.dart';
import '../../providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/emi_calculator.dart';

class LoanDetailScreen extends ConsumerStatefulWidget {
  final int loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  ConsumerState<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends ConsumerState<LoanDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Loan? _loan;
  List<LoanPayment> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = ref.read(loanRepoProvider);
    final loan = await repo.getById(widget.loanId);
    final payments = await repo.getPayments(widget.loanId);

    if (mounted) {
      setState(() {
        _loan = loan;
        _payments = payments;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    if (_loan == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Loan not found')));

    final loan = _loan!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loan.name),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              final router = GoRouter.of(context);
              if (v == 'edit') {
                final result = await context.push<bool>('/add-loan?editId=${loan.id}');
                if (result == true) {
                  ref.read(loanRefreshProvider.notifier).state++;
                  await _loadData();
                }
              } else if (v == 'close') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Mark as Closed?'),
                    content: const Text('This will mark the loan as closed. You can reopen it later from the menu.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Close Loan'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(loanRepoProvider).deactivate(loan.id!);
                  ref.read(loanRefreshProvider.notifier).state++;
                  router.pop();
                }
              } else if (v == 'reopen') {
                await ref.read(loanRepoProvider).activate(loan.id!);
                ref.read(loanRefreshProvider.notifier).state++;
                await _loadData();
              } else if (v == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Loan?'),
                    content: const Text('This will delete the loan, all its payment history, and linked expenses.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(backgroundColor: cs.error),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(loanRepoProvider).delete(loan.id!);
                  ref.read(loanRefreshProvider.notifier).state++;
                  ref.read(expenseRefreshProvider.notifier).state++;
                  router.pop();
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Loan')),
              if (loan.isActive)
                const PopupMenuItem(value: 'close', child: Text('Mark as Closed'))
              else
                const PopupMenuItem(value: 'reopen', child: Text('Reopen Loan')),
              const PopupMenuItem(value: 'delete', child: Text('Delete Loan')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'EMI Schedule'),
            Tab(text: 'Payments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverview(loan),
          _buildEmiSchedule(loan),
          _buildPayments(),
        ],
      ),
      floatingActionButton: loan.isActive ? FloatingActionButton.extended(
        onPressed: () => _showPrepaymentDialog(loan),
        icon: const Icon(Icons.add),
        label: const Text('Prepay'),
      ) : null,
    );
  }

  List<AmortizationRow> _generateSchedule(Loan loan) {
    final paidPayments = _payments.where((p) => !p.isExtraPayment).toList()
      ..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));
    final extraPayments = _payments.where((p) => p.isExtraPayment).toList()
      ..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));

    return EmiCalculator.generateSchedule(
      principal: loan.totalAmount,
      emiAmount: loan.emiAmount,
      tenureMonths: loan.tenureMonths,
      deductionDay: loan.deductionDay,
      disbursementDate: loan.effectiveDisbursementDate,
      firstEmiDate: loan.startDate,
      defaultInterestRate: loan.interestRate,
      rateHistory: loan.rateHistory,
      paidPayments: paidPayments,
      extraPayments: extraPayments,
    );
  }

  String _fmt(double amount) => CurrencyFormatter.formatWithCurrency(amount, _loan?.currency ?? 'INR');
  String _fmtC(double amount) {
    final code = _loan?.currency ?? 'INR';
    final sym = CurrencyFormatter.symbolFor(code);
    if (amount >= 10000000 && code == 'INR') return '$sym${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000 && code == 'INR') return '$sym${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000000) return '$sym${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '$sym${(amount / 1000).toStringAsFixed(1)}K';
    return _fmt(amount);
  }

  Widget _buildOverview(Loan loan) {
    final cs = Theme.of(context).colorScheme;
    final scheduleRows = _generateSchedule(loan);

    double principalPaid = 0;
    double interestPaid = 0;
    double principalRemaining = 0;
    double interestRemaining = 0;
    int paidEmiCount = 0;

    for (final row in scheduleRows) {
      if (row.isPaid) {
        principalPaid += row.principal;
        interestPaid += row.interest;
        paidEmiCount++;
      } else {
        principalRemaining += row.principal;
        interestRemaining += row.interest;
      }
    }

    interestPaid += loan.preEmiInterest;
    final totalExpectedInterest = interestPaid + interestRemaining;
    final totalOutstandingPayable = principalRemaining + interestRemaining;
    final totalMoneyPaid = principalPaid + interestPaid;
    final progress = loan.totalAmount > 0
        ? (principalPaid / loan.totalAmount).clamp(0.0, 1.0)
        : 0.0;

    final currentRate = loan.rateHistory.isNotEmpty
        ? EmiCalculator.getRateForDate(DateTime.now(), loan.interestRate, loan.rateHistory)
        : loan.interestRate;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 10,
                            backgroundColor: Colors.white.withOpacity(0.25),
                            color: Colors.white,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                            ),
                            const Text(
                              'PRINCIPAL PAID',
                              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 1.2),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _InfoColumn(label: 'PRINCIPAL LOAN', value: _fmtC(loan.totalAmount), valueColor: Colors.white, labelColor: Colors.white70),
                      Container(width: 1, height: 36, color: Colors.white24),
                      _InfoColumn(label: 'REMAINING', value: _fmtC(principalRemaining), valueColor: Colors.white, labelColor: Colors.white70),
                      Container(width: 1, height: 36, color: Colors.white24),
                      _InfoColumn(label: 'INTEREST LEFT', value: _fmtC(interestRemaining), valueColor: Colors.white, labelColor: Colors.white70),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _MetricCard(title: 'PRINCIPAL REMAINING', value: _fmt(principalRemaining), icon: Icons.account_balance_wallet_outlined, color: cs.primary)),
              const SizedBox(width: 8),
              Expanded(child: _MetricCard(title: 'INTEREST REMAINING', value: _fmt(interestRemaining), icon: Icons.percent_outlined, color: AppColors.warning)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _MetricCard(title: 'PRINCIPAL PAID', value: _fmt(principalPaid), icon: Icons.check_circle_outline, color: AppColors.income)),
              const SizedBox(width: 8),
              Expanded(child: _MetricCard(title: 'INTEREST PAID', value: _fmt(interestPaid), icon: Icons.trending_up_outlined, color: const Color(0xFFF472B6))),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: cs.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OVERALL FINANCIAL SUMMARY', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface, letterSpacing: 1.0)),
                  const SizedBox(height: 12),
                  _DetailRow(label: 'Total Outstanding Payable', value: _fmt(totalOutstandingPayable)),
                  _DetailRow(label: 'Total Money Spent So Far', value: _fmt(totalMoneyPaid)),
                  _DetailRow(label: 'Total Overall Expected Interest', value: _fmt(totalExpectedInterest)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: cs.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LOAN DETAILS', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface, letterSpacing: 1.0)),
                  const SizedBox(height: 12),
                  _DetailRow(label: 'Monthly EMI', value: _fmt(loan.emiAmount)),
                  _DetailRow(label: 'Current Rate', value: '${currentRate.toStringAsFixed(2)}% p.a.'),
                  _DetailRow(label: 'Original Tenure', value: '${loan.tenureMonths} months'),
                  _DetailRow(label: 'Remaining EMIs', value: '${scheduleRows.length - paidEmiCount} of ${scheduleRows.length} months'),
                  _DetailRow(label: 'EMI Day', value: '${loan.deductionDay} of each month'),
                  _DetailRow(label: 'Disbursement Date', value: AppDateUtils.formatDate(loan.effectiveDisbursementDate)),
                  _DetailRow(label: 'First EMI Date', value: AppDateUtils.formatDate(loan.startDate)),
                  _DetailRow(label: 'Status', value: loan.isActive ? 'Active' : 'Closed'),
                  _DetailRow(label: 'EMIs Paid', value: '$paidEmiCount / ${scheduleRows.length}'),
                  if (loan.preEmiInterest > 0)
                    _DetailRow(label: 'Pre-EMI Interest', value: _fmt(loan.preEmiInterest)),
                ],
              ),
            ),
          ),
          if (loan.rateHistory.length > 1) ...[
            const SizedBox(height: 16),
            Card(
              color: cs.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RATE HISTORY', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface, letterSpacing: 1.0)),
                    const SizedBox(height: 12),
                    ...loan.rateHistory.map((rc) => _DetailRow(
                      label: AppDateUtils.formatDate(rc.effectiveDate),
                      value: '${rc.rate.toStringAsFixed(2)}% p.a.',
                    )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmiSchedule(Loan loan) {
    final scheduleItems = _generateSchedule(loan);
    final cs = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: scheduleItems.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: const [
                SizedBox(width: 24, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                SizedBox(width: 28, child: Text('Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                Expanded(flex: 2, child: Text('Opening', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                Expanded(flex: 2, child: Text('EMI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                Expanded(flex: 2, child: Text('Principal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                Expanded(flex: 2, child: Text('Interest', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                Expanded(flex: 2, child: Text('Closing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                SizedBox(width: 28),
              ],
            ),
          );
        }

        final item = scheduleItems[index - 1];
        final prevRate = index > 1 ? scheduleItems[index - 2].rate : null;
        final rateChanged = prevRate != null && item.rate != prevRate;

        return InkWell(
          onTap: !item.isPaid ? () => _showEditEmiDialog(loan, item, scheduleItems) : null,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: item.isPaid
                  ? cs.primaryContainer.withOpacity(0.3)
                  : rateChanged
                      ? Colors.orange.withOpacity(0.08)
                      : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rateChanged)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('Rate: ${item.rate.toStringAsFixed(2)}%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.orange.shade700)),
                  ),
                Row(
                  children: [
                    SizedBox(width: 24, child: Text('${item.month}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant))),
                    SizedBox(width: 28, child: Text('${item.days}d', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))),
                    Expanded(flex: 2, child: Text(_fmtC(item.openingBalance), style: const TextStyle(fontSize: 10))),
                    Expanded(flex: 2, child: Text(_fmtC(item.emi), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.primary))),
                    Expanded(flex: 2, child: Text(_fmtC(item.principal), style: const TextStyle(fontSize: 10))),
                    Expanded(flex: 2, child: Text(_fmtC(item.interest), style: TextStyle(fontSize: 10, color: cs.error))),
                    Expanded(flex: 2, child: Text(_fmtC(item.closingBalance), style: const TextStyle(fontSize: 10))),
                    SizedBox(
                      width: 28,
                      child: item.isPaid
                          ? Icon(Icons.check_circle, size: 14, color: cs.primary)
                          : Icon(Icons.edit_outlined, size: 14, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditEmiDialog(Loan loan, AmortizationRow emiRow, List<AmortizationRow> allRows) async {
    final controller = TextEditingController(text: emiRow.emi.toStringAsFixed(0));
    try {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit EMI - Month ${emiRow.month}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Opening Balance: ${_fmt(emiRow.openingBalance)}', style: const TextStyle(fontSize: 13)),
            Text('Days: ${emiRow.days} | Rate: ${emiRow.rate.toStringAsFixed(2)}%', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(labelText: 'EMI Amount', prefixText: '${CurrencyFormatter.symbolFor(_loan?.currency ?? 'INR')} '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text('Changing this will recalculate all subsequent months.', style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount == null || amount <= 0) return;

              final dailyRate = emiRow.rate / 100.0 / 365.0;
              final interest = EmiCalculator.round2(emiRow.openingBalance * dailyRate * emiRow.days);
              final principal = EmiCalculator.round2((amount - interest).clamp(0.0, amount));

              final payment = LoanPayment(
                loanId: loan.id!,
                amount: amount,
                principal: principal,
                interest: interest,
                paymentDate: emiRow.date,
                currency: loan.currency,
              );
              await ref.read(loanRepoProvider).addPayment(payment);
              ref.read(loanRefreshProvider.notifier).state++;
              await _loadData();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Payment'),
          ),
        ],
      ),
    );
    } finally {
      controller.dispose();
    }
  }

  Widget _buildPayments() {
    final cs = Theme.of(context).colorScheme;
    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No payments recorded', style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (_, i) {
        final payment = _payments[i];
        return Card(
          color: cs.surfaceContainerLow,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: payment.isExtraPayment ? Colors.orange.withOpacity(0.15) : cs.primaryContainer,
              child: Icon(
                payment.isExtraPayment ? Icons.flash_on : Icons.payment,
                color: payment.isExtraPayment ? Colors.orange : cs.primary,
                size: 20,
              ),
            ),
            title: Text(
              _fmt(payment.amount),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${payment.isExtraPayment ? "Prepayment" : "EMI"} • ${AppDateUtils.formatDate(payment.paymentDate)}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('P: ${_fmtC(payment.principal)}', style: TextStyle(fontSize: 11, color: cs.primary)),
                    Text('I: ${_fmtC(payment.interest)}', style: TextStyle(fontSize: 11, color: cs.error)),
                  ],
                ),
                if (payment.isExtraPayment && payment.id != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Prepayment?'),
                          content: Text('Delete prepayment of ${_fmt(payment.amount)}? The linked expense will also be removed.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: FilledButton.styleFrom(backgroundColor: cs.error),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(loanRepoProvider).deletePayment(payment.id!);
                        ref.read(loanRefreshProvider.notifier).state++;
                        ref.read(expenseRefreshProvider.notifier).state++;
                        await _loadData();
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPrepaymentDialog(Loan loan) async {
    final controller = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool createExpense = true;
    final paymentMethods = await ref.read(paymentMethodRepoProvider).getAll();
    int selectedPaymentMethodId = paymentMethods.isNotEmpty ? paymentMethods.first.id! : 1;

    try {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Make Prepayment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '${CurrencyFormatter.symbolFor(_loan?.currency ?? 'INR')} ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, size: 20),
                  title: const Text('Payment Date', style: TextStyle(fontSize: 13)),
                  subtitle: Text(AppDateUtils.formatDate(selectedDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: loan.startDate,
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
                if (createExpense && paymentMethods.length > 1)
                  DropdownButtonFormField<int>(
                    value: selectedPaymentMethodId,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: paymentMethods.map((pm) => DropdownMenuItem(
                      value: pm.id,
                      child: Text(pm.name),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedPaymentMethodId = v);
                    },
                  ),
                if (createExpense && paymentMethods.length > 1)
                  const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Create expense entry', style: TextStyle(fontSize: 13)),
                  value: createExpense,
                  onChanged: (v) => setDialogState(() => createExpense = v),
                ),
                const SizedBox(height: 8),
                Text(
                  'The principal will be reduced by this amount. Remaining amortization will be recalculated.',
                  style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(controller.text);
                if (amount == null || amount <= 0) return;

                int? expenseId;
                if (createExpense) {
                  final db = await ref.read(expenseRepoProvider).insert(
                    Expense(
                      amount: amount,
                      categoryId: loan.categoryId,
                      paymentMethodId: selectedPaymentMethodId,
                      note: 'Prepayment: ${loan.name}',
                      date: selectedDate,
                      type: 'EXPENSE',
                      currency: loan.currency,
                    ),
                  );
                  expenseId = db;
                  ref.read(expenseRefreshProvider.notifier).state++;
                }

                final payment = LoanPayment(
                  loanId: loan.id!,
                  amount: amount,
                  principal: amount,
                  interest: 0,
                  paymentDate: selectedDate,
                  isExtraPayment: true,
                  expenseId: expenseId,
                  currency: loan.currency,
                );
                await ref.read(loanRepoProvider).addPayment(payment);
                ref.read(loanRefreshProvider.notifier).state++;
                await _loadData();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Pay'),
            ),
          ],
        ),
      ),
    );
    } finally {
      controller.dispose();
    }
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Color? labelColor;
  const _InfoColumn({required this.label, required this.value, this.valueColor, this.labelColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: valueColor ?? Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.8, color: labelColor ?? Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w400)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500, letterSpacing: 0.8),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: cs.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
