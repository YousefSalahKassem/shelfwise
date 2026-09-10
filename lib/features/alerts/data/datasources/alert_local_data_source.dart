// OWNER: A4. The only place alert SQL lives. Alert *rows* are written by the
// stock feature inside the movement transaction (they must be atomic with it);
// this data source reads them and records acknowledgements.
import '../../../../core/database/app_database.dart';
import '../../../../core/database/schema/tables.dart';
import '../../../../core/domain/stock_status.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/quantity.dart';
import '../../domain/entities/stock_alert.dart';

class AlertLocalDataSource {
  const AlertLocalDataSource(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Open alerts at [branchId], out of stock first, newest first inside a level.
  Future<List<StockAlert>> open(String branchId) async {
    final rows = await _db.db.rawQuery('''
      SELECT a.id, a.product_id, a.branch_id, a.level, a.triggered_at,
             a.resolved_at, a.acknowledged_at,
             p.name AS product_name, p.reorder_point_milli,
             COALESCE(sl.qty_milli, 0) AS qty_milli
      FROM ${T.stockAlerts} a
      JOIN ${T.products} p ON p.id = a.product_id
      LEFT JOIN ${T.stockLevels} sl ON sl.product_id = a.product_id AND sl.branch_id = a.branch_id
      WHERE a.branch_id = ? AND a.resolved_at IS NULL AND p.deleted_at IS NULL
      ORDER BY CASE a.level WHEN 'out' THEN 0 ELSE 1 END, a.triggered_at DESC''', [branchId]);
    return [for (final row in rows) _fromRow(row)];
  }

  Future<AlertCounts> counts(String branchId) async {
    final rows = await _db.db.rawQuery('''
      SELECT a.level AS level, COUNT(*) AS n
      FROM ${T.stockAlerts} a
      JOIN ${T.products} p ON p.id = a.product_id
      WHERE a.branch_id = ? AND a.resolved_at IS NULL AND p.deleted_at IS NULL
      GROUP BY a.level''', [branchId]);
    var low = 0;
    var out = 0;
    for (final row in rows) {
      final n = (row['n'] as int?) ?? 0;
      if (row['level'] == 'out') {
        out = n;
      } else {
        low = n;
      }
    }
    return AlertCounts(low: low, out: out);
  }

  /// Returns false when the alert is gone or already resolved.
  Future<bool> acknowledge(String alertId, String branchId) async {
    final now = _clock.now().epochMs;
    final updated = await _db.db.update(
      T.stockAlerts,
      {'acknowledged_at': now, C.updatedAt: now},
      where: '${C.id} = ? AND ${C.branchId} = ? AND resolved_at IS NULL',
      whereArgs: [alertId, branchId],
    );
    return updated > 0;
  }

  StockAlert _fromRow(Map<String, Object?> row) => StockAlert(
        id: row[C.id]! as String,
        productId: row[C.productId]! as String,
        productName: (row['product_name'] as String?) ?? '',
        branchId: row[C.branchId]! as String,
        level: row['level'] == 'out' ? StockStatus.out : StockStatus.low,
        quantity: Quantity((row['qty_milli'] as int?) ?? 0),
        reorderPoint: Quantity((row['reorder_point_milli'] as int?) ?? 0),
        triggeredAt: fromEpochMs((row['triggered_at'] as int?) ?? 0),
        resolvedAt: row['resolved_at'] == null ? null : fromEpochMs(row['resolved_at']! as int),
        acknowledgedAt:
            row['acknowledged_at'] == null ? null : fromEpochMs(row['acknowledged_at']! as int),
      );
}
