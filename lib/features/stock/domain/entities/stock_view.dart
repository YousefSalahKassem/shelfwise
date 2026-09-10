// OWNER: A4. Read models and write results that the frozen stock entities
// (stock.dart) don't cover. Pure Dart — no Flutter, sqflite or Riverpod.
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/stock_status.dart';
import '../../../../core/utils/quantity.dart';
import 'stock.dart';

part 'stock_view.freezed.dart';

/// A product with its current stock at the session branch. Used by the receive
/// and adjust flows, which need the name and unit next to the quantity.
@freezed
abstract class ProductStock with _$ProductStock {
  const factory ProductStock({
    required String productId,
    required String name,
    required ProductUnit unit,
    required Quantity quantity,
    required Quantity reorderPoint,
  }) = _ProductStock;

  const ProductStock._();

  StockStatus get status =>
      StockStatus.of(qtyMilli: quantity.milli, reorderPointMilli: reorderPoint.milli);
}

/// A ledger row with the product it belongs to (movement lists show names).
@freezed
abstract class MovementEntry with _$MovementEntry {
  const factory MovementEntry({
    required StockMovement movement,
    required String productName,
    @Default(ProductUnit.piece) ProductUnit unit,
  }) = _MovementEntry;
}

/// An alert that was opened (or escalated) inside a movement transaction.
/// Reported after the commit so the use case can notify and log it.
@freezed
abstract class OpenedAlert with _$OpenedAlert {
  const factory OpenedAlert({
    required String alertId,
    required String productId,
    required String productName,
    @Default(ProductUnit.piece) ProductUnit unit,
    /// [StockStatus.low] or [StockStatus.out].
    required StockStatus level,
    required Quantity quantity,
    required Quantity reorderPoint,
  }) = _OpenedAlert;
}

/// Result of one `recordBatch` transaction.
@freezed
abstract class MovementBatch with _$MovementBatch {
  const factory MovementBatch({
    @Default(<StockMovement>[]) List<StockMovement> movements,
    @Default(<OpenedAlert>[]) List<OpenedAlert> openedAlerts,
  }) = _MovementBatch;
}
