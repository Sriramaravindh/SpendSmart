import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../providers/providers.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../core/constants/icon_map.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  @override
  Widget build(BuildContext context) {
    final budgets = ref.watch(currentBudgetsProvider);
    final overallBudget = ref.watch(overallBudgetProvider);
    final monthTotal = ref.watch(monthExpenseTotalProvider);
    final categories = ref.watch(categoriesProvider);
    final categoryTotals = ref.watch(monthCategoryTotalsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showBudgetDialog(categories: categories.valueOrNull ?? []),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall budget card
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('Monthly Budget', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
                    const SizedBox(height: 12),
                    overallBudget.when(
                      data: (budget) {
                        if (budget == null) {
                          return Column(
                            children: [
                              Text('No budget set', style: TextStyle(color: cs.onPrimaryContainer.withOpacity(0.7))),
                              const SizedBox(height: 8),
                              FilledButton.tonal(
                                onPressed: () => _showOverallBudgetDialog(),
                                child: const Text('Set Budget'),
                              ),
                            ],
                          );
                        }
                        final spent = monthTotal.valueOrNull ?? 0;
                        final progress = budget.amount > 0 ? (spent / budget.amount).clamp(0.0, 1.5) : 0.0;
                        final remaining = budget.amount - spent;
                        final progressColor = progress > 1.0 ? cs.error : progress > 0.8 ? const Color(0xFFFF9800) : cs.primary;

                        return Column(
                          children: [
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: CircularProgressIndicator(
                                      value: progress.clamp(0.0, 1.0),
                                      strokeWidth: 8,
                                      backgroundColor: cs.onPrimaryContainer.withOpacity(0.1),
                                      color: progressColor,
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),
                                  Text('${(progress * 100).toInt()}%', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: progressColor,
                                  )),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _BudgetStat(label: 'Budget', value: CurrencyFormatter.formatCompact(budget.amount), color: cs.onPrimaryContainer),
                                _BudgetStat(label: 'Spent', value: CurrencyFormatter.formatCompact(spent), color: progressColor),
                                _BudgetStat(label: 'Remaining', value: CurrencyFormatter.formatCompact(remaining.abs()), color: remaining >= 0 ? cs.primary : cs.error),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => _showOverallBudgetDialog(current: budget),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit'),
                            ),
                          ],
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Category Budgets', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            // Category budgets
            budgets.when(
              data: (budgetList) {
                final catBudgets = budgetList.where((b) => b.categoryId != null).toList();
                final cats = categories.valueOrNull ?? [];
                final totals = categoryTotals.valueOrNull ?? [];

                if (catBudgets.isEmpty) {
                  return Card(
                    color: cs.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.pie_chart_outline, size: 48, color: cs.onSurfaceVariant),
                            const SizedBox(height: 8),
                            Text('No category budgets set', style: TextStyle(color: cs.onSurfaceVariant)),
                            const SizedBox(height: 8),
                            FilledButton.tonal(
                              onPressed: () => _showBudgetDialog(categories: cats),
                              child: const Text('Add Category Budget'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: catBudgets.map((budget) {
                    final cat = cats.where((c) => c.id == budget.categoryId).firstOrNull;
                    if (cat == null) return const SizedBox.shrink();
                    final spent = totals.where((t) => t.categoryId == budget.categoryId).firstOrNull?.total ?? 0;
                    final progress = budget.amount > 0 ? (spent / budget.amount).clamp(0.0, 1.0) : 0.0;
                    final overBudget = spent > budget.amount;

                    return Card(
                      color: cs.surfaceContainerLow,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Color(cat.color).withOpacity(0.15),
                                  child: Icon(getIconData(cat.icon), color: Color(cat.color), size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                      Text(
                                        '${CurrencyFormatter.formatCompact(spent)} / ${CurrencyFormatter.formatCompact(budget.amount)}',
                                        style: TextStyle(fontSize: 12, color: overBudget ? cs.error : cs.outline),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => _showBudgetDialog(categories: cats, editBudget: budget),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogCtx) => AlertDialog(
                                        title: const Text('Delete Budget?'),
                                        content: Text('Remove the budget for "${cat.name}"?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dialogCtx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(dialogCtx, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await ref.read(budgetRepoProvider).delete(budget.id!);
                                      ref.read(budgetRefreshProvider.notifier).state++;
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: cs.outline.withOpacity(0.1),
                                color: overBudget ? cs.error : Color(cat.color),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOverallBudgetDialog({Budget? current}) async {
    final controller = TextEditingController(text: _formatAmount(current?.amount));
    try {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly Budget'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Budget Amount',
            prefixText: '${CurrencyFormatter.symbol} ',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount == null || amount <= 0) return;
              await ref.read(budgetRepoProvider).upsert(Budget(
                id: current?.id,
                amount: amount,
                month: AppDateUtils.currentYearMonth(),
              ));
              ref.read(budgetRefreshProvider.notifier).state++;
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    } finally {
      controller.dispose();
    }
  }

  // Formats a budget amount for prefilling a text field, dropping trailing
  // zeros (e.g. 1500.0 -> "1500", 1500.5 -> "1500.50").
  String _formatAmount(double? amount) {
    if (amount == null) return '';
    if (amount == amount.roundToDouble()) return amount.toStringAsFixed(0);
    return amount.toStringAsFixed(2);
  }

  Future<void> _showBudgetDialog({required List<Category> categories, Budget? editBudget}) async {
    final controller = TextEditingController(text: _formatAmount(editBudget?.amount));
    int? selectedCategoryId = editBudget?.categoryId;

    try {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(editBudget == null ? 'Add Category Budget' : 'Edit Budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (editBudget == null) ...[
                DropdownButtonFormField<int>(
                  value: selectedCategoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      children: [
                        Icon(getIconData(c.icon), color: Color(c.color), size: 20),
                        const SizedBox(width: 8),
                        Text(c.name),
                      ],
                    ),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedCategoryId = v),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Budget Amount',
                  prefixText: '${CurrencyFormatter.symbol} ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                autofocus: editBudget != null,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(controller.text);
                if (amount == null || amount <= 0) return;
                if (editBudget == null && selectedCategoryId == null) return;
                await ref.read(budgetRepoProvider).upsert(Budget(
                  id: editBudget?.id,
                  categoryId: selectedCategoryId ?? editBudget?.categoryId,
                  amount: amount,
                  month: AppDateUtils.currentYearMonth(),
                ));
                ref.read(budgetRefreshProvider.notifier).state++;
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
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

class _BudgetStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BudgetStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
      ],
    );
  }
}
