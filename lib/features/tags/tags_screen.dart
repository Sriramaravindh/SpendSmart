import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../providers/providers.dart';

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Groups'), centerTitle: true),
      body: tags.when(
        data: (list) => list.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.label_outlined, size: 64, color: cs.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text('No expense groups', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final tag = list[i];
                  return Card(
                    color: cs.surfaceContainerLow,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Icon(Icons.label, color: cs.primary, size: 22),
                      ),
                      title: Text(tag.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (tag.isDefault)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Chip(label: const Text('Default'), labelStyle: TextStyle(fontSize: 11, color: cs.primary)),
                            ),
                          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showDialog(tag: tag)),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 20, color: tag.isDefault ? cs.outline : cs.error),
                            onPressed: tag.isDefault ? null : () => _delete(tag),
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
        onPressed: () => _showDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Group'),
      ),
    );
  }

  Future<void> _delete(Tag tag) async {
    final repo = ref.read(tagRepoProvider);
    final expenseCount = await repo.getExpenseCount(tag.name);
    final allTags = ref.read(tagsProvider).valueOrNull ?? [];
    final otherTags = allTags.where((t) => t.id != tag.id).toList();

    if (!mounted) return;

    if (expenseCount > 0 && otherTags.isNotEmpty) {
      String? reassignToName = otherTags.first.name;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Delete Expense Group?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('"${tag.name}" has $expenseCount expense(s). Reassign them to:'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: reassignToName,
                  decoration: const InputDecoration(labelText: 'Move expenses to'),
                  items: otherTags.map((t) => DropdownMenuItem(
                    value: t.name,
                    child: Row(
                      children: [
                        const Icon(Icons.label, size: 18),
                        const SizedBox(width: 8),
                        Text(t.name),
                      ],
                    ),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => reassignToName = v),
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
      if (confirm == true && reassignToName != null) {
        await repo.reassignExpenses(tag.name, reassignToName!);
        await repo.delete(tag.id!);
        if (!mounted) return;
        ref.read(tagRefreshProvider.notifier).state++;
        ref.read(expenseRefreshProvider.notifier).state++;
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Expense Group?'),
          content: Text('Delete "${tag.name}"?${expenseCount > 0 ? ' $expenseCount expense(s) will lose their group.' : ''}'),
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
        await repo.delete(tag.id!);
        if (!mounted) return;
        ref.read(tagRefreshProvider.notifier).state++;
      }
    }
  }

  Future<void> _showDialog({Tag? tag}) async {
    final nameController = TextEditingController(text: tag?.name ?? '');
    final oldName = tag?.name;

    try {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tag == null ? 'Add Expense Group' : 'Edit Expense Group'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Group Name'),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;
              try {
                if (tag != null) {
                  await ref.read(tagRepoProvider).update(tag.copyWith(name: newName));
                  if (oldName != null && oldName != newName) {
                    await ref.read(tagRepoProvider).reassignExpenses(oldName, newName);
                    ref.read(expenseRefreshProvider.notifier).state++;
                  }
                } else {
                  await ref.read(tagRepoProvider).insert(Tag(name: newName));
                }
                ref.read(tagRefreshProvider.notifier).state++;
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Group "$newName" already exists'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    } finally {
      nameController.dispose();
    }
  }
}
