import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/stock_status.dart';
import '../../../../core/utils/quantity.dart';

part 'stock_alert.freezed.dart';

@freezed
abstract class StockAlert with _$StockAlert {
  const factory StockAlert({
    required String id,
    required String productId,
    required String productName,
    required String branchId,
    /// [StockStatus.low] or [StockStatus.out].
    required StockStatus level,
    required Quantity quantity,
    required Quantity reorderPoint,
    required DateTime triggeredAt,
    DateTime? resolvedAt,
    DateTime? acknowledgedAt,
  }) = _StockAlert;
}

@freezed
abstract class AlertCounts with _$AlertCounts {
  const factory AlertCounts({@Default(0) int low, @Default(0) int out}) = _AlertCounts;
  const AlertCounts._();
  int get total => low + out;
}
