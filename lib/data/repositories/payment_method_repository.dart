import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models.dart';

class PaymentMethodRepository {
  Future<Database> get _db => AppDatabase.database;

  Future<List<PaymentMethod>> getAll() async {
    final db = await _db;
    final maps = await db.query('payment_methods', orderBy: 'isDefault DESC, name ASC');
    return maps.map((m) => PaymentMethod.fromMap(m)).toList();
  }

  Future<PaymentMethod?> getById(int id) async {
    final db = await _db;
    final maps = await db.query('payment_methods', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return PaymentMethod.fromMap(maps.first);
  }

  Future<int> insert(PaymentMethod pm) async {
    final db = await _db;
    return db.insert('payment_methods', pm.toMap());
  }

  Future<void> update(PaymentMethod pm) async {
    final db = await _db;
    await db.update('payment_methods', pm.toMap(), where: 'id = ?', whereArgs: [pm.id]);
  }

  /// Counts all rows referencing this payment method across expenses and
  /// recurring_expenses so the UI can decide before deleting.
  Future<int> countReferences(int id) async {
    final db = await _db;
    int total = 0;
    for (final table in ['expenses', 'recurring_expenses']) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $table WHERE paymentMethodId = ?',
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
      for (final table in ['expenses', 'recurring_expenses']) {
        final result = await txn.rawQuery(
          'SELECT COUNT(*) as count FROM $table WHERE paymentMethodId = ?',
          [id],
        );
        refs += (result.first['count'] as int);
      }
      if (refs > 0) {
        throw Exception(
            'Cannot delete: still used by $refs transactions/budgets/loans. Reassign first.');
      }
      await txn.delete('payment_methods', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Reassigns all referencing rows to [reassignToId] then deletes the
  /// payment method, all within a single transaction.
  Future<void> deleteWithReassign(int id, int reassignToId) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final table in ['expenses', 'recurring_expenses']) {
        await txn.update(table, {'paymentMethodId': reassignToId},
            where: 'paymentMethodId = ?', whereArgs: [id]);
      }
      await txn.delete('payment_methods', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> getExpenseCount(int paymentMethodId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM expenses WHERE paymentMethodId = ?',
      [paymentMethodId],
    );
    return (result.first['count'] as int);
  }

  Future<void> reassignExpenses(int fromId, int toId) async {
    final db = await _db;
    await db.update('expenses', {'paymentMethodId': toId},
        where: 'paymentMethodId = ?', whereArgs: [fromId]);
  }
}
