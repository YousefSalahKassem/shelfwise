import 'package:sqflite_common/sqlite_api.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/schema/tables.dart';
import '../models/pricing_rows.dart';

/// The only place pricing SQL lives (TECHNICAL_STRUCTURE §3).
class PricingLocalDataSource {
  const PricingLocalDataSource(this.database);

  final AppDatabase database;

  /// SQLite allows a limited number of statement variables; ids are queried in
  /// chunks so a selection of thousands of products still works.
  static const int _chunk = 400;

  DatabaseExecutor get _db => database.db;

  /// Products a rule applies to: an explicit [productIds] selection when given,
  /// otherwise [categoryId] (plus its sub-categories when
  /// [includeSubcategories]). Archived and deleted products are skipped.
  Future<List<ProductPricingRow>> productsInScope({
    required String storeId,
    String? categoryId,
    bool includeSubcategories = true,
    List<String> productIds = const [],
  }) async {
    const columns = 'id, ${PriceColumns.name}, ${PriceColumns.priceMinor}, ${PriceColumns.costMinor}';
    const base = 'FROM ${T.products} WHERE ${C.storeId} = ? AND ${C.deletedAt} IS NULL '
        'AND ${PriceColumns.isArchived} = 0';
    const order = 'ORDER BY ${PriceColumns.name} COLLATE NOCASE';

    if (productIds.isNotEmpty) {
      final rows = <Map<String, Object?>>[];
      for (var i = 0; i < productIds.length; i += _chunk) {
        final ids = productIds.sublist(i, (i + _chunk).clamp(0, productIds.length));
        final marks = List.filled(ids.length, '?').join(',');
        rows.addAll(await _db.rawQuery(
          'SELECT $columns $base AND ${C.id} IN ($marks) $order',
          [storeId, ...ids],
        ));
      }
      return rows.map(ProductPricingRow.fromMap).toList();
    }

    if (categoryId == null || categoryId.isEmpty) return const [];
    final categoryIds = includeSubcategories
        ? [categoryId, ...await descendantCategoryIds(storeId: storeId, categoryId: categoryId)]
        : [categoryId];
    final marks = List.filled(categoryIds.length, '?').join(',');
    final rows = await _db.rawQuery(
      'SELECT $columns $base AND ${PriceColumns.categoryId} IN ($marks) $order',
      [storeId, ...categoryIds],
    );
    return rows.map(ProductPricingRow.fromMap).toList();
  }

  /// Sub-categories of [categoryId] (the tree is at most two deep, §6).
  Future<List<String>> descendantCategoryIds({
    required String storeId,
    required String categoryId,
  }) async {
    final rows = await _db.query(
      T.categories,
      columns: [C.id],
      where: '${C.storeId} = ? AND ${PriceColumns.parentId} = ? AND ${C.deletedAt} IS NULL',
      whereArgs: [storeId, categoryId],
    );
    return [for (final r in rows) r[C.id]! as String];
  }

  /// The store's two-level category tree, ordered as the catalogue shows it.
  Future<List<CategoryOptionRow>> categories({required String storeId}) async {
    final rows = await _db.query(
      T.categories,
      columns: [C.id, PriceColumns.name, PriceColumns.parentId],
      where: '${C.storeId} = ? AND ${C.deletedAt} IS NULL',
      whereArgs: [storeId],
      orderBy: '${PriceColumns.sortOrder}, ${PriceColumns.name} COLLATE NOCASE',
    );
    return rows.map(CategoryOptionRow.fromMap).toList();
  }

  /// Writes every change of one repricing in a single transaction: the product
  /// rows and their `price_changes` history entries commit together or not at
  /// all. [batchId] is null for a single-product edit.
  Future<void> applyChanges({
    required List<PriceChangeWrite> writes,
    required String profileId,
    required int nowMs,
    required List<String> changeIds,
    String? batchId,
  }) async {
    assert(changeIds.length == writes.length, 'one id per change');
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (var i = 0; i < writes.length; i++) {
        final w = writes[i];
        batch.update(
          T.products,
          {
            PriceColumns.priceMinor: w.newPriceMinor,
            PriceColumns.costMinor: w.newCostMinor,
            C.updatedAt: nowMs,
          },
          where: '${C.id} = ? AND ${C.deletedAt} IS NULL',
          whereArgs: [w.productId],
        );
        batch.insert(T.priceChanges, {
          C.id: changeIds[i],
          C.productId: w.productId,
          PriceColumns.oldPriceMinor: w.oldPriceMinor,
          PriceColumns.newPriceMinor: w.newPriceMinor,
          PriceColumns.oldCostMinor: w.changesCost ? w.oldCostMinor : null,
          PriceColumns.newCostMinor: w.changesCost ? w.newCostMinor : null,
          PriceColumns.batchId: batchId,
          C.profileId: profileId,
          C.createdAt: nowMs,
          C.updatedAt: nowMs,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, Object?>>> priceChangesForProduct(String productId) => _db.query(
        T.priceChanges,
        where: '${C.productId} = ? AND ${C.deletedAt} IS NULL',
        whereArgs: [productId],
        orderBy: '${C.createdAt} DESC',
      );

  Future<List<Map<String, Object?>>> priceChangesForBatch(String batchId) => _db.query(
        T.priceChanges,
        where: '${PriceColumns.batchId} = ? AND ${C.deletedAt} IS NULL',
        whereArgs: [batchId],
        orderBy: C.createdAt,
      );
}
