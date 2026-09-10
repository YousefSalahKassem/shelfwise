import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common/utils/utils.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/schema/tables.dart';

/// All category SQL lives here (TECHNICAL_STRUCTURE §3, rule 2).
/// Rows are plain maps; `data/mappers/` turns them into entities.
class CategoryLocalDataSource {
  const CategoryLocalDataSource(this.database);

  final AppDatabase database;

  DatabaseExecutor _exec(DatabaseExecutor? txn) => txn ?? database.db;

  /// Every live category of the store with the number of active products
  /// assigned directly to it, ordered for display.
  Future<List<Map<String, Object?>>> tree(String storeId) => database.db.rawQuery(
        '''
        SELECT c.${C.id}          AS id,
               c.parent_id        AS parent_id,
               c.name             AS name,
               c.sort_order       AS sort_order,
               (SELECT COUNT(*) FROM ${T.products} p
                 WHERE p.category_id = c.${C.id}
                   AND p.${C.deletedAt} IS NULL
                   AND p.is_archived = 0) AS product_count
          FROM ${T.categories} c
         WHERE c.${C.storeId} = ? AND c.${C.deletedAt} IS NULL
         ORDER BY c.sort_order ASC, c.name COLLATE NOCASE ASC
        ''',
        [storeId],
      );

  Future<Map<String, Object?>?> byId(String storeId, String id, [DatabaseExecutor? txn]) async {
    final rows = await _exec(txn).query(
      T.categories,
      where: '${C.id} = ? AND ${C.storeId} = ? AND ${C.deletedAt} IS NULL',
      whereArgs: [id, storeId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Live siblings under [parentId] (null = top level), ordered as displayed.
  Future<List<Map<String, Object?>>> siblings(
    String storeId,
    String? parentId, [
    DatabaseExecutor? txn,
  ]) =>
      _exec(txn).query(
        T.categories,
        columns: [C.id, 'sort_order', 'name'],
        where: '${C.storeId} = ? AND ${C.deletedAt} IS NULL AND '
            '${parentId == null ? 'parent_id IS NULL' : 'parent_id = ?'}',
        whereArgs: [storeId, ?parentId],
        orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
      );

  Future<int> childCount(String storeId, String id, [DatabaseExecutor? txn]) async =>
      firstIntValue(await _exec(txn).rawQuery(
        'SELECT COUNT(*) FROM ${T.categories} '
        'WHERE ${C.storeId} = ? AND parent_id = ? AND ${C.deletedAt} IS NULL',
        [storeId, id],
      )) ??
      0;

  Future<int> productCount(String storeId, String id, [DatabaseExecutor? txn]) async =>
      firstIntValue(await _exec(txn).rawQuery(
        'SELECT COUNT(*) FROM ${T.products} '
        'WHERE ${C.storeId} = ? AND category_id = ? AND ${C.deletedAt} IS NULL',
        [storeId, id],
      )) ??
      0;

  /// True when another live sibling already uses [name] (case-insensitive).
  Future<bool> siblingNameTaken(
    String storeId,
    String? parentId,
    String name, {
    String? exceptId,
    DatabaseExecutor? txn,
  }) async {
    final count = firstIntValue(await _exec(txn).rawQuery(
      'SELECT COUNT(*) FROM ${T.categories} '
      'WHERE ${C.storeId} = ? AND ${C.deletedAt} IS NULL '
      'AND ${parentId == null ? 'parent_id IS NULL' : 'parent_id = ?'} '
      'AND name = ? COLLATE NOCASE '
      '${exceptId == null ? '' : 'AND ${C.id} <> ?'}',
      [storeId, ?parentId, name, ?exceptId],
    ));
    return (count ?? 0) > 0;
  }

  Future<void> insert(
    DatabaseExecutor txn, {
    required String id,
    required String storeId,
    required String? parentId,
    required String name,
    required int sortOrder,
    required int nowMs,
  }) =>
      txn.insert(T.categories, {
        C.id: id,
        C.storeId: storeId,
        'parent_id': parentId,
        'name': name,
        'sort_order': sortOrder,
        C.createdAt: nowMs,
        C.updatedAt: nowMs,
      });

  Future<void> updateFields(
    DatabaseExecutor txn,
    String id,
    Map<String, Object?> values,
    int nowMs,
  ) =>
      txn.update(
        T.categories,
        {...values, C.updatedAt: nowMs},
        where: '${C.id} = ?',
        whereArgs: [id],
      );

  /// Soft delete (AD-2).
  Future<void> softDelete(DatabaseExecutor txn, String id, int nowMs) => txn.update(
        T.categories,
        {C.deletedAt: nowMs, C.updatedAt: nowMs},
        where: '${C.id} = ?',
        whereArgs: [id],
      );

  /// Moves every product of [fromId] to [toId] (null clears the category).
  Future<int> reassignProducts(
    DatabaseExecutor txn,
    String storeId,
    String fromId,
    String? toId,
    int nowMs,
  ) =>
      txn.update(
        T.products,
        {'category_id': toId, C.updatedAt: nowMs},
        where: '${C.storeId} = ? AND category_id = ? AND ${C.deletedAt} IS NULL',
        whereArgs: [storeId, fromId],
      );
}
