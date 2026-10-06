import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models.dart';
import '../../providers/providers.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/emi_calculator.dart';
import '../../core/constants/icon_map.dart';

class AddLoanScreen extends ConsumerStatefulWidget {
  final int? editLoanId;
  const AddLoanScreen({super.key, this.editLoanId});

  @override
  ConsumerState<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends ConsumerState<AddLoanScreen> {
  final _nameController = TextEditingController();
  final _totalController = TextEditingController();
  final _emiController = TextEditingController();
  final _interestController = TextEditingController();
  final _tenureController = TextEditingController();
  int _deductionDay = 1;
  int? _selectedCategoryId;
  DateTime _startDate = DateTime.now();
  DateTime? _disbursementDate;
  String _selectedCurrency = CurrencyFormatter.defaultCurrencyCode;
  bool _isLoading = false;
  bool _isEditMode = false;
  Loan? _existingLoan;
  String? _emiWarning;
  List<LoanRateChange> _rateHistory = [];
  bool _showRateHistory = false;
  final _preEmiInterestController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.editLoanId != null) {
      _isEditMode = true;
      _loadLoanForEdit();
    }
  }

  Future<void> _loadLoanForEdit() async {
    final repo = ref.read(loanRepoProvider);
    final loan = await repo.getById(widget.editLoanId!);
    if (loan != null && mounted) {
      setState(() {
        _existingLoan = loan;
        _nameController.text = loan.name;
        _totalController.text = loan.totalAmount.toStringAsFixed(0);
        _emiController.text = loan.emiAmount.toStringAsFixed(0);
        _interestController.text = loan.interestRate.toString();
        _tenureController.text = loan.tenureMonths.toString();
        _deductionDay = loan.deductionDay;
        _selectedCategoryId = loan.categoryId;
        _startDate = loan.startDate;
        _disbursementDate = loan.disbursementDate;
        _selectedCurrency = loan.currency;
        _rateHistory = List.from(loan.rateHistory);
        _showRateHistory = loan.rateHistory.length > 1;
        if (loan.preEmiInterest > 0) {
          _preEmiInterestController.text = loan.preEmiInterest.toStringAsFixed(0);
        }
      });
    }
  }

  double? _calculateEmi() {
    final total = double.tryParse(_totalController.text);
    final interest = double.tryParse(_interestController.text);
    final tenure = int.tryParse(_tenureController.text);

    if (total == null || total <= 0 || tenure == null || tenure <= 0) return null;

    final rate = interest ?? 0;
    if (rate == 0) return total / tenure;

    return EmiCalculator.calculateEmiByFormula(
      principal: total,
      tenureMonths: tenure,
      interestRate: rate,
    );
  }

  void _onCalculateEmi() {
    final emi = _calculateEmi();
    if (emi == null) {
      _showError('Enter valid total amount and tenure first');
      return;
    }
    setState(() {
      _emiController.text = emi.toStringAsFixed(0);
      _emiWarning = null;
    });
  }

  void _validateEmi() {
    final calculatedEmi = _calculateEmi();
    final userEmi = double.tryParse(_emiController.text);

    if (calculatedEmi != null && userEmi != null && userEmi > 0) {
      final deviation = ((userEmi - calculatedEmi) / calculatedEmi).abs();
      if (deviation > 0.20) {
        setState(() {
          _emiWarning = 'EMI differs by ${(deviation * 100).toStringAsFixed(0)}% from calculated value (${CurrencyFormatter.formatWithCurrency(calculatedEmi, _selectedCurrency)})';
        });
        return;
      }
    }
    setState(() => _emiWarning = null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _totalController.dispose();
    _emiController.dispose();
    _interestController.dispose();
    _tenureController.dispose();
    _preEmiInterestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditMode ? 'Edit Loan' : 'Add Loan'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Loan Name', hintText: 'e.g., Home Loan - HDFC'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCurrency,
              decoration: const InputDecoration(labelText: 'Currency'),
              items: CurrencyFormatter.codeToSymbol.entries.map((e) => DropdownMenuItem(
                value: e.key,
                child: Text('${e.value} ${e.key} — ${CurrencyFormatter.codeToName[e.key]}'),
              )).toList(),
              onChanged: (v) { if (v != null) setState(() => _selectedCurrency = v); },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _totalController,
              decoration: InputDecoration(labelText: 'Total Amount (Principal)', prefixText: '${CurrencyFormatter.symbolFor(_selectedCurrency)} '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _interestController,
                    decoration: const InputDecoration(labelText: 'Interest Rate', suffixText: '% p.a.'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _tenureController,
                    decoration: const InputDecoration(labelText: 'Tenure', suffixText: 'months'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _emiController,
                        decoration: InputDecoration(
                          labelText: 'EMI Amount',
                          prefixText: '${CurrencyFormatter.symbolFor(_selectedCurrency)} ',
                          helperText: 'Enter bank EMI or tap Calculate',
                          helperStyle: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                        onChanged: (_) => _validateEmi(),
                      ),
                      if (_emiWarning != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_emiWarning!, style: TextStyle(fontSize: 11, color: cs.error)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.tonal(
                    onPressed: _onCalculateEmi,
                    child: const Text('Calculate'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _deductionDay,
              decoration: const InputDecoration(labelText: 'EMI Day'),
              items: List.generate(28, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
              onChanged: (v) { if (v != null) setState(() => _deductionDay = v); },
            ),
            const SizedBox(height: 20),

            // Rate History Section
            InkWell(
              onTap: () => setState(() => _showRateHistory = !_showRateHistory),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(_showRateHistory ? Icons.expand_less : Icons.expand_more, size: 20, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('Rate History (Floating Rate)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.primary)),
                    const Spacer(),
                    if (_rateHistory.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
                        child: Text('${_rateHistory.length} rates', style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer)),
                      ),
                  ],
                ),
              ),
            ),
            if (_showRateHistory) ...[
              if (_rateHistory.isNotEmpty)
                ..._rateHistory.asMap().entries.map((entry) {
                  final i = entry.key;
                  final rc = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      dense: true,
                      title: Text('${rc.rate.toStringAsFixed(2)}% p.a.', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text('From ${rc.effectiveDate.day}/${rc.effectiveDate.month}/${rc.effectiveDate.year}', style: const TextStyle(fontSize: 12)),
                      trailing: i == 0
                          ? Text('Initial', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))
                          : IconButton(
                              icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                              onPressed: () => setState(() => _rateHistory.removeAt(i)),
                            ),
                    ),
                  );
                }),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _showAddRateChangeDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Rate Change'),
              ),
              const SizedBox(height: 8),
              Text(
                'Add rate changes for floating-rate loans. The schedule will recalculate at each rate change.',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 20),

            Text('Category', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            categories.when(
              data: (cats) {
                final loanCats = cats.where((c) => c.name.toLowerCase().contains('loan')).toList();
                final otherCats = cats.where((c) => !c.name.toLowerCase().contains('loan')).toList();
                final sortedCats = [...loanCats, ...otherCats];

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...sortedCats.map((cat) => ChoiceChip(
                      avatar: Icon(getIconData(cat.icon), size: 18, color: _selectedCategoryId == cat.id ? cs.onSecondaryContainer : Color(cat.color)),
                      label: Text(cat.name),
                      selected: _selectedCategoryId == cat.id,
                      onSelected: (sel) { if (sel) setState(() => _selectedCategoryId = cat.id); },
                    )),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Add Category'),
                      onPressed: () => _showQuickAddCategoryDialog(cs),
                    ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 20),

            // Disbursement Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.account_balance, color: cs.primary),
              title: const Text('Disbursement Date'),
              subtitle: Text(
                _disbursementDate != null
                    ? '${_disbursementDate!.day}/${_disbursementDate!.month}/${_disbursementDate!.year}'
                    : 'Same as First EMI Date',
                style: TextStyle(fontWeight: FontWeight.w600, color: _disbursementDate != null ? null : cs.onSurfaceVariant),
              ),
              trailing: _disbursementDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _disbursementDate = null),
                    )
                  : null,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _disbursementDate ?? _startDate,
                  firstDate: DateTime(2015),
                  lastDate: _startDate,
                );
                if (picked != null) setState(() => _disbursementDate = picked);
              },
            ),

            // First EMI Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.calendar_today, color: cs.primary),
              title: const Text('First EMI Date'),
              subtitle: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}', style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2015),
                  lastDate: DateTime(2050),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),

            if (_disbursementDate != null && _disbursementDate!.isBefore(_startDate)) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _preEmiInterestController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Pre-EMI Interest Paid',
                  helperText: 'Interest paid during construction period',
                  prefixText: '${CurrencyFormatter.symbolFor(_selectedCurrency)} ',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _save,
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                label: Text(_isEditMode ? 'Update Loan' : 'Save Loan'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final total = double.tryParse(_totalController.text);
    final emi = double.tryParse(_emiController.text);
    final interest = double.tryParse(_interestController.text) ?? 0;
    final tenure = int.tryParse(_tenureController.text);

    if (name.isEmpty) { _showError('Enter loan name'); return; }
    if (total == null || total <= 0) { _showError('Enter valid total amount'); return; }
    if (emi == null || emi <= 0) { _showError('Enter valid EMI amount'); return; }
    if (tenure == null || tenure <= 0) { _showError('Enter valid tenure'); return; }
    if (_selectedCategoryId == null) { _showError('Select a category'); return; }

    setState(() => _isLoading = true);

    // Build rate history: ensure at least the initial rate entry
    final rateHistory = _rateHistory.isNotEmpty
        ? _rateHistory
        : [LoanRateChange(loanId: 0, effectiveDate: _disbursementDate ?? _startDate, rate: interest)];

    try {
    if (_isEditMode && _existingLoan != null) {
      final updatedLoan = Loan(
        id: _existingLoan!.id,
        name: name,
        totalAmount: total,
        emiAmount: emi,
        interestRate: interest,
        tenureMonths: tenure,
        deductionDay: _deductionDay.clamp(1, 28),
        categoryId: _selectedCategoryId!,
        startDate: _startDate,
        isActive: _existingLoan!.isActive,
        currency: _selectedCurrency,
        disbursementDate: _disbursementDate,
        rateHistory: rateHistory,
        preEmiInterest: double.tryParse(_preEmiInterestController.text) ?? 0,
      );
      await ref.read(loanRepoProvider).update(updatedLoan);
      await ref.read(loanRepoProvider).processAutoDeductions();
      ref.read(loanRefreshProvider.notifier).state++;
      ref.read(expenseRefreshProvider.notifier).state++;

      if (mounted) context.pop(true);
    } else {
      final loan = Loan(
        name: name,
        totalAmount: total,
        emiAmount: emi,
        interestRate: interest,
        tenureMonths: tenure,
        deductionDay: _deductionDay.clamp(1, 28),
        categoryId: _selectedCategoryId!,
        startDate: _startDate,
        currency: _selectedCurrency,
        disbursementDate: _disbursementDate,
        rateHistory: rateHistory,
        preEmiInterest: double.tryParse(_preEmiInterestController.text) ?? 0,
      );

      await ref.read(loanRepoProvider).insert(loan);
      await ref.read(loanRepoProvider).processAutoDeductions();
      ref.read(loanRefreshProvider.notifier).state++;
      ref.read(expenseRefreshProvider.notifier).state++;

      if (mounted) context.pop();
    }
    } catch (e) {
      if (mounted) _showError('Failed to save loan. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddRateChangeDialog() {
    final rateController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Rate Change'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: rateController,
                decoration: const InputDecoration(labelText: 'New Rate', suffixText: '% p.a.'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                autofocus: true,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, size: 20),
                title: const Text('Effective Date', style: TextStyle(fontSize: 13)),
                subtitle: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}', style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2015),
                    lastDate: DateTime(2050),
                  );
                  if (picked != null) setDialogState(() => selectedDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final rate = double.tryParse(rateController.text);
                if (rate == null || rate <= 0) return;
                setState(() {
                  _rateHistory.add(LoanRateChange(
                    loanId: _existingLoan?.id ?? 0,
                    effectiveDate: selectedDate,
                    rate: rate,
                  ));
                  _rateHistory.sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    ).whenComplete(() => rateController.dispose());
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showQuickAddCategoryDialog(ColorScheme colorScheme) async {
    final nameController = TextEditingController();
    String selectedIcon = availableIcons.first;
    int selectedColor = 0xFFE57373;

    final colors = [
      0xFFE57373, 0xFF64B5F6, 0xFFFFB74D, 0xFFBA68C8, 0xFF4DB6AC,
      0xFFF06292, 0xFF7986CB, 0xFF90A4AE, 0xFF5C6BC0, 0xFF26A69A,
      0xFFFF8A65, 0xFFAED581,
    ];

    try {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Category Name'),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Text('Icon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 120,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisSpacing: 8, crossAxisSpacing: 8),
                    itemCount: availableIcons.length,
                    itemBuilder: (_, i) {
                      final icon = availableIcons[i];
                      final isSelected = icon == selectedIcon;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedIcon = icon),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Color(selectedColor).withAlpha(50) : null,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: Color(selectedColor), width: 2) : null,
                          ),
                          child: Icon(getIconData(icon), size: 22, color: isSelected ? Color(selectedColor) : null),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((c) {
                    final isSelected = c == selectedColor;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedColor = c),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                          boxShadow: isSelected ? [BoxShadow(color: Color(c).withAlpha(100), blurRadius: 8)] : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final cat = Category(
                  name: nameController.text.trim(),
                  icon: selectedIcon,
                  color: selectedColor,
                  type: 'EXPENSE',
                );
                final newId = await ref.read(categoryRepoProvider).insert(cat);
                ref.read(categoryRefreshProvider.notifier).state++;
                if (mounted) {
                  setState(() => _selectedCategoryId = newId);
                }
                if (ctx.mounted) Navigator.pop(ctx);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Category "${cat.name}" added successfully!')),
                  );
                }
              },
              child: const Text('Add'),
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
