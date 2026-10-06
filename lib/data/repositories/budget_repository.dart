import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models.dart';

class BudgetRepository {
  Future<Database> get _db => AppDatabase.database;

  Future<List<Budget>> getByMonth(int month) async {
    final db = await _db;
    final maps = await db.query('budgets', where: 'month = ?', whereArgs: [month]);
    return maps.map((m) => Budget.fromMap(m)).toList();
  }

  Future<Budget?> getOverallBudget(int month) async {
    final db = await _db;
    final maps = await db.query('budgets', where: 'month = ? AND categoryId IS NULL', whereArgs: [month]);
    if (maps.isEmpty) return null;
    return Budget.fromMap(maps.first);
  }

  Future<Budget?> getCategoryBudget(int categoryId, int month) async {
    final db = await _db;
    final maps = await db.query('budgets', where: 'month = ? AND categoryId = ?', whereArgs: [month, categoryId]);
    if (maps.isEmpty) return null;
    return Budget.fromMap(maps.first);
  }

  Future<int> insert(Budget budget) async {
    final db = await _db;
    return db.insert('budgets', budget.toMap());
  }

  Future<void> update(Budget budget) async {
    final db = await _db;
    await db.update('budgets', budget.toMap(), where: 'id = ?', whereArgs: [budget.id]);
  }

  Future<void> upsert(Budget budget) async {
    final db = await _db;
    if (budget.categoryId == null) {
      final existing = await getOverallBudget(budget.month);
      if (existing != null) {
        await db.update('budgets', budget.toMap(), where: 'id = ?', whereArgs: [existing.id]);
        return;
      }
    } else {
      final existing = await getCategoryBudget(budget.categoryId!, budget.month);
      if (existing != null) {
        await db.update('budgets', budget.toMap(), where: 'id = ?', whereArgs: [existing.id]);
        return;
      }
    }
    await db.insert('budgets', budget.toMap());
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }
}
