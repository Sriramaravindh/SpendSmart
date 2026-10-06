import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models.dart';
import '../../core/utils/emi_calculator.dart';

class SavingsGoalRepository {
  Future<Database> get _db => AppDatabase.database;

  Future<List<SavingsGoal>> getAll() async {
    final db = await _db;
    final maps = await db.query('savings_goals', orderBy: 'id DESC');
    return maps.map((m) => SavingsGoal.fromMap(m)).toList();
  }

  Future<SavingsGoal?> getById(int id) async {
    final db = await _db;
    final maps = await db.query('savings_goals', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return SavingsGoal.fromMap(maps.first);
  }

  Future<int> insert(SavingsGoal goal) async {
    final db = await _db;
    return db.insert('savings_goals', goal.toMap());
  }

  Future<void> update(SavingsGoal goal) async {
    final db = await _db;
    await db.update('savings_goals', goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
  }

  Future<void> addDeposit(int goalId, double amount) async {
    final db = await _db;
    final goal = await getById(goalId);
    if (goal != null) {
      final newAmount = EmiCalculator.round2(goal.savedAmount + amount);
      await db.update('savings_goals', {'savedAmount': newAmount}, where: 'id = ?', whereArgs: [goalId]);
    }
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
  }
}
