import '../../../../core/error/result.dart';
import '../entities/stock_alert.dart';

abstract interface class AlertRepository {
  /// Open alerts, out-of-stock first.
  Stream<List<StockAlert>> watchOpen();

  Stream<AlertCounts> watchCounts();

  Future<Result<void>> acknowledge(String alertId);
}
