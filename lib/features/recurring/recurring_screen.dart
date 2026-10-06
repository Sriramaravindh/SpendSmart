import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models.dart';
import '../../providers/providers.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/constants/icon_map.dart';

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  @override
  Widget build(BuildContext context) {
    final recurring = ref.watch(recurringExpensesProvider);
    final categories = ref.watch(categoriesProvider);
    final paymentMethods = ref.watch(paymentMethodsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Expenses'), centerTitle: true),
      body: recurring.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat_outlined, size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No recurring expenses', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text('Set up automatic expense tracking', style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }

          final cats = categories.valueOrNull ?? [];
          final pms = paymentMethods.valueOrNull ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final re = list[i];
              final cat = cats.where((c) => c.id == re.categoryId).firstOrNull;
              final pm = pms.where((p) => p.id == re.paymentMethodId).firstOrNull;

              return Card(
                color: cs.surfaceContainerLow,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cat != null ? Color(cat.color).withOpacity(0.15) : cs.primaryContainer,
                    child: Icon(
                      cat != null ? getIconData(cat.icon) : Icons.repeat,
                      color: cat != null ? Color(cat.color) : cs.primary,
                      size: 22,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        CurrencyFormatter.format(re.amount),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _frequencyLabel(re.frequency),
                          style: TextStyle(fontSize: 10, color: cs.primary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${cat?.name ?? "Unknown"} • ${pm?.name ?? "Unknown"}${re.note != null ? " • ${re.note}" : ""}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: re.isActive,
                        onChanged: (v) async {
                          await ref.read(recurringRepoProvider).toggleActive(re.id!, v);
                          ref.read(recurringRefreshProvider.notifier).state++;
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined, size: 20, color: cs.primary),
                        onPressed: () => _showAddDialog(cats, pms, editExpense: re),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete?'),
                              content: const Text('Delete this recurring expense?'),
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
                            await ref.read(recurringRepoProvider).delete(re.id!);
                            ref.read(recurringRefreshProvider.notifier).state++;
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(
          categories.valueOrNull ?? [],
          paymentMethods.valueOrNull ?? [],
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Recurring'),
      ),
    );
  }

  String _frequencyLabel(String freq) {
    switch (freq) {
      case 'daily': return 'Daily';
      case 'weekly': return 'Weekly';
      case 'monthly': return 'Monthly';
      case 'yearly': return 'Yearly';
      default: return freq;
    }
  }

  List<DateTime> _getUpcomingDates(DateTime startDate, String frequency, DateTime? endDate, int count) {
    final dates = <DateTime>[];
    var current = startDate;
    for (int i = 0; i < count; i++) {
      if (endDate != null && current.isAfter(endDate)) break;
      dates.add(current);
      switch (frequency) {
        case 'daily':
          current = current.add(const Duration(days: 1));
          break;
        case 'weekly':
          current = current.add(const Duration(days: 7));
          break;
        case 'monthly':
          final nextMonth = current.month + 1;
          final nextYear = current.year + (nextMonth > 12 ? 1 : 0);
          final actualMonth = nextMonth > 12 ? nextMonth - 12 : nextMonth;
          final lastDay = DateTime(nextYear, actualMonth + 1, 0).day;
          final day = startDate.day > lastDay ? lastDay : startDate.day;
          current = DateTime(nextYear, actualMonth, day);
          break;
        case 'yearly':
          current = DateTime(current.year + 1, current.month, current.day);
          break;
      }
    }
    return dates;
  }

  Future<void> _showAddDialog(List<Category> categories, List<PaymentMethod> pms, {RecurringExpense? editExpense}) async {
    final amountController = TextEditingController(text: editExpense != null ? editExpense.amount.toStringAsFixed(2) : '');
    final noteController = TextEditingController(text: editExpense?.note ?? '');
    int? selectedCategoryId = editExpense?.categoryId;
    int? selectedPmId = editExpense?.paymentMethodId;
    String selectedFreq = editExpense?.frequency ?? 'monthly';
    DateTime startDate = editExpense?.startDate ?? DateTime.now();
    DateTime? endDate = editExpense?.endDate;
    final frequencies = ['daily', 'weekly', 'monthly', 'yearly'];
    final dateFormat = DateFormat('dd MMM yyyy');

    try {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final amount = double.tryParse(amountController.text) ?? 0;
          final upcomingDates = _getUpcomingDates(startDate, selectedFreq, endDate, 5);

          return AlertDialog(
            title: Text(editExpense == null ? 'Add Recurring Expense' : 'Edit Recurring Expense'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(labelText: 'Amount', prefixText: '${CurrencyFormatter.symbol} '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedFreq,
                    decoration: const InputDecoration(labelText: 'Frequency'),
                    items: frequencies.map((f) => DropdownMenuItem(value: f, child: Text(_frequencyLabel(f)))).toList(),
                    onChanged: (v) { if (v != null) setDialogState(() => selectedFreq = v); },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Row(
                        children: [
                          Icon(getIconData(c.icon), color: Color(c.color), size: 18),
                          const SizedBox(width: 8),
                          Text(c.name),
                        ],
                      ),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => selectedCategoryId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedPmId,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: pms.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                    onChanged: (v) => setDialogState(() => selectedPmId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Note (optional)'),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, size: 20),
                    title: const Text('Start Date', style: TextStyle(fontSize: 13)),
                    subtitle: Text(dateFormat.format(startDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setDialogState(() => startDate = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event, size: 20),
                    title: const Text('End Date (optional)', style: TextStyle(fontSize: 13)),
                    subtitle: Text(endDate != null ? dateFormat.format(endDate!) : 'No end date', style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: endDate != null
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setDialogState(() => endDate = null))
                        : null,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: endDate ?? startDate.add(const Duration(days: 365)),
                        firstDate: startDate,
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setDialogState(() => endDate = picked);
                    },
                  ),
                  if (upcomingDates.isNotEmpty && amount > 0) ...[
                    const SizedBox(height: 12),
                    Text('Upcoming entries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Theme.of(ctx).colorScheme.primary)),
                    const SizedBox(height: 6),
                    ...upcomingDates.map((d) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(dateFormat.format(d), style: const TextStyle(fontSize: 12)),
                          Text(CurrencyFormatter.format(amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
                    if (endDate == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text('...and more', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter a valid number')),
                    );
                    return;
                  }
                  if (selectedCategoryId == null || selectedPmId == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Select a category and payment method')),
                    );
                    return;
                  }

                  final re = RecurringExpense(
                    id: editExpense?.id,
                    amount: amount,
                    categoryId: selectedCategoryId!,
                    paymentMethodId: selectedPmId!,
                    note: noteController.text.isEmpty ? null : noteController.text.trim(),
                    frequency: selectedFreq,
                    startDate: startDate,
                    endDate: endDate,
                  );
                  if (editExpense != null) {
                    await ref.read(recurringRepoProvider).update(re);
                  } else {
                    await ref.read(recurringRepoProvider).insert(re);
                  }
                  ref.read(recurringRefreshProvider.notifier).state++;
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(editExpense == null ? 'Save' : 'Update'),
              ),
            ],
          );
        },
      ),
    );
    } finally {
      amountController.dispose();
      noteController.dispose();
    }
  }
}
