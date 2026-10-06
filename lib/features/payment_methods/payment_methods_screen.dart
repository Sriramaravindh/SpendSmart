import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../providers/providers.dart';

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  static const _typeIcons = {
    'CASH': Icons.money,
    'UPI': Icons.phone_android,
    'CREDIT_CARD': Icons.credit_card,
    'DEBIT_CARD': Icons.credit_card_outlined,
    'BANK_TRANSFER': Icons.account_balance,
    'WALLET': Icons.account_balance_wallet,
  };

  @override
  Widget build(BuildContext context) {
    final methods = ref.watch(paymentMethodsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Methods'), centerTitle: true),
      body: methods.when(
        data: (list) => list.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.payment_outlined, size: 64, color: cs.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text('No payment methods', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final pm = list[i];
                  return Card(
                    color: cs.surfaceContainerLow,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Icon(_typeIcons[pm.type] ?? Icons.payment, color: cs.primary, size: 22),
                      ),
                      title: Text(pm.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(_formatType(pm.type), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (pm.isDefault)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Chip(label: const Text('Default'), labelStyle: TextStyle(fontSize: 11, color: cs.primary)),
                            ),
                          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showDialog(pm: pm)),
                          IconButton(icon: Icon(Icons.delete_outline, size: 20, color: cs.error), onPressed: () => _delete(pm)),
                        ],
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Method'),
      ),
    );
  }

  String _formatType(String type) {
    switch (type) {
      case 'CASH': return 'Cash';
      case 'UPI': return 'UPI';
      case 'CREDIT_CARD': return 'Credit Card';
      case 'DEBIT_CARD': return 'Debit Card';
      case 'BANK_TRANSFER': return 'Bank Transfer';
      case 'WALLET': return 'Digital Wallet';
      default: return type;
    }
  }

  Future<void> _delete(PaymentMethod pm) async {
    final repo = ref.read(paymentMethodRepoProvider);
    // Count references across expenses and recurring_expenses, not just
    // expenses, so we know whether a reassign is required before deleting.
    final refCount = await repo.countReferences(pm.id!);
    final allMethods = ref.read(paymentMethodsProvider).valueOrNull ?? [];
    final otherMethods = allMethods.where((m) => m.id != pm.id).toList();

    if (!mounted) return;

    if (refCount > 0 && otherMethods.isNotEmpty) {
      int? reassignToId = otherMethods.first.id;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Delete Payment Method?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('"${pm.name}" is used by $refCount item(s). Reassign them to:'),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: reassignToId,
                  decoration: const InputDecoration(labelText: 'Move expenses to'),
                  items: otherMethods.map((m) => DropdownMenuItem(
                    value: m.id,
                    child: Row(
                      children: [
                        Icon(_typeIcons[m.type] ?? Icons.payment, size: 18),
                        const SizedBox(width: 8),
                        Text(m.name),
                      ],
                    ),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => reassignToId = v),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Delete & Reassign'),
              ),
            ],
          ),
        ),
      );
      if (confirm == true && reassignToId != null) {
        try {
          // Reassigns expenses and recurring rows atomically.
          await repo.deleteWithReassign(pm.id!, reassignToId!);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete payment method: $e')),
          );
          return;
        }
        if (!mounted) return;
        ref.read(paymentMethodRefreshProvider.notifier).state++;
        ref.read(expenseRefreshProvider.notifier).state++;
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Payment Method?'),
          content: Text(refCount > 0
              ? 'Cannot delete "${pm.name}" — it is still used by $refCount item(s) and there is no other payment method to reassign them to. Create another one first.'
              : 'Delete "${pm.name}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            if (refCount == 0)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Delete'),
              ),
          ],
        ),
      );
      if (confirm == true) {
        try {
          await repo.delete(pm.id!);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete payment method: $e')),
          );
          return;
        }
        if (!mounted) return;
        ref.read(paymentMethodRefreshProvider.notifier).state++;
      }
    }
  }

  Future<void> _showDialog({PaymentMethod? pm}) async {
    final nameController = TextEditingController(text: pm?.name ?? '');
    String selectedType = pm?.type ?? 'CASH';
    final types = ['CASH', 'UPI', 'CREDIT_CARD', 'DEBIT_CARD', 'BANK_TRANSFER', 'WALLET'];

    try {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(pm == null ? 'Add Payment Method' : 'Edit Payment Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              Text('Type', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: types.map((t) => ChoiceChip(
                  label: Text(_formatType(t)),
                  avatar: Icon(_typeIcons[t], size: 18),
                  selected: selectedType == t,
                  onSelected: (sel) { if (sel) setDialogState(() => selectedType = t); },
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final method = PaymentMethod(
                  id: pm?.id,
                  name: nameController.text.trim(),
                  type: selectedType,
                  isDefault: pm?.isDefault ?? false,
                );
                if (pm != null) {
                  await ref.read(paymentMethodRepoProvider).update(method);
                } else {
                  await ref.read(paymentMethodRepoProvider).insert(method);
                }
                ref.read(paymentMethodRefreshProvider.notifier).state++;
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    } finally {
      nameController.dispose();
    }
  }
}
