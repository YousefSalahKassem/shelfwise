import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/stock_status.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/quantity.dart';

part 'stock.freezed.dart';

enum MovementType {
  receive('receive'),
  sale('sale'),
  damaged('damaged'),
  expired('expired'),
  adjustment('adjustment'),
  count('count'),
  transferIn('transfer_in'),
  transferOut('transfer_out');

  const MovementType(this.dbName);
  final String dbName;

  /// +1 adds stock, -1 removes, 0 = signed by the caller (adjustment/count).
  int get sign => switch (this) {
        receive || transferIn => 1,
        sale || damaged || expired || transferOut => -1,
        adjustment || count => 0,
      };

  static MovementType fromDb(String v) => MovementType.values.firstWhere((t) => t.dbName == v);
}

@freezed
abstract class StockLevel with _$StockLevel {
  const factory StockLevel({
    required String productId,
    required String branchId,
    required Quantity quantity,
    required Quantity reorderPoint,
  }) = _StockLevel;

  const StockLevel._();

  StockStatus get status =>
      StockStatus.of(qtyMilli: quantity.milli, reorderPointMilli: reorderPoint.milli);
}

@freezed
abstract class StockMovement with _$StockMovement {
  const factory StockMovement({
    required String id,
    required String productId,
    required String branchId,
    required MovementType type,
    /// Signed change.
    required Quantity delta,
    required Quantity quantityAfter,
    Money? unitCost,
    String? note,
    required String profileId,
    String? profileName,
    required DateTime createdAt,
  }) = _StockMovement;
}

@freezed
abstract class MovementInput with _$MovementInput {
  const factory MovementInput({
    required String productId,
    required MovementType type,
    /// Magnitude for typed movements; signed for adjustment/count.
    required Quantity quantity,
    Money? unitCost,
    String? note,
  }) = _MovementInput;
}
