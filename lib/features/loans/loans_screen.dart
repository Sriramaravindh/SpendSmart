import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models.dart';
import '../../providers/providers.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/constants/icon_map.dart';

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loans = ref.watch(loansProvider);
    final categories = ref.watch(categoriesProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Loans & EMI'), centerTitle: true),
      body: loans.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_outlined, size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No loans yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text('Track your EMIs and loan progress', style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => context.push('/add-loan'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Loan'),
                  ),
                ],
              ),
            );
          }

          final cats = categories.valueOrNull ?? [];
          final active = list.where((l) => l.isActive).toList();
          final closed = list.where((l) => !l.isActive).toList();

          return FutureBuilder<Map<int, double>>(
            future: _loadTotalPaid(ref, list),
            builder: (context, snapshot) {
              final paidMap = snapshot.data ?? {};
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (active.isNotEmpty) ...[
                    Text('Active Loans', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.primary)),
                    const SizedBox(height: 8),
                    ...active.map((loan) => _LoanCard(loan: loan, categories: cats, totalPaid: paidMap[loan.id] ?? 0)),
                    const SizedBox(height: 16),
                  ],
                  if (closed.isNotEmpty) ...[
                    Text('Closed Loans', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    ...closed.map((loan) => _LoanCard(loan: loan, categories: cats, totalPaid: paidMap[loan.id] ?? 0)),
                  ],
                  const SizedBox(height: 80),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-loan'),
        icon: const Icon(Icons.add),
        label: const Text('Add Loan'),
      ),
    );
  }

  static Future<Map<int, double>> _loadTotalPaid(WidgetRef ref, List<Loan> loans) async {
    final repo = ref.read(loanRepoProvider);
    final map = <int, double>{};
    for (final loan in loans) {
      if (loan.id != null) {
        map[loan.id!] = await repo.getTotalPaid(loan.id!);
      }
    }
    return map;
  }
}

class _LoanCard extends StatelessWidget {
  final Loan loan;
  final List<Category> categories;
  final double totalPaid;

  const _LoanCard({required this.loan, required this.categories, required this.totalPaid});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cat = categories.where((c) => c.id == loan.categoryId).firstOrNull;
    final progressColor = loan.isActive ? cs.primary : cs.onSurfaceVariant;

    final remaining = (loan.totalAmount - totalPaid).clamp(0.0, loan.totalAmount);
    final progress = loan.totalAmount > 0 ? (totalPaid / loan.totalAmount).clamp(0.0, 1.0) : 0.0;

        return Card(
          color: cs.surfaceContainerLow,
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => context.push('/loan/${loan.id}'),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (cat != null)
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(cat.color).withOpacity(0.15),
                          child: Icon(getIconData(cat.icon), color: Color(cat.color), size: 20),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loan.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            Text(
                              'EMI: ${CurrencyFormatter.formatWithCurrency(loan.emiAmount, loan.currency)} / month',
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      if (!loan.isActive)
                        Chip(
                          label: const Text('Closed'),
                          labelStyle: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                          side: BorderSide(color: cs.onSurfaceVariant.withOpacity(0.3)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _LoanStat(label: 'Total', value: CurrencyFormatter.formatWithCurrency(loan.totalAmount, loan.currency)),
                      _LoanStat(label: 'Principal Paid', value: CurrencyFormatter.formatWithCurrency(totalPaid, loan.currency)),
                      _LoanStat(label: 'Remaining', value: CurrencyFormatter.formatWithCurrency(remaining, loan.currency)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: cs.outline.withOpacity(0.1),
                      color: progressColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(progress * 100).toInt()}% complete',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
  }
}

class _LoanStat extends StatelessWidget {
  final String label;
  final String value;
  const _LoanStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
