import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models.dart';

class TagRepository {
  Future<Database> get _db => AppDatabase.database;

  Future<List<Tag>> getAll() async {
    final db = await _db;
    final maps = await db.query('tags', orderBy: 'isDefault DESC, name ASC');
    return maps.map((m) => Tag.fromMap(m)).toList();
  }

  Future<Tag?> getById(int id) async {
    final db = await _db;
    final maps = await db.query('tags', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Tag.fromMap(maps.first);
  }

  Future<int> insert(Tag tag) async {
    final db = await _db;
    return db.insert('tags', tag.toMap());
  }

  Future<void> update(Tag tag) async {
    final db = await _db;
    await db.update('tags', tag.toMap(), where: 'id = ?', whereArgs: [tag.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('tags', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getExpenseCount(String tagName) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM expenses WHERE tag = ?',
      [tagName],
    );
    return (result.first['count'] as int);
  }

  Future<void> reassignExpenses(String fromTagName, String toTagName) async {
    final db = await _db;
    await db.update('expenses', {'tag': toTagName},
        where: 'tag = ?', whereArgs: [fromTagName]);
  }
}
