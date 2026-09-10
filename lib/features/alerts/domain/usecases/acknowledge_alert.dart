// OWNER: A4.
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../entities/stock_alert.dart';
import '../repositories/alert_repository.dart';

/// Marks an alert as seen. It stays open until the stock is back above the
/// reorder point, but stops standing out in the list.
class AcknowledgeAlert {
  const AcknowledgeAlert({
    required this.repository,
    required this.session,
    required this.analytics,
  });

  final AlertRepository repository;
  final SessionReader Function() session;
  final AnalyticsService analytics;

  Future<Result<void>> call(StockAlert alert) async {
    if (!session().can(Permission.viewCatalogue)) {
      return const Err(PermissionFailure('viewCatalogue'));
    }
    final result = await repository.acknowledge(alert.id);
    if (result.isSuccess) {
      await analytics.log(AppEvent.alertOpened, {
        'alert_id': alert.id,
        'product_id': alert.productId,
        'level': alert.level.name,
        'action': 'acknowledged',
      });
    }
    return result;
  }
}
