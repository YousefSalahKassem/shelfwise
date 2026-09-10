// OWNER: A4. Dependency graph of the alerts feature.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/database/db_changes.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/utils/core_providers.dart';
import '../../data/datasources/alert_local_data_source.dart';
import '../../data/repositories/alert_repository_impl.dart';
import '../../domain/entities/stock_alert.dart';
import '../../domain/repositories/alert_repository.dart';
import '../../domain/usecases/acknowledge_alert.dart';
import '../../domain/usecases/open_alert.dart';
import '../../domain/usecases/watch_alerts.dart';

part 'alert_providers.g.dart';

@Riverpod(keepAlive: true)
AlertLocalDataSource alertLocalDataSource(Ref ref) => AlertLocalDataSource(
  ref.watch(appDatabaseProvider),
  ref.watch(clockProvider),
);

@Riverpod(keepAlive: true)
AlertRepository alertRepository(Ref ref) => AlertRepositoryImpl(
  local: ref.watch(alertLocalDataSourceProvider),
  changes: ref.watch(dbChangesProvider),
  session: () => ref.read(sessionControllerProvider),
);

@Riverpod(keepAlive: true)
WatchAlerts watchAlerts(Ref ref) => WatchAlerts(
  repository: ref.watch(alertRepositoryProvider),
  session: () => ref.read(sessionControllerProvider),
);

@Riverpod(keepAlive: true)
AcknowledgeAlert acknowledgeAlert(Ref ref) => AcknowledgeAlert(
  repository: ref.watch(alertRepositoryProvider),
  session: () => ref.read(sessionControllerProvider),
  analytics: ref.watch(analyticsServiceProvider),
);

/// Logs the `alert_opened` pilot event when someone acts on an alert.
@Riverpod(keepAlive: true)
OpenAlert alertOpenedLogger(Ref ref) =>
    OpenAlert(ref.watch(analyticsServiceProvider));

/// Open alerts at the current branch, out of stock first.
@riverpod
Stream<List<StockAlert>> openAlerts(Ref ref) =>
    ref.watch(watchAlertsProvider)();

/// Low/out counts for the nav badge and the stock overview.
@riverpod
Stream<AlertCounts> alertCounts(Ref ref) =>
    ref.watch(watchAlertsProvider).counts();
