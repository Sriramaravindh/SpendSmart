import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/icon_map.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models.dart';
import '../../providers/providers.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final int? expenseId;

  const AddExpenseScreen({super.key, this.expenseId});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFocusNode = FocusNode();

  int? _selectedCategoryId;
  int? _selectedPaymentMethodId;
  DateTime _selectedDate = DateTime.now();
  String _transactionType = 'EXPENSE'; // 'EXPENSE' or 'INCOME'
  String? _selectedTag;
  String _selectedCurrency = CurrencyFormatter.defaultCurrencyCode;
  bool _isLoading = false;

  // Guards so auto-select post-frame callbacks are only scheduled once each.
  bool _categoryAutoSelected = false;
  bool _tagAutoSelected = false;
  bool _paymentMethodAutoSelected = false;

  bool get _isEditMode => widget.expenseId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadExpense();
    }
  }

  Future<void> _loadExpense() async {
    final expense = await ref.read(expenseRepoProvider).getById(widget.expenseId!);
    if (expense != null && mounted) {
      setState(() {
        _amountController.text = expense.amount.toStringAsFixed(
          expense.amount == expense.amount.roundToDouble() ? 0 : 2,
        );
        _selectedCategoryId = expense.categoryId;
        _selectedPaymentMethodId = expense.paymentMethodId;
        _selectedDate = expense.date;
        _noteController.text = expense.note ?? '';
        _transactionType = expense.type;
        _selectedTag = expense.tag;
        _selectedCurrency = expense.currency;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final now = DateTime.now();
      setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day, now.hour, now.minute));
    }
  }

  Future<void> _save() async {
    // Validate
    var amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    // Strip a trailing '.' left by partial input (e.g. "12.")
    if (amountText.endsWith('.')) {
      amountText = amountText.substring(0, amountText.length - 1);
    }

    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(amountText)) {
      _showError('Please enter a valid amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount greater than zero');
      return;
    }

    if (_selectedCategoryId == null) {
      _showError('Please select a category');
      return;
    }

    if (_selectedPaymentMethodId == null) {
      _showError('Please select a payment method');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final expense = Expense(
        id: widget.expenseId,
        amount: amount,
        categoryId: _selectedCategoryId!,
        paymentMethodId: _selectedPaymentMethodId!,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        date: _selectedDate,
        type: _transactionType,
        tag: _selectedTag,
        currency: _selectedCurrency,
      );

      if (widget.expenseId != null) {
        await ref.read(expenseRepoProvider).update(expense);
      } else {
        await ref.read(expenseRepoProvider).insert(expense);
      }

      ref.read(expenseRefreshProvider.notifier).state++;

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        _showError('Failed to save expense. Please try again.');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showCurrencyPicker(ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Select Currency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            ...CurrencyFormatter.codeToSymbol.entries.map((entry) {
              final code = entry.key;
              final sym = entry.value;
              final name = CurrencyFormatter.codeToName[code] ?? code;
              return ListTile(
                leading: Text(sym, style: const TextStyle(fontSize: 24)),
                title: Text(name),
                subtitle: Text(code),
                trailing: _selectedCurrency == code ? Icon(Icons.check_circle, color: colorScheme.primary) : null,
                onTap: () {
                  setState(() => _selectedCurrency = code);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categories = ref.watch(categoriesProvider);
    final paymentMethods = ref.watch(paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode
            ? (_transactionType == 'INCOME' ? 'Edit Income' : 'Edit Expense')
            : (_transactionType == 'INCOME' ? 'Add Income' : 'Add Expense')),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -- Expense / Income Segmented Toggle --
              if (!_isEditMode) ...[
                _buildTypeSegmentedButton(colorScheme),
                const SizedBox(height: 20),
              ],

              // -- Amount Input --
              _buildAmountSection(colorScheme),
              const SizedBox(height: 28),

              // -- Date Picker --
              _buildDateSection(theme, colorScheme),
              const SizedBox(height: 28),

              // -- Category Selection --
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionLabel('Category', theme),
                  TextButton.icon(
                    onPressed: () => _showQuickAddCategoryDialog(colorScheme),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Category'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              categories.when(
                data: (cats) => _buildCategoryChips(cats, colorScheme),
                loading: () => const _ChipShimmer(),
                error: (_, __) => Text(
                  'Failed to load categories',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
              const SizedBox(height: 28),

              // -- Expense Group / Tag Selection --
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionLabel('Expense Group / Tag', theme),
                  TextButton.icon(
                    onPressed: () => context.push('/tags'),
                    icon: const Icon(Icons.settings, size: 18),
                    label: const Text('Manage'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildTagChips(colorScheme),
              const SizedBox(height: 28),

              // -- Payment Method Selection --
              _buildSectionLabel('Payment Method', theme),
              const SizedBox(height: 10),
              paymentMethods.when(
                data: (methods) =>
                    _buildPaymentMethodChips(methods, colorScheme),
                loading: () => const _ChipShimmer(),
                error: (_, __) => Text(
                  'Failed to load payment methods',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
              const SizedBox(height: 28),

              // -- Note Field --
              _buildSectionLabel('Note', theme),
              const SizedBox(height: 10),
              _buildNoteField(colorScheme),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            onPressed: _isLoading ? null : _save,
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : Icon(_isEditMode ? Icons.check : Icons.add),
            label: Text(
              _isEditMode ? 'Update Expense' : 'Save Expense',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Amount Section
  // -------------------------------------------------------------------------
  Widget _buildAmountSection(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Text(
            'AMOUNT',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              GestureDetector(
                onTap: () => _showCurrencyPicker(colorScheme),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withAlpha(120),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        CurrencyFormatter.symbolFor(_selectedCurrency),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down, size: 20, color: colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 80, maxWidth: 240),
                  child: TextField(
                    controller: _amountController,
                    focusNode: _amountFocusNode,
                    autofocus: !_isEditMode,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                      letterSpacing: -1,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w300,
                        color: colorScheme.onSurface.withAlpha(80),
                      ),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Date Section
  // -------------------------------------------------------------------------
  Widget _buildDateSection(ThemeData theme, ColorScheme colorScheme) {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withAlpha(100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withAlpha(50),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                size: 20,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isToday
                        ? 'Today, ${AppDateUtils.formatDate(_selectedDate)}'
                        : AppDateUtils.formatDate(_selectedDate),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Section Label
  // -------------------------------------------------------------------------
  Widget _buildSectionLabel(String label, ThemeData theme) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1.5,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Type Toggle Button
  // -------------------------------------------------------------------------
  Widget _buildTypeSegmentedButton(ColorScheme colorScheme) {
    return Center(
      child: SegmentedButton<String>(
        segments: [
          const ButtonSegment(
            value: 'EXPENSE',
            label: Text('Expense'),
            icon: Icon(Icons.arrow_downward_rounded, color: Colors.red),
          ),
          ButtonSegment(
            value: 'INCOME',
            label: const Text('Income'),
            icon: Icon(Icons.arrow_upward_rounded, color: AppColors.income),
          ),
        ],
        selected: {_transactionType},
        onSelectionChanged: (Set<String> newSelection) {
          setState(() {
            _transactionType = newSelection.first;
            _selectedCategoryId = null; // reset category on type switch
          });
        },
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: _transactionType == 'INCOME'
              ? AppColors.income.withOpacity(0.15)
              : colorScheme.errorContainer,
          selectedForegroundColor: _transactionType == 'INCOME'
              ? AppColors.income
              : colorScheme.onErrorContainer,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Category Chips
  // -------------------------------------------------------------------------
  Widget _buildCategoryChips(List<Category> allCategories, ColorScheme colorScheme) {
    final categories = allCategories.where((c) => c.type == _transactionType || c.type == 'BOTH').toList();

    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No categories found. Add categories first.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    // Auto-select default category when not in edit mode and nothing selected
    if (_selectedCategoryId == null && !_isEditMode && !_categoryAutoSelected) {
      final defaultCat = categories.where((c) => c.isDefault).firstOrNull;
      if (defaultCat != null) {
        _categoryAutoSelected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedCategoryId == null) {
            setState(() => _selectedCategoryId = defaultCat.id);
          }
        });
      }
    }

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showQuickAddCategoryDialog(colorScheme),
              child: Container(
                width: 84,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withAlpha(80),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outline.withAlpha(80), style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, size: 22, color: colorScheme.primary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add New',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colorScheme.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final category = categories[index - 1];
          final isSelected = _selectedCategoryId == category.id;
          final catColor = Color(category.color);

          return GestureDetector(
            onTap: () =>
                setState(() => _selectedCategoryId = category.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: 84,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? catColor.withAlpha(40)
                    : colorScheme.surfaceContainerHighest.withAlpha(80),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? catColor : Colors.transparent,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? catColor.withAlpha(50)
                          : colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      getIconData(category.icon),
                      size: 22,
                      color: isSelected
                          ? catColor
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? catColor
                          : colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Tag / Group Chips
  // -------------------------------------------------------------------------
  Widget _buildTagChips(ColorScheme colorScheme) {
    final tagsAsync = ref.watch(tagsProvider);

    return tagsAsync.when(
      data: (tags) {
        final tagNames = tags.map((t) => t.name).toList();
        final hasCustomTag = _selectedTag != null && !tagNames.contains(_selectedTag);

        if (_selectedTag == null && !_isEditMode && tags.isNotEmpty && !_tagAutoSelected) {
          final defaultTag = tags.where((t) => t.isDefault).firstOrNull ?? tags.first;
          _tagAutoSelected = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedTag == null) {
              setState(() => _selectedTag = defaultTag.name);
            }
          });
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...tags.map((tag) {
              final isSelected = _selectedTag == tag.name;
              return ChoiceChip(
                label: Text(tag.name),
                avatar: isSelected ? const Icon(Icons.label, size: 16) : const Icon(Icons.label_outlined, size: 16),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedTag = tag.name);
                },
              );
            }),
            if (hasCustomTag)
              InputChip(
                label: Text(_selectedTag!),
                avatar: const Icon(Icons.label, size: 16),
                selected: true,
                onDeleted: () {
                  setState(() => _selectedTag = tags.isNotEmpty ? tags.first.name : null);
                },
                onPressed: () {},
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Custom Tag'),
              onPressed: _showCustomTagDialog,
            ),
          ],
        );
      },
      loading: () => const _ChipShimmer(),
      error: (_, __) => Text(
        'Failed to load tags',
        style: TextStyle(color: colorScheme.error),
      ),
    );
  }

  Future<void> _showCustomTagDialog() async {
    final controller = TextEditingController();
    try {
      await showDialog(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Tag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. Vacation, Renovation'),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                setState(() => _selectedTag = text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Set Tag'),
          ),
        ],
      ),
    );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showQuickAddCategoryDialog(ColorScheme colorScheme) async {
    final nameController = TextEditingController();
    String selectedIcon = availableIcons.isNotEmpty ? availableIcons.first : 'category';
    int selectedColor = 0xFF8B5CF6;

    final colors = [
      0xFF8B5CF6, 0xFF00D1FF, 0xFFF87171, 0xFF34D399, 0xFFFBBF24,
      0xFFF472B6, 0xFF60A5FA, 0xFF818CF8, 0xFFFB923C, 0xFF4ADE80,
      0xFFC084FC, 0xFF38BDF8,
    ];

    try {
      await showDialog(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Category'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
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
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 140,
                    child: GridView.count(
                      crossAxisCount: 5,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: availableIcons.map((icon) {
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
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
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
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final cat = Category(
                  name: nameController.text.trim(),
                  icon: selectedIcon,
                  color: selectedColor,
                  type: _transactionType,
                );
                final newId = await ref.read(categoryRepoProvider).insert(cat);
                ref.read(categoryRefreshProvider.notifier).state++;
                if (mounted) {
                  setState(() => _selectedCategoryId = newId);
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
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

  // -------------------------------------------------------------------------
  // Payment Method Chips
  // -------------------------------------------------------------------------
  Widget _buildPaymentMethodChips(
      List<PaymentMethod> methods, ColorScheme colorScheme) {
    if (methods.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No payment methods found. Add payment methods first.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    // Auto-select default payment method when not in edit mode
    if (_selectedPaymentMethodId == null && !_isEditMode && !_paymentMethodAutoSelected) {
      final defaultPm = methods.where((m) => m.isDefault).firstOrNull;
      if (defaultPm != null) {
        _paymentMethodAutoSelected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedPaymentMethodId == null) {
            setState(() => _selectedPaymentMethodId = defaultPm.id);
          }
        });
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: methods.map((method) {
        final isSelected = _selectedPaymentMethodId == method.id;

        IconData methodIcon;
        switch (method.type.toLowerCase()) {
          case 'cash':
            methodIcon = Icons.payments_outlined;
            break;
          case 'upi':
            methodIcon = Icons.phone_android;
            break;
          case 'credit_card':
          case 'credit card':
            methodIcon = Icons.credit_card;
            break;
          case 'debit_card':
          case 'debit card':
            methodIcon = Icons.credit_card_outlined;
            break;
          case 'bank_transfer':
          case 'bank transfer':
            methodIcon = Icons.account_balance;
            break;
          case 'wallet':
            methodIcon = Icons.account_balance_wallet;
            break;
          default:
            methodIcon = Icons.payment;
        }

        return FilterChip(
          selected: isSelected,
          onSelected: (_) =>
              setState(() => _selectedPaymentMethodId = method.id),
          avatar: Icon(methodIcon, size: 18),
          label: Text(method.name),
          labelStyle: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
          showCheckmark: false,
          selectedColor: colorScheme.secondaryContainer,
          side: BorderSide(
            color: isSelected
                ? colorScheme.secondary
                : colorScheme.outline.withAlpha(80),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        );
      }).toList(),
    );
  }

  // -------------------------------------------------------------------------
  // Note Field
  // -------------------------------------------------------------------------
  Widget _buildNoteField(ColorScheme colorScheme) {
    return TextField(
      controller: _noteController,
      maxLines: 2,
      maxLength: 200,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: 'Add a note (optional)',
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withAlpha(140),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Icon(
            Icons.note_alt_outlined,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        counterStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withAlpha(140),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline.withAlpha(80)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline.withAlpha(80)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withAlpha(60),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer placeholder for loading chips
// ---------------------------------------------------------------------------
class _ChipShimmer extends StatelessWidget {
  const _ChipShimmer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, __) => Container(
          width: 80,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withAlpha(80),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
