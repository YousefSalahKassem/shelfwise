// OWNER: A4.
import '../../../../core/database/db_changes.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../../domain/entities/stock_alert.dart';
import '../../domain/repositories/alert_repository.dart';
import '../datasources/alert_local_data_source.dart';

class AlertRepositoryImpl implements AlertRepository {
  const AlertRepositoryImpl({
    required this.local,
    required this.changes,
    required this.session,
  });

  final AlertLocalDataSource local;
  final DbChanges changes;
  final SessionReader Function() session;

  /// Alerts follow stock: a movement can open or resolve one, and archiving or
  /// renaming a product changes what the list shows.
  static const _watched = {
    DbTable.stockAlerts,
    DbTable.stockLevels,
    DbTable.products,
  };

  String? get _branchId => session().branch?.id;

  @override
  Stream<List<StockAlert>> watchOpen() {
    final branchId = _branchId;
    if (branchId == null) return Stream.value(const []);
    return watchQuery(changes, _watched, () => local.open(branchId));
  }

  @override
  Stream<AlertCounts> watchCounts() {
    final branchId = _branchId;
    if (branchId == null) return Stream.value(const AlertCounts());
    return watchQuery(changes, _watched, () => local.counts(branchId));
  }

  @override
  Future<Result<void>> acknowledge(String alertId) async {
    final branchId = _branchId;
    if (branchId == null) return const Err(NotFoundFailure('session'));
    try {
      final done = await local.acknowledge(alertId, branchId);
      if (!done) return Err(NotFoundFailure('alert', alertId));
      changes.notify({DbTable.stockAlerts});
      return ok;
    } on Object catch (e) {
      return Err(StorageFailure('alert acknowledge failed', e));
    }
  }
}
