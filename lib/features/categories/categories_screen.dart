import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../providers/providers.dart';
import '../../core/constants/icon_map.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        centerTitle: true,
      ),
      body: categories.when(
        data: (list) => list.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category_outlined, size: 64, color: cs.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text('No categories yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final cat = list[index];
                  return Card(
                    color: cs.surfaceContainerLow,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(cat.color).withOpacity(0.15),
                        child: Icon(getIconData(cat.icon), color: Color(cat.color), size: 22),
                      ),
                      title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: cat.isDefault ? Text('Default', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _showCategoryDialog(category: cat),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
                            onPressed: () => _deleteCategory(cat),
                          ),
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
        onPressed: () => _showCategoryDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
    );
  }

  Future<void> _deleteCategory(Category cat) async {
    final repo = ref.read(categoryRepoProvider);
    // Count references across all tables (expenses, budgets, loans, recurring),
    // not just expenses, so we know whether a reassign is required.
    final refCount = await repo.countReferences(cat.id!);
    final allCategories = ref.read(categoriesProvider).valueOrNull ?? [];
    final otherCategories = allCategories.where((c) => c.id != cat.id).toList();

    if (!mounted) return;

    if (refCount > 0 && otherCategories.isNotEmpty) {
      int? reassignToId = otherCategories.first.id;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Delete Category?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('"${cat.name}" is used by $refCount item(s). Reassign them to:'),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: reassignToId,
                  decoration: const InputDecoration(labelText: 'Move expenses to'),
                  items: otherCategories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      children: [
                        Icon(getIconData(c.icon), color: Color(c.color), size: 18),
                        const SizedBox(width: 8),
                        Text(c.name),
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
          // Reassigns expenses, budgets, loans and recurring rows atomically.
          await repo.deleteWithReassign(cat.id!, reassignToId!);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete category: $e')),
          );
          return;
        }
        if (!mounted) return;
        ref.read(categoryRefreshProvider.notifier).state++;
        ref.read(expenseRefreshProvider.notifier).state++;
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Category?'),
          content: Text(refCount > 0
              ? 'Cannot delete "${cat.name}" — it is still used by $refCount item(s) and there is no other category to reassign them to. Create another category first.'
              : 'Are you sure you want to delete "${cat.name}"?'),
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
          await repo.delete(cat.id!);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete category: $e')),
          );
          return;
        }
        if (!mounted) return;
        ref.read(categoryRefreshProvider.notifier).state++;
      }
    }
  }

  Future<void> _showCategoryDialog({Category? category}) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    String selectedIcon = category?.icon ?? (availableIcons.isNotEmpty ? availableIcons.first : 'category');
    int selectedColor = category?.color ?? 0xFFE57373;

    final colors = [
      0xFF8B5CF6, 0xFF00D1FF, 0xFFF87171, 0xFF34D399,
      0xFFFBBF24, 0xFFF472B6, 0xFF60A5FA, 0xFF818CF8,
      0xFFFB923C, 0xFF4ADE80, 0xFFC084FC, 0xFF38BDF8,
    ];

    try {
    await showDialog(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(category == null ? 'Add Category' : 'Edit Category'),
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
                  const SizedBox(height: 20),
                  Text('Icon', style: Theme.of(context).textTheme.labelLarge),
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
                              color: isSelected ? Color(selectedColor).withOpacity(0.2) : null,
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
                  Text('Color', style: Theme.of(context).textTheme.labelLarge),
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
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                            boxShadow: isSelected ? [BoxShadow(color: Color(c).withOpacity(0.4), blurRadius: 8)] : null,
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
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
                  id: category?.id,
                  name: nameController.text.trim(),
                  icon: selectedIcon,
                  color: selectedColor,
                  type: category?.type ?? 'EXPENSE',
                  isDefault: category?.isDefault ?? false,
                );
                if (category != null) {
                  await ref.read(categoryRepoProvider).update(cat);
                } else {
                  await ref.read(categoryRepoProvider).insert(cat);
                }
                ref.read(categoryRefreshProvider.notifier).state++;
                if (ctx.mounted) Navigator.of(ctx).pop();
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
