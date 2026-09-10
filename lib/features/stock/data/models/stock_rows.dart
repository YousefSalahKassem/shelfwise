// OWNER: A4. Row ⇄ entity mapping. Entities never carry column names.
import '../../../../core/database/schema/tables.dart';
import '../../../../core/domain/stock_status.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/quantity.dart';
import '../../domain/entities/stock.dart';
import '../../domain/entities/stock_view.dart';

/// Columns of the tables A4 writes.
abstract final class StockC {
  static const qtyMilli = 'qty_milli';
  static const type = 'type';
  static const qtyDeltaMilli = 'qty_delta_milli';
  static const qtyAfterMilli = 'qty_after_milli';
  static const unitCostMinor = 'unit_cost_minor';
  static const note = 'note';
  static const level = 'level';
  static const triggeredAt = 'triggered_at';
  static const resolvedAt = 'resolved_at';
  static const acknowledgedAt = 'acknowledged_at';
  // Read-only columns owned by other agents.
  static const name = 'name';
  static const unit = 'unit';
  static const reorderPointMilli = 'reorder_point_milli';
  static const isArchived = 'is_archived';
  static const categoryId = 'category_id';
  static const parentId = 'parent_id';
  static const barcode = 'barcode';
  static const sku = 'sku';
}

/// Who and where a write happens: taken from the session, never from the UI.
class StockScope {
  const StockScope({
    required this.storeId,
    required this.branchId,
    required this.profileId,
    required this.currency,
  });

  final String storeId;
  final String branchId;
  final String profileId;
  final String currency;
}

/// Thrown inside a transaction to roll it back with a translatable [Failure].
class StockDataException implements Exception {
  const StockDataException(this.failure);
  final Failure failure;
  @override
  String toString() => 'StockDataException($failure)';
}

typedef Row = Map<String, Object?>;

int _int(Object? v) => (v as int?) ?? 0;

Quantity qtyOf(Object? v) => Quantity(_int(v));

StockStatus levelFromDb(Object? v) =>
    v == 'out' ? StockStatus.out : StockStatus.low;

String levelToDb(StockStatus status) => status == StockStatus.out ? 'out' : 'low';

ProductUnit unitOf(Object? v) => ProductUnit.fromName((v as String?) ?? 'piece');

/// `stock_movements` row (optionally joined with `profiles.name`).
StockMovement movementFromRow(Row row, String currency) => StockMovement(
      id: row[C.id]! as String,
      productId: row[C.productId]! as String,
      branchId: row[C.branchId]! as String,
      type: MovementType.fromDb(row[StockC.type]! as String),
      delta: qtyOf(row[StockC.qtyDeltaMilli]),
      quantityAfter: qtyOf(row[StockC.qtyAfterMilli]),
      unitCost: row[StockC.unitCostMinor] == null
          ? null
          : Money(row[StockC.unitCostMinor]! as int, currency),
      note: row[StockC.note] as String?,
      profileId: row[C.profileId]! as String,
      profileName: row['profile_name'] as String?,
      createdAt: fromEpochMs(_int(row[C.createdAt])),
    );

/// Movement joined with `products.name` / `products.unit`.
MovementEntry movementEntryFromRow(Row row, String currency) => MovementEntry(
      movement: movementFromRow(row, currency),
      productName: (row['product_name'] as String?) ?? '',
      unit: unitOf(row['product_unit']),
    );

/// Product joined with its level at one branch.
ProductStock productStockFromRow(Row row) => ProductStock(
      productId: row[C.id]! as String,
      name: row[StockC.name]! as String,
      unit: unitOf(row[StockC.unit]),
      quantity: qtyOf(row[StockC.qtyMilli]),
      reorderPoint: qtyOf(row[StockC.reorderPointMilli]),
    );

StockLevel stockLevelFromRow(Row row, String branchId) => StockLevel(
      productId: row[C.id]! as String,
      branchId: branchId,
      quantity: qtyOf(row[StockC.qtyMilli]),
      reorderPoint: qtyOf(row[StockC.reorderPointMilli]),
    );
