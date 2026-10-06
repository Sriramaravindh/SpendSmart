import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models.dart';

class CategoryRepository {
  Future<Database> get _db => AppDatabase.database;

  Future<List<Category>> getAll() async {
    final db = await _db;
    final maps = await db.query('categories', orderBy: 'isDefault DESC, name ASC');
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<Category?> getById(int id) async {
    final db = await _db;
    final maps = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  Future<int> insert(Category category) async {
    final db = await _db;
    return db.insert('categories', category.toMap());
  }

  Future<void> update(Category category) async {
    final db = await _db;
    await db.update('categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
  }

  /// Counts all rows referencing this category across expenses, budgets,
  /// loans and recurring_expenses so the UI can decide before deleting.
  Future<int> countReferences(int id) async {
    final db = await _db;
    int total = 0;
    for (final table in ['expenses', 'budgets', 'loans', 'recurring_expenses']) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $table WHERE categoryId = ?',
        [id],
      );
      total += (result.first['count'] as int);
    }
    return total;
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.transaction((txn) async {
      int refs = 0;
      for (final table in ['expenses', 'budgets', 'loans', 'recurring_expenses']) {
        final result = await txn.rawQuery(
          'SELECT COUNT(*) as count FROM $table WHERE categoryId = ?',
          [id],
        );
        refs += (result.first['count'] as int);
      }
      if (refs > 0) {
        throw Exception(
            'Cannot delete: still used by $refs transactions/budgets/loans. Reassign first.');
      }
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Reassigns all referencing rows to [reassignToId] then deletes the
  /// category, all within a single transaction.
  Future<void> deleteWithReassign(int id, int reassignToId) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final table in ['expenses', 'budgets', 'loans', 'recurring_expenses']) {
        await txn.update(table, {'categoryId': reassignToId},
            where: 'categoryId = ?', whereArgs: [id]);
      }
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> getExpenseCount(int categoryId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM expenses WHERE categoryId = ?',
      [categoryId],
    );
    return (result.first['count'] as int);
  }

  Future<void> reassignExpenses(int fromCategoryId, int toCategoryId) async {
    final db = await _db;
    await db.update('expenses', {'categoryId': toCategoryId},
        where: 'categoryId = ?', whereArgs: [fromCategoryId]);
  }
}
