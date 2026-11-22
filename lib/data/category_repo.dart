import '../models/category_model.dart';
import 'db_helper.dart';

/// All database work for the `categories` table.
class CategoryRepo {
  final DbHelper _helper;
  CategoryRepo([DbHelper? helper]) : _helper = helper ?? DbHelper.instance;

  static const _table = DbHelper.tCategories;

  /// Inserts a category and returns its new id.
  Future<int> insert(CategoryModel category) async {
    final db = await _helper.database;
    return db.insert(_table, category.toMap()..remove('id'));
  }

  /// Returns the number of rows changed (1 if it worked, 0 if not found).
  Future<int> update(CategoryModel category) async {
    final db = await _helper.database;
    return db.update(
      _table,
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  /// Deletes a category. Throws a DatabaseException if a transaction still
  /// uses it (ON DELETE RESTRICT) — check [isUsed] first.
  Future<int> delete(int id) async {
    final db = await _helper.database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<CategoryModel?> getById(int id) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : CategoryModel.fromMap(rows.first);
  }

  /// All categories, defaults first, then by name.
  Future<List<CategoryModel>> getAll() async {
    final db = await _helper.database;
    final rows = await db.query(_table, orderBy: 'is_default DESC, name');
    return rows.map(CategoryModel.fromMap).toList();
  }

  /// Only 'expense' or only 'income' categories (for the Add screen grid).
  Future<List<CategoryModel>> getByType(String type) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'is_default DESC, name',
    );
    return rows.map(CategoryModel.fromMap).toList();
  }

  /// Finds a category by name (case-insensitive), e.g. 'Others'.
  Future<CategoryModel?> getByName(String name) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [name],
      limit: 1,
    );
    return rows.isEmpty ? null : CategoryModel.fromMap(rows.first);
  }

  /// True if any transaction or repeat payment uses this category
  /// (both block the delete with ON DELETE RESTRICT).
  Future<bool> isUsed(int id) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      'SELECT 1 FROM ${DbHelper.tTransactions} WHERE category_id = ? '
      'UNION ALL '
      'SELECT 1 FROM ${DbHelper.tRecurringPayments} WHERE category_id = ? '
      'LIMIT 1',
      [id, id],
    );
    return rows.isNotEmpty;
  }
}
