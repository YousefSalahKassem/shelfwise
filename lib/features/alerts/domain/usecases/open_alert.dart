// OWNER: A4.
import '../../../../core/analytics/analytics_service.dart';
import '../entities/stock_alert.dart';

/// The pilot metric behind "do alerts change how owners reorder?" (business
/// plan §9): logged when someone acts on an alert — taps it to open the product
/// or starts receiving stock from it.
class OpenAlert {
  const OpenAlert(this._analytics);

  final AnalyticsService _analytics;

  Future<void> call(StockAlert alert, {required String action}) =>
      _analytics.log(AppEvent.alertOpened, {
        'alert_id': alert.id,
        'product_id': alert.productId,
        'level': alert.level.name,
        'action': action,
      });
}
