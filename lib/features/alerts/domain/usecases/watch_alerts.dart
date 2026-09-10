// OWNER: A4.
import '../../../../core/auth/permission.dart';
import '../../../../core/session/session_reader.dart';
import '../entities/stock_alert.dart';
import '../repositories/alert_repository.dart';

/// Open low/out alerts for the current branch. Staff see them too — they are
/// the ones who receive the delivery.
class WatchAlerts {
  const WatchAlerts({required this.repository, required this.session});

  final AlertRepository repository;
  final SessionReader Function() session;

  bool get _allowed => session().can(Permission.viewCatalogue);

  /// Out of stock first, then low.
  Stream<List<StockAlert>> call() =>
      _allowed ? repository.watchOpen() : Stream.value(const []);

  Stream<AlertCounts> counts() =>
      _allowed ? repository.watchCounts() : Stream.value(const AlertCounts());
}
