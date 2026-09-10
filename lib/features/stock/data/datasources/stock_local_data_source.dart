// OWNER: A4. The only place stock SQL lives.
import 'package:sqflite_common/sqlite_api.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/schema/tables.dart';
import '../../../../core/domain/stock_status.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/date_range.dart';
import '../../../../core/utils/ids.dart';
import '../../../../core/utils/quantity.dart';
import '../../domain/entities/stock.dart';
import '../../domain/entities/stock_view.dart';
import '../models/stock_rows.dart';

/// Ledger, cached levels and alert rows. Every method that writes runs in one
/// transaction and throws [StockDataException] to roll it back.
class StockLocalDataSource {
  const StockLocalDataSource(this._db, this._clock, this._ids);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

  static const _movementColumns = '''
      m.id, m.product_id, m.branch_id, m.type, m.qty_delta_milli, m.qty_after_milli,
      m.unit_cost_minor, m.note, m.profile_id, m.created_at,
      pr.name AS profile_name, p.name AS product_name, p.unit AS product_unit''';

  static const _movementJoins = '''
      FROM ${T.stockMovements} m
      JOIN ${T.products} p ON p.id = m.product_id
      LEFT JOIN ${T.profiles} pr ON pr.id = m.profile_id''';

  // ---------------------------------------------------------------- writes

  /// Ledger row + level upsert + alert evaluation for every input, atomically.
  Future<MovementBatch> recordBatch(List<MovementInput> inputs, StockScope scope) =>
      _db.transaction((txn) async {
        final now = _clock.now().epochMs;
        final movements = <StockMovement>[];
        final opened = <OpenedAlert>[];

        for (final input in inputs) {
          final product = await _productForWrite(txn, input.productId, scope);
          final before = await _levelMilli(txn, input.productId, scope.branchId);
          final delta = input.type.sign == 0
              ? input.quantity.milli
              : input.type.sign * input.quantity.milli;
          final after = before + delta;

          // Only a deliberate correction may take stock below zero; the UI asks
          // the user to confirm before sending it.
          if (after < 0 && input.type != MovementType.adjustment) {
            throw const StockDataException(
              ValidationFailure(field: 'quantity', code: 'negativeStock'),
            );
          }

          final id = _ids.newId();
          await txn.insert(T.stockMovements, {
            C.id: id,
            C.productId: input.productId,
            C.branchId: scope.branchId,
            StockC.type: input.type.dbName,
            StockC.qtyDeltaMilli: delta,
            StockC.qtyAfterMilli: after,
            StockC.unitCostMinor: input.unitCost?.minor,
            StockC.note: input.note,
            C.profileId: scope.profileId,
            C.createdAt: now,
            C.updatedAt: now,
          });
          await _upsertLevel(txn, input.productId, scope.branchId, after, now);

          final alert = await _evaluateAlert(
            txn,
            productId: input.productId,
            productName: product[StockC.name]! as String,
            unit: unitOf(product[StockC.unit]),
            branchId: scope.branchId,
            qtyMilli: after,
            reorderPointMilli: (product[StockC.reorderPointMilli] as int?) ?? 0,
            now: now,
          );
          if (alert != null) opened.add(alert);

          movements.add(
            StockMovement(
              id: id,
              productId: input.productId,
              branchId: scope.branchId,
              type: input.type,
              delta: Quantity(delta),
              quantityAfter: Quantity(after),
              unitCost: input.unitCost,
              note: input.note,
              profileId: scope.profileId,
              createdAt: fromEpochMs(now),
            ),
          );
        }
        return MovementBatch(movements: movements, openedAlerts: opened);
      });

  /// Sets `products.reorder_point_milli` and re-evaluates the product's alert.
  Future<void> setReorderPoint(String productId, Quantity reorderPoint, StockScope scope) =>
      _db.transaction((txn) async {
        final now = _clock.now().epochMs;
        final product = await _productForWrite(txn, productId, scope);
        await txn.update(
          T.products,
          {StockC.reorderPointMilli: reorderPoint.milli, C.updatedAt: now},
          where: '${C.id} = ?',
          whereArgs: [productId],
        );
        await _evaluateAlert(
          txn,
          productId: productId,
          productName: product[StockC.name]! as String,
          unit: unitOf(product[StockC.unit]),
          branchId: scope.branchId,
          qtyMilli: await _levelMilli(txn, productId, scope.branchId),
          reorderPointMilli: reorderPoint.milli,
          now: now,
        );
      });

  /// Same for every product of a category. Returns how many were updated.
  Future<int> setReorderPointForCategory(
    String categoryId,
    Quantity reorderPoint,
    StockScope scope, {
    required bool includeSubcategories,
  }) =>
      _db.transaction((txn) async {
        final now = _clock.now().epochMs;
        final categoryIds = <String>[categoryId];
        if (includeSubcategories) {
          final children = await txn.query(
            T.categories,
            columns: [C.id],
            where: '${C.storeId} = ? AND ${StockC.parentId} = ? AND ${C.deletedAt} IS NULL',
            whereArgs: [scope.storeId, categoryId],
          );
          categoryIds.addAll(children.map((r) => r[C.id]! as String));
        }
        final placeholders = List.filled(categoryIds.length, '?').join(', ');
        final products = await txn.query(
          T.products,
          columns: [C.id, StockC.name, StockC.unit],
          where: '${C.storeId} = ? AND ${StockC.categoryId} IN ($placeholders) '
              'AND ${C.deletedAt} IS NULL AND ${StockC.isArchived} = 0',
          whereArgs: [scope.storeId, ...categoryIds],
        );
        if (products.isEmpty) return 0;

        for (final product in products) {
          final id = product[C.id]! as String;
          await txn.update(
            T.products,
            {StockC.reorderPointMilli: reorderPoint.milli, C.updatedAt: now},
            where: '${C.id} = ?',
            whereArgs: [id],
          );
          await _evaluateAlert(
            txn,
            productId: id,
            productName: product[StockC.name]! as String,
            unit: unitOf(product[StockC.unit]),
            branchId: scope.branchId,
            qtyMilli: await _levelMilli(txn, id, scope.branchId),
            reorderPointMilli: reorderPoint.milli,
            now: now,
          );
        }
        return products.length;
      });

  // ----------------------------------------------------------------- reads

  Future<ProductStock> productStock(String productId, StockScope scope) async {
    final rows = await _db.db.rawQuery('''
      SELECT p.id, p.name, p.unit, p.reorder_point_milli,
             COALESCE(sl.qty_milli, 0) AS qty_milli
      FROM ${T.products} p
      LEFT JOIN ${T.stockLevels} sl ON sl.product_id = p.id AND sl.branch_id = ?
      WHERE p.id = ? AND p.store_id = ? AND p.deleted_at IS NULL
      LIMIT 1''', [scope.branchId, productId, scope.storeId]);
    if (rows.isEmpty) throw StockDataException(NotFoundFailure('product', productId));
    return productStockFromRow(rows.first);
  }

  Future<ProductStock?> findByCode(String code, StockScope scope) async {
    final rows = await _db.db.rawQuery('''
      SELECT p.id, p.name, p.unit, p.reorder_point_milli,
             COALESCE(sl.qty_milli, 0) AS qty_milli
      FROM ${T.products} p
      LEFT JOIN ${T.stockLevels} sl ON sl.product_id = p.id AND sl.branch_id = ?
      WHERE p.store_id = ? AND p.deleted_at IS NULL AND p.is_archived = 0
        AND (p.barcode = ? OR p.sku = ?)
      ORDER BY CASE WHEN p.barcode = ? THEN 0 ELSE 1 END
      LIMIT 1''', [scope.branchId, scope.storeId, code, code, code]);
    return rows.isEmpty ? null : productStockFromRow(rows.first);
  }

  Future<StockLevel> level(String productId, StockScope scope) async {
    final rows = await _db.db.rawQuery('''
      SELECT p.id, p.reorder_point_milli, COALESCE(sl.qty_milli, 0) AS qty_milli
      FROM ${T.products} p
      LEFT JOIN ${T.stockLevels} sl ON sl.product_id = p.id AND sl.branch_id = ?
      WHERE p.id = ? AND p.store_id = ?
      LIMIT 1''', [scope.branchId, productId, scope.storeId]);
    if (rows.isEmpty) throw StockDataException(NotFoundFailure('product', productId));
    return stockLevelFromRow(rows.first, scope.branchId);
  }

  Future<List<MovementEntry>> movements(
    String productId,
    StockScope scope, {
    DateRange? range,
    int limit = 100,
  }) async {
    final where = StringBuffer('WHERE m.product_id = ? AND m.branch_id = ?');
    final args = <Object?>[productId, scope.branchId];
    if (range != null) {
      where.write(' AND m.created_at >= ? AND m.created_at < ?');
      args..add(range.start.epochMs)..add(range.end.epochMs);
    }
    final rows = await _db.db.rawQuery(
      'SELECT $_movementColumns $_movementJoins $where '
      'ORDER BY m.created_at DESC, m.rowid DESC LIMIT ?',
      [...args, limit],
    );
    return [for (final row in rows) movementEntryFromRow(row, scope.currency)];
  }

  Future<List<MovementEntry>> recentMovements(StockScope scope, {int limit = 20}) async {
    final rows = await _db.db.rawQuery(
      'SELECT $_movementColumns $_movementJoins WHERE m.branch_id = ? '
      'ORDER BY m.created_at DESC, m.rowid DESC LIMIT ?',
      [scope.branchId, limit],
    );
    return [for (final row in rows) movementEntryFromRow(row, scope.currency)];
  }

  // ------------------------------------------------------------- internals

  Future<Row> _productForWrite(Transaction txn, String productId, StockScope scope) async {
    final rows = await txn.query(
      T.products,
      columns: [C.id, StockC.name, StockC.unit, StockC.reorderPointMilli],
      where: '${C.id} = ? AND ${C.storeId} = ? AND ${C.deletedAt} IS NULL',
      whereArgs: [productId, scope.storeId],
      limit: 1,
    );
    if (rows.isEmpty) throw StockDataException(NotFoundFailure('product', productId));
    return rows.first;
  }

  Future<int> _levelMilli(Transaction txn, String productId, String branchId) async {
    final rows = await txn.query(
      T.stockLevels,
      columns: [StockC.qtyMilli],
      where: '${C.productId} = ? AND ${C.branchId} = ?',
      whereArgs: [productId, branchId],
      limit: 1,
    );
    return rows.isEmpty ? 0 : (rows.first[StockC.qtyMilli] as int?) ?? 0;
  }

  Future<void> _upsertLevel(
    Transaction txn,
    String productId,
    String branchId,
    int qtyMilli,
    int now,
  ) async {
    final updated = await txn.update(
      T.stockLevels,
      {StockC.qtyMilli: qtyMilli, C.updatedAt: now},
      where: '${C.productId} = ? AND ${C.branchId} = ?',
      whereArgs: [productId, branchId],
    );
    if (updated == 0) {
      await txn.insert(T.stockLevels, {
        C.productId: productId,
        C.branchId: branchId,
        StockC.qtyMilli: qtyMilli,
        C.createdAt: now,
        C.updatedAt: now,
      });
    }
  }

  /// Opens, escalates, de-escalates or resolves the product's alert.
  /// Returns the alert when it is newly opened at a *higher* level than before
  /// (ok → low, ok → out, low → out) — the only cases worth a notification.
  Future<OpenedAlert?> _evaluateAlert(
    Transaction txn, {
    required String productId,
    required String productName,
    required ProductUnit unit,
    required String branchId,
    required int qtyMilli,
    required int reorderPointMilli,
    required int now,
  }) async {
    final status = StockStatus.of(qtyMilli: qtyMilli, reorderPointMilli: reorderPointMilli);
    final open = await txn.query(
      T.stockAlerts,
      where: '${C.productId} = ? AND ${C.branchId} = ? AND ${StockC.resolvedAt} IS NULL',
      whereArgs: [productId, branchId],
      orderBy: '${StockC.triggeredAt} DESC',
    );

    Future<void> resolveOpen() => txn.update(
          T.stockAlerts,
          {StockC.resolvedAt: now, C.updatedAt: now},
          where: '${C.productId} = ? AND ${C.branchId} = ? AND ${StockC.resolvedAt} IS NULL',
          whereArgs: [productId, branchId],
        );

    Future<OpenedAlert> openAlert() async {
      final id = _ids.newId();
      await txn.insert(T.stockAlerts, {
        C.id: id,
        C.productId: productId,
        C.branchId: branchId,
        StockC.level: levelToDb(status),
        StockC.triggeredAt: now,
        C.createdAt: now,
        C.updatedAt: now,
      });
      return OpenedAlert(
        alertId: id,
        productId: productId,
        productName: productName,
        unit: unit,
        level: status,
        quantity: Quantity(qtyMilli),
        reorderPoint: Quantity(reorderPointMilli),
      );
    }

    if (status == StockStatus.ok) {
      if (open.isNotEmpty) await resolveOpen();
      return null;
    }
    if (open.isEmpty) return openAlert();

    final current = levelFromDb(open.first[StockC.level]);
    if (current == status) return null;
    if (status == StockStatus.out) {
      // low → out: close the low alert and open an out one, so the timeline
      // keeps when each level started, and notify again.
      await resolveOpen();
      return openAlert();
    }
    // out → low: stock came back but is still under the reorder point. Keep the
    // same alert row (and its acknowledgement) — no second notification.
    await txn.update(
      T.stockAlerts,
      {StockC.level: levelToDb(status), C.updatedAt: now},
      where: '${C.id} = ?',
      whereArgs: [open.first[C.id]],
    );
    return null;
  }
}
