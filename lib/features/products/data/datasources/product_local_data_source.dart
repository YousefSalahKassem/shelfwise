import 'dart:typed_data';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common/utils/utils.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/schema/tables.dart';
import '../../../../core/domain/stock_status.dart';
import '../../../../core/utils/money.dart' show normalizeDigits;
import '../../domain/entities/product.dart';

/// All product SQL lives here. Stock levels and categories are *read* here
/// (A4/A2 own the writes) so one query can return list rows ready to draw.
class ProductLocalDataSource {
  const ProductLocalDataSource(this.database);

  final AppDatabase database;

  DatabaseExecutor _exec(DatabaseExecutor? txn) => txn ?? database.db;

  /// Current quantity at the branch; products never stocked count as 0.
  static const _qty = 'COALESCE(sl.qty_milli, 0)';

  static const _columns = '''
        p.${C.id}                AS id,
        p.category_id            AS category_id,
        p.name                   AS name,
        p.name_alt               AS name_alt,
        p.sku                    AS sku,
        p.barcode                AS barcode,
        p.unit                   AS unit,
        p.cost_minor             AS cost_minor,
        p.price_minor            AS price_minor,
        p.reorder_point_milli    AS reorder_point_milli,
        p.is_archived            AS is_archived,
        p.${C.updatedAt}         AS updated_at,
        $_qty                    AS qty_milli,
        c.name                   AS category_name,
        EXISTS(SELECT 1 FROM ${T.productImages} pi
                WHERE pi.${C.productId} = p.${C.id}
                  AND pi.${C.deletedAt} IS NULL) AS has_image''';

  static const _from = '''
     FROM ${T.products} p
     LEFT JOIN ${T.stockLevels} sl
            ON sl.${C.productId} = p.${C.id}
           AND sl.${C.branchId} = ?
           AND sl.${C.deletedAt} IS NULL
     LEFT JOIN ${T.categories} c
            ON c.${C.id} = p.category_id
           AND c.${C.deletedAt} IS NULL''';

  /// One page of list rows for [query].
  Future<List<Map<String, Object?>>> search({
    required String storeId,
    required String branchId,
    required ProductQuery query,
  }) {
    final where = _WhereClause.forQuery(storeId: storeId, query: query);
    final orderBy = switch (query.sort) {
      ProductSort.name => 'p.name COLLATE NOCASE ASC, p.${C.id} ASC',
      ProductSort.recentlyUpdated => 'p.${C.updatedAt} DESC, p.${C.id} ASC',
    };
    return database.db.rawQuery(
      'SELECT $_columns $_from WHERE ${where.sql} ORDER BY $orderBy LIMIT ? OFFSET ?',
      [branchId, ...where.args, query.limit, query.offset],
    );
  }

  Future<int> count({
    required String storeId,
    required String branchId,
    required ProductQuery query,
  }) async {
    final where = _WhereClause.forQuery(storeId: storeId, query: query);
    return firstIntValue(await database.db.rawQuery(
          'SELECT COUNT(*) $_from WHERE ${where.sql}',
          [branchId, ...where.args],
        )) ??
        0;
  }

  /// A single list row (product + its stock), or null when it doesn't exist.
  Future<Map<String, Object?>?> summaryById({
    required String storeId,
    required String branchId,
    required String id,
  }) async {
    final rows = await database.db.rawQuery(
      'SELECT $_columns $_from WHERE p.${C.storeId} = ? AND p.${C.id} = ? '
      'AND p.${C.deletedAt} IS NULL LIMIT 1',
      [branchId, storeId, id],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> byId(String storeId, String id, [DatabaseExecutor? txn]) async {
    final rows = await _exec(txn).query(
      T.products,
      where: '${C.id} = ? AND ${C.storeId} = ? AND ${C.deletedAt} IS NULL',
      whereArgs: [id, storeId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> byBarcode(
    String storeId,
    String barcode, [
    DatabaseExecutor? txn,
  ]) async {
    final rows = await _exec(txn).query(
      T.products,
      where: '${C.storeId} = ? AND barcode = ? AND ${C.deletedAt} IS NULL',
      whereArgs: [storeId, barcode],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// True when another live product of the store already uses [value].
  Future<bool> fieldTaken(
    DatabaseExecutor txn,
    String storeId,
    String column,
    String value, {
    String? exceptId,
  }) async {
    final count = firstIntValue(await txn.rawQuery(
      'SELECT COUNT(*) FROM ${T.products} '
      'WHERE ${C.storeId} = ? AND $column = ? AND ${C.deletedAt} IS NULL '
      '${exceptId == null ? '' : 'AND ${C.id} <> ?'}',
      [storeId, value, ?exceptId],
    ));
    return (count ?? 0) > 0;
  }

  Future<void> insert(DatabaseExecutor txn, Map<String, Object?> values) =>
      txn.insert(T.products, values);

  Future<void> updateFields(
    DatabaseExecutor txn,
    String id,
    Map<String, Object?> values,
    int nowMs,
  ) =>
      txn.update(
        T.products,
        {...values, C.updatedAt: nowMs},
        where: '${C.id} = ?',
        whereArgs: [id],
      );

  Future<void> upsertImage(
    DatabaseExecutor txn,
    String productId,
    Uint8List bytes,
    String mime,
    int nowMs,
  ) =>
      txn.insert(
        T.productImages,
        {
          C.productId: productId,
          'thumb': bytes,
          'mime': mime,
          C.createdAt: nowMs,
          C.updatedAt: nowMs,
          C.deletedAt: null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> deleteImage(DatabaseExecutor txn, String productId) => txn.delete(
        T.productImages,
        where: '${C.productId} = ?',
        whereArgs: [productId],
      );

  Future<Uint8List?> image(String productId) async {
    final rows = await database.db.query(
      T.productImages,
      columns: ['thumb'],
      where: '${C.productId} = ? AND ${C.deletedAt} IS NULL',
      whereArgs: [productId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final blob = rows.first['thumb'];
    return blob is Uint8List ? blob : (blob is List<int> ? Uint8List.fromList(blob) : null);
  }
}

/// Builds the shared WHERE clause for list, count and paging so they can never
/// drift apart.
class _WhereClause {
  const _WhereClause(this.sql, this.args);

  final String sql;
  final List<Object?> args;

  static _WhereClause forQuery({required String storeId, required ProductQuery query}) {
    final sql = <String>['p.${C.storeId} = ?', 'p.${C.deletedAt} IS NULL'];
    final args = <Object?>[storeId];

    if (!query.includeArchived) sql.add('p.is_archived = 0');

    final term = searchTerm(query.search);
    if (term != null) {
      sql.add(r"(p.name LIKE ? ESCAPE '\' OR p.name_alt LIKE ? ESCAPE '\' "
          r"OR p.sku LIKE ? ESCAPE '\' OR p.barcode LIKE ? ESCAPE '\')");
      args.addAll([term, term, term, term]);
    }

    final categoryId = query.categoryId;
    if (categoryId != null) {
      if (query.includeSubcategories) {
        sql.add('(p.category_id = ? OR p.category_id IN '
            '(SELECT ${C.id} FROM ${T.categories} '
            'WHERE parent_id = ? AND ${C.deletedAt} IS NULL))');
        args.addAll([categoryId, categoryId]);
      } else {
        sql.add('p.category_id = ?');
        args.add(categoryId);
      }
    }

    if (query.statuses.isNotEmpty && query.statuses.length < StockStatus.values.length) {
      sql.add('(${query.statuses.map(_statusSql).join(' OR ')})');
    }
    return _WhereClause(sql.join(' AND '), args);
  }

  static String _statusSql(StockStatus status) => switch (status) {
        StockStatus.out => '${ProductLocalDataSource._qty} <= 0',
        StockStatus.low => '(${ProductLocalDataSource._qty} > 0 AND p.reorder_point_milli > 0 '
            'AND ${ProductLocalDataSource._qty} <= p.reorder_point_milli)',
        StockStatus.ok => '(${ProductLocalDataSource._qty} > 0 AND (p.reorder_point_milli <= 0 '
            'OR ${ProductLocalDataSource._qty} > p.reorder_point_milli))',
      };

  /// `%term%` with LIKE wildcards escaped and Arabic-Indic digits normalised
  /// (so scanning `٦٢٢…` finds a Latin-digit barcode). Null when blank.
  static String? searchTerm(String raw) {
    final term = normalizeDigits(raw.trim());
    if (term.isEmpty) return null;
    final escaped = term
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }
}
