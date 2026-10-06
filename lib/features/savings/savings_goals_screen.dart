import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/icon_map.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models.dart';
import '../../providers/providers.dart';

class SavingsGoalsScreen extends ConsumerStatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  ConsumerState<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends ConsumerState<SavingsGoalsScreen> {
  void _showAddEditGoalDialog({SavingsGoal? editGoal}) {
    final nameController = TextEditingController(text: editGoal?.name ?? '');
    final targetController = TextEditingController(text: editGoal != null ? editGoal.targetAmount.toStringAsFixed(0) : '');
    final savedController = TextEditingController(text: editGoal != null ? editGoal.savedAmount.toStringAsFixed(0) : '0');
    int selectedColor = editGoal?.color ?? 0xFF8B5CF6;
    String selectedIcon = editGoal?.icon ?? 'savings';
    DateTime? selectedTargetDate = editGoal?.targetDate;

    final colors = [
      0xFF8B5CF6, 0xFF00D1FF, 0xFFF87171, 0xFF34D399,
      0xFFFBBF24, 0xFFF472B6, 0xFF60A5FA, 0xFF818CF8,
    ];

    final icons = ['savings', 'card_travel', 'laptop', 'directions_car', 'home', 'star', 'shopping_bag', 'school'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(editGoal == null ? 'Create Savings Goal' : 'Edit Goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Goal Name', hintText: 'e.g. Emergency Fund'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetController,
                  decoration: InputDecoration(labelText: 'Target Amount', prefixText: '${CurrencyFormatter.symbol} '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: savedController,
                  decoration: InputDecoration(labelText: 'Already Saved Amount', prefixText: '${CurrencyFormatter.symbol} '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                ),
                const SizedBox(height: 16),
                const Text('Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: colors.map((c) => GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = c),
                    child: CircleAvatar(
                      backgroundColor: Color(c),
                      radius: 14,
                      child: selectedColor == c ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Icon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: icons.map((ic) => InkWell(
                    onTap: () => setDialogState(() => selectedIcon = ic),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: selectedIcon == ic ? Color(selectedColor).withOpacity(0.2) : null,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selectedIcon == ic ? Color(selectedColor) : Colors.transparent),
                      ),
                      child: Icon(getIconData(ic), size: 20, color: Color(selectedColor)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, size: 20),
                  title: const Text('Target Date (optional)', style: TextStyle(fontSize: 13)),
                  subtitle: Text(
                    selectedTargetDate != null
                        ? DateFormat('dd MMM yyyy').format(selectedTargetDate!)
                        : 'No target date',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: selectedTargetDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setDialogState(() => selectedTargetDate = null),
                        )
                      : null,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedTargetDate ?? DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) setDialogState(() => selectedTargetDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final target = double.tryParse(targetController.text.trim());
                final saved = double.tryParse(savedController.text.trim()) ?? 0;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Enter a goal name')),
                  );
                  return;
                }
                if (target == null || target <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Enter a valid number')),
                  );
                  return;
                }

                final goal = SavingsGoal(
                  id: editGoal?.id,
                  name: name,
                  targetAmount: target,
                  savedAmount: saved,
                  targetDate: selectedTargetDate,
                  color: selectedColor,
                  icon: selectedIcon,
                );

                if (editGoal == null) {
                  await ref.read(savingsGoalRepoProvider).insert(goal);
                } else {
                  await ref.read(savingsGoalRepoProvider).update(goal);
                }

                ref.read(savingsGoalRefreshProvider.notifier).state++;
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(editGoal == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nameController.dispose();
      targetController.dispose();
      savedController.dispose();
    });
  }

  void _showDepositDialog(SavingsGoal goal) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deposit to ${goal.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current: ${CurrencyFormatter.format(goal.savedAmount)} / ${CurrencyFormatter.format(goal.targetAmount)}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              autofocus: true,
              decoration: InputDecoration(labelText: 'Amount to Add', prefixText: '${CurrencyFormatter.symbol} '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text.trim());
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter a valid number')),
                );
                return;
              }
              if (goal.id == null) return;

              await ref.read(savingsGoalRepoProvider).addDeposit(goal.id!, amount);
              ref.read(savingsGoalRefreshProvider.notifier).state++;
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add Deposit'),
          ),
        ],
      ),
    ).whenComplete(() => amountController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final goalsAsync = ref.watch(savingsGoalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        centerTitle: true,
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.savings_outlined, size: 64, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  const Text('No savings goals set yet.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Create goals for vacation, emergency fund, or buying gadgets.'),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => _showAddEditGoalDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Goal'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final goal = goals[index];
              final goalColor = Color(goal.color);

              return Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: goalColor.withOpacity(0.2),
                            child: Icon(getIconData(goal.icon), color: goalColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(goal.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                if (goal.targetDate != null)
                                  Text('Target: ${DateFormat('dd MMM yyyy').format(goal.targetDate!)}', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                _showAddEditGoalDialog(editGoal: goal);
                              } else if (v == 'delete' && goal.id != null) {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Savings Goal?'),
                                    content: Text('Are you sure you want to delete "${goal.name}"?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref.read(savingsGoalRepoProvider).delete(goal.id!);
                                  ref.read(savingsGoalRefreshProvider.notifier).state++;
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${CurrencyFormatter.format(goal.savedAmount)} saved', style: TextStyle(fontWeight: FontWeight.bold, color: goalColor)),
                          Text('Goal: ${CurrencyFormatter.format(goal.targetAmount)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: goal.progress,
                          minHeight: 10,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(goalColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _showDepositDialog(goal),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Deposit'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load savings goals')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditGoalDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
