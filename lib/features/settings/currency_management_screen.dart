import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models.dart';
import '../../data/repositories/currency_rate_repository.dart';

class CurrencyManagementScreen extends StatefulWidget {
  const CurrencyManagementScreen({super.key});

  @override
  State<CurrencyManagementScreen> createState() => _CurrencyManagementScreenState();
}

class _CurrencyManagementScreenState extends State<CurrencyManagementScreen> {
  final _repo = CurrencyRateRepository();
  List<CurrencyRate> _rates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    final rates = await _repo.getAll();
    final seen = <String>{};
    final unique = <CurrencyRate>[];
    for (final r in rates) {
      final key = '${r.fromCurrency}-${r.toCurrency}';
      final reverseKey = '${r.toCurrency}-${r.fromCurrency}';
      if (!seen.contains(key) && !seen.contains(reverseKey)) {
        seen.add(key);
        unique.add(r);
      }
    }
    if (mounted) setState(() { _rates = unique; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Rates'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.currency_exchange, size: 64, color: cs.onSurfaceVariant.withAlpha(100)),
                      const SizedBox(height: 16),
                      Text('No conversion rates set', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Add rates to convert between currencies', style: TextStyle(color: cs.onSurfaceVariant.withAlpha(150), fontSize: 13)),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _showAddRateDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Rate'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final rate = _rates[index];
                    final fromSym = CurrencyFormatter.symbolFor(rate.fromCurrency);
                    final toSym = CurrencyFormatter.symbolFor(rate.toCurrency);
                    final fromName = CurrencyFormatter.codeToName[rate.fromCurrency] ?? rate.fromCurrency;
                    final toName = CurrencyFormatter.codeToName[rate.toCurrency] ?? rate.toCurrency;

                    return Card(
                      color: cs.surfaceContainerLow,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.primaryContainer,
                          child: Text(fromSym, style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
                        ),
                        title: Text('$fromName → $toName'),
                        subtitle: Text(
                          '1 $fromSym (${rate.fromCurrency}) = ${rate.rate.toStringAsFixed(4)} $toSym (${rate.toCurrency})',
                          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _showEditRateDialog(rate),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
                              onPressed: () => _deleteRate(rate),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: _rates.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showAddRateDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _showAddRateDialog() async {
    String fromCurrency = 'JPY';
    String toCurrency = 'INR';
    final rateController = TextEditingController();

    final codes = CurrencyFormatter.codeToSymbol.keys.toList();

    try {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Conversion Rate'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: fromCurrency,
                decoration: const InputDecoration(labelText: 'From Currency'),
                items: codes.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text('${CurrencyFormatter.symbolFor(c)} $c'),
                )).toList(),
                onChanged: (v) { if (v != null) setDialogState(() => fromCurrency = v); },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: toCurrency,
                decoration: const InputDecoration(labelText: 'To Currency'),
                items: codes.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text('${CurrencyFormatter.symbolFor(c)} $c'),
                )).toList(),
                onChanged: (v) { if (v != null) setDialogState(() => toCurrency = v); },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateController,
                decoration: const InputDecoration(
                  labelText: 'Rate',
                  hintText: 'e.g., 0.55 (1 JPY = 0.55 INR)',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final rate = double.tryParse(rateController.text);
                if (rate == null || rate <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Enter a valid number')),
                  );
                  return;
                }
                if (fromCurrency == toCurrency) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('From and To currencies must differ')),
                  );
                  return;
                }
                await _repo.upsertRate(fromCurrency, toCurrency, rate);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadRates();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    } finally {
      rateController.dispose();
    }
  }

  Future<void> _showEditRateDialog(CurrencyRate existing) async {
    final rateController = TextEditingController(text: existing.rate.toStringAsFixed(4));

    try {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${existing.fromCurrency} → ${existing.toCurrency}'),
        content: TextField(
          controller: rateController,
          decoration: InputDecoration(
            labelText: 'Rate',
            hintText: '1 ${existing.fromCurrency} = ? ${existing.toCurrency}',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final rate = double.tryParse(rateController.text);
              if (rate == null || rate <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter a valid number')),
                );
                return;
              }
              await _repo.upsertRate(existing.fromCurrency, existing.toCurrency, rate);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadRates();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    } finally {
      rateController.dispose();
    }
  }

  Future<void> _deleteRate(CurrencyRate rate) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Rate?'),
        content: Text('Remove ${rate.fromCurrency} ↔ ${rate.toCurrency} conversion rate?'),
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
      await _repo.delete(rate.fromCurrency, rate.toCurrency);
      _loadRates();
    }
  }
}
